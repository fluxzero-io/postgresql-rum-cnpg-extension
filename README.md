# PostgreSQL RUM CloudNativePG Extension Image

This repository is intended to own the Fluxzero-maintained, extension-only OCI image for the PostgreSQL RUM extension.
The image is meant for CloudNativePG PostgreSQL 18+ clusters that use Image Volume Extensions.

This document is deliberately detailed. It is the project brief for bootstrapping the new repository with Codex.

## Executive Summary

Fluxzero wants to use RUM indexes in PostgreSQL, primarily for Fluxzero Runtime search collections.
CloudNativePG should keep using the upstream CloudNativePG PostgreSQL operand image, while RUM is delivered as a separate
read-only image volume mounted into the Postgres pod.

The recommended implementation is:

1. Build a small `FROM scratch` extension-only image.
2. Install RUM from the PGDG Debian package in a build stage based on the exact CloudNativePG operand image.
3. Copy only the files PostgreSQL needs into the final image:
   - `/share/extension/rum*`
   - `/lib/rum.so`
   - license/metadata files where practical
4. Publish immutable versioned tags to GHCR, and optionally to `registry.fluxzero.io`.
5. Automate new image releases when the PGDG `postgresql-<PG_MAJOR>-rum` package changes.
6. Let consumer repositories, such as `flux-host-infra-exoscale`, update to new image tags with Dependabot where possible.
7. Use Dependabot for normal GitHub Actions and Docker base-image updates, matching the pattern used in
   `fluxzero-sdk-java` and `fluxzero-runtime`.

The current recommendation is not to fork `postgrespro/rum` unless Fluxzero needs to carry patches or build from source.
For production packaging, the PGDG package is a cleaner source of truth than a fork.

## Why This Repository Exists

CloudNativePG now supports Image Volume Extensions for PostgreSQL 18+. This allows a PostgreSQL extension to be delivered
as a standalone OCI image and mounted into a Postgres pod without baking it into the database operand image.

RUM is not currently part of the official CloudNativePG extension image catalog. The official CloudNativePG
`postgres-extensions-containers` repository currently maintains images for:

- `pg-crash`
- `pgaudit`
- `pgvector`
- `postgis`
- `timescaledb-oss`
- `wal2json`

Because `rum` is absent, Fluxzero needs its own image if it wants to use CNPG's extension-image mechanism.

## Important References

- CloudNativePG Image Volume Extensions:
  https://cloudnative-pg.io/documentation/current/imagevolume_extensions/
- CloudNativePG official extension image repository:
  https://github.com/cloudnative-pg/postgres-extensions-containers
- CloudNativePG official extension catalogs:
  https://github.com/cloudnative-pg/artifacts/tree/main/image-catalogs-extensions
- RUM upstream source repository:
  https://github.com/postgrespro/rum
- RUM latest upstream release observed on 2026-06-04:
  https://github.com/postgrespro/rum/releases/tag/1.3.15
- PGDG apt repository:
  https://apt.postgresql.org/

## Current Observations

Observed on 2026-06-04 from `ghcr.io/cloudnative-pg/postgresql:18.4`:

```text
postgresql-18-rum:
  Candidate: 1.3.15-1.pgdg11+2
  Repository: http://apt.postgresql.org/pub/repos/apt bullseye-pgdg/main amd64
  Package: postgresql-18-rum
  Source: postgresql-rum
  Version: 1.3.15-1.pgdg11+2
  Architecture: amd64
  SHA256: 3e87fd7b451489b265e291e4d202a51102b3ec0609172a10391c863fd501982e
```

The current Fluxzero infrastructure uses `ghcr.io/cloudnative-pg/postgresql:18.4` without an explicit distro suffix.
That image currently resolves to a Debian Bullseye-based operand image. This matters: extension images must match the
PostgreSQL major version, operating system distribution, and CPU architecture of the operand image.

## Goals

- Publish a production-suitable CNPG extension-only image for RUM.
- Keep the database operand image on the official CloudNativePG PostgreSQL image.
- Make the image reproducible enough for production:
  - pinned RUM package version
  - explicit PostgreSQL major version
  - explicit base operand image
  - OCI labels
  - smoke tests
  - immutable tags
