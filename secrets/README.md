# Kubernetes Secrets

The current Kubernetes manifests expect a database secret for PostgreSQL.

Create it with:

```bash
kubectl -n aria-config create secret generic ssc-db \
  --from-literal=name=raas \
  --from-literal=user=raas \
  --from-literal=password='raaspass'
```

Redis does not currently require a Kubernetes secret in the validated manifest
set.

## Optional Bootstrap Identity Secret

The RaaS and salt-master manifests can also consume an optional bootstrap
secret for deployment-specific identity values:

```bash
kubectl -n aria-config create secret generic ssc-bootstrap \
  --from-literal=customer_id="$(uuidgen)" \
  --from-literal=cluster_id="$(uuidgen)"
```

An example manifest shape is provided at `secrets/ssc-bootstrap.example.yaml`
if you prefer to manage that secret declaratively.

The currently consumed keys are:

- `customer_id`
  RaaS database namespace identifier. If omitted, the RaaS entrypoint
  generates a UUID on first start and persists it for later restarts.
- `cluster_id`
  Salt master cluster identifier. If omitted, the salt-master entrypoint
  generates a UUID on first start and persists it with the master-local PVC.

This directory is also the right place to document later additions such as:

- TLS secrets for mounted server certificates
- registry pull secrets if the images move to a private registry
- any per-platform secret handling differences that matter to operators

## RaaS First Login

The validated deployment path currently relies on the Broadcom product default
RaaS login for first access to the UI:

- username: `root`
- password: `salt`

That is used for first login so an operator can approve the pending Salt master
key and complete initial validation.
