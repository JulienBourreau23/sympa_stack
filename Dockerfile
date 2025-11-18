FROM debian:13.1
ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC

# Paquets de base + Apache + client PG + outils debconf + Sympa
RUN apt-get update && \
    # Préseed Sympa (listmaster) et Postfix pour éviter les questions
    echo "sympa sympa/listmaster string listmaster@example.com" | debconf-set-selections && \
    echo "postfix postfix/main_mailer_type select No configuration" | debconf-set-selections && \
    echo "postfix postfix/mailname string example.org" | debconf-set-selections && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg gettext-base \
      postgresql-client \
      apache2 libapache2-mod-fcgid \
      debconf-utils dbconfig-no-thanks \
      rsyslog postfix \
      # Sympa + libs Perl utiles (repris du Dockerfile GitLab)
      sympa \
      libclass-c3-xs-perl libdevel-lexalias-perl \
      libfcgi-bin libintl-xs-perl javascript-common libjs-bootstrap libjson-xs-perl \
      libmime-types-perl libdigest-bubblebabble-perl libnet-dns-sec-perl libnet-libidn-perl \
      libperl4-corelibs-perl libgssapi-perl libauthen-sasl-perl libpackage-stash-xs-perl \
      libclass-xsaccessor-perl libxmlrpc-lite-perl libref-util-perl libmath-base-convert-perl \
      libtext-soundex-perl libdata-dump-perl libhtml-form-perl libxml-sax-expat-perl \
      libcrypt-ciphersaber-perl \
    && rm -rf /var/lib/apt/lists/*

# Sauvegarder l'état "origine" pour pouvoir peupler les volumes au premier démarrage
RUN set -eux; \
    mkdir -p /etc/sympa.orig /var/lib/sympa.orig /var/spool/sympa.orig; \
    if [ -d /etc/sympa ]; then cp -a /etc/sympa/* /etc/sympa.orig/ || true; fi; \
    if [ -d /var/lib/sympa ]; then cp -a /var/lib/sympa/* /var/lib/sympa.orig/ || true; fi; \
    if [ -d /var/spool/sympa ]; then cp -a /var/spool/sympa/* /var/spool/sympa.orig/ || true; fi

# Config Apache pour wwsympa (avec variables ${SYMPA_DOMAIN}, ${SYMPA_LISTMASTER})
COPY sympa-apache.conf /etc/apache2/sites-available/sympa.conf

# Entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80

# Volumes pour les données Sympa
VOLUME ["/etc/sympa", "/var/lib/sympa", "/var/spool/sympa"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apachectl", "-D", "FOREGROUND"]