- Automate PRs when the RUM package changes in PGDG.
- Automate PRs for GitHub Actions and Docker base image updates via Dependabot.
- Make downstream image updates easy for `flux-host-infra-exoscale`, ideally through Dependabot Docker image updates.
- Support at least `linux/amd64`, because current production clusters run `linux/amd64`.
- Keep the repository small and boring.

## Non-Goals

- Do not ship a full PostgreSQL server image for CNPG production use.
- Do not manage `CREATE EXTENSION rum` in this repository.
- Do not manage Fluxzero Runtime configuration in this repository.
- Do not carry a fork of RUM unless Fluxzero needs patches.
- Do not create a custom extension package manager.
- Do not support every PostgreSQL major/distro combination immediately.

## Forking `postgrespro/rum`: Recommendation

The upstream source repository is `postgrespro/rum`. It has GitHub releases and tags, with `1.3.15` observed as the
latest release on 2026-06-04.

### Recommended Default: Do Not Fork

Use PGDG packages as the source for the production image.

Reasons:

- PGDG packages are already compiled for the target PostgreSQL major version and Debian distribution.
- The package metadata includes the exact version and checksum.
- The package is the same installation path ordinary Debian/PostgreSQL operators use.
- This mirrors the approach CloudNativePG uses for official extension images: build extension images from audited package
  repositories where possible.
- A fork adds synchronization work but does not automatically make the production artifact safer.

### When a Fork Would Make Sense

A fork becomes reasonable if Fluxzero needs one of these:

- Carry a production patch before upstream/PGDG releases it.
- Build RUM from source because PGDG stops publishing a needed package.
- Add CI against CloudNativePG that upstream does not want to maintain.
- Contribute a CNPG packaging workflow upstream or maintain a long-lived packaging branch.

### Optional Middle Ground

Create no fork now, but add an upstream-release watcher:

- Watch `postgrespro/rum` GitHub releases.
- If a new upstream release exists but PGDG has not published the matching package yet, open an issue.
- Once PGDG publishes the package, open the actual package-version PR.

This gives visibility without taking ownership of the source tree.

## Proposed Repository Name

Recommended GitHub repository:

```text
fluxzero-io/postgresql-rum-cnpg-extension
```

Alternative names:

- `fluxzero-io/postgresql-rum-extension-image`
- `fluxzero-io/cnpg-rum-extension`
- `fluxzero-io/postgresql-rum-image`

The first option is the clearest: PostgreSQL RUM, packaged specifically for CloudNativePG extension images.

## Proposed Repository Layout

```text
.
├── .github/
│   ├── dependabot.yml
│   └── workflows/
│       ├── build-and-publish.yml
│       ├── check-rum-package.yml
│       ├── dependabot-auto-merge.yml
│       └── pull-requests.yml
├── docker/
│   └── pg18-bullseye/
│       ├── Dockerfile
│       └── Dockerfile.smoke
├── scripts/
│   ├── check-rum-package.sh
│   ├── inspect-image.sh
│   └── smoke-test.sh
├── versions/
│   └── pg18-bullseye.env
├── README.md
└── LICENSE
```

Keep the first implementation focused on `pg18-bullseye`, because that matches the current
`ghcr.io/cloudnative-pg/postgresql:18.4` operand image.

When the Fluxzero clusters move to a distro-suffixed CloudNativePG image such as `bookworm` or `trixie`, add a new
`docker/pg18-<distro>/` target rather than silently changing the existing tag semantics.

## Version File

Use a plain env file so shell workflows can source it easily:

```bash
PG_MAJOR=18
PG_VERSION=18.4
PG_DISTRO=bullseye
BASE_IMAGE=ghcr.io/cloudnative-pg/postgresql:18.4
RUM_PACKAGE=postgresql-18-rum
RUM_PACKAGE_VERSION=1.3.15-1.pgdg11+2
RUM_UPSTREAM_VERSION=1.3.15
RUM_PACKAGE_SHA256=3e87fd7b451489b265e291e4d202a51102b3ec0609172a10391c863fd501982e
```

The package-version watcher should update this file when PGDG publishes a newer RUM package.

## Dockerfile Requirements

The extension image should be built from the same CloudNativePG operand image used in production.

Example:

