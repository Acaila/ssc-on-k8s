# Docker Desktop Kubernetes Guide

This guide documents the current Docker Desktop Kubernetes workflow that has
been validated in this repository.

It assumes the container images have already been built locally by following
[images/README.md](../../images/README.md).

## Audience

This guide is written for an operator who is comfortable with:

- Docker Desktop
- `kubectl`
- reading Kubernetes manifests
- basic Linux and Salt administration

## What This Guide Covers

This workflow validates:

- local Docker Desktop Kubernetes deployment of PostgreSQL, Redis, RaaS, and
  salt-master
- RaaS on HTTPS `443`
- salt-master registration against RaaS over HTTPS
- first-login approval of the pending Salt master key

This workflow does not yet claim:

- a finished TKG deployment story
- shared-storage validation for multiple Salt masters
- minion lifecycle validation with a real enrolled minion

## Prerequisites

You need:

- Docker Desktop running locally
- Kubernetes enabled in Docker Desktop
- locally built images:
  - `localhost/ssc-raas:8.18.3`
  - `localhost/ssc-salt-master:3006-lts`

Verify Docker first:

```bash
docker version
docker info
docker run --rm hello-world
```

Verify the cluster:

```bash
kubectl config current-context
kubectl get nodes
kubectl get pods -A
```

Expected context:

```text
docker-desktop
```

## Cluster Settings

For the currently validated path, use Docker Desktop Kubernetes in `kubeadm`
mode.

Do not use Docker Desktop Kubernetes in `kind` mode for this repo if you want
to reuse the locally built `localhost/...` images directly. The validated
runtime path here is the `kubeadm` mode.

Single-node Kubernetes is enough for the current validation scope.

## 1. Deploy The Stack

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
entrypoints generate them on first start, create the optional bootstrap secret:

```bash
kubectl -n aria-config create secret generic ssc-bootstrap \
  --from-literal=customer_id="$(uuidgen | tr '[:upper:]' '[:lower:]')" \
  --from-literal=cluster_id="$(uuidgen)"
```

If you skip that secret:

- RaaS generates and persists a deployment-unique `customer_id`
- salt-master generates and persists a deployment-unique `cluster_id`

Apply the consolidated kustomize entry point:

```bash
kubectl apply -k .
```

The validated manifests do not hardcode a storage class. They follow the
cluster default storage class provided by Docker Desktop Kubernetes.

## 2. Watch First Boot

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

## 3. Review The Logs

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

## 4. Access The RaaS UI

For the currently validated Docker Desktop workflow, the RaaS service is
reachable on:

```text
https://localhost
```

Because the lab generates a self-signed certificate when no certificate is
provided, a browser warning is expected on first access.

## 5. Approve The Salt Master Key

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
  - `cmd.get_master_cmd`
  - `fs.get_envs`
  - `master.save_master`
  - `minions.save_minion_key_state`
  - `masterfs.save_masterfs`
  - `ret.save_event`

## 6. Notes

- The validated Docker Desktop Kubernetes path uses the already-built local
  images directly.
- The PVC manifests intentionally rely on the cluster default storage class
  instead of hardcoding a local-lab-specific class name.
- The same RaaS VIP localization gap still exists here as in the other local
  runtime paths. It does not block the validated RaaS/salt-master workflow.
