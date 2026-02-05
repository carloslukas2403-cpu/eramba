#!/usr/bin/env bash
set -euo pipefail

echo "==> entrypoint-fix: starting"
echo "==> PORT=${PORT:-"(not set)"}"
echo "==> CMD args: ${*:-"(none)"}"

ROOT="/var/www/eramba"

# 1) Prefork
a2dismod -f mpm_event mpm_worker >/dev/null 2>&1 || true
a2enmod  mpm_prefork >/dev/null 2>&1 || true

# 2) ServerName
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername >/dev/null 2>&1 || true

# 3) Escuchar en $PORT (Railway)
if [[ -n "${PORT:-}" ]]; then
  echo "Listen ${PORT}" > /etc/apache2/ports.conf

  for f in /etc/apache2/sites-available/*.conf; do
    sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/g" "$f" || true
    sed -ri "s/<VirtualHost \*>/<VirtualHost *:${PORT}>/g" "$f" || true
  done
fi

# 4) Crear app_local.php si no existe (SIN composer)
if [[ -d "$ROOT/config" ]] && [[ ! -f "$ROOT/config/app_local.php" ]]; then
  echo "==> app_local.php missing. Trying to create from template..."

  if [[ -f "$ROOT/config/app_local.example.php" ]]; then
    cp "$ROOT/config/app_local.example.php" "$ROOT/config/app_local.php"
    echo "==> app_local.php created from app_local.example.php"
  elif [[ -f "$ROOT/config/app_local.php.default" ]]; then
    cp "$ROOT/config/app_local.php.default" "$ROOT/config/app_local.php"
    echo "==> app_local.php created from app_local.php.default"
  else
    echo "==> ERROR: No template found to create app_local.php"
    echo "==> Listing config folder:"
    ls -la "$ROOT/config" || true
  fi
fi

apache2ctl -t

# 5) Arrancar Apache
if [[ $# -gt 0 ]]; then
  exec "$@"
else
  exec apache2ctl -D FOREGROUND
fi