```dockerfile
ARG BASE_IMAGE=ghcr.io/cloudnative-pg/postgresql:18.4
ARG PG_MAJOR=18
ARG RUM_PACKAGE=postgresql-18-rum
ARG RUM_PACKAGE_VERSION

FROM ${BASE_IMAGE} AS build
ARG PG_MAJOR
ARG RUM_PACKAGE
ARG RUM_PACKAGE_VERSION

USER root

RUN test -n "${RUM_PACKAGE_VERSION}" \
    && apt-get update \
    && apt-get install -y --no-install-recommends "${RUM_PACKAGE}=${RUM_PACKAGE_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /rum/share/extension /rum/lib /rum/licenses \
    && cp "/usr/share/postgresql/${PG_MAJOR}/extension"/rum* /rum/share/extension/ \
    && cp "/usr/lib/postgresql/${PG_MAJOR}/lib/rum.so" /rum/lib/ \
    && find /usr/share/doc -maxdepth 2 -type f \( -iname 'copyright' -o -iname 'changelog*' \) \
       -path "*${RUM_PACKAGE#postgresql-${PG_MAJOR}-}*" -exec cp {} /rum/licenses/ \; || true

FROM scratch
ARG PG_MAJOR
ARG PG_VERSION
ARG PG_DISTRO
ARG RUM_PACKAGE_VERSION

LABEL org.opencontainers.image.title="PostgreSQL RUM extension for CloudNativePG"
LABEL org.opencontainers.image.description="Extension-only image containing RUM files for CloudNativePG Image Volume Extensions"
LABEL org.opencontainers.image.source="https://github.com/fluxzero-io/postgresql-rum-cnpg-extension"
LABEL io.cloudnativepg.image.base.pgmajor="${PG_MAJOR}"
LABEL io.cloudnativepg.image.base.version="${PG_VERSION}"
LABEL io.cloudnativepg.image.base.os="${PG_DISTRO}"
LABEL io.cloudnativepg.image.sql.version="${RUM_PACKAGE_VERSION}"

COPY --from=build /rum/share /share
COPY --from=build /rum/lib /lib
COPY --from=build /rum/licenses /licenses
```

The final image must contain:

```text
/share/extension/rum.control
/share/extension/rum--*.sql
/lib/rum.so
```

## Smoke Test Strategy

An extension-only image cannot be tested by simply running it, because it is `FROM scratch` and contains no server.
The primary local smoke test uses Docker image mounts to mimic the production Image Volume Extension shape:

1. Build the extension image locally.
2. Start a temporary PostgreSQL container based on the same `BASE_IMAGE`.
3. Mount the extension image read-only at `/extensions/rum` with `docker run --mount type=image`.
4. Configure PostgreSQL with:
   - `extension_control_path = '/extensions/rum/share:$system'`
   - `dynamic_library_path = '/extensions/rum/lib:$libdir'`
5. Start Postgres.
6. Run:

```sql
CREATE EXTENSION rum;
SELECT extname, extversion FROM pg_extension WHERE extname = 'rum';
CREATE TABLE rum_smoke (id bigint generated always as identity primary key, summary tsvector);
CREATE INDEX rum_smoke_summary_rum ON rum_smoke USING rum (summary rum_tsvector_ops);
```

This is intentionally closer to CloudNativePG production behavior than copying files into the operand image. Docker
currently reports image mounts as experimental, but Docker Compose documents `type: image` mounts and `docker run`
supports the same mount form on Docker Engine versions with the feature enabled.

`docker/pg18-bullseye/Dockerfile.smoke` remains as a build-time fallback pattern for environments where Docker image
mounts are unavailable:

1. Build a temporary PostgreSQL image based on the same `BASE_IMAGE`.
2. Copy `/share/extension/*` and `/lib/rum.so` from the extension image into the standard PostgreSQL locations.
3. Start Postgres.
4. Run:

```sql
CREATE EXTENSION rum;
SELECT extname, extversion FROM pg_extension WHERE extname = 'rum';
CREATE TABLE rum_smoke (id bigint generated always as identity primary key, summary tsvector);
CREATE INDEX rum_smoke_summary_rum ON rum_smoke USING rum (summary rum_tsvector_ops);
```

The smoke test must fail the build if the extension cannot be created or if the index cannot be created.

## Tagging

Use immutable and rolling tags, but make distro compatibility visible.

Recommended Dependabot-friendly immutable tag:

```text
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:1.3.15-pgdg11.2-pg18-bullseye
```

