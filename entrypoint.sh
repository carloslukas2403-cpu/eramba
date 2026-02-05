#!/usr/bin/env bash
set -euo pipefail

echo "==> entrypoint-fix: starting"
echo "==> PORT=${PORT:-"(not set)"}"
echo "==> CMD args: ${*:-"(none)"}"

# ===== 0) Paths =====
ROOT="/var/www/eramba"

# ===== 1) Apache: Prefork =====
a2dismod -f mpm_event mpm_worker >/dev/null 2>&1 || true
a2enmod  mpm_prefork >/dev/null 2>&1 || true

# ===== 2) Apache: ServerName =====
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername >/dev/null 2>&1 || true

# ===== 3) Apache: Escuchar en $PORT (Railway) =====
if [[ -n "${PORT:-}" ]]; then
  # Forzar Listen sí o sí (más seguro que el sed)
  echo "Listen ${PORT}" > /etc/apache2/ports.conf

  # Forzar TODOS los vhosts al puerto de Railway
  for f in /etc/apache2/sites-available/*.conf; do
    sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/g" "$f" || true
    sed -ri "s/<VirtualHost \*>/<VirtualHost *:${PORT}>/g" "$f" || true
  done
fi

# ===== 4) FIX Eramba: crear app_local.php si no existe =====
if [[ -d "$ROOT" ]]; then
  if [[ ! -f "$ROOT/config/app_local.php" ]]; then
    echo "==> app_local.php missing. Running composer post-install..."
    cd "$ROOT"

    # Esto es lo que te pide el mensaje en el navegador
    composer run-script post-install-cmd || true

    # Si no lo creó, intentamos copiar un ejemplo (por si la imagen lo trae)
    if [[ ! -f "$ROOT/config/app_local.php" ]]; then
      if [[ -f "$ROOT/config/app_local.example.php" ]]; then
        echo "==> Creating app_local.php from example"
        cp "$ROOT/config/app_local.example.php" "$ROOT/config/app_local.php"
      fi
    fi
  else
    echo "==> app_local.php exists. Skipping post-install."
  fi

  # ===== 5) Migraciones: crear tablas si DB ya está configurada =====
  if [[ -f "$ROOT/bin/cake" ]]; then
    echo "==> Running migrations (if DB is reachable)..."
    cd "$ROOT"
    php bin/cake migrations migrate || true
  fi
else
  echo "==> WARNING: ROOT folder not found at $ROOT"
fi

# ===== 6) Validar Apache =====
apache2ctl -t

# ===== 7) Arrancar =====
if [[ $# -gt 0 ]]; then
  echo "==> executing original CMD: $*"
  exec "$@"
else
  echo "==> no CMD provided, starting apache in foreground"
  exec apache2ctl -D FOREGROUND
fi
