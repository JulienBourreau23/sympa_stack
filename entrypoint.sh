#!/usr/bin/env bash
set -euo pipefail

############################
# 0) Variables d’environnement
############################
: "${DB_HOST:=db}"
: "${DB_PORT:=5432}"
: "${DB_NAME:=sympa}"
: "${DB_USER:=sympa}"
: "${DB_PASSWORD:=sympa}"

: "${SYMPA_DOMAIN:=localhost}"
: "${SYMPA_LISTMASTER:=postmaster@tondomaine.tld}"
: "${SYMPA_HTTP_PORT:=8080}"

# Aide Sympa à trouver sa conf et ses libs
export SYMPA_DOMAIN
export SYMPA_CONF="/etc/sympa/sympa.conf"
export PERL5LIB="/usr/share/sympa/lib"

echo "[sympa-entrypoint] DB = ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo "[sympa-entrypoint] Domain = ${SYMPA_DOMAIN}, listmaster = ${SYMPA_LISTMASTER}"

echo "[sympa-entrypoint] Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
until pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" >/dev/null 2>&1; do
  sleep 2
done
echo "[sympa-entrypoint] PostgreSQL is ready."

############################
# 1) mailname + Apache ServerName
############################
echo "${SYMPA_DOMAIN}" > /etc/mailname

if [ ! -f /etc/apache2/conf-available/servername.conf ]; then
  echo "ServerName ${SYMPA_DOMAIN}" > /etc/apache2/conf-available/servername.conf || true
  a2enconf servername || true
fi

############################
# 2) Installation de Sympa au runtime (si absent)
############################
if ! dpkg -s sympa >/dev/null 2>&1; then
  echo "[sympa-entrypoint] Installing Sympa (runtime)..."
  export DEBIAN_FRONTEND=noninteractive

  # Bloquer les tentatives de démarrage de services
  ln -sf /bin/true /usr/bin/systemctl 2>/dev/null || true
  ln -sf /bin/true /usr/sbin/service   2>/dev/null || true
  printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
  chmod +x /usr/sbin/policy-rc.d

  apt-get update

  # Désactiver dbconfig pour sympa (on gère la DB nous-mêmes)
  echo "sympa sympa/dbconfig-install boolean false"        | debconf-set-selections
  echo "sympa sympa/remove-purge boolean true"             | debconf-set-selections
  echo "sympa sympa/listmaster string ${SYMPA_LISTMASTER}" | debconf-set-selections

  set +e
  apt-get install -y --no-install-recommends sympa
  rc_install=$?
  dpkg --configure -a
  rc_config=$?
  set -e

  echo "[sympa-entrypoint] apt-get rc=${rc_install} ; dpkg --configure rc=${rc_config}"
  tail -n 50 /var/log/dpkg.log || true

  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
else
  echo "[sympa-entrypoint] Sympa already installed."
fi

############################
# 3) Configuration Sympa (single domain)
############################
echo "[sympa-entrypoint] Writing Sympa config"

mkdir -p /etc/sympa/sympa
mkdir -p /etc/sympa/"${SYMPA_DOMAIN}"

cat >/etc/sympa/sympa/sympa.conf <<EOF
## Global Sympa config (single domain)

# Répertoire de configuration
etc          /etc/sympa

# Domaine “principal” des listes
domain       ${SYMPA_DOMAIN}

# Listmaster global (super-listmaster)
listmaster   ${SYMPA_LISTMASTER}

# URL de l'interface web Sympa
wwsympa_url  http://${SYMPA_DOMAIN}/sympa

# Base PostgreSQL
db_type      PostgreSQL
db_host      ${DB_HOST}
db_port      ${DB_PORT}
db_name      ${DB_NAME}
db_user      ${DB_USER}
db_passwd    ${DB_PASSWORD}
EOF

cp -f /etc/sympa/sympa/sympa.conf /etc/sympa/sympa.conf || true

cat >/etc/sympa/"${SYMPA_DOMAIN}"/robot.conf <<EOF
## Robot config for ${SYMPA_DOMAIN}

domain       ${SYMPA_DOMAIN}
listmaster   ${SYMPA_LISTMASTER}
http_host    ${SYMPA_DOMAIN}
wwsympa_url  http://${SYMPA_DOMAIN}/sympa
EOF

echo "[sympa-entrypoint] /etc/sympa/sympa.conf:"
sed -n '1,30p' /etc/sympa/sympa.conf || true

############################
# 4) Création du schéma PostgreSQL si nécessaire
############################
echo "[sympa-entrypoint] Checking Sympa DB schema"
export PGPASSWORD="${DB_PASSWORD}"

if command -v psql >/dev/null 2>&1; then
  # On considère que la table sympa_session est un bon indicateur
  if ! psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c "\dt" | grep -q "sympa_session"; then
    echo "[sympa-entrypoint] No Sympa tables found, loading schema into PostgreSQL..."

    if [ -f /usr/share/doc/sympa/examples/create_db.Pg.gz ]; then
      zcat /usr/share/doc/sympa/examples/create_db.Pg.gz | \
        psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}"
    elif [ -f /usr/share/doc/sympa/examples/db_pgsql.sql.gz ]; then
      zcat /usr/share/doc/sympa/examples/db_pgsql.sql.gz | \
        psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}"
    else
      echo "[sympa-entrypoint] WARNING: No Sympa schema SQL file found in /usr/share/doc/sympa/examples"
    fi
  else
    echo "[sympa-entrypoint] Sympa DB already has tables, skipping schema creation."
  fi
else
  echo "[sympa-entrypoint] psql not found (?) – cannot initialize DB schema."
fi

unset PGPASSWORD

############################
# 5) Corriger le chemin de wwsympa.fcgi
############################
mkdir -p /usr/lib/cgi-bin/sympa

if [ -x /usr/lib/cgi-bin/wwsympa.fcgi ]; then
  ln -sf ../wwsympa.fcgi /usr/lib/cgi-bin/sympa/wwsympa.fcgi
elif [ -x /usr/lib/sympa/cgi/wwsympa.fcgi ]; then
  ln -sf /usr/lib/sympa/cgi/wwsympa.fcgi /usr/lib/cgi-bin/sympa/wwsympa.fcgi
fi

if [ -f /usr/lib/cgi-bin/sympa/wwsympa.fcgi ]; then
  chmod 755 /usr/lib/cgi-bin/sympa/wwsympa.fcgi || true
else
  echo "[sympa-entrypoint] WARNING: /usr/lib/cgi-bin/sympa/wwsympa.fcgi not found"
fi

############################
# 6) Upgrade / check Sympa
############################
if [ ! -f /var/lib/sympa/.initialized ]; then
  echo "[sympa-entrypoint] Running: sympa.pl --upgrade (DB init / upgrade)"

  if command -v sympa.pl >/dev/null 2>&1; then
    set +e
    sympa.pl --upgrade
    rc_up=$?
    set -e
    echo "[sympa-entrypoint] sympa.pl --upgrade exit code=${rc_up} (often non-zero on fresh DB, can be ignored si tout marche)"
  fi

  touch /var/lib/sympa/.initialized || true
fi

############################
# 7) Apache
############################
a2enmod fcgid   || true
a2enmod rewrite || true
a2ensite sympa  || true
a2dissite 000-default || true

echo "[sympa-entrypoint] Starting Apache: $*"
exec "$@"