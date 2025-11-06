# Debian 13 (Trixie). Tu peux aussi utiliser debian:13-slim
FROM debian:13.1

ENV DEBIAN_FRONTEND=noninteractive

# Paquets de base + client PG + Sympa + Apache (mod_fcgid)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg gettext-base \
      postgresql-client \
      sympa \
      apache2 libapache2-mod-fcgid \
    && rm -rf /var/lib/apt/lists/*

# (optionnel) utilisateur applicatif
RUN useradd -r -M -s /usr/sbin/nologin sympa || true

# EntryPoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80

# Volumes persistant Sympa
VOLUME ["/etc/sympa", "/var/lib/sympa", "/var/spool/sympa"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apachectl", "-D", "FOREGROUND"]