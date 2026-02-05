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

# 3) Escuchar en $PORT (Railway)
if [[ -n "${PORT:-}" ]]; then
  echo "Listen ${PORT}" > /etc/apache2/ports.conf
  for f in /etc/apache2/sites-available/*.conf; do
    sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/g" "$f" || true
    sed -ri "s/<VirtualHost \*>/<VirtualHost *:${PORT}>/g" "$f" || true
  done
fi

# 4) Encontrar ROOT real (busca config/app.php)
APP_PHP="$(find / -maxdepth 6 -type f -path '*/config/app.php' 2>/dev/null | head -n 1 || true)"
if [[ -z "${APP_PHP}" ]]; then
  echo "==> ERROR: Could not find config/app.php (can't locate Eramba root)"
else
  ROOT="$(dirname "$(dirname "$APP_PHP")")"
  echo "==> Detected ROOT: $ROOT"
  echo "==> Config dir listing:"
  ls -la "$ROOT/config" || true

  # 5) Crear app_local.php SIEMPRE si falta (sin composer)
  if [[ ! -f "$ROOT/config/app_local.php" ]]; then
    echo "==> app_local.php missing. Creating minimal app_local.php ..."
    cat > "$ROOT/config/app_local.php" <<'PHP'
<?php
// Minimal app_local.php created by entrypoint to satisfy CakePHP/Eramba boot.
// You can later configure DB via installer or edit this file as needed.
return [];
PHP
    echo "==> app_local.php created."
  else
    echo "==> app_local.php already exists."
  fi
fi

# 6) Validar Apache
apache2ctl -t

# 7) Arrancar Apache
if [[ $# -gt 0 ]]; then
  exec "$@"
else
  exec apache2ctl -D FOREGROUND
fi
