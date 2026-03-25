# Image Build Guide

This document covers the current process for building the SSC container images in this repository.

It is intentionally scoped to image preparation and image builds. Runtime bring-up for the lab stack is handled separately by the compose files under [`lab/compose/`](../lab/compose/).

## Scope

The repo currently builds these Broadcom-based images:

- `localhost/ssc-raas:8.18.3`
- `localhost/ssc-salt-master:3006-lts`

The RaaS image is built from the official Broadcom `raas` RPM and supporting RPMs.
The salt-master image installs Salt 3006 LTS from the Salt Project repository and then adds the Broadcom `SSEAPE` plugin wheel plus `pygit2` through `salt-pip` for `gitfs` and `git_pillar` support.

The separate air-gapped minion bundle can live in the top-level `bundle/` directory, but it is not used by the image build flow at this stage.

## Image Boundary

The images in this repo are expected to provide the baseline filesystem layout
for their service.

That means the Dockerfiles and image entrypoints should own things like:

- standard application directories under `/etc`, `/var/lib`, `/var/log`, and `/var/run`
- packaged runtime dependencies and Python modules
- first-boot config rendering that targets the container's writable service paths

This is intentional because it keeps the images usable in more than one runtime:

- direct `docker run` smoke tests
- the checked-in Docker Compose lab
- Kubernetes deployments

When a path is replaced by a mounted volume at runtime, the image content at
that mount point is hidden by the container runtime. In those cases, the image
still defines the expected layout, but the runtime platform is responsible for
preparing the inside of the mounted filesystem.

For operators with a Linux or vSphere background, the practical rule is:

- build the image so it can boot cleanly on its own
- treat mounted volumes like fresh filesystems that may need runtime prep
- do not duplicate the whole directory tree in Kubernetes init containers just
  because the image also creates it

## Prerequisites

You need:

- Docker Desktop or a Docker engine with `docker build` support
- The official Broadcom RaaS installer bundle for the target SSC release
- An extracted copy of that installer bundle

The helper scripts in this repo assume the extracted installer root contains paths like:

```text
salt/sse/eapi_service/files/
salt/sse/eapi_plugin/files/
salt/sse/keys/
```

## 1. Obtain The Official Bundle

Obtain the official Broadcom RaaS installer bundle for the release you are targeting.

Example file currently used in the lab:

```text
bundle/VMware_Salt_RaaS-8.18.3-25253633.el9_Installer.tar.gz
```

This repository does not include Broadcom binaries in git. They must be obtained separately and staged locally.

## 2. Extract The Installer Bundle

Extract the Broadcom installer tarball into the top-level `bundle/` directory or another local path.

Example:

```bash
tar -xzf bundle/VMware_Salt_RaaS-8.18.3-25253633.el9_Installer.tar.gz -C bundle
```

The expected extracted root for the helper scripts is then:

```text
bundle/sse-installer
```

## 3. Stage The Build Inputs

Run the staging helper against the extracted installer root:

```bash
./scripts/prep-bundle.sh bundle/sse-installer
```

This stages the vendor artifacts into the layout expected by the Dockerfiles:

- `bundle/whl/SSEAPE-8.18.3.6-py3-none-any.whl`
- `keys/*.asc`
- `rpms/deps/*.rpm`
- `rpms/raas/*.rpm`

The helper intentionally ignores the separate air-gapped minion bundle.

## 4. Platform Notes

Broadcom currently ships `x86_64` payloads for the RaaS-side artifacts in this repo.

That means:

- `x86_64` desktop hosts can build natively
- non-`x86_64` desktop hosts should build these images as `linux/amd64`

The helper scripts already default to:

```bash
SSC_IMAGE_PLATFORM=linux/amd64
```

when you do not override the variable.

If you need to force a platform explicitly:

```bash
SSC_IMAGE_PLATFORM=linux/amd64 ./scripts/build-raas.sh
SSC_IMAGE_PLATFORM=linux/amd64 ./scripts/build-salt-master.sh
```

## 5. Run Preflight Checks

Before running a full build, use the preflight helper:

```bash
./scripts/preflight-build.sh raas
./scripts/preflight-build.sh salt-master
```

The preflight checks:

- Docker daemon reachability
- whether the required Broadcom inputs are staged or extractable
- whether the selected base image advertises the requested platform

## 6. Build The RaaS Image

Use the wrapper script:

```bash
./scripts/build-raas.sh
```

This script will:

