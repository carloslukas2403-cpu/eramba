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

# 4) Encontrar ROOT REAL de la APP WEB (buscando app/webroot/index.php)
WEBROOT_INDEX="$(find /var/www/eramba -maxdepth 7 -type f -path '*/app/webroot/index.php' 2>/dev/null | head -n 1 || true)"

if [[ -z "${WEBROOT_INDEX}" ]]; then
  echo "==> ERROR: Could not find */app/webroot/index.php under /var/www/eramba"
  echo "==> Candidates (index.php found):"
  find /var/www/eramba -maxdepth 9 -type f -name 'index.php' 2>/dev/null | head -n 20 || true
else
  # WEBROOT_INDEX = .../app/webroot/index.php
  # ROOT = ... (subimos 3 niveles)
  ROOT="$(dirname "$(dirname "$(dirname "$WEBROOT_INDEX")")")"

  echo "==> Detected APP ROOT: $ROOT"
  echo "==> Config dir listing:"
  ls -la "$ROOT/config" || true

  # 5) Crear app_local.php en el ROOT correcto
  if [[ ! -f "$ROOT/config/app_local.php" ]]; then
    echo "==> app_local.php missing in APP ROOT. Creating..."

    if [[ -f "$ROOT/config/app_local.example.php" ]]; then
      cp "$ROOT/config/app_local.example.php" "$ROOT/config/app_local.php"
      echo "==> app_local.php created from app_local.example.php"
    else
      cat > "$ROOT/config/app_local.php" <<'PHP'
<?php
return [];
PHP
      echo "==> app_local.php created (minimal)"
    fi

    chown www-data:www-data "$ROOT/config/app_local.php" || true
  else
    echo "==> app_local.php already exists in APP ROOT."
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
