#!/usr/bin/env bash
set -euo pipefail

# These defaults match the lab topology. The same entrypoint can be reused with
# different values in Kubernetes by overriding the environment variables.
SALT_MASTER_ID="${SALT_MASTER_ID:-saltmaster1}"
RAAS_HOST="${RAAS_HOST:-ssc-raas}"
RAAS_PORT="${RAAS_PORT:-443}"
RAAS_SCHEME="${RAAS_SCHEME:-https}"
EAPI_CLUSTER_ID="${EAPI_CLUSTER_ID:-}"
EAPI_CLUSTER_ID_FILE="${EAPI_CLUSTER_ID_FILE:-/etc/salt/master.d/.cluster_id}"
EAPI_FAILOVER_MASTER="${EAPI_FAILOVER_MASTER:-False}"
EAPI_SSL_VALIDATION="${EAPI_SSL_VALIDATION:-False}"

mkdir -p /etc/salt/master.d
mkdir -p /etc/salt/pki/master
mkdir -p "$(dirname "${EAPI_CLUSTER_ID_FILE}")"

generate_uuid() {
  /opt/saltstack/salt/bin/python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
}

# Keep the SSE cluster ID stable for a given deployment unless the operator
# overrides it. This avoids multiple installs of the repo all registering to
# RaaS with the same default cluster identifier.
if [ -n "${EAPI_CLUSTER_ID}" ]; then
  cluster_id="${EAPI_CLUSTER_ID}"
elif [ -s "${EAPI_CLUSTER_ID_FILE}" ]; then
  cluster_id="$(tr -d '\r\n' < "${EAPI_CLUSTER_ID_FILE}")"
else
  cluster_id="$(generate_uuid)"
fi

if [ ! -s "${EAPI_CLUSTER_ID_FILE}" ] || [ "$(tr -d '\r\n' < "${EAPI_CLUSTER_ID_FILE}" 2>/dev/null || true)" != "${cluster_id}" ]; then
  echo "${cluster_id}" > "${EAPI_CLUSTER_ID_FILE}"
fi

chmod 600 "${EAPI_CLUSTER_ID_FILE}" 2>/dev/null || true

# SSEAPE installs into Salt's Python environment, so resolve its actual site-
# packages path at runtime instead of assuming a distro-specific location.
EGG_PATH="$(
  /opt/saltstack/salt/bin/python3 -c 'import site; print(site.getsitepackages()[0])'
)"

# Rebuild the external module path file on every start so the container stays
# consistent even if the wheel version or Python path changes between builds.
cat > /etc/salt/master.d/eAPIMasterPaths.conf <<EOF
# Engines External Modules Path(s)
engines_dirs:
- ${EGG_PATH}/sseape/engines

# Fileserver External Modules Path(s)
fileserver_dirs:
- ${EGG_PATH}/sseape/fileserver

# Pillar External Modules Path(s)
pillar_dirs:
- ${EGG_PATH}/sseape/pillar

# Returner External Modules Path(s)
returner_dirs:
- ${EGG_PATH}/sseape/returners

# Roster External Modules Path(s)
roster_dirs:
- ${EGG_PATH}/sseape/roster

# Runner External Modules Path(s)
runner_dirs:
- ${EGG_PATH}/sseape/runners

# Module External Modules Path(s)
module_dirs:
- ${EGG_PATH}/sseape/modules

# Proxy External Modules Path(s)
proxy_dirs:
- ${EGG_PATH}/sseape/proxy

# State External Modules Path(s)
states_dirs:
- ${EGG_PATH}/sseape/states
EOF

# Render the master-to-RaaS integration config from environment so the same
# image works in the lab and in a cluster without baking endpoints into the
# image filesystem.
cat > /etc/salt/master.d/raas.conf <<EOF
# Set ID to override default name for this master that will display in the UI
id: ${SALT_MASTER_ID}

# Set the cluster ID that this Salt Master belongs to
sseapi_cluster_id: ${cluster_id}

# Set if multiple masters configurations are "active" or "failover"
sseapi_failover_master: ${EAPI_FAILOVER_MASTER}

# Enable VMware Salt engines
engines:
  - sseapi: {}
  - eventqueue: {}
  - rpcqueue: {}
  - jobcompletion: {}
  - keyauth: {}
  # - tgtmatch: {}

# Enable eAPI as a Master Job Cache and event returner
master_job_cache: sseapi
event_return: sseapi

# Specify eAPI connection settings
sseapi_server: ${RAAS_SCHEME}://${RAAS_HOST}:${RAAS_PORT}
sseapi_ssl_validate_cert: ${EAPI_SSL_VALIDATION}

# Key authentication settings
sseapi_pubkey_path: /etc/salt/pki/master/sseapi_key.pub
sseapi_key_check: 15
sseapi_key_test: 300
sseapi_key_rotation: 86400

# How frequently should the RaaS engine running on each master poll RaaS
sseapi_poll_interval: 10

# Timeout for eAPI requests
sseapi_timeout: 180

# Specify the eAPI fileserver update interval
sseapi_update_interval: 60

# Enable fileserver backends to use eAPI first, then local filesystem
fileserver_backend:
  - sseapi
  - roots

# Enable the eAPI external pillar
ext_pillar:
  - sseapi: {}

# Queue events locally and send to VMware Salt in batches
sseapi_event_queue:
  name: sseapi-events
  strategy: never
  push_interval: 5
  batch_limit: 2000
  age_limit: 86400
  size_limit: 35000000
  vacuum_interval: 86400
  vacuum_limit: 350000
  forward: []

# Queue some RPC calls locally and send to VMware Salt in batches
sseapi_rpc_queue:
  name: sseapi-rpc
  strategy: never
  push_interval: 5
  batch_limit: 500
  age_limit: 3600
  size_limit: 360000
  vacuum_interval: 86400
  vacuum_limit: 100000

# Cache some VMware Salt objects locally
sseapi_local_cache:
  load: 3600
  tgt: 300

sseapi_command_age_limit: 0
EOF

exec /opt/saltstack/salt/salt-master -l info
