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