1. confirm the required RaaS RPMs are present
2. auto-run `prep-bundle.sh` if `bundle/sse-installer` exists but staging has not happened yet
3. run the preflight unless `SSC_SKIP_PREFLIGHT=1`
4. build `images/Dockerfile.raas`

Default result:

```text
localhost/ssc-raas:8.18.3
```

## 7. Build The Salt Master Image

Use the wrapper script:

```bash
./scripts/build-salt-master.sh
```

This script will:

1. confirm the `SSEAPE` wheel is present
2. auto-run `prep-bundle.sh` if `bundle/sse-installer` exists but staging has not happened yet
3. run the preflight unless `SSC_SKIP_PREFLIGHT=1`
4. build `images/Dockerfile.salt-master`

Default result:

```text
localhost/ssc-salt-master:3006-lts
```

## 8. Optional Overrides

Useful overrides:

```bash
SSC_RAAS_IMAGE=registry.example.com/ssc/raas:8.18.3 ./scripts/build-raas.sh
SSC_SALT_MASTER_IMAGE=registry.example.com/ssc/salt-master:3006-lts ./scripts/build-salt-master.sh
SSC_BUNDLE_ROOT=/path/to/extracted/sse-installer ./scripts/build-raas.sh
SSC_SKIP_PREFLIGHT=1 ./scripts/build-raas.sh
```

## 9. Build Outputs

After a successful build, confirm the local images exist:

```bash
docker images | grep -E 'ssc-raas|ssc-salt-master'
```

Expected tags:

- `localhost/ssc-raas:8.18.3`
- `localhost/ssc-salt-master:3006-lts`

## 10. Optional Local Docker Bring-Up

If you want to run the lab stack locally after building the images, use the compose files under [`lab/compose/`](../lab/compose/).

For the cleanest operator workflow, choose one style per session:

- use the split compose files when you want to bring dependencies up step by step for troubleshooting
- use `compose.full.yaml` when you want to start or stop the whole lab stack as one unit

Avoid mixing `up` and `down` operations across both styles in parallel, because
the files share the same fixed container names.

Start the dependencies first:

```bash
docker compose -f lab/compose/compose.postgres.yaml up -d
docker compose -f lab/compose/compose.redis.yaml up -d
```

Then start RaaS:

```bash
docker compose -f lab/compose/compose.raas.yaml up -d
```

The RaaS UI should then be available at:

```text
https://localhost
```

If local port `443` is already in use, override only the host-side published
port and keep RaaS on `443` inside the container:

```bash
RAAS_HOST_PORT=8443 docker compose -f lab/compose/compose.raas.yaml up -d
```

Then browse to:

```text
https://localhost:8443
```

The lab defaults to a self-signed certificate if no cert/key pair is mounted, so a browser warning is expected on first access.

On first start, the checked-in templates also generate deployment-local
identity values unless you override them:

- RaaS stamps a unique `customer_id` into its config
- salt-master generates a unique `sseapi_cluster_id`

For compose-based local runs, those generated values persist in the mounted
config paths unless you replace them with explicit environment overrides.

For the currently validated first login to the RaaS UI, use the Broadcom
default credentials:

- username: `root`
- password: `salt`

After RaaS is healthy, you can start the salt-master:

```bash
docker compose -f lab/compose/compose.salt-master.yaml up -d
```

To start the full lab stack in one command:

```bash
docker compose -f lab/compose/compose.full.yaml up -d
```

The same host-side override works for the full stack:

```bash
RAAS_HOST_PORT=8443 docker compose -f lab/compose/compose.full.yaml up -d
```

## 11. Tag And Push To A Registry

If you want to move the images into a registry for Kubernetes use, retag them and push them after the local builds complete.

Example:

```bash
docker tag localhost/ssc-raas:8.18.3 registry.example.com/ssc/ssc-raas:8.18.3
docker tag localhost/ssc-salt-master:3006-lts registry.example.com/ssc/ssc-salt-master:3006-lts

docker push registry.example.com/ssc/ssc-raas:8.18.3
docker push registry.example.com/ssc/ssc-salt-master:3006-lts
```

For Minikube, you can also load the local images directly instead of pushing them:

```bash
minikube image load localhost/ssc-raas:8.18.3
minikube image load localhost/ssc-salt-master:3006-lts
```

## Notes

- The RaaS image terminates TLS itself and can generate a self-signed certificate at runtime if no cert/key is mounted.
- The lab RaaS config intentionally blanks `vip.vip_url` because the appliance-style VIP localization endpoint on `127.0.0.1:8091` is not part of this containerized build path.
- That missing VIP localization service does not block core RaaS or salt-master operation in the current lab model.
