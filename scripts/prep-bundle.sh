#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 /path/to/extracted/bundle-root"
  exit 1
fi

BUNDLE_ROOT="$1"

PLUGIN_WHL_SRC="${BUNDLE_ROOT}/salt/sse/eapi_plugin/files/SSEAPE-8.18.3.6-py3-none-any.whl"
PLUGIN_WHL_DST="bundle/whl/SSEAPE-8.18.3.6-py3-none-any.whl"

mkdir -p bundle/whl

if [ ! -f "${PLUGIN_WHL_SRC}" ]; then
  echo "Missing plugin wheel:"
  echo "  ${PLUGIN_WHL_SRC}"
  exit 1
fi

cp -f "${PLUGIN_WHL_SRC}" "${PLUGIN_WHL_DST}"

echo "Staged:"
echo "  ${PLUGIN_WHL_DST}"
