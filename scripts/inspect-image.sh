#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: scripts/inspect-image.sh IMAGE}"
platform="${PLATFORM:-linux/amd64}"
tmp_dir="$(mktemp -d)"
container_id=""

cleanup() {
  if [[ -n "${container_id}" ]]; then
    docker rm -f "${container_id}" >/dev/null 2>&1 || true
  fi
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

container_id="$(docker create --platform "${platform}" "${image}" /noop)"
mkdir -p "${tmp_dir}/root"
docker cp "${container_id}:/share" "${tmp_dir}/root/share"
docker cp "${container_id}:/lib" "${tmp_dir}/root/lib"

test -f "${tmp_dir}/root/share/extension/rum.control"
test -f "${tmp_dir}/root/lib/rum.so"

sql_count="$(find "${tmp_dir}/root/share/extension" -maxdepth 1 -type f -name 'rum--*.sql' | wc -l | tr -d ' ')"
if [[ "${sql_count}" -eq 0 ]]; then
  printf 'No rum--*.sql files found in %s\n' "${image}" >&2
  exit 1
fi

sql_version="$(docker image inspect "${image}" --format '{{ index .Config.Labels "io.cloudnativepg.image.sql.version" }}')"
sql_sha256="$(docker image inspect "${image}" --format '{{ index .Config.Labels "io.cloudnativepg.image.sql.package_sha256" }}')"
base_version="$(docker image inspect "${image}" --format '{{ index .Config.Labels "io.cloudnativepg.image.base.version" }}')"
base_os="$(docker image inspect "${image}" --format '{{ index .Config.Labels "io.cloudnativepg.image.base.os" }}')"

printf 'Image: %s\n' "${image}"
printf 'RUM SQL files: %s\n' "${sql_count}"
printf 'RUM package version label: %s\n' "${sql_version}"
printf 'RUM package SHA256 label: %s\n' "${sql_sha256}"
printf 'Base PostgreSQL version label: %s\n' "${base_version}"
printf 'Base distro label: %s\n' "${base_os}"
find "${tmp_dir}/root/share/extension" -maxdepth 1 -type f | sort | while IFS= read -r file; do
  printf '/share/extension/%s\n' "$(basename "${file}")"
done
printf '/lib/rum.so\n'
