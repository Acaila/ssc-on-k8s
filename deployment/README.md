# Deployment Guides

This directory collects runtime deployment guidance by platform target.

The intent is to keep image-build instructions, local runtime validation, and
platform-specific deployment notes separate so operators can go directly to the
workflow that matches their environment.

## Current Guides

- [Docker Desktop Kubernetes](docker-desktop-kubernetes/README.md)
- [Minikube on macOS](minikube-macos/README.md)
- [Docker Host Runtime](dockerhost/README.md)
- [TKG](tkg/README.md)
- [Podman](podman/README.md)
- [Salt Master CLI Usage](salt-admin-usage.md)

## Scope

These guides are runtime-oriented.

Use [images/README.md](../images/README.md) first when you need to:

- obtain the Broadcom bundle
- stage the vendor artifacts
- build the `ssc-raas` and `ssc-salt-master` images

Then use the platform guide in this directory that matches the target runtime.

## Current Validation Boundary

The platform coverage in this directory is not uniform yet.

- Docker Desktop Kubernetes is now a validated local Kubernetes path
- Minikube on macOS is also a validated Kubernetes path
- Docker-host runtime is already covered by the compose workflow in the repo
- TKG and Podman are noted here as target environments, but they are not yet
  documented as fully validated deployment paths

## Runtime Filesystem Rule

The Kubernetes manifests in this repo follow a simple boundary:

- the image owns the baseline application filesystem layout
- the deployment owns only runtime-mounted storage preparation

In practice, that means an init container should usually do only the following:

- create nested directories inside a mounted volume when Kubernetes `subPath`
  needs them to exist first
- fix ownership or mode on mounted storage when the main container runs as a
  non-root UID/GID
- prepare runtime-only data that cannot be baked into the image

An init container should usually not recreate the full service directory tree
from the image. For example, if the image already creates `/etc/salt`,
`/var/log/salt`, or `/var/lib/raas`, then a Kubernetes init step should not
blindly rebuild all of those paths again. Once Kubernetes mounts an `emptyDir`
or PVC there, only the contents of that mounted filesystem matter.

This keeps the manifests easier to reason about for operators who already know
containers, Linux filesystems, and vSphere-style infrastructure behavior:

- images define what the service expects
- volumes supply writable state
- init containers bridge only the gap created by mounts
