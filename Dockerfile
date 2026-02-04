FROM ghcr.io/eramba/eramba:latest

# Dejar SOLO 1 MPM (prefork) para evitar: AH00534 more than one MPM loaded
RUN a2dismod mpm_event mpm_worker || true \
 && a2enmod mpm_prefork \
 && apache2ctl -t
