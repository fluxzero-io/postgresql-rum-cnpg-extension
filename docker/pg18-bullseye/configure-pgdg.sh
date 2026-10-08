#!/bin/sh
# PGDG archived Bullseye after its support ended. Keep signature verification.
set -eu
. /etc/os-release
if [ "${VERSION_CODENAME:-}" != bullseye ]; then
  echo "pg18-bullseye requires a Bullseye base; add a new target for another distro." >&2
  exit 1
fi
sed -i \
  -e 's|http://apt.postgresql.org/pub/repos/apt|https://apt-archive.postgresql.org/pub/repos/apt|g' \
  -e 's|https://apt.postgresql.org/pub/repos/apt|https://apt-archive.postgresql.org/pub/repos/apt|g' \
  /etc/apt/sources.list.d/pgdg.list
