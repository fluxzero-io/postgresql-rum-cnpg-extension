# Agent Notes

This file is for AI agents and automation helpers working on this repository.
The human-facing overview is in `README.md`.

## Project Purpose

This repository owns the Fluxzero-maintained, extension-only OCI image for the
PostgreSQL RUM extension, packaged for CloudNativePG Image Volume Extensions.

The important architectural rule: do not build or publish a full PostgreSQL
server image for production. The production artifact is a tiny `FROM scratch`
image that contains only:

```text
/share/extension/rum.control
/share/extension/rum--*.sql
/lib/rum.so
/licenses/*
```

CloudNativePG keeps using the upstream operand image. RUM is mounted as a
read-only image volume into the Postgres pod.

## Current Target

The only implemented target is `pg18-bullseye`.

Source of truth:

```text
versions/pg18-bullseye.env
```

Current values:

```text
PG_MAJOR=18
PG_VERSION=18.4
PG_DISTRO=bullseye
BASE_IMAGE=ghcr.io/cloudnative-pg/postgresql:18.4
RUM_PACKAGE=postgresql-18-rum
RUM_PACKAGE_VERSION=1.3.15-1.pgdg11+2
RUM_UPSTREAM_VERSION=1.3.15
RUM_PACKAGE_SHA256=3e87fd7b451489b265e291e4d202a51102b3ec0609172a10391c863fd501982e
IMAGE_REPOSITORY=ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension
```

The checksum is architecture-specific. The package watcher and smoke tests must
run against `linux/amd64`; an arm64 Docker host will see a different PGDG
package checksum if the platform is not forced.

## Local Commands

Run these before committing meaningful changes:

```bash
bash -n scripts/*.sh
ruby -e 'require "yaml"; Dir[".github/**/*.yml"].sort.each { |f| YAML.load_file(f); puts "ok #{f}" }'
./scripts/smoke-test.sh versions/pg18-bullseye.env
```

Useful targeted checks:

```bash
./scripts/image-tags.sh versions/pg18-bullseye.env env
./scripts/image-tags.sh versions/pg18-bullseye.env full-tags
./scripts/check-rum-package.sh versions/pg18-bullseye.env
./scripts/inspect-image.sh postgresql-rum-cnpg-extension:1.3.15-pgdg11.2-pg18-bullseye
./scripts/image-volume-smoke-test.sh postgresql-rum-cnpg-extension:1.3.15-pgdg11.2-pg18-bullseye versions/pg18-bullseye.env
```

`./scripts/smoke-test.sh` is the main integration test. It builds the extension
image, inspects the contents, then runs PostgreSQL with the extension image
mounted by Docker image mount.

## Smoke Test Semantics

The primary smoke test intentionally mimics the production CloudNativePG shape:

```text
docker run --mount type=image,source=<extension-image>,target=/extensions/rum,readonly
```

Inside the temporary PostgreSQL container it sets:

```text
extension_control_path = '/extensions/rum/share:$system'
dynamic_library_path = '/extensions/rum/lib:$libdir'
```

Then it runs:

```sql
CREATE EXTENSION rum;
SELECT extname, extversion FROM pg_extension WHERE extname = 'rum';
CREATE TABLE rum_smoke (id bigint generated always as identity primary key, summary tsvector);
CREATE INDEX rum_smoke_summary_rum ON rum_smoke USING rum (summary rum_tsvector_ops);
```

Docker may print `Image mount is an experimental feature`; this is acceptable.
Do not replace the image-volume smoke test with a copy-only test. A copy-only
test can remain as a fallback, but it does not prove the production mount model.

`docker/pg18-bullseye/Dockerfile.smoke` is that fallback. It copies the
extension files into a temporary PostgreSQL image and runs the same SQL checks.

## Build Invariants

Keep `docker/pg18-bullseye/Dockerfile` aligned with these invariants:

