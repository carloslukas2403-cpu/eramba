FROM ghcr.io/eramba/eramba:3.28.1-6

# Dejar SOLO 1 MPM (prefork) para evitar: AH00534 more than one MPM loaded
RUN a2dismod mpm_event || true \
 && a2dismod mpm_worker || true \
 && a2dismod mpm_prefork || true \
 && a2enmod mpm_prefork \
 && apache2ctl -M | grep mpm || true \
 && apache2ctl -t
