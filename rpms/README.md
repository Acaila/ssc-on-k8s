# Staged RPM Payloads

`scripts/prep-bundle.sh` stages the Broadcom RPM payloads needed for container
builds under this directory.

Subdirectories:

- `raas/` for the Broadcom RaaS RPM
- `deps/` for supporting RPM dependencies used by the RaaS image build

The RPM files are local build inputs and are intentionally ignored by git.
