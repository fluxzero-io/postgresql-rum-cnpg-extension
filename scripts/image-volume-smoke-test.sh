#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

image="${1:?Usage: scripts/image-volume-smoke-test.sh IMAGE [VERSION_FILE]}"
version_file="${2:-${repo_root}/versions/pg18-bullseye.env}"

if [[ "${version_file}" != /* ]]; then
  version_file="${repo_root}/${version_file}"
fi

# shellcheck disable=SC1090
source "${version_file}"

platform="${PLATFORM:-linux/amd64}"
extension_name="${EXTENSION_NAME:-rum}"
extension_root="/extensions/${extension_name}"

printf 'Running image-volume smoke test for %s on %s\n' "${image}" "${platform}"

docker run --rm -i \
  --platform "${platform}" \
  --mount "type=image,source=${image},target=${extension_root},readonly" \
  --user postgres \
  --env "PG_MAJOR=${PG_MAJOR}" \
  --env "EXTENSION_ROOT=${extension_root}" \
  "${BASE_IMAGE}" \
  sh -s <<'CONTAINER_SCRIPT'
set -eux

export PATH="/usr/lib/postgresql/${PG_MAJOR}/bin:${PATH}"
export PGDATA="/tmp/rum-image-volume-data"
export PGHOST="/tmp/rum-image-volume-run"

mkdir -p "${PGDATA}" "${PGHOST}"

test -f "${EXTENSION_ROOT}/share/extension/rum.control"
test -f "${EXTENSION_ROOT}/lib/rum.so"

initdb -D "${PGDATA}" --no-locale --encoding=UTF8

printf "%s\n" \
  "listen_addresses = ''" \
  "unix_socket_directories = '${PGHOST}'" \
  "extension_control_path = '${EXTENSION_ROOT}/share:\$system'" \
  "dynamic_library_path = '${EXTENSION_ROOT}/lib:\$libdir'" \
  >> "${PGDATA}/postgresql.conf"

pg_ctl -D "${PGDATA}" -w start

psql -v ON_ERROR_STOP=1 -d postgres \
  -c "SHOW extension_control_path;" \
  -c "SHOW dynamic_library_path;" \
  -c "CREATE EXTENSION rum;" \
  -c "SELECT extname, extversion FROM pg_extension WHERE extname = 'rum';" \
  -c "CREATE TABLE rum_smoke (id bigint generated always as identity primary key, summary tsvector);" \
  -c "CREATE INDEX rum_smoke_summary_rum ON rum_smoke USING rum (summary rum_tsvector_ops);"

pg_ctl -D "${PGDATA}" -m fast -w stop
CONTAINER_SCRIPT

printf 'Image-volume smoke test passed for %s\n' "${image}"
