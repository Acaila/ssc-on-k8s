#!/usr/bin/env bash
set -euo pipefail

# RaaS expects its config, logs, and TLS material to exist on persistent paths.
# In the lab these paths may be mounted from the host, but they still need to
# exist for first boot and for image-local testing.
mkdir -p /etc/raas /var/log/raas /etc/pki/raas/certs

if [ ! -s /etc/raas/raas ]; then
  echo "[entrypoint] Seeding /etc/raas/raas from /bootstrap/raas"
  cp /bootstrap/raas /etc/raas/raas
fi

# Keep the template generic in the image and stamp in service names at runtime
# so the same image can be reused in the lab and later in Kubernetes.
sed -i "s#@@DB_HOST@@#${RAAS_DB_HOST:-ssc-postgres}#g" /etc/raas/raas
sed -i "s#@@REDIS_HOST@@#${RAAS_REDIS_HOST:-ssc-redis}#g" /etc/raas/raas
sed -i "s#@@REDIS_PORT@@#${RAAS_REDIS_PORT:-6379}#g" /etc/raas/raas

TLS_CRT="/etc/pki/raas/certs/localhost.crt"
TLS_KEY="/etc/pki/raas/certs/localhost.key"
TLS_CN="${RAAS_TLS_CN:-ssc-raas}"

# Broadcom's appliance model expects RaaS to terminate TLS itself. If the lab
# operator did not mount a cert/key pair, generate a self-signed pair so the
# service still comes up on HTTPS without a manual prep step.
if [ ! -s "${TLS_CRT}" ] || [ ! -s "${TLS_KEY}" ]; then
  echo "[entrypoint] Generating self-signed TLS certificate for ${TLS_CN}"
  openssl req -x509 -nodes -newkey rsa:4096 \
    -keyout "${TLS_KEY}" \
    -out "${TLS_CRT}" \
    -days "${RAAS_TLS_DAYS:-825}" \
    -subj "/CN=${TLS_CN}" \
    -addext "subjectAltName=DNS:${TLS_CN},DNS:localhost,IP:127.0.0.1"
fi

chmod 600 "${TLS_KEY}" || true
chmod 644 "${TLS_CRT}" || true

# The secconf file stores database and Redis credentials in the format expected
# by `raas`. Create it once and then leave it alone so restarts are idempotent.
if [ ! -f /etc/raas/raas.secconf ]; then
  echo "[entrypoint] Creating /etc/raas/raas.secconf with raas save_creds"
  /opt/saltstack/raas/bin/raas -c /etc/raas save_creds \
    "postgres={\"username\":\"${RAAS_DB_USER:-raas}\",\"password\":\"${RAAS_DB_PASS:-raaspass}\"}" \
    "redis={\"password\":\"${RAAS_REDIS_PASS:-}\"}"
fi

chmod 600 /etc/raas/raas.secconf || true

exec "$@"
