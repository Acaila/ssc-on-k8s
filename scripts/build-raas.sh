#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
)"

IMAGE_PLATFORM="${SSC_IMAGE_PLATFORM:-linux/amd64}"
IMAGE_TAG="${SSC_RAAS_IMAGE:-localhost/ssc-raas:8.18.3}"
BUNDLE_ROOT="${SSC_BUNDLE_ROOT:-${ROOT_DIR}/bundle/sse-installer}"

ensure_raas_inputs() {
  # Prefer staged RPMs for repeatable rebuilds, but auto-stage from an already
  # extracted installer tree so the common happy path stays one-command simple.
  if [ -f "${ROOT_DIR}/rpms/raas/raas-8.18.3.el9.x86_64.rpm" ]; then
    return 0
  fi

  if [ -d "${BUNDLE_ROOT}" ]; then
    echo "[build-raas] Staging Broadcom bundle content from ${BUNDLE_ROOT}"
    "${ROOT_DIR}/scripts/prep-bundle.sh" "${BUNDLE_ROOT}"
    return 0
  fi

  echo "Missing staged RaaS RPMs under ${ROOT_DIR}/rpms/raas"
  echo "Extract the Broadcom installer bundle and run:"
  echo "  ${ROOT_DIR}/scripts/prep-bundle.sh /path/to/extracted/bundle-root"
  exit 1
}

ensure_raas_inputs

# The preflight catches the common cross-architecture failure modes before we
# spend time in a long emulated build.
if [ "${SSC_SKIP_PREFLIGHT:-0}" != "1" ]; then
  "${ROOT_DIR}/scripts/preflight-build.sh" raas
fi

echo "[build-raas] Building ${IMAGE_TAG} for ${IMAGE_PLATFORM}"
exec docker build \
  --platform "${IMAGE_PLATFORM}" \
  -f "${ROOT_DIR}/images/Dockerfile.raas" \
  -t "${IMAGE_TAG}" \
  "${ROOT_DIR}"
