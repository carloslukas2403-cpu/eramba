#!/usr/bin/env bash
set -euo pipefail

echo "==> fix-mpm: starting"
echo "==> PORT=${PORT:-"(not set)"}"

# 1) Un solo MPM (prefork)
a2dismod -f mpm_event mpm_worker mpm_prefork >/dev/null 2>&1 || true
a2enmod  mpm_prefork >/dev/null 2>&1 || true

# 2) ServerName (warning harmless, pero lo quitamos)
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername >/dev/null 2>&1 || true

# 3) Railway: escuchar en $PORT
if [[ -n "${PORT:-}" ]]; then
  echo "==> configuring Apache to listen on PORT=$PORT"
  echo "Listen ${PORT}" > /etc/apache2/ports.conf
  for f in /etc/apache2/sites-available/*.conf; do
    sed -ri "s/<VirtualHost \*:[0-9]+>/<VirtualHost *:${PORT}>/g" "$f" || true
    sed -ri "s/<VirtualHost \*>/<VirtualHost *:${PORT}>/g" "$f" || true
  done
fi

# 4) Ejecutar instalador/init de Eramba (si existe)
echo "==> trying to run Eramba init/installer (if present)"

# Algunas imágenes traen init en una de estas rutas:
for candidate in \
  "/entrypoint.sh" \
  "/usr/local/bin/entrypoint.sh" \
  "/usr/local/bin/docker-entrypoint.sh" \
  "/docker-entrypoint.sh" \
  "/var/www/eramba/app/upgrade/bin/cake" \
  "/var/www/eramba/bin/cake"
do
  if [[ -x "$candidate" ]]; then
    echo "==> found executable: $candidate"

    # Si es Cake, intentamos el postInstall que viste en logs
    if [[ "$candidate" == *"/bin/cake" ]]; then
      echo "==> running: php $candidate installer postInstall (best effort)"
      php "$candidate" installer postInstall || true
    else
      echo "==> running: $candidate (best effort)"
      "$candidate" || true
    fi
  fi
done

# 5) Si aún no existe app_local, copiamos un ejemplo (último recurso)
# OJO: esto NO mete migraciones, solo crea el archivo local.
ROOT="/var/www/eramba/app/upgrade"
if [[ ! -f "$ROOT/config/app_local.php" ]] && [[ -f "$ROOT/config/app_local.example.php" ]]; then
  echo "==> app_local.php missing, creating from example (upgrade root)"
  cp "$ROOT/config/app_local.example.php" "$ROOT/config/app_local.php" || true
fi

# (también probamos el root principal si existiera)
ROOT2="/var/www/eramba"
if [[ ! -f "$ROOT2/config/app_local.php" ]] && [[ -f "$ROOT2/config/app_local.example.php" ]]; then
  echo "==> app_local.php missing, creating from example (main root)"
  cp "$ROOT2/config/app_local.example.php" "$ROOT2/config/app_local.php" || true
fi

apache2ctl -t

echo "==> starting Apache in foreground"
exec apache2ctl -D FOREGROUND
