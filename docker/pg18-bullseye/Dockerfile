# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

ARG PG_MAJOR=18
ARG PG_VERSION
ARG PG_DISTRO=bullseye
ARG RUM_PACKAGE=postgresql-18-rum
ARG RUM_PACKAGE_VERSION
ARG RUM_PACKAGE_SHA256

FROM ghcr.io/cloudnative-pg/postgresql:18.6 AS build
ARG PG_MAJOR
ARG RUM_PACKAGE
ARG RUM_PACKAGE_VERSION
ARG RUM_PACKAGE_SHA256

USER root
COPY configure-pgdg.sh /tmp/configure-pgdg.sh

RUN set -eux; \
    sh /tmp/configure-pgdg.sh; \
    test -n "${RUM_PACKAGE_VERSION}"; \
    test -n "${RUM_PACKAGE_SHA256}"; \
    apt-get update; \
    cd /tmp; \
    apt-get download "${RUM_PACKAGE}=${RUM_PACKAGE_VERSION}"; \
    deb_file="$(find . -maxdepth 1 -type f -name "${RUM_PACKAGE}_*.deb" -print -quit)"; \
    test -n "${deb_file}"; \
    echo "${RUM_PACKAGE_SHA256}  ${deb_file}" | sha256sum -c -; \
    dpkg -i "${deb_file}"; \
    rm -f "${deb_file}"; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    mkdir -p /rum/share/extension /rum/lib /rum/licenses; \
    cp "/usr/share/postgresql/${PG_MAJOR}/extension"/rum* /rum/share/extension/; \
    cp "/usr/lib/postgresql/${PG_MAJOR}/lib/rum.so" /rum/lib/; \
    if [ -d "/usr/share/doc/${RUM_PACKAGE}" ]; then \
      find "/usr/share/doc/${RUM_PACKAGE}" -maxdepth 1 -type f \( -iname 'copyright' -o -iname 'changelog*' \) -exec cp {} /rum/licenses/ \; ; \
    fi; \
    test -f /rum/share/extension/rum.control; \
    test -f /rum/lib/rum.so

FROM scratch
ARG PG_MAJOR
ARG PG_VERSION
ARG PG_DISTRO
ARG RUM_PACKAGE_VERSION
ARG RUM_PACKAGE_SHA256

LABEL org.opencontainers.image.title="PostgreSQL RUM extension for CloudNativePG"
LABEL org.opencontainers.image.description="Extension-only image containing RUM files for CloudNativePG Image Volume Extensions"
LABEL org.opencontainers.image.source="https://github.com/fluxzero-io/postgresql-rum-cnpg-extension"
LABEL io.cloudnativepg.image.base.pgmajor="${PG_MAJOR}"
LABEL io.cloudnativepg.image.base.version="${PG_VERSION}"
LABEL io.cloudnativepg.image.base.os="${PG_DISTRO}"
LABEL io.cloudnativepg.image.sql.version="${RUM_PACKAGE_VERSION}"
LABEL io.cloudnativepg.image.sql.package_sha256="${RUM_PACKAGE_SHA256}"

COPY --from=build /rum/share /share
COPY --from=build /rum/lib /lib
COPY --from=build /rum/licenses /licenses
