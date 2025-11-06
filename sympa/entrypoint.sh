#!/usr/bin/env bash
set -euo pipefail

# Valeurs par défaut
: "${DB_HOST:=db}"
: "${DB_PORT:=5432}"
: "${DB_NAME:=sympa}"
: "${DB_USER:=sympa}"
: "${DB_PASSWORD:=sympa}"

echo "[sympa-entrypoint] Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
until pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" >/dev/null 2>&1; do
  sleep 2
done
echo "[sympa-entrypoint] PostgreSQL is ready."

# Génère (ou met à jour) la config DB de Sympa si absente
mkdir -p /etc/sympa
DB_CONF="/etc/sympa/robot.conf"
MAIN_CONF="/etc/sympa/sympa.conf"

if [ ! -f "${MAIN_CONF}" ]; then
  cat > "${MAIN_CONF}" <<EOF
## Fichier généré par l'image Docker
db_type  PostgreSQL
db_host  ${DB_HOST}
db_port  ${DB_PORT}
db_name  ${DB_NAME}
db_user  ${DB_USER}
db_passwd  ${DB_PASSWORD}

# Ajuste selon ton domaine et chemins :
domain  example.org
listmasters  postmaster@example.org
log_facility  LOCAL1
EOF
  echo "[sympa-entrypoint] /etc/sympa/sympa.conf créé."
fi

# (Optionnel) préparation Apache/FCGI – active les modules utiles
if command -v a2enmod >/dev/null 2>&1; then
  a2enmod cgi || true
  a2enmod proxy_fcgi || true
fi

# TODO :
# - initialiser le schéma si besoin via les outils Sympa, ex:
#   sympa.pl --health_check  (ou outils d'init fournis par ta version)
# - config Apache vhost pour l’interface web de Sympa
# - intégrer Postfix/Exim (dans un conteneur séparé de préférence)

echo "[sympa-entrypoint] Starting main process: $*"
exec "$@"
