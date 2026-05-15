#!/usr/bin/env bash
# Runtime entrypoint for the otserv container.
#
# Two responsibilities:
#   1. Wait until the mariadb sidecar is reachable. otserv crashes hard if
#      the database isn't there at startup, and compose's `depends_on` only
#      waits for the container to *start*, not for MySQL itself to be ready.
#   2. Patch config.lua to point at our local mariadb instead of the
#      hardcoded `jamera.com.br` credentials the upstream repo ships with.
#      Without this the binary would attempt an outbound connection to a
#      third-party MySQL on every boot. (Network egress is also blocked at
#      the compose level as defence in depth.)
#
# All five OTSERV_SQL_* values come from docker-compose.yml env vars and
# default to safe values for local dev — never run this image without the
# compose orchestration providing them.

set -euo pipefail

: "${OTSERV_SQL_HOST:?OTSERV_SQL_HOST must be set (e.g. 'mariadb')}"
: "${OTSERV_SQL_PORT:=3306}"
: "${OTSERV_SQL_USER:?OTSERV_SQL_USER must be set}"
: "${OTSERV_SQL_PASS:?OTSERV_SQL_PASS must be set}"
: "${OTSERV_SQL_DB:?OTSERV_SQL_DB must be set}"

echo "[entrypoint] Waiting for mariadb at ${OTSERV_SQL_HOST}:${OTSERV_SQL_PORT}..."
# nc -z probes a TCP port without sending any data. Loop up to 60 seconds.
for _ in $(seq 1 60); do
  if nc -z "${OTSERV_SQL_HOST}" "${OTSERV_SQL_PORT}" 2>/dev/null; then
    echo "[entrypoint] mariadb reachable."
    break
  fi
  sleep 1
done

# Patch the config in-place. Each substitution is anchored on the variable
# name (Lua `Var = "..."` style) so we don't accidentally replace something
# elsewhere. The /tmp/config.lua write goes to a tmpfs mount (read-only root
# filesystem prevents writing to /app).
mkdir -p /tmp/otserv
cp /app/config.lua /tmp/otserv/config.lua

sed -i -E \
  -e "s|^\s*SQL_Host\s*=.*|    SQL_Host = \"${OTSERV_SQL_HOST}\"|" \
  -e "s|^\s*SQL_Port\s*=.*|    SQL_Port = ${OTSERV_SQL_PORT}|" \
  -e "s|^\s*SQL_User\s*=.*|    SQL_User = \"${OTSERV_SQL_USER}\"|" \
  -e "s|^\s*SQL_Pass\s*=.*|    SQL_Pass = \"${OTSERV_SQL_PASS}\"|" \
  -e "s|^\s*SQL_DB\s*=.*|    SQL_DB   = \"${OTSERV_SQL_DB}\"|" \
  -e "s|^\s*SQLDatabase\s*=.*|    SQLDatabase = \"${OTSERV_SQL_DB}\"|" \
  /tmp/otserv/config.lua

echo "[entrypoint] config.lua patched. SQL pointing at ${OTSERV_SQL_HOST}:${OTSERV_SQL_PORT}/${OTSERV_SQL_DB} as ${OTSERV_SQL_USER}."

# otserv reads config.lua from its CWD. Symlink the patched copy back in
# (read-only fs makes a real overwrite impossible).
cd /tmp/otserv
ln -sf /app/data data
ln -sf /app/otserv otserv

echo "[entrypoint] Starting otserv..."
exec ./otserv
