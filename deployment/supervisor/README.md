# Deploy SSC directly onto Supervisor

This is the generic phase-2 deployment path. It runs RaaS, Salt master,
PostgreSQL and Redis as native vSphere Pods in an existing Supervisor namespace.
No workload cluster is created. Supply your own environment settings; no private
lab addresses, registry, storage policy or Git destination are embedded.

## 1. Prepare the platform services

Ask your platform administrator to provision or identify:

| Dependency | Required outcome |
| --- | --- |
| Supervisor | Native vSphere Pod support, namespace and renewable API access |
| Namespace resources | Sufficient CPU/memory quota and reservations; assigned storage policy and at least 37 GiB for five PVCs |
| Private OCI registry, such as Harbor | Reachable HTTPS registry, private project, push and pull identities, native-runtime CA trust |
| Contour | Healthy controller/Envoy, HTTPProxy API, target namespace watched, reachable ingress address |
| Networking | LoadBalancer addresses, registry egress, DNS, time synchronization and required SSC flows |

If Harbor or Contour is absent, install a service version compatible with
**your Supervisor release** using its platform lifecycle workflow. Record its
actual namespace, endpoint, network and storage choices. This repository does
not install or upgrade shared platform services.
[Broadcom's Harbor/Contour guidance](https://knowledge.broadcom.com/external/article/454210/best-practices-for-deploying-contour-and.html)
links installation instructions. For automated certificates, use an existing
compatible cert-manager installation and authorized issuer; see
[certificate setup](certificates.md).

Choose Contour routing by testing reachability **from Envoy**:

- `direct`: Envoy can reach workload pods; HTTPProxy routes to `ssc-raas`.
- `bridge`: Envoy cannot reach workload pods but can reach a namespace
  LoadBalancer. An additional RaaS LoadBalancer and selectorless Service bridge
  that path. Its external backend mapping is bootstrapped after IP allocation.

Namespace access does not imply cluster-admin rights. The operator applies
the generated Kustomization directly using an explicit workload context.

## 2. Publish locally built images

Complete the [local build](../../images/README.md), then follow the
[OCI/Harbor procedure](registry.md). Publish all four runtime images into your
private project. Record their tags or preferably immutable `@sha256:` digests.
Local workstation images are not available to native pods automatically.

## 3. Generate your Kustomize overlay

Requires Python 3 (standard library only), kubectl with Kustomize support, and
working platform login. From the repository root:

```bash
mkdir -p .supervisor
cp deployment/supervisor/settings.example.json .supervisor/settings.json
# Edit every setting for your environment before generating.
python3 scripts/configure-supervisor.py --config .supervisor/settings.json
```

Settings include namespace, storage class, SSC/Salt DNS names, master identity,
four complete image references, Contour mode and TLS mode. The example uses
reserved example domains. No Git server or deployment controller is required.
Older generated settings containing Git/Argo fields must be migrated to the new
example schema; preserve existing overlays and credentials when doing so.

For `environment: my-supervisor`, the output is:

```text
deployment/environments/my-supervisor/
  settings.json
  workloads/                 # apply with kubectl -k
    kustomization.yaml
    httpproxy.yaml
    contour-backend.yaml     # bridge mode only
  bootstrap/                 # applied separately by the operator
    certificate.yaml         # cert-manager mode only
    postgres-keepalives.sql
```

The generator makes no cluster changes and refuses to overwrite an existing
environment. Generated directories and `.supervisor/` are ignored by default.
Keep the component directories and generated overlay in the same repo so its
relative Kustomize references continue to resolve. Use one SSC instance per
namespace; the generated resource/secret names use the fixed `ssc-` prefix.

Review the generated files. Further customization (resource sizing, ingress
class, storage sizes, annotations or additional configuration) belongs in your
own overlay. Do not edit the shared component manifests for environment values.

## 4. Supply secrets and verify prerequisites

Set these shell variables to your actual context and generated environment:

```bash
export SSC_CONTEXT=your-supervisor-context
export SSC_NAMESPACE=my-ssc-namespace
export SSC_ENV=deployment/environments/my-supervisor
export SSC_HOSTNAME=ssc.example.com
kssc() { kubectl --context "$SSC_CONTEXT" -n "$SSC_NAMESPACE" "$@"; }
```

### Secret contract

| Secret | Required content |
| --- | --- |
| `ssc-db` | `name`, `user`, `password`; initial PostgreSQL database/user and RaaS authentication |
| `ssc-registry` | `.dockerconfigjson`, type `kubernetes.io/dockerconfigjson`; pull-only robot |
| `ssc-web-tls` | `tls.crt`, `tls.key`, type `kubernetes.io/tls`; certificate for your SSC hostname |
| `ssc-bootstrap` (optional) | Stable `customer_id` and `cluster_id` UUIDs |

Create first-install secrets from restricted files supplied by your vault:

```bash
kssc create secret generic ssc-db \
  --from-file=name=/secure/ssc-db/name \
  --from-file=user=/secure/ssc-db/user \
  --from-file=password=/secure/ssc-db/password
# Complete certificates.md for your TLS mode and create ssc-registry
# using the registry guide, then:
python3 scripts/check-supervisor.py --environment "$SSC_ENV" \
  --context "$SSC_CONTEXT"
```

Credential files must have no trailing newline. Reuse existing identities and
secrets on later deployments. Generated identities persist on PVCs if the
optional bootstrap secret is omitted. Changing a Secret alone does not rotate
an initialized PostgreSQL role. See [secret handling](../../secrets/README.md).

Follow [certificate setup](certificates.md) before running preflight.
The checker reads API availability, permissions and secret presence, renders
the overlay, and submits a server-side **dry-run**. It does not apply changes.
It cannot establish native-pod image-pull trust, free storage, Envoy routing or
client CA trust; verify those with the platform administrator.
Deployment dry-run does not prove actual native Pod admission.

## 5. Apply the generated Kustomization

Review the rendered resources and changes before applying. `kubectl diff` exits
1 when differences exist; other failures need investigation.

```bash
kubectl kustomize "$SSC_ENV/workloads"
kssc diff -k "$SSC_ENV/workloads"
kssc apply -k "$SSC_ENV/workloads"
for component in postgres redis raas salt-master; do
  kssc rollout status "deployment/ssc-$component" --timeout=15m || break
done
kssc get pods,pvc,svc -l app.kubernetes.io/part-of=ssc
```

Stop and investigate a failed rollout before acceptance. Deployment changes are
applied explicitly; there is no automatic reconciliation from Git. Keep reviewed
non-secret configuration under version control if desired. Avoid `--prune` and
`kubectl delete -k` for this stateful stack: both can remove persistent claims.
Direct deployment does not provide deletion protection for PVCs.

Wait for PostgreSQL, then configure keepalives on this dedicated instance:

```bash
# Substitute your chosen initial database and role if different.
kssc exec -i deployment/ssc-postgres -- psql -v ON_ERROR_STOP=1 -U raas -d raas \
  < "$SSC_ENV/bootstrap/postgres-keepalives.sql"
```

This persisted setting shortens detection of disappeared RaaS clients that can
otherwise leave scheduler advisory locks held for a long TCP timeout.

## 6. Complete routing and DNS

For **direct** mode, skip the bridge commands. For **bridge** mode:

```bash
kssc get svc ssc-raas-ingress
# Set SSC_RAAS_INGRESS_IP to the assigned ingress IPv4 address, not a pod IP.
python3 scripts/contour-supervisor-backend.py --environment "$SSC_ENV" \
  --address "$SSC_RAAS_INGRESS_IP"
kssc apply -f "$SSC_ENV/bootstrap/contour-endpoints.json"
kssc get endpointslices -l kubernetes.io/service-name=ssc-raas-contour
```

The selectorless bridge's slices must contain only the ingress LB address.
The helper writes a manifest; it does not apply it. Kubernetes mirrors Endpoints
into EndpointSlices. This path requires platform support for that mechanism.
Reconcile the mapping manually whenever the LB address changes. Preserve the selectorless Service.

Point your SSC hostname to **Contour Envoy** and your Salt hostname to the
**`ssc-salt-master` LoadBalancer**. The Salt hostname setting records the desired
DNS name; it does not create DNS records or alter native Salt transport.
For Windows DNS, the optional [PowerShell helper](../../scripts/set-supervisor-dns.ps1)
accepts the zone, relative record names, assigned IPv4 addresses and DNS server.
It checks conflicts before adding missing records. Other DNS providers can be
managed with their normal tooling; there is no DNS-provider dependency.

| Flow | Required destination |
| --- | --- |
| Workstation/native runtime → registry | Registry HTTPS and token service |
| Browser → Contour | HTTPS 443 |
| Envoy → RaaS | Pod 8443 directly, or bridge LB 443 → pod 8443 |
| Master → RaaS | Internal Service 443 → pod 8443 |
| RaaS → PostgreSQL / Redis | Internal 5432 / 6379 |
| Minions → Salt LB | TCP 4505 and 4506 |

Registry trust, browser-to-Contour TLS and upstream RaaS trust are separate.
The template uses upstream TLS without certificate verification and inherits
master-to-RaaS verification disabled from the current container configuration.
Trusted upstream/master certificate configuration remains work before broader
use. Image-pull authentication does not configure native-runtime CA trust.

## 7. Accept the deployment

- Four Deployments finish rollout, four pods are Ready and five PVCs Bound; HTTPProxy is Valid.
- HTTPS and login work through your DNS name with the intended certificate.
- Complete initial SSC administrator setup and licensed feature configuration
  using the product's documentation; store credentials in your vault.
- Verify the pending master's fingerprint before approval; confirm enrollment.
- Enroll one disposable minion, submit a scoped `test.ping` through SSC, and
  verify both a successful return **and completed job status**.
- Record image digests, Git revision, versions and results. Test controlled
  replacement and backups before entrusting important data to the stack.

## Ownership and current automation boundary

The generator automates environment-specific manifests; preflight checks are
scripted. The operator applies workload resources directly. Platform services,
credentials, registry publication, DB tuning, DNS, optional bridge mapping and
SSC enrollment remain explicit steps. Certificate issuance/renewal is managed
by cert-manager when selected, or by the operator for supplied secrets.

The runtime design has been exercised, but the generic direct-deployment and
certificate workflow still needs a clean-namespace end-to-end rehearsal.
See [operations and remaining work](operations.md).
