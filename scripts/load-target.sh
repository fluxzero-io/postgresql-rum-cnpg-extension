#!/usr/bin/env bash
# Sourced after repo_root and version_file are set by the caller.
# Keep the Docker FROM as the sole base-image pin, readable by Dependabot.
# shellcheck disable=SC1090
source "${version_file}"
BASE_IMAGE="$(awk '$1 == "FROM" && $3 == "AS" && $4 == "build" {print $2; exit}' "${repo_root}/docker/pg18-bullseye/Dockerfile")"
if [[ ! "${BASE_IMAGE}" =~ ^ghcr\.io/cloudnative-pg/postgresql:([0-9]+)\.([0-9]+)$ ]] || [[ "${BASH_REMATCH[1]}" != "${PG_MAJOR}" ]]; then
  printf 'The base image must remain on PostgreSQL %s; add a new target for another major.\n' "${PG_MAJOR}" >&2
  exit 1
fi
PG_VERSION="${BASE_IMAGE##*:}"
