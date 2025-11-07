#!/usr/bin/env bash
set -euo pipefail

# First-run bootstrap of /etc/raas/raas.conf if missing
if [ ! -s /etc/raas/raas.conf ]; then
  echo "[entrypoint] Seeding /etc/raas/raas.conf from /bootstrap/raas.conf"
  cp /bootstrap/raas.conf /etc/raas/raas.conf
fi

# Optional environment substitutions for convenience
# RAAS_DB_HOST/NAME/USER/PASS, RAAS_REDIS_HOST/PORT
sed -i "s#@@DB_HOST@@#${RAAS_DB_HOST:-postgres}#g" /etc/raas/raas.conf
sed -i "s#@@DB_NAME@@#${RAAS_DB_NAME:-raas}#g" /etc/raas/raas.conf
sed -i "s#@@DB_USER@@#${RAAS_DB_USER:-raas}#g" /etc/raas/raas.conf
sed -i "s#@@DB_PASS@@#${RAAS_DB_PASS:-changeme}#g" /etc/raas/raas.conf
sed -i "s#@@REDIS_HOST@@#${RAAS_REDIS_HOST:-redis}#g" /etc/raas/raas.conf
sed -i "s#@@REDIS_PORT@@#${RAAS_REDIS_PORT:-6379}#g" /etc/raas/raas.conf

# Permissions hygiene
chown -R ssc:root /etc/raas /var/log/raas

exec "$@"