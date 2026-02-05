#!/usr/bin/env bash
set -e

echo "==> Fixing Apache MPM modules (ensure only one is enabled)"

# Apagar todos (por si acaso)
a2dismod -f mpm_event mpm_worker mpm_prefork >/dev/null 2>&1 || true

# Encender SOLO prefork
a2enmod mpm_prefork >/dev/null 2>&1 || true

# Verificación rápida (no mata el contenedor si falla)
apache2ctl -t || true

# Ejecutar el entrypoint/cmd original del contenedor
if [ -x /entrypoint.sh ]; then
  exec /entrypoint.sh "$@"
fi

exec "$@"
