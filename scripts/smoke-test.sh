#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
version_file="${1:-${repo_root}/versions/pg18-bullseye.env}"

if [[ "${version_file}" != /* ]]; then
  version_file="${repo_root}/${version_file}"
fi

# shellcheck disable=SC1090
source "${version_file}"

platform="${PLATFORM:-linux/amd64}"
immutable_tag="$("${script_dir}/image-tags.sh" "${version_file}" immutable-tag)"
local_image="${LOCAL_IMAGE:-postgresql-rum-cnpg-extension:${immutable_tag}}"
docker_dir="${repo_root}/docker/pg18-bullseye"

printf 'Building extension image %s for %s\n' "${local_image}" "${platform}"
docker buildx build \
  --platform "${platform}" \
  --load \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "PG_MAJOR=${PG_MAJOR}" \
  --build-arg "PG_VERSION=${PG_VERSION}" \
  --build-arg "PG_DISTRO=${PG_DISTRO}" \
  --build-arg "RUM_PACKAGE=${RUM_PACKAGE}" \
  --build-arg "RUM_PACKAGE_VERSION=${RUM_PACKAGE_VERSION}" \
  --build-arg "RUM_PACKAGE_SHA256=${RUM_PACKAGE_SHA256}" \
  -t "${local_image}" \
  -f "${docker_dir}/Dockerfile" \
  "${docker_dir}"

"${script_dir}/inspect-image.sh" "${local_image}"

"${script_dir}/image-volume-smoke-test.sh" "${local_image}" "${version_file}"

printf 'Smoke test passed for %s\n' "${local_image}"
