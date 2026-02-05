#!/usr/bin/env bash
set -e

# 1) Apagar MPMs a nivel de symlinks (más fuerte que a2dismod)
rm -f /etc/apache2/mods-enabled/mpm_event.* || true
rm -f /etc/apache2/mods-enabled/mpm_worker.* || true
rm -f /etc/apache2/mods-enabled/mpm_prefork.* || true

# 2) Encender solo prefork
ln -s /etc/apache2/mods-available/mpm_prefork.load /etc/apache2/mods-enabled/mpm_prefork.load || true
ln -s /etc/apache2/mods-available/mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf || true

# (Opcional) evitar warning ServerName
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername || true

apache2ctl -t

# 3) Ejecutar el comando original del contenedor
exec apache2ctl -D FOREGROUND
