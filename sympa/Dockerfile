# Si 13.1 n’est pas dispo sur ton registre, remplace par debian:13-slim
FROM debian:13.1

ENV DEBIAN_FRONTEND=noninteractive

# Paquets de base + Sympa + client PG (pour tests/health)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg gettext-base \
      postgresql-client \
      # Paquets Sympa (les noms peuvent varier selon la release)
      sympa sympa-www \
      apache2 libfcgi-perl spawn-fcgi fcgiwrap \
    && rm -rf /var/lib/apt/lists/*

# Prépare un utilisateur système (optionnel, selon ta politique)
RUN useradd -r -M -s /usr/sbin/nologin sympa || true

# Copie de l’entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose HTTP (si tu utilises Apache dans ce conteneur)
EXPOSE 80

# Dossiers persistants (montés par docker-compose)
VOLUME ["/etc/sympa", "/var/lib/sympa", "/var/spool/sympa"]

# Démarrage
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apachectl", "-D", "FOREGROUND"]
