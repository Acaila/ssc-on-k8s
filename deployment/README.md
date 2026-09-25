# Deployment guides

The primary target is **native vSphere Pods in an existing Supervisor
namespace**, following local licensed image builds.

## Primary path

- [Supervisor deployment](supervisor/README.md): platform services, ownership,
  environment setup, direct Kustomize deployment and certificates, Contour routing and acceptance.
- [OCI registry / Harbor](supervisor/registry.md): private image publication,
  runtime pulls, trust and release references.
- [Operations and gaps](supervisor/operations.md): persistence, recovery,
  upgrades, credentials, backups and remaining work.
- [Salt administrator CLI](salt-admin-usage.md): operating the containerized master.

Build first using [images/README.md](../images/README.md).
The root Kustomization is for local `aria-config` development; the Supervisor
entry point is your generated `deployment/environments/<name>/workloads` overlay.

## Alternative development paths

| Guide | Scope |
| --- | --- |
| [Docker Desktop Kubernetes](docker-desktop-kubernetes/README.md) | Previously validated local development |
| [Minikube on macOS](minikube-macos/README.md) | Previously validated local development |
| [Docker host / Compose](dockerhost/README.md) | Optional local runtime smoke tests |
| [Podman](podman/README.md) | Separate runtime guide; direct Podman image builds were used for Supervisor |
| [TKG/VKS workload cluster](tkg/README.md) | Historical alternative, not the primary target or a completed deployment guide |

## Filesystem boundary

Images provide the baseline service filesystem and dependencies. Volumes supply
writable state. Init containers prepare ownership and nested mount directories;
they should not duplicate the whole image filesystem. PVC-backed master keys,
RaaS encryption material and database state must survive pod replacement.
