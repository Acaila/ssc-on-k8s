#!/usr/bin/env bash
set -euo pipefail

mkdir -p /etc/raas /var/log/raas

if [ ! -s /etc/raas/raas ]; then
  echo "[entrypoint] Seeding /etc/raas/raas from /bootstrap/raas"
  cp /bootstrap/raas /etc/raas/raas
fi

sed -i "s#@@DB_HOST@@#${RAAS_DB_HOST:-postgres}#g" /etc/raas/raas
sed -i "s#@@REDIS_HOST@@#${RAAS_REDIS_HOST:-redis}#g" /etc/raas/raas
sed -i "s#@@REDIS_PORT@@#${RAAS_REDIS_PORT:-6379}#g" /etc/raas/raas

if [ ! -f /etc/raas/raas.secconf ]; then
  echo "[entrypoint] Creating /etc/raas/raas.secconf with raas save_creds"
  /opt/saltstack/raas/bin/raas -c /etc/raas save_creds \
    "postgres={\"username\":\"${RAAS_DB_USER:-raas}\",\"password\":\"${RAAS_DB_PASS:-raaspass}\"}" \
    "redis={\"password\":\"${RAAS_REDIS_PASS:-}\"}"
fi

chmod 600 /etc/raas/raas.secconf || true

exec "$@"