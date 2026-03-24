#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 /path/to/extracted/bundle-root"
  exit 1
fi

BUNDLE_ROOT="$1"

# Stage Broadcom-supplied payloads into the layout expected by the Dockerfiles.
# This keeps vendor artifacts out of git while making builds deterministic.
KEYS_SRC_DIR="${BUNDLE_ROOT}/salt/sse/keys"
EAPI_SERVICE_SRC_DIR="${BUNDLE_ROOT}/salt/sse/eapi_service/files"
PLUGIN_WHL_SRC="${BUNDLE_ROOT}/salt/sse/eapi_plugin/files/SSEAPE-8.18.3.6-py3-none-any.whl"
PLUGIN_WHL_DST="bundle/whl/SSEAPE-8.18.3.6-py3-none-any.whl"

mkdir -p bundle/whl keys rpms/deps rpms/raas

if [ ! -f "${PLUGIN_WHL_SRC}" ]; then
  echo "Missing plugin wheel:"
  echo "  ${PLUGIN_WHL_SRC}"
  exit 1
fi

if [ ! -d "${KEYS_SRC_DIR}" ]; then
  echo "Missing keys directory:"
  echo "  ${KEYS_SRC_DIR}"
  exit 1
fi

if [ ! -d "${EAPI_SERVICE_SRC_DIR}" ]; then
  echo "Missing RaaS RPM directory:"
  echo "  ${EAPI_SERVICE_SRC_DIR}"
  exit 1
fi

# The air-gapped minion bundle is intentionally ignored here; this script only
# stages what is needed for the RaaS and salt-master container builds.
cp -f "${PLUGIN_WHL_SRC}" "${PLUGIN_WHL_DST}"
cp -f "${KEYS_SRC_DIR}"/*.asc keys/
cp -f "${KEYS_SRC_DIR}"/*.md keys/
cp -f \
  "${EAPI_SERVICE_SRC_DIR}"/libsodium-*.rpm \
  "${EAPI_SERVICE_SRC_DIR}"/libtool-ltdl-*.rpm \
  "${EAPI_SERVICE_SRC_DIR}"/libxslt-*.rpm \
  "${EAPI_SERVICE_SRC_DIR}"/xmlsec1-*.rpm \
  "${EAPI_SERVICE_SRC_DIR}"/xmlsec1-openssl-*.rpm \
  rpms/deps/
cp -f "${EAPI_SERVICE_SRC_DIR}"/raas-*.rpm rpms/raas/

echo "Staged:"
echo "  ${PLUGIN_WHL_DST}"
echo "  keys/*.asc"
echo "  rpms/deps/*.rpm"
echo "  rpms/raas/*.rpm"
