#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
)"

IMAGE_PLATFORM="${SSC_IMAGE_PLATFORM:-linux/amd64}"
IMAGE_TAG="${SSC_SALT_MASTER_IMAGE:-localhost/ssc-salt-master:3006-lts}"
BUNDLE_ROOT="${SSC_BUNDLE_ROOT:-${ROOT_DIR}/bundle/sse-installer}"
WHEEL_PATH="${ROOT_DIR}/bundle/whl/SSEAPE-8.18.3.6-py3-none-any.whl"

ensure_salt_master_inputs() {
  # The salt-master image only needs the Broadcom plugin wheel, but we stage it
  # the same way as the RaaS artifacts so both images can be built from one
  # extracted installer tree.
  if [ -f "${WHEEL_PATH}" ]; then
    return 0
  fi

  if [ -d "${BUNDLE_ROOT}" ]; then
    echo "[build-salt-master] Staging bundle content from ${BUNDLE_ROOT}"
    "${ROOT_DIR}/scripts/prep-bundle.sh" "${BUNDLE_ROOT}"
    return 0
  fi

  echo "Missing ${WHEEL_PATH}"
  echo "Extract the Broadcom installer bundle and run:"
  echo "  ${ROOT_DIR}/scripts/prep-bundle.sh /path/to/extracted/bundle-root"
  exit 1
}

ensure_salt_master_inputs

# Reuse the same preflight gate as the RaaS image so cross-architecture issues
# are caught early and reported consistently.
if [ "${SSC_SKIP_PREFLIGHT:-0}" != "1" ]; then
  "${ROOT_DIR}/scripts/preflight-build.sh" salt-master
fi

echo "[build-salt-master] Building ${IMAGE_TAG} for ${IMAGE_PLATFORM}"
exec docker build \
  --platform "${IMAGE_PLATFORM}" \
  -f "${ROOT_DIR}/images/Dockerfile.salt-master" \
  -t "${IMAGE_TAG}" \
  "${ROOT_DIR}"
