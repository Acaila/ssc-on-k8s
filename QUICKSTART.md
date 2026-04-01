# Quick Start

This quick start is the shortest currently validated path from a fresh clone to
logging in to RaaS in a browser.

It uses:

- Docker Desktop
- Docker Desktop Kubernetes in `kubeadm` mode
- locally built images
- the checked-in Kubernetes manifests in this repo

For more detailed platform notes, see:

- [images/README.md](images/README.md)
- [deployment/docker-desktop-kubernetes/README.md](deployment/docker-desktop-kubernetes/README.md)
- [deployment/salt-admin-usage.md](deployment/salt-admin-usage.md)

## 1. Check Out The Repo

```bash
git clone <repo-url>
cd ssc-on-k8s
```

## 2. Download The Broadcom Bundle

Obtain the official Broadcom RaaS installer bundle for the SSC release you are
targeting.

Example file name used in this repo:

```text
bundle/VMware_Salt_RaaS-8.18.3-25253633.el9_Installer.tar.gz
```

The separate air-gapped minion bundle can also be kept in `bundle/`, but it is
not used by this quick start.

## 3. Install Docker Desktop And Enable Kubernetes

Install Docker Desktop and make sure it is running.

Verify Docker:

```bash
docker version
docker info
docker run --rm hello-world
```

Then enable Kubernetes in Docker Desktop with these settings:

- cluster type: `kubeadm`
- nodes: `1`

After the cluster is ready, verify it:

```bash
kubectl config current-context
kubectl get nodes
kubectl get pods -A
```

Expected context:

```text
docker-desktop
```

## 4. Extract The Bundle

Extract the installer bundle into the top-level `bundle/` directory:

```bash
tar -xzf bundle/VMware_Salt_RaaS-8.18.3-25253633.el9_Installer.tar.gz -C bundle
```

Expected extracted root:

```text
bundle/sse-installer
```

## 5. Build The Local Images

Stage the Broadcom artifacts and build the images.

The build wrappers already run the same preflight checks automatically, so the
explicit preflight commands below are optional but useful when you want a fast
sanity check before a longer image build:

```bash
./scripts/prep-bundle.sh bundle/sse-installer
./scripts/preflight-build.sh raas
./scripts/preflight-build.sh salt-master
./scripts/build-raas.sh
./scripts/build-salt-master.sh
```

## 6. Confirm The Images Are In The Local Docker Image Store

The validated Docker Desktop Kubernetes workflow uses the locally built images
directly. There is no separate registry push step in this quick start.

Confirm the images exist:

```bash
docker images | grep -E 'ssc-raas|ssc-salt-master'
```

Expected tags:

```text
localhost/ssc-raas:8.18.3
localhost/ssc-salt-master:3006-lts
```

## 7. Start The Stack In Kubernetes

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

Optional: pin deployment-specific identifiers instead of letting the entrypoint
generate them on first start:

```bash
kubectl -n aria-config create secret generic ssc-bootstrap \
  --from-literal=customer_id="$(uuidgen | tr '[:upper:]' '[:lower:]')" \
  --from-literal=cluster_id="$(uuidgen)"
```

Then apply the consolidated kustomize entry point:

```bash
kubectl apply -k .
```

Watch the stack come up:

```bash
kubectl -n aria-config get pvc,pods,svc,endpoints -o wide
kubectl -n aria-config get pods -w
kubectl -n aria-config rollout status deployment/raas --timeout=180s
kubectl -n aria-config rollout status deployment/salt-master --timeout=180s
```

Expected steady state:

- `postgres` running
- `redis` running
- `raas` running
- `salt-master` running

## 8. Log In To The Browser Endpoint

Open:

```text
https://localhost
```

Because the lab generates a self-signed certificate when no certificate is
provided, a browser warning is expected on first access.

If local port `443` is already in use on the workstation, forward the RaaS
service to another local port instead:

```bash
kubectl -n aria-config port-forward svc/raas 8443:443
```

Then browse to:

```text
https://localhost:8443
```

For the currently validated first-login flow, use:

- username: `root`
- password: `salt`

After login:

1. approve the pending Salt master key

## 9. Verify Salt-Master Registration

After approving the key, confirm the salt-master moves from `pending` to
`accepted`:

```bash
kubectl -n aria-config logs deployment/salt-master --tail=200
```

Healthy steady-state log patterns include:

- `Auth key state: accepted`
- `fs.get_envs`
- `master.save_master`
- `minions.save_minion_key_state`
- `masterfs.save_masterfs`
- `ret.save_event`

## 10. Prove The Salt Master Is Usable

This stack is not just the RaaS UI. It also gives you a working Salt master
that you can access from the command line.

Open a shell on the running master:

```bash
kubectl -n aria-config exec -it deploy/salt-master -- sh
```

Once inside the container, you can run normal Salt commands such as:

```bash
salt-run fileserver.envs
salt-call --local test.version
```

Expected results from a fresh deployment include:

- `salt-run fileserver.envs` returning `base`
- `salt-call --local test.version` returning the Salt version from the master

You can also run those commands directly from the workstation without opening
an interactive shell first:

```bash
kubectl -n aria-config exec deploy/salt-master -- salt-run fileserver.envs
kubectl -n aria-config exec deploy/salt-master -- salt-call --local test.version
```

After you have one or more minions enrolled to this master, typical day-to-day
Salt commands look like:

```bash
kubectl -n aria-config exec deploy/salt-master -- salt '*' test.ping
kubectl -n aria-config exec deploy/salt-master -- salt '*' pillar.items
```

On a fresh quickstart deployment with no enrolled minions yet, those targeting
commands may return no matches. That is expected until minions are connected.

For more detail on interactive shell usage, one-off commands, and container
operating patterns for traditional Salt administrators, see:

- [deployment/salt-admin-usage.md](deployment/salt-admin-usage.md)
