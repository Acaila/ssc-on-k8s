#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
)"

TARGET="${1:-raas}"
IMAGE_PLATFORM="${SSC_IMAGE_PLATFORM:-linux/amd64}"
BUNDLE_ROOT="${SSC_BUNDLE_ROOT:-${ROOT_DIR}/bundle/sse-installer}"

# Broadcom currently ships x86_64 payloads, so non-x86 desktop builders need an
# explicit amd64 target instead of Docker's host-native default.
case "${TARGET}" in
  raas)
    BASE_IMAGE="registry.access.redhat.com/ubi9/ubi-minimal:9.4"
    REQUIRED_PATH="${ROOT_DIR}/rpms/raas/raas-8.18.3.el9.x86_64.rpm"
    SOURCE_PATH="${BUNDLE_ROOT}/salt/sse/eapi_service/files/raas-8.18.3.el9.x86_64.rpm"
    ;;
  salt-master)
    BASE_IMAGE="docker.io/library/rockylinux:9"
    REQUIRED_PATH="${ROOT_DIR}/bundle/whl/SSEAPE-8.18.3.6-py3-none-any.whl"
    SOURCE_PATH="${BUNDLE_ROOT}/salt/sse/eapi_plugin/files/SSEAPE-8.18.3.6-py3-none-any.whl"
    ;;
  *)
    echo "Usage: $0 [raas|salt-master]"
    exit 1
    ;;
esac

ARCH="${IMAGE_PLATFORM##*/}"

pass() {
  echo "[preflight] OK: $*"
}

fail() {
  echo "[preflight] ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

check_docker() {
  require_command docker
  docker info >/dev/null 2>&1 || fail "Docker daemon is not reachable"
  pass "Docker daemon is reachable"
}

check_lab_network() {
  # This is a non-blocking check for operators using the optional local lab
  # compose flow. The compose files now create the named network automatically
  # if it is missing, so we report the state rather than failing the build.
  if docker network inspect ssc-net >/dev/null 2>&1; then
    pass "Local lab network ssc-net already exists"
  else
    pass "Local lab network ssc-net is absent; Docker Compose will create it on first local bring-up"
  fi
}

check_bundle_inputs() {
  # Accept either already-staged artifacts or an extracted installer tree that
  # can be staged by the build wrapper before the actual docker build starts.
  if [ -f "${REQUIRED_PATH}" ]; then
    pass "Staged build input is present: ${REQUIRED_PATH}"
    return 0
  fi

  if [ -f "${SOURCE_PATH}" ]; then
    pass "Extracted installer input is present and can be staged: ${SOURCE_PATH}"
    return 0
  fi

  fail "Missing required build input. Expected either ${REQUIRED_PATH} or ${SOURCE_PATH}"
}

inspect_with_buildx() {
  docker buildx imagetools inspect "${BASE_IMAGE}" 2>/dev/null
}

inspect_with_manifest() {
  docker manifest inspect "${BASE_IMAGE}" 2>/dev/null
}

check_base_image_platform() {
  local inspect_output=""

  # Prefer buildx metadata when available, but fall back to plain manifest
  # inspection so the preflight also works on older Docker Desktop versions.
  if inspect_output="$(inspect_with_buildx)"; then
    :
  elif inspect_output="$(inspect_with_manifest)"; then
    :
  else
    fail "Unable to inspect base image metadata for ${BASE_IMAGE}. Check Docker registry access."
  fi

  if grep -qE "linux/${ARCH}|\"architecture\"[[:space:]]*:[[:space:]]*\"${ARCH}\"" <<<"${inspect_output}"; then
    pass "Base image ${BASE_IMAGE} advertises ${IMAGE_PLATFORM}"
    return 0
  fi

  fail "Base image ${BASE_IMAGE} does not appear to advertise ${IMAGE_PLATFORM}"
}

check_host_platform() {
  local host_arch
  host_arch="$(uname -m)"

  case "${host_arch}" in
    arm64|aarch64)
      # Emulation is expected for the Broadcom-based images on non-x86 hosts.
      if [ "${ARCH}" = "amd64" ]; then
        pass "Host is ${host_arch}; build will rely on amd64 emulation"
      else
        pass "Host and target platform are aligned"
      fi
      ;;
    *)
      pass "Host architecture is ${host_arch}"
      ;;
  esac
}

check_docker
check_lab_network
check_bundle_inputs
check_base_image_platform
check_host_platform

echo "[preflight] Ready to build ${TARGET} for ${IMAGE_PLATFORM}"
