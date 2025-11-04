#!/usr/bin/env bash
set -euo pipefail

# First-run bootstrap: if /etc/raas/raas.conf is missing, seed from /bootstrap or env
if [ ! -s /etc/raas/raas.conf ]; then
echo "[entrypoint] Seeding /etc/raas/raas.conf"
cp /bootstrap/raas.conf /etc/raas/raas.conf
fi

# Allow overrides via env vars (simple envsubst-style replacement)
# Expected envs: RAAS_DB_HOST, RAAS_DB_NAME, RAAS_DB_USER, RAAS_DB_PASS, RAAS_REDIS_HOST, RAAS_REDIS_PORT
sed -i "s#@@DB_HOST@@#${RAAS_DB_HOST:-postgres}#g" /etc/raas/raas.conf
sed -i "s#@@DB_NAME@@#${RAAS_DB_NAME:-raas}#g" /etc/raas/raas.conf
sed -i "s#@@DB_USER@@#${RAAS_DB_USER:-raas}#g" /etc/raas/raas.conf
sed -i "s#@@DB_PASS@@#${RAAS_DB_PASS:-changeme}#g" /etc/raas/raas.conf
sed -i "s#@@REDIS_HOST@@#${RAAS_REDIS_HOST:-redis}#g" /etc/raas/raas.conf
sed -i "s#@@REDIS_PORT@@#${RAAS_REDIS_PORT:-6379}#g" /etc/raas/raas.conf

# TLS (optional): mount to /etc/raas/tls and point raas.conf to those files
# Ensure perms
chown -R ssc:root /etc/raas /var/log/raas

exec "$@"