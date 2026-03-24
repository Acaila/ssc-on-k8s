# Staged Wheel Payloads

`scripts/prep-bundle.sh` extracts Broadcom wheel payloads into this directory
for use during image builds.

Current use:

- the `SSEAPE` wheel consumed by the salt-master image build

The staged wheel files are generated locally and are intentionally ignored by
git.
