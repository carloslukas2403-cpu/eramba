#!/usr/bin/env bash
set -euo pipefail

echo "==> entrypoint-fix: starting"
echo "==> PORT=${PORT:-"(not set)"}"
echo "==> CMD args: ${*:-"(none)"}"

# 1) Prefork
a2dismod -f mpm_event mpm_worker >/dev/null 2>&1 || true
a2enmod  mpm_prefork >/dev/null 2>&1 || true

# 2) ServerName
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername >/dev/null 2>&1 || true

# 3) Escuchar en $PORT si existe (Railway)
if [[ -n "${PORT:-}" ]]; then
  sed -ri "s/^\s*Listen\s+80\s*$/Listen ${PORT}/" /etc/apache2/ports.conf || true
  for f in /etc/apache2/sites-available/*.conf; do
    sed -ri "s/<VirtualHost \*:80>/<VirtualHost *:${PORT}>/g" "$f" || true
  done
fi

# 4) Validar config
apache2ctl -t

# 5) Ejecutar CMD original si existe, si no: arrancar Apache foreground
if [[ $# -gt 0 ]]; then
  echo "==> executing original CMD: $*"
  exec "$@"
else
  echo "==> no CMD provided, starting apache in foreground"
  exec apache2ctl -D FOREGROUND
fi
