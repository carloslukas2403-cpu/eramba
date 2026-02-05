#!/usr/bin/env bash
set -euo pipefail

# 1) Asegurar MPM prefork (mejor que symlinks “a mano”)
a2dismod -f mpm_event mpm_worker >/dev/null 2>&1 || true
a2enmod  mpm_prefork >/dev/null 2>&1 || true

# 2) Evitar warning ServerName
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername >/dev/null 2>&1 || true

# 3) Railway/PaaS: escuchar en $PORT si existe
if [[ -n "${PORT:-}" ]]; then
  # ports.conf
  sed -ri "s/^\s*Listen\s+80\s*$/Listen ${PORT}/" /etc/apache2/ports.conf || true

  # vhosts (típico 000-default.conf u otros)
  for f in /etc/apache2/sites-available/*.conf; do
    sed -ri "s/<VirtualHost \*:80>/<VirtualHost *:${PORT}>/g" "$f" || true
  done
fi

# 4) Validar y arrancar con el CMD original de la imagen
apache2ctl -t
exec "$@"