Recommended rolling tags:

```text
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:1.3.15-pg18-bullseye
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:pg18-bullseye
```

Avoid a bare `:18` or `:latest` in production-facing examples because OS distribution compatibility matters.

The immutable tag should start with the upstream RUM version. This gives Dependabot and Renovate a better chance of
recognizing newer tags as upgrades. The Debian package revision should be encoded without `+`, because Docker tags do
not allow plus signs. Example conversion:

```text
1.3.15-1.pgdg11+2  ->  1.3.15-pgdg11.2-pg18-bullseye
```

The implemented CI workflow publishes exactly these GHCR tags for the current `versions/pg18-bullseye.env` file:

```text
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:1.3.15-pgdg11.2-pg18-bullseye
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:1.3.15-pg18-bullseye
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:pg18-bullseye
```

The tag conversion is centralized in `scripts/image-tags.sh`; CI overrides only the repository prefix to
`ghcr.io/${GITHUB_REPOSITORY}` so forks publish to their own GHCR namespace.

Production Helm values should ideally pin the digest:

```text
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:1.3.15-pgdg11.2-pg18-bullseye@sha256:<digest>
```

## Publishing

Publish to GHCR by default:

```text
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension
```

Optional mirror if Fluxzero wants all production pulls from the Flux Host registry:

```text
registry.fluxzero.io/fluxzero-io/postgresql-rum-cnpg-extension
```

If the GHCR package is public, CNPG can pull it without `imagePullSecrets`. If the package or mirror is private, the
consumer cluster must configure `Cluster.spec.imagePullSecrets`.

## Automation Plan

### 1. Dependabot

Use the same basic pattern as `fluxzero-sdk-java` and `fluxzero-runtime`:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "daily"
    open-pull-requests-limit: 10
    commit-message:
      prefix: "deps"

  - package-ecosystem: "docker"
    directory: "/docker/pg18-bullseye"
    schedule:
      interval: "daily"
    open-pull-requests-limit: 10
    commit-message:
      prefix: "deps"
```

Add a `dependabot-auto-merge.yml` workflow using the GitHub App token pattern from `fluxzero-sdk-java` /
`fluxzero-runtime`:

- Use `dependabot/fetch-metadata`.
- Auto-merge GitHub Actions and Docker updates once required checks pass.
- Use `DEPENDABOT_AUTOMERGE_APP_CLIENT_ID` and `DEPENDABOT_AUTOMERGE_APP_PRIVATE_KEY`.

### 2. PGDG RUM Package Watcher

Dependabot does not reliably detect apt package updates inside `apt-get install postgresql-18-rum`, especially when the
package is pinned through a build argument. Add a custom scheduled workflow.

Workflow:

```yaml
name: Check RUM package

on:
  schedule:
    - cron: "20 6 * * *"
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Check PGDG package metadata
        run: ./scripts/check-rum-package.sh versions/pg18-bullseye.env
      - name: Create GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.DEPENDABOT_AUTOMERGE_APP_CLIENT_ID }}
          private-key: ${{ secrets.DEPENDABOT_AUTOMERGE_APP_PRIVATE_KEY }}
      - name: Create pull request
        uses: peter-evans/create-pull-request@v8
        with:
          token: ${{ steps.app-token.outputs.token }}
          branch: deps/update-rum-package
          title: "deps: update PostgreSQL RUM package"
          commit-message: "deps: update PostgreSQL RUM package"
          labels: dependencies
