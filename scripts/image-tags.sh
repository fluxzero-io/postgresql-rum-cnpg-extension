#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
version_file="${1:-${repo_root}/versions/pg18-bullseye.env}"
mode="${2:-env}"

if [[ "${version_file}" != /* ]]; then
  version_file="${repo_root}/${version_file}"
fi

# shellcheck disable=SC1090
source "${version_file}"

: "${PG_MAJOR:?}"
: "${PG_DISTRO:?}"
: "${BASE_IMAGE:?}"
: "${PG_VERSION:?}"
: "${RUM_PACKAGE:?}"
: "${RUM_PACKAGE_VERSION:?}"
: "${RUM_UPSTREAM_VERSION:?}"
: "${RUM_PACKAGE_SHA256:?}"

IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension}"

package_revision="${RUM_PACKAGE_VERSION#${RUM_UPSTREAM_VERSION}-}"
if [[ "${package_revision}" == "${RUM_PACKAGE_VERSION}" ]]; then
  package_revision="${RUM_PACKAGE_VERSION}"
fi

# PGDG package revisions commonly look like 1.pgdg11+2. The public tag keeps
# the meaningful PGDG part and replaces Docker-incompatible characters.
package_revision="${package_revision#1.}"
safe_revision="${package_revision//+/.}"
safe_revision="${safe_revision//~/-}"
safe_revision="${safe_revision//:/-}"
safe_revision="${safe_revision//[^a-zA-Z0-9_.-]/-}"

IMMUTABLE_TAG="${RUM_UPSTREAM_VERSION}-${safe_revision}-pg${PG_MAJOR}-${PG_DISTRO}"
UPSTREAM_TAG="${RUM_UPSTREAM_VERSION}-pg${PG_MAJOR}-${PG_DISTRO}"
ROLLING_TAG="pg${PG_MAJOR}-${PG_DISTRO}"

print_env() {
  printf 'IMAGE_REPOSITORY=%s\n' "${IMAGE_REPOSITORY}"
  printf 'IMMUTABLE_TAG=%s\n' "${IMMUTABLE_TAG}"
  printf 'UPSTREAM_TAG=%s\n' "${UPSTREAM_TAG}"
  printf 'ROLLING_TAG=%s\n' "${ROLLING_TAG}"
  printf 'BASE_IMAGE=%s\n' "${BASE_IMAGE}"
  printf 'PG_MAJOR=%s\n' "${PG_MAJOR}"
  printf 'PG_VERSION=%s\n' "${PG_VERSION}"
  printf 'PG_DISTRO=%s\n' "${PG_DISTRO}"
  printf 'RUM_PACKAGE=%s\n' "${RUM_PACKAGE}"
  printf 'RUM_PACKAGE_VERSION=%s\n' "${RUM_PACKAGE_VERSION}"
  printf 'RUM_PACKAGE_SHA256=%s\n' "${RUM_PACKAGE_SHA256}"
}

print_full_tags() {
  printf '%s:%s\n' "${IMAGE_REPOSITORY}" "${IMMUTABLE_TAG}"
  printf '%s:%s\n' "${IMAGE_REPOSITORY}" "${UPSTREAM_TAG}"
  printf '%s:%s\n' "${IMAGE_REPOSITORY}" "${ROLLING_TAG}"
}

case "${mode}" in
  env)
    print_env
    ;;
  immutable-tag)
    printf '%s\n' "${IMMUTABLE_TAG}"
    ;;
  full-tags)
    print_full_tags
    ;;
  github-output)
    : "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set for github-output mode}"
    {
      printf 'image_repository=%s\n' "${IMAGE_REPOSITORY}"
      printf 'immutable_tag=%s\n' "${IMMUTABLE_TAG}"
      printf 'upstream_tag=%s\n' "${UPSTREAM_TAG}"
      printf 'rolling_tag=%s\n' "${ROLLING_TAG}"
      printf 'base_image=%s\n' "${BASE_IMAGE}"
      printf 'pg_major=%s\n' "${PG_MAJOR}"
      printf 'pg_version=%s\n' "${PG_VERSION}"
      printf 'pg_distro=%s\n' "${PG_DISTRO}"
      printf 'rum_package=%s\n' "${RUM_PACKAGE}"
      printf 'rum_package_version=%s\n' "${RUM_PACKAGE_VERSION}"
      printf 'rum_package_sha256=%s\n' "${RUM_PACKAGE_SHA256}"
      printf 'tags<<EOF\n'
      print_full_tags
      printf 'EOF\n'
    } >> "${GITHUB_OUTPUT}"
    ;;
  *)
    printf 'Unknown mode: %s\n' "${mode}" >&2
    exit 64
    ;;
esac
