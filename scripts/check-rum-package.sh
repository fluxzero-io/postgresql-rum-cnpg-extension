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

: "${BASE_IMAGE:?}"
: "${RUM_PACKAGE:?}"

platform="${PLATFORM:-linux/amd64}"

metadata="$(
  docker run --rm --platform "${platform}" --user root --env "RUM_PACKAGE=${RUM_PACKAGE}" "${BASE_IMAGE}" sh -eu -c '
    apt-get update >/dev/null
    candidate="$(apt-cache policy "${RUM_PACKAGE}" | awk "/Candidate:/ {print \$2; exit}")"
    test -n "${candidate}"
    test "${candidate}" != "(none)"
    sha="$(apt-cache show "${RUM_PACKAGE}" | awk -v ver="${candidate}" '"'"'
      BEGIN {RS=""; FS="\n"}
      {
        version = "";
        sha256 = "";
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^Version: /) {
            version = substr($i, 10);
          }
          if ($i ~ /^SHA256: /) {
            sha256 = substr($i, 9);
          }
        }
        if (version == ver) {
          print sha256;
          exit;
        }
      }
    '"'"')"
    test -n "${sha}"
    printf "%s\n%s\n" "${candidate}" "${sha}"
  '
)"

new_package_version="$(printf '%s\n' "${metadata}" | sed -n '1p')"
new_package_sha256="$(printf '%s\n' "${metadata}" | sed -n '2p')"
new_upstream_version="${new_package_version%%-*}"

tmp_file="$(mktemp)"
awk \
  -v package_version="${new_package_version}" \
  -v upstream_version="${new_upstream_version}" \
  -v package_sha256="${new_package_sha256}" '
    BEGIN {
      saw_package_version = 0;
      saw_upstream_version = 0;
      saw_package_sha256 = 0;
    }
    /^RUM_PACKAGE_VERSION=/ {
      print "RUM_PACKAGE_VERSION=" package_version;
      saw_package_version = 1;
      next;
    }
    /^RUM_UPSTREAM_VERSION=/ {
      print "RUM_UPSTREAM_VERSION=" upstream_version;
      saw_upstream_version = 1;
      next;
    }
    /^RUM_PACKAGE_SHA256=/ {
      print "RUM_PACKAGE_SHA256=" package_sha256;
      saw_package_sha256 = 1;
      next;
    }
    { print; }
    END {
      if (!saw_package_version) {
        print "RUM_PACKAGE_VERSION=" package_version;
      }
      if (!saw_upstream_version) {
        print "RUM_UPSTREAM_VERSION=" upstream_version;
      }
      if (!saw_package_sha256) {
        print "RUM_PACKAGE_SHA256=" package_sha256;
      }
    }
  ' "${version_file}" > "${tmp_file}"

if cmp -s "${version_file}" "${tmp_file}"; then
  rm -f "${tmp_file}"
  printf 'RUM package metadata is current: %s (%s)\n' "${new_package_version}" "${new_package_sha256}"
else
  mv "${tmp_file}" "${version_file}"
  printf 'Updated %s to RUM package %s (%s)\n' "${version_file}" "${new_package_version}" "${new_package_sha256}"
  "${script_dir}/image-tags.sh" "${version_file}" full-tags
fi
