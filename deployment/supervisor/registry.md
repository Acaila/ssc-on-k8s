# Private OCI registry / Harbor

This is the handoff between local builds and Supervisor deployment. OCI here
means container-image storage. The generated Kustomization is applied directly with kubectl. Publishing an OCI chart or manifest bundle
is a separate packaging option, not implemented or needed for this path.

## Registry setup

Use an existing, compatible Harbor service or another private OCI registry.
For Harbor, the registry administrator:

1. Verifies its reachable HTTPS endpoint, external URL/token endpoint and CA
   chain. Use a hostname or IP actually covered by its certificate, not a
   placeholder external URL from sample service values.
2. Creates a **private** project, such as `ssc`, with sufficient quota and a
   retention policy that preserves both the deployed release and rollback images.
3. Creates a short-lived build robot with repository pull/push rights and a
   separate runtime robot with pull-only rights, scoped to that project.
4. Stores robot secrets in the operator's vault and assigns a renewal owner.
   Choose an explicit robot expiration policy. Registry pull secrets
   do not renew themselves, and cached images can hide expiry until replacement.

Harbor's [project robot account documentation](https://goharbor.io/docs/2.14.0/working-with-projects/project-configuration/create-robot-accounts/)
explains project scope, combined pull/push permission and secret export/renewal.
Never commit robot secrets, registry auth JSON or proprietary images to Git.

Establish registry CA trust on both the build workstation and native Supervisor
image-pull path using the platform's supported configuration. `imagePullSecrets`
provide authentication, not CA trust. A successful local push does not prove
that ESXi/native pods can pull. Do not make TLS bypass the normal installation path.

## Publish the release

The following Docker example assumes phase 1 produced the default local tags.
Choose a new release identifier and your actual registry endpoint. Use Podman's
matching tag/push/login commands if the images were built in Podman's image store.

```bash
export SSC_REGISTRY=registry.example.com
export SSC_PROJECT=ssc
export SSC_RAAS_TAG=8.18.3-your-release
export SSC_MASTER_TAG=3006-lts-your-release
# Interactive login with the project-scoped build robot; no password in argv.
docker login "$SSC_REGISTRY"

docker tag localhost/ssc-raas:8.18.3 "$SSC_REGISTRY/$SSC_PROJECT/raas:$SSC_RAAS_TAG"
docker tag localhost/ssc-salt-master:3006-lts "$SSC_REGISTRY/$SSC_PROJECT/salt-master:$SSC_MASTER_TAG"
docker push "$SSC_REGISTRY/$SSC_PROJECT/raas:$SSC_RAAS_TAG"
docker push "$SSC_REGISTRY/$SSC_PROJECT/salt-master:$SSC_MASTER_TAG"

# Mirror the other runtime dependencies as well.
docker pull --platform linux/amd64 docker.io/library/postgres:15-alpine
docker pull --platform linux/amd64 docker.io/library/redis:7-alpine
docker tag postgres:15-alpine "$SSC_REGISTRY/$SSC_PROJECT/postgres:15-alpine"
docker tag redis:7-alpine "$SSC_REGISTRY/$SSC_PROJECT/redis:7-alpine"
docker push "$SSC_REGISTRY/$SSC_PROJECT/postgres:15-alpine"
docker push "$SSC_REGISTRY/$SSC_PROJECT/redis:7-alpine"
docker logout "$SSC_REGISTRY"
```

Record the pushed manifest digests in the release record. Prefer digest-pinned
Kustomize image entries for promotion; remove `newTag` when supplying `digest`:

```yaml
images:
  - name: localhost/ssc-raas
    newName: registry.example.com/ssc/raas
    digest: sha256:REPLACE_WITH_ACTUAL_PUSHED_MANIFEST_DIGEST
```

That example is deliberately not an apply-ready manifest. The example settings use release tags and mutable PostgreSQL/Redis tags;
replace them with your recorded digests for an immutable deployment. Never overwrite
an already deployed release tag as an upgrade mechanism. Update the overlay image reference and apply it explicitly to promote a release.

## Supply pull-only credentials to the namespace

Using the `kssc` function/context established in the deployment guide, generate
an isolated Docker auth file for the pull robot. With a fresh Docker config,
credentials are written to that config instead of reusing an unrelated account:

```bash
ssc_auth_dir="$(mktemp -d)"
chmod 700 "$ssc_auth_dir"
# Log in as the PULL-ONLY robot, not the build robot.
docker --config "$ssc_auth_dir" login "$SSC_REGISTRY"
kssc create secret generic ssc-registry \
  --type=kubernetes.io/dockerconfigjson \
  --from-file=.dockerconfigjson="$ssc_auth_dir/config.json"
docker --config "$ssc_auth_dir" logout "$SSC_REGISTRY"
rm -rf "$ssc_auth_dir"
unset ssc_auth_dir
```

This is a first-install example; update an existing Secret using your secret
manager's rotation process. The Secret must contain usable registry auth, not
only a workstation-specific credential-helper reference. Its registry authority
must match the image names. All four Deployments and their init containers must
use private references and the `ssc-registry` pull secret; `imagePullPolicy:
Never` and `localhost/...` images belong only to local development.

## Publication exit criteria

- All four image repositories exist and the selected Linux amd64 artifacts pull
  using the runtime robot; the platform trusts their registry CA.
- Installer checksum, repository commit, resolved package versions, build
  architecture and pushed digests are recorded without copying licensed payloads.
- Overlay references identify those artifacts; prior compatible release artifacts
  remain available for rollback. Database migration compatibility is checked
  separately; reverting an image is not automatically a database rollback.
- Credentials are retained in the vault/namespace secret, with renewal ownership;
  temporary build credentials are revoked or allowed only their intended lifetime.
