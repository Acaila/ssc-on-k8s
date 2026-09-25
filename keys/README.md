# Staged GPG Keys

`scripts/prep-bundle.sh` extracts vendor and repository signing keys from the
official Broadcom bundle into this directory.

The Dockerfiles copy these keys into the build context and import them before
installing the staged RPM payloads.

The key files themselves are local build inputs and are intentionally ignored by
git.
