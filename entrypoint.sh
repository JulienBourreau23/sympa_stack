#!/usr/bin/env bash
set -euo pipefail

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

# Conf minimale Sympa si absente
mkdir -p /etc/sympa
MAIN_CONF="/etc/sympa/sympa.conf"
if [ ! -f "${MAIN_CONF}" ]; then
  cat > "${MAIN_CONF}" <<EOF
db_type  PostgreSQL
db_host  ${DB_HOST}
db_port  ${DB_PORT}
db_name  ${DB_NAME}
db_user  ${DB_USER}
db_passwd  ${DB_PASSWORD}
domain  example.org
listmasters  postmaster@example.org
EOF
  echo "[sympa-entrypoint] /etc/sympa/sympa.conf créé."
fi

exec "$@"
