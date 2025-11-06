FROM debian:13.1
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg gettext-base \
      postgresql-client \
      sympa \
      apache2 libapache2-mod-fcgid \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80
VOLUME ["/etc/sympa", "/var/lib/sympa", "/var/spool/sympa"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apachectl", "-D", "FOREGROUND"]