FROM ghcr.io/eramba/eramba:3.28.1-6

COPY entrypoint.sh /entrypoint-fix.sh
RUN chmod +x /entrypoint-fix.sh

# Ejecuta el fix y luego deja correr el CMD original del contenedor
ENTRYPOINT ["/entrypoint-fix.sh"]
