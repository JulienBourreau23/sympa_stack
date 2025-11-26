FROM debian:13.1
ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC

# Paquets de base + Apache + client PG + Postfix + outils debconf
RUN apt-get update && \
    echo "postfix postfix/main_mailer_type select No configuration" | debconf-set-selections && \
    echo "postfix postfix/mailname string example.org" | debconf-set-selections && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg gettext-base \
      postgresql-client \
      apache2 libapache2-mod-fcgid \
      debconf-utils dbconfig-no-thanks \
      rsyslog postfix \
      libclass-c3-xs-perl libdevel-lexalias-perl \
      libfcgi-bin libintl-xs-perl javascript-common libjs-bootstrap libjson-xs-perl \
      libmime-types-perl libdigest-bubblebabble-perl libnet-dns-sec-perl libnet-libidn-perl \
      libperl4-corelibs-perl libgssapi-perl libauthen-sasl-perl libpackage-stash-xs-perl \
      libclass-xsaccessor-perl libxmlrpc-lite-perl libref-util-perl libmath-base-convert-perl \
      libtext-soundex-perl libdata-dump-perl libhtml-form-perl libxml-sax-expat-perl \
      libcrypt-ciphersaber-perl \
      # libs manquantes pour que wwsympa.fcgi tourne correctement
      libfcgi-perl libhtml-format-perl libhtml-tree-perl libmime-charset-perl \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# >>> ICI : on copie le vhost Sympa <<<
COPY sympa-apache.conf /etc/apache2/sites-available/sympa.conf

# Entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80

VOLUME ["/etc/sympa", "/var/lib/sympa", "/var/spool/sympa"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apachectl", "-D", "FOREGROUND"]