```

Use a GitHub App token for this pull request instead of the default `GITHUB_TOKEN`, so the resulting PR can trigger the
normal pull request workflow. Fluxzero already uses the same app-token pattern for Dependabot auto-merge workflows via
`DEPENDABOT_AUTOMERGE_APP_CLIENT_ID` and `DEPENDABOT_AUTOMERGE_APP_PRIVATE_KEY`.

`scripts/check-rum-package.sh` should:

- Source the version file.
- Run the current `BASE_IMAGE` as root.
- Execute `apt-get update`.
- Read the candidate package version and SHA256 from `apt-cache show "$RUM_PACKAGE"`.
- Compare with `RUM_PACKAGE_VERSION` and `RUM_PACKAGE_SHA256`.
- Update the version file if either value changed.
- Optionally compare the package version's upstream component with the latest `postgrespro/rum` GitHub release and print
  a warning if PGDG lags behind upstream.

### 3. Pull Request Build

Every PR should:

- Build the extension image for `linux/amd64`.
- Inspect the image contents.
- Run the smoke test.
- Check the README snippets or shell scripts if relevant.

### 4. Publish Build

On `main`:

- Build with `docker/build-push-action`.
- Push GHCR tags.
- Optionally push `registry.fluxzero.io` tags.
- Create or update a GitHub Release for the immutable image tag.
- Enable provenance/SBOM if practical.
- Optionally sign with keyless Cosign using GitHub OIDC.

The release boundary is the PGDG RUM package version for a specific PostgreSQL major and distro. In other words:

```text
new PGDG postgresql-18-rum package -> PR in this repo -> CI smoke test -> merge -> publish new image tag
```

Consumer repositories then only need to track the published Docker image tag:

```text
new image tag -> Dependabot/Renovate PR in flux-host-infra-exoscale -> normal Argo rollout
```

### 5. Weekly Rebuild

Consider a weekly rebuild even without version changes to pick up base-image security fixes if the tag is mutable.
If production always pins immutable digest tags, weekly rebuilds should publish a timestamped tag or digest only after
the smoke test passes.

## Comparison With Existing Fluxzero Repos

Observed patterns:

- `fluxzero-sdk-java`
  - Daily Dependabot for Maven, GitHub Actions, and Docker.
  - `dependabot-auto-merge.yml` uses `dependabot/fetch-metadata`.
  - GitHub Actions and Docker updates are considered safe enough for auto-merge after checks.
  - Maven patch/minor updates are auto-merged, major updates are not.

- `fluxzero-runtime`
  - Similar Dependabot and auto-merge setup.
  - Has a manual `build-postgres-rum-image.yml`, but that image is a full PostgreSQL image for tests, not a CNPG
    extension-only image.

- `flux-host-service`
  - Uses Dependabot plus label/merge workflows after the PR build succeeds.
  - More involved because it deploys production artifacts after merging.

- `fluxzero-cli`
  - Uses Renovate with grouped minor/patch and major PRs.
  - Renovate is powerful for custom regex managers, but most nearby Fluxzero repos use Dependabot.

Recommendation for this repo:

- Use Dependabot for normal dependency automation.
- Use a small custom PGDG package watcher for RUM package updates.
- Avoid introducing Renovate unless the package watcher becomes too complex or we want Renovate custom managers across
  more repositories.

## Consumer Integration in `flux-host-infra-exoscale`

After this repository publishes its first image, `flux-host-infra-exoscale` should consume it rather than building the
extension image itself.

The infra repo should keep only the Helm support:

- `Cluster.spec.postgresql.extensions`
- optional `Cluster.spec.imagePullSecrets`
- CNPG `Database` resource with `spec.extensions`
- Fluxzero Runtime RUM env vars

The infra repo should remove:

- any local `postgresql-rum/` Dockerfile
- any local workflow job that builds the RUM extension image

Example future values:

```yaml
flux:
  db:
    postgresqlExtensions:
      - name: rum
        image:
          reference: ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:1.3.15-pgdg11.2-pg18-bullseye
          pullPolicy: IfNotPresent
    database:
      extensions:
        - name: rum
          ensure: present
```

### Infra Dependency Updates

The preferred downstream flow is:

1. This repository publishes a new immutable image tag when the PGDG RUM package changes.
2. `flux-host-infra-exoscale` gets an automated dependency PR that updates the image reference.
3. The infra PR renders/lints the Helm chart and is merged through the normal process.
4. Argo reconciles the new extension image reference into the cluster.

Try Dependabot first in `flux-host-infra-exoscale`.

GitHub documents Docker version updates for Kubernetes manifests and Helm charts. The CNPG extension value is not a
normal container `image:` field, though; it is `postgresql.extensions[].image.reference`. That should be verified with a
real Dependabot PR after the first image is published.

Suggested infra Dependabot entry:

```yaml
version: 2
updates:
  - package-ecosystem: "docker"
    directory: "/argocd/fp-db"
    schedule:
      interval: "daily"
    open-pull-requests-limit: 5
    commit-message:
      prefix: "deps:"
