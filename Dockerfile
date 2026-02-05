FROM ghcr.io/eramba/eramba:3.28.1-6

COPY fix-mpm.sh /fix-mpm.sh
RUN chmod +x /fix-mpm.sh

ENTRYPOINT ["/fix-mpm.sh"]
