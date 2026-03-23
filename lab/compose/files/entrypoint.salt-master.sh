#!/usr/bin/env bash
set -euo pipefail

SALT_MASTER_ID="${SALT_MASTER_ID:-saltmaster1}"
RAAS_HOST="${RAAS_HOST:-ssc-raas}"
RAAS_PORT="${RAAS_PORT:-443}"
RAAS_SCHEME="${RAAS_SCHEME:-https}"
EAPI_CLUSTER_ID="${EAPI_CLUSTER_ID:-salt}"
EAPI_FAILOVER_MASTER="${EAPI_FAILOVER_MASTER:-False}"
EAPI_SSL_VALIDATION="${EAPI_SSL_VALIDATION:-False}"

mkdir -p /etc/salt/master.d
mkdir -p /etc/salt/pki/master

cat > /etc/salt/master.d/raas.conf <<EOF
# Set ID to override default name for this master that will display in the UI
id: ${SALT_MASTER_ID}

# Set the cluster ID that this Salt Master belongs to
sseapi_cluster_id: ${EAPI_CLUSTER_ID}

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