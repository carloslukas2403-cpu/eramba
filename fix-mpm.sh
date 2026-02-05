#!/usr/bin/env bash
set -euo pipefail

echo "==> Fixing Apache MPM modules (ensure only one is enabled)"

a2dismod -f mpm_event mpm_worker mpm_prefork >/dev/null 2>&1 || true
a2enmod  mpm_prefork >/dev/null 2>&1 || true

echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername >/dev/null 2>&1 || true

apache2ctl -t

# Intentar entrypoint original (muchas imágenes lo tienen)
if [[ -x /entrypoint.sh ]]; then
  echo "==> Found /entrypoint.sh, running it"
  exec /entrypoint.sh
fi

# Si no existe, arrancar Apache
echo "==> /entrypoint.sh not found. Starting Apache in foreground"
exec apache2ctl -D FOREGROUND