- The build stage is based on `BASE_IMAGE`.
- RUM comes from the PGDG Debian package, not from a fork or source checkout.
- The `.deb` package version is pinned by `RUM_PACKAGE_VERSION`.
- The downloaded `.deb` is verified against `RUM_PACKAGE_SHA256`.
- The final stage is `FROM scratch`.
- The final image contains only extension files and practical license metadata.
- OCI labels include PostgreSQL major/version/distro, RUM package version, and
  package SHA256.

Do not silently change the semantics of `pg18-bullseye`. If Fluxzero moves to
Bookworm, Trixie, a different PostgreSQL major, or a different architecture, add
a new target directory and version file.

## Tagging

Do not duplicate tag derivation logic in workflows. Use:

```bash
scripts/image-tags.sh versions/pg18-bullseye.env
```

Current output:

```text
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:1.3.15-pgdg11.2-pg18-bullseye
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:1.3.15-pg18-bullseye
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:pg18-bullseye
```

Docker tags cannot contain `+`, so PGDG revisions are normalized. Example:

```text
1.3.15-1.pgdg11+2 -> 1.3.15-pgdg11.2-pg18-bullseye
```

The immutable tag should remain Dependabot/Renovate-friendly by starting with
the upstream RUM version.

## Package Updates

Use `scripts/check-rum-package.sh` to update `versions/pg18-bullseye.env` when
PGDG publishes a new `postgresql-18-rum` package.

The script:

1. Runs the current `BASE_IMAGE` as root on `linux/amd64`.
2. Runs `apt-get update`.
3. Reads the candidate `RUM_PACKAGE` version.
4. Reads the SHA256 for that exact candidate version.
5. Updates `RUM_PACKAGE_VERSION`, `RUM_UPSTREAM_VERSION`, and
   `RUM_PACKAGE_SHA256` if they changed.

After a package update, run the full smoke test before committing.

Do not fork `postgrespro/rum` unless Fluxzero explicitly needs to carry patches
or PGDG stops publishing the needed package. PGDG is the source of truth for the
production image today.

## Workflows

`pull-requests.yml`

Runs `./scripts/smoke-test.sh versions/pg18-bullseye.env`.

`build-and-publish.yml`

Runs the same smoke test on `main`, computes tags through `scripts/image-tags.sh`,
then publishes `linux/amd64` images to GHCR with provenance and SBOM enabled.

`check-rum-package.yml`

Runs daily and opens a PR when PGDG package metadata changes. It creates a
GitHub App token before calling `peter-evans/create-pull-request`. Keep this:
PRs created with the default `GITHUB_TOKEN` may not trigger the normal PR
workflow.

`dependabot-auto-merge.yml`

Uses `dependabot/fetch-metadata` and a GitHub App token to approve and enable
auto-merge for Dependabot PRs from Docker and GitHub Actions ecosystems.

Expected secrets:

```text
DEPENDABOT_AUTOMERGE_APP_CLIENT_ID
DEPENDABOT_AUTOMERGE_APP_PRIVATE_KEY
```

## Downstream Context

`flux-host-infra-exoscale` should consume this image rather than building its
own RUM image. The downstream repo should keep the CloudNativePG extension
configuration, CNPG `Database` extension declaration, optional pull secrets, and
Fluxzero Runtime RUM settings.

The downstream repo should not need a local `postgresql-rum/` Dockerfile or a
workflow that builds this extension image.

Dependabot may or may not recognize CNPG-style values such as
`postgresql.extensions[].image.reference`. If it does not, use Renovate with a
regex custom manager for this image reference.

## Open Decisions

These are product/ops decisions, not implementation details to guess:

- Should the GHCR package be public?
- Should images also be mirrored to `registry.fluxzero.io`?
- Should production values pin image tags only or full digests?
- Should this repo eventually support `linux/arm64` too?
- Should upstream `postgrespro/rum` releases create informational issues when
  PGDG lags?
- Should this image eventually be proposed upstream to
  `cloudnative-pg/postgres-extensions-containers`?

## Git And Deployment Boundaries

Local commits are allowed when requested or when they make the work complete.
Do not push without explicit user permission. Do not create external releases,
publish GHCR images manually, or alter GitHub secrets without explicit approval.
