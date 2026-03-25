# Minikube Deployment Guide For macOS

This guide documents the current macOS Minikube workflow that has been
validated in this repository.

It assumes the container images have already been built locally by following
[images/README.md](../../images/README.md).

## Audience

This guide is written for an operator who is comfortable with:

- Docker Desktop
- Minikube and `kubectl`
- reading Kubernetes manifests
- basic Linux and Salt administration

## What This Guide Covers

This workflow validates:

- local Minikube deployment of PostgreSQL, Redis, RaaS, and salt-master
- RaaS on HTTPS `443`
- salt-master registration against RaaS over HTTPS
- persistence of the RaaS encryption key across pod restart

This workflow does not yet claim:

- a finished TKG deployment story
- shared-storage validation for multiple Salt masters
- minion lifecycle validation with a real enrolled minion

## Prerequisites

You need:

- Docker Desktop running on macOS
- `minikube`
- `kubectl`
- locally built images:
  - `localhost/ssc-raas:8.18.3`
  - `localhost/ssc-salt-master:3006-lts`

Verify Docker first:

```bash
docker version
docker info
docker run --rm hello-world
```

Verify tool versions:

```bash
minikube version
kubectl version --client
```

## 1. Start Or Refresh The Cluster

If an old cluster profile is in an unknown state, delete it and recreate it:

```bash
minikube delete --all --purge
minikube start --driver=docker
```

Then confirm the control plane is healthy:

```bash
kubectl get nodes
kubectl get pods -A
minikube status
```

## 2. Load The Local Images Into Minikube

Load the locally built images:

```bash
minikube image load localhost/ssc-raas:8.18.3
minikube image load localhost/ssc-salt-master:3006-lts
```

The Kubernetes manifests in this repo use `imagePullPolicy: Never` for the
Broadcom-based images, so the cluster expects those tags to already exist in
the node runtime.

## 3. Deploy The Stack

Create the namespace:

```bash
kubectl apply -f namespace.yaml
```

Create the database secret:

```bash
kubectl -n aria-config create secret generic ssc-db \
  --from-literal=name=raas \
  --from-literal=user=raas \
  --from-literal=password='raaspass'
```

If you want to pin deployment-specific identifiers instead of letting the
entrypoints generate them on first start, apply the optional bootstrap secret:

```bash
kubectl -n aria-config create secret generic ssc-bootstrap \
  --from-literal=customer_id="$(uuidgen)" \
  --from-literal=cluster_id="$(uuidgen)"
```

If you skip that secret:

- RaaS generates and persists a deployment-unique `customer_id`
- salt-master generates and persists a deployment-unique `cluster_id`

Create the PVCs:

```bash
kubectl apply -f storage/pvc-postgres.yaml
kubectl apply -f storage/pvc-redis.yaml
kubectl apply -f storage/pvc-raas.yaml
kubectl apply -f storage/pvc-salt-master.yaml
kubectl apply -f storage/pvc-salt-minion-artifacts.yaml
```

Deploy the services:

```bash
kubectl apply -f postgres/
kubectl apply -f redis/
kubectl apply -f raas/
kubectl apply -f salt-master/
```

## 4. Watch First Boot

Check the stack state:

```bash
kubectl -n aria-config get pvc,pods,svc,endpoints -o wide
```

Expected steady-state result:

- `postgres` running
- `redis` running
- `raas` running
- `salt-master` running
- service endpoints populated for all four services

## 5. Review The Logs

RaaS:

```bash
kubectl -n aria-config logs deployment/raas --tail=200
```

Salt master:

```bash
kubectl -n aria-config logs deployment/salt-master --tail=200
```

Expected startup behavior:

- RaaS seeds `/etc/raas/raas`
- RaaS generates or uses TLS material for `443`
- RaaS persists its encryption key to the dedicated persistence path
- salt-master starts as user `salt`
- salt-master connects to `https://raas:443`
- before key approval, salt-master reports `Auth key state: pending`

## 6. Access The RaaS UI

The manifests publish RaaS as a `LoadBalancer` service.

On a local Minikube setup, expose the service from the cluster to the laptop:

```bash
minikube tunnel
```

Then check the services:

```bash
kubectl -n aria-config get svc
```

For the currently validated local workflow, the RaaS service is reachable on:

```text
https://127.0.0.1
```

Because the lab generates a self-signed certificate when no certificate is
provided, a browser warning is expected on first access.

## 7. Approve The Salt Master Key

Log in to the RaaS UI and approve the pending Salt master key.

For the currently validated first-login flow, use the Broadcom default RaaS
credentials:

- username: `root`
- password: `salt`

After approval, recheck the salt-master logs:

```bash
kubectl -n aria-config logs deployment/salt-master --tail=200
```

Expected steady-state result:

- `Auth key state: accepted`
- successful SSE calls such as:
  - `fs.get_envs`
  - `master.save_master`
  - `minions.save_minion_key_state`
  - `masterfs.save_masterfs`
  - `ret.save_event`

## 8. Validate RaaS Key Persistence

The current RaaS deployment persists only the encryption key, not the entire
runtime tree. That avoids carrying cache and pid files across restarts while
still keeping the database/key relationship intact.

Check that the persisted key exists:

```bash
kubectl -n aria-config exec deploy/raas -- sh -lc \
  'ls -la /etc/raas/pki /persist/raas-state'
```

Then restart RaaS:

```bash
kubectl -n aria-config rollout restart deployment/raas
kubectl -n aria-config rollout status deployment/raas --timeout=180s
```

Recheck the RaaS log:

```bash
kubectl -n aria-config logs deployment/raas --tail=200
```

Expected result:

- the replacement pod logs `Restoring persisted RaaS encryption key`
- RaaS comes back without the earlier key-mismatch failure

## 9. Validate Salt-Master Persistence Boundary

The current manifest intentionally separates:

- master-local PKI/auth state and generated master-local values
- minion trust-state directories

The accepted and pending minion key directories live under:

```text
/etc/salt/pki/master/minions
/etc/salt/pki/master/minions_pre
/etc/salt/pki/master/minions_denied
/etc/salt/pki/master/minions_rejected
/etc/salt/pki/master/minions_autosign
```

In the current manifest, those paths are mounted from a dedicated PVC so they
are not coupled to the master's own identity material, which now persists on
the master-local PVC across redeploys.

The scale-out/shared-master implications of that split are noted in:

- [storage/pvc-salt-minion-artifacts.yaml](../../storage/pvc-salt-minion-artifacts.yaml)
- [salt-master/deployment.yaml](../../salt-master/deployment.yaml)

## 10. Useful Commands

Stack status:

```bash
kubectl -n aria-config get pvc,pods,svc,endpoints -o wide
```

RaaS logs:

```bash
kubectl -n aria-config logs deployment/raas --tail=200
```

Salt master logs:

```bash
kubectl -n aria-config logs deployment/salt-master --tail=200
```

RaaS restart:

```bash
kubectl -n aria-config rollout restart deployment/raas
kubectl -n aria-config rollout status deployment/raas --timeout=180s
```

Salt master restart:

```bash
kubectl -n aria-config rollout restart deployment/salt-master
kubectl -n aria-config rollout status deployment/salt-master --timeout=180s
```

## Known Scope Limits

- This guide documents a validated local Kubernetes workflow on macOS.
- It should be treated as a development and validation path, not a finished
  production deployment guide.
- TKG remains the primary target platform direction for this repository, but
  that runtime guide still needs its own dedicated validation pass.
