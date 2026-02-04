#!/usr/bin/env bash
set -e

# Apagar MPMs (fuerza bruta en mods-enabled)
rm -f /etc/apache2/mods-enabled/mpm_event.* || true
rm -f /etc/apache2/mods-enabled/mpm_worker.* || true
rm -f /etc/apache2/mods-enabled/mpm_prefork.* || true

# Encender SOLO prefork
ln -s /etc/apache2/mods-available/mpm_prefork.load /etc/apache2/mods-enabled/mpm_prefork.load || true
ln -s /etc/apache2/mods-available/mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf || true

# Evitar warning de ServerName
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername || true

# Validar config
apache2ctl -t

exec apache2ctl -D FOREGROUND