```

If Dependabot does not recognize `image.reference`, use Renovate for this one dependency. `fluxzero-cli` already uses
Renovate, so this is not a foreign pattern in the organization.

Example Renovate fallback:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "customManagers": [
    {
      "customType": "regex",
      "fileMatch": ["^argocd/fp-db/.*\\.ya?ml$"],
      "matchStrings": [
        "reference:\\s*(?<depName>ghcr\\.io/fluxzero-io/postgresql-rum-cnpg-extension):(?<currentValue>[^\\s\"']+)"
      ],
      "datasourceTemplate": "docker"
    }
  ],
  "packageRules": [
    {
      "matchPackageNames": ["ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension"],
      "labels": ["dependencies", "postgresql-rum"]
    }
  ]
}
```

If neither Dependabot nor Renovate is desired in the infra repo, a small scheduled workflow can query GHCR tags and open a
PR with `yq`, but that should be the fallback rather than the default.

Runtime values after the database extension is installed:

```yaml
flux:
  service:
    search:
      rum:
        enabled: true
        collections: "*"
        createExtension: false
        required: true
```

Important runtime behavior:

- RUM indexes are used for new matching search collections.
- Existing collections are not automatically converted.
- Keep `createExtension=false` in production; the CNPG `Database` resource should install `rum`.
- Consider `required=true` once RUM is deliberately enabled, so misconfiguration fails loudly.

## Initial Implementation Tasks for Codex

Use this as the kickoff checklist in the new Codex project.

1. Initialize the repository structure from this README.
2. Add `versions/pg18-bullseye.env` with the observed PGDG package metadata.
3. Add `docker/pg18-bullseye/Dockerfile` for the extension-only image.
4. Add `docker/pg18-bullseye/Dockerfile.smoke`.
5. Add `scripts/inspect-image.sh`.
6. Add `scripts/smoke-test.sh`.
7. Add `scripts/check-rum-package.sh`.
8. Add `.github/dependabot.yml`.
9. Add `.github/workflows/pull-requests.yml`.
10. Add `.github/workflows/build-and-publish.yml`.
11. Add `.github/workflows/check-rum-package.yml`.
12. Add `.github/workflows/dependabot-auto-merge.yml`.
13. Build locally for `linux/amd64`.
14. Run the smoke test locally.
15. Validate workflow YAML.
16. Document the exact image tags emitted by CI.

## Acceptance Criteria

The first production-ready version of this repository is done when:

- A PR build can build the extension-only image.
- A PR build can prove the image contains the expected RUM files.
- A PR build can create the RUM extension in a temporary PostgreSQL smoke container.
- Main publishes immutable GHCR tags.
- The RUM package watcher opens a PR when PGDG package metadata changes.
- Dependabot opens PRs for GitHub Actions and Docker updates.
- A documented downstream test confirms whether `flux-host-infra-exoscale` can use Dependabot to update the published
  image tag, or records the chosen Renovate fallback.
- The README explains how `flux-host-infra-exoscale` should consume the image.

## Open Decisions

- Should the GHCR package be public?
  - Public is easiest for CNPG pull behavior.
  - Private requires image pull secrets in every consumer cluster.
- Should the image also be mirrored to `registry.fluxzero.io`?
- Should the first release support only `linux/amd64`, or also `linux/arm64`?
- Should production values pin image tags or full digests?
- Does Dependabot detect the CNPG Helm value `postgresql.extensions[].image.reference` in `flux-host-infra-exoscale`?
  - If yes, use Dependabot downstream.
  - If no, use Renovate's Docker datasource with a regex custom manager for that image reference.
- Should `postgrespro/rum` upstream releases open informational issues when PGDG lags?
- Should this repo eventually be proposed upstream to `cloudnative-pg/postgres-extensions-containers`?

## Suggested New Codex Prompt

```text
This is a new repository for a CloudNativePG extension-only image for PostgreSQL RUM.
Read README.md fully first.
Implement the repository scaffold and CI described there.
Keep the first version focused on PostgreSQL 18, Debian Bullseye, linux/amd64, and the PGDG package
postgresql-18-rum=1.3.15-1.pgdg11+2.
Do not build a full PostgreSQL production operand image.
Use the existing Fluxzero patterns for Dependabot and auto-merge where practical.
Before finishing, run a local linux/amd64 Docker build and smoke test that executes CREATE EXTENSION rum.
```
