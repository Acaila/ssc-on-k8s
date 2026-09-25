# Quick start: build locally, deploy to your Supervisor

## Phase 1 — build your licensed images

Obtain the entitled installer, then run from the repository root:

```bash
tar -xzf /path/to/VMware_Salt_RaaS-8.18.3-25253633.el9_Installer.tar.gz -C bundle
./scripts/prep-bundle.sh bundle/sse-installer
./scripts/build-raas.sh
./scripts/build-salt-master.sh
```

See the [build guide](images/README.md) for prerequisites and the Podman
alternative. Keep licensed inputs and resulting images private.

## Phase 2 — configure and deploy to Supervisor

1. Prepare an existing native-pod namespace, storage/capacity, OCI registry,
   Contour and certificate handling. See [platform readiness](deployment/supervisor/README.md#1-prepare-the-platform-services).
2. [Publish all four images](deployment/supervisor/registry.md) to your private registry.
3. Copy and edit the configuration, then generate your own Kustomization:

   ```bash
   mkdir -p .supervisor
   cp deployment/supervisor/settings.example.json .supervisor/settings.json
   # Edit for your namespace, storage, image references, DNS and TLS.
   python3 scripts/configure-supervisor.py --config .supervisor/settings.json
   ```

4. Follow the [deployment guide](deployment/supervisor/README.md) to supply
   secrets and certificates, run preflight, apply your Kustomization directly,
   complete routing/DNS and validate SSC.

Generated settings/overlays are ignored by default; explicitly publish reviewed
non-secret configuration only to your own deployment repository. The generator
never applies cluster changes or overwrites an existing environment.

The shared platform services must already be installed or provisioned separately.
Clean-install rehearsal and recovery automation remain work toward a fully
turnkey experience. Local Docker Desktop/Minikube/Compose paths remain optional
[development alternatives](deployment/README.md).
