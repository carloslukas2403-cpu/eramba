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

# 4) Encontrar ROOT REAL de CakePHP (buscando bin/cake)
BIN_CAKE="$(find / -maxdepth 7 -type f -path '*/bin/cake' 2>/dev/null | head -n 1 || true)"

if [[ -z "${BIN_CAKE}" ]]; then
  echo "==> ERROR: Could not find bin/cake (CakePHP root not found)"
  echo "==> FYI: found config/app.php at:"
  find / -maxdepth 7 -type f -path '*/config/app.php' 2>/dev/null | head -n 5 || true
else
  ROOT="$(dirname "$(dirname "$BIN_CAKE")")"
  echo "==> Detected CakePHP ROOT: $ROOT"
  echo "==> Config dir listing:"
  ls -la "$ROOT/config" || true

  # 5) Crear app_local.php en CakePHP ROOT
  if [[ ! -f "$ROOT/config/app_local.php" ]]; then
    echo "==> app_local.php missing in CakePHP root. Creating..."
    cat > "$ROOT/config/app_local.php" <<'PHP'
<?php
// Minimal app_local.php created by entrypoint.
// Real configuration can be completed via installer / env settings.
return [];
PHP
    chown www-data:www-data "$ROOT/config/app_local.php" || true
    echo "==> app_local.php created at $ROOT/config/app_local.php"
  else
    echo "==> app_local.php already exists in CakePHP root."
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
