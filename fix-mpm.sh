#!/usr/bin/env bash
set -euo pipefail

echo "==> fix-mpm: starting"
echo "==> PORT=${PORT:-"(not set)"}"

# 1) Asegurar un solo MPM
a2dismod -f mpm_event mpm_worker mpm_prefork >/dev/null 2>&1 || true
a2enmod  mpm_prefork >/dev/null 2>&1 || true

# 2) Quitar warning ServerName
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername >/dev/null 2>&1 || true

# 3) Railway: escuchar en $PORT
if [[ -n "${PORT:-}" ]]; then
  echo "==> configuring Apache to listen on PORT=$PORT"

  # Fuerza ports.conf
  echo "Listen ${PORT}" > /etc/apache2/ports.conf

  # Fuerza todos los vhosts
  for f in /etc/apache2/sites-available/*.conf; do
    sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/g" "$f" || true
    sed -ri "s/<VirtualHost \*>/<VirtualHost *:${PORT}>/g" "$f" || true
  done
fi

apache2ctl -t

echo "==> starting Apache in foreground"
exec apache2ctl -D FOREGROUND
