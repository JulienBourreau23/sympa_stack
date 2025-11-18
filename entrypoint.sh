#!/usr/bin/env bash
set -euo pipefail

: "${DB_HOST:=db}"
: "${DB_PORT:=5432}"
: "${DB_NAME:=sympa}"
: "${DB_USER:=sympa}"
: "${DB_PASSWORD:=sympa}"
: "${SYMPA_DOMAIN:=example.org}"
: "${SYMPA_LISTMASTER:=postmaster@example.org}"

echo "[sympa-entrypoint] Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
until pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" >/dev/null 2>&1; do
  sleep 2
done
echo "[sympa-entrypoint] PostgreSQL is ready."

# mailname pour postfix / sympa
echo "${SYMPA_DOMAIN}" > /etc/mailname

# Eviter l’avertissement Apache sur le FQDN
if [ ! -f /etc/apache2/conf-available/servername.conf ]; then
  echo "ServerName ${SYMPA_DOMAIN}" > /etc/apache2/conf-available/servername.conf || true
  a2enconf servername || true
fi

# 0) Si les volumes sont vides, les peupler depuis les .orig créés au build
if [ -d /etc/sympa.orig ] && [ -z "$(ls -A /etc/sympa 2>/dev/null || true)" ]; then
  echo "[sympa-entrypoint] Seeding /etc/sympa from /etc/sympa.orig"
  cp -a /etc/sympa.orig/* /etc/sympa/ || true
fi

if [ -d /var/lib/sympa.orig ] && [ -z "$(ls -A /var/lib/sympa 2>/dev/null || true)" ]; then
  echo "[sympa-entrypoint] Seeding /var/lib/sympa from /var/lib/sympa.orig"
  cp -a /var/lib/sympa.orig/* /var/lib/sympa/ || true
fi

if [ -d /var/spool/sympa.orig ] && [ -z "$(ls -A /var/spool/sympa 2>/dev/null || true)" ]; then
  echo "[sympa-entrypoint] Seeding /var/spool/sympa from /var/spool/sympa.orig"
  cp -a /var/spool/sympa.orig/* /var/spool/sympa/ || true
fi

# 1) Générer /etc/sympa/sympa.conf avec les paramètres de la DB
mkdir -p /etc/sympa

cat >/etc/sympa/sympa.conf <<EOF
db_type    PostgreSQL
db_host    ${DB_HOST}
db_port    ${DB_PORT}
db_name    ${DB_NAME}
db_user    ${DB_USER}
db_passwd  ${DB_PASSWORD}
domain     ${SYMPA_DOMAIN}
listmasters ${SYMPA_LISTMASTER}
EOF

# 2) Remplacer les variables dans la conf Apache (ServerName / ServerAdmin)
if grep -q '\${SYMPA_DOMAIN}' /etc/apache2/sites-available/sympa.conf 2>/dev/null; then
  echo "[sympa-entrypoint] Applying envsubst on sympa-apache.conf"
  envsubst '${SYMPA_DOMAIN} ${SYMPA_LISTMASTER}' \
    </etc/apache2/sites-available/sympa.conf \
    >/etc/apache2/sites-available/sympa.conf.tmp
  mv /etc/apache2/sites-available/sympa.conf.tmp /etc/apache2/sites-available/sympa.conf
fi

# Apache: activer les modules/sites nécessaires
a2enmod fcgid || true
a2enmod rewrite || true
a2ensite sympa || true
a2dissite 000-default || true

echo "[sympa-entrypoint] Starting: $*"
exec "$@"
