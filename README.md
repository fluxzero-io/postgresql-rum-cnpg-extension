# PostgreSQL RUM CloudNativePG Extension Image

This repository builds and publishes a Fluxzero-maintained, extension-only OCI
image for the PostgreSQL RUM extension.

The image is meant for CloudNativePG PostgreSQL 18 clusters that use
[Image Volume Extensions](https://cloudnative-pg.io/documentation/current/imagevolume_extensions/).
It is not a PostgreSQL server image. CloudNativePG should keep using the
upstream CloudNativePG PostgreSQL operand image, while RUM is delivered as a
small read-only image volume mounted into the Postgres pod.

## What This Publishes

The production image is built as `FROM scratch` and contains only the files
PostgreSQL needs to load RUM:

```text
/share/extension/rum.control
/share/extension/rum--*.sql
/lib/rum.so
/licenses/*
```

The files are installed from the PGDG Debian package in a build stage based on
the same CloudNativePG PostgreSQL image used by the target cluster. The package
version and SHA256 are pinned in `versions/pg18-bullseye.env`. The base image
is pinned directly in the production Dockerfile so Dependabot can read and update
it; scripts derive the PostgreSQL version from that pin through `scripts/load-target.sh`.
The Dockerfile verifies the downloaded `.deb` before installing it.

Current target:

```text
PostgreSQL major: 18
PostgreSQL version: 18.6
Distribution: Debian Bullseye
Platform: linux/amd64
Base image: ghcr.io/cloudnative-pg/postgresql:18.6
PGDG package: postgresql-18-rum=1.3.15-1.pgdg11+2
PGDG package SHA256: 3e87fd7b451489b265e291e4d202a51102b3ec0609172a10391c863fd501982e
```

## Repository Layout

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
│   ├── image-tags.sh
│   ├── image-volume-smoke-test.sh
│   ├── inspect-image.sh
│   └── smoke-test.sh
├── versions/
│   └── pg18-bullseye.env
├── AGENTS.md
├── LICENSE
└── README.md
```

The first supported target is `pg18-bullseye`, because that matches the current
CloudNativePG operand image used by Fluxzero. If the cluster moves to a
distro-suffixed image such as Bookworm or Trixie, add a new target instead of
silently changing the meaning of the Bullseye tags.

## Tags

Image tags are derived by `scripts/image-tags.sh`.

For the current version file, CI publishes:

```text
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:1.3.15-pgdg11.2-pg18-bullseye
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:1.3.15-pg18-bullseye
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:pg18-bullseye
```

The immutable tag starts with the upstream RUM version and includes the PGDG
package revision, PostgreSQL major, and distro. Docker tags cannot contain `+`,
so `1.3.15-1.pgdg11+2` becomes `1.3.15-pgdg11.2-pg18-bullseye`.

For production use, prefer pinning the digest as well:

```text
ghcr.io/fluxzero-io/postgresql-rum-cnpg-extension:1.3.15-pgdg11.2-pg18-bullseye@sha256:<digest>
```

## Local Build And Test

Requirements:

- Docker with Buildx
- Access to `ghcr.io/cloudnative-pg/postgresql:18.6`
- `linux/amd64` build support, usually via Buildx/QEMU on non-amd64 machines

Run the full local smoke test:

```bash
./scripts/smoke-test.sh versions/pg18-bullseye.env
```

This command:

1. Builds the extension-only image for `linux/amd64`.
2. Verifies the image contains the expected RUM control, SQL, library, and OCI
   labels.
3. Starts a temporary PostgreSQL container from the same CloudNativePG base
   image.
4. Mounts the extension image read-only with Docker image mounts at
   `/extensions/rum`.
5. Configures PostgreSQL with:

```text
extension_control_path = '/extensions/rum/share:$system'
dynamic_library_path = '/extensions/rum/lib:$libdir'
```

6. Runs:

```sql
CREATE EXTENSION rum;
SELECT extname, extversion FROM pg_extension WHERE extname = 'rum';
CREATE TABLE rum_smoke (id bigint generated always as identity primary key, summary tsvector);
CREATE INDEX rum_smoke_summary_rum ON rum_smoke USING rum (summary rum_tsvector_ops);
```

Docker may print `Image mount is an experimental feature`. That is expected on
Docker versions where `--mount type=image` is still marked experimental. The
test uses this path because it is closer to the CloudNativePG production model
than copying files into a PostgreSQL image.

Useful one-off commands:

```bash
./scripts/image-tags.sh versions/pg18-bullseye.env full-tags
./scripts/inspect-image.sh postgresql-rum-cnpg-extension:1.3.15-pgdg11.2-pg18-bullseye
./scripts/check-rum-package.sh versions/pg18-bullseye.env
```

`docker/pg18-bullseye/Dockerfile.smoke` remains as a fallback build-time smoke
pattern for environments that cannot use Docker image mounts. It copies the
extension files into a temporary PostgreSQL image and runs the same SQL checks.

## Automation

`pull-requests.yml`

Builds the extension image and runs the full smoke test for pull requests and
manual workflow dispatches.

`build-and-publish.yml`

Runs the same smoke test on `main`, then publishes the image to GHCR with the
immutable and rolling tags produced by `scripts/image-tags.sh`. The publish
step also enables provenance and SBOM generation.

`check-rum-package.yml`

Runs daily and checks PGDG package metadata from inside the target
CloudNativePG base image on `linux/amd64`. If the candidate package version or
SHA256 changes, it updates `versions/pg18-bullseye.env` and opens a pull
request.

The package watcher uses a GitHub App token instead of the default
`GITHUB_TOKEN`, so the generated pull request can trigger the normal pull
request workflow. The expected Actions secrets for the selected release-App installation are:

```text
FLUXZERO_BOT_CLIENT_ID
FLUXZERO_BOT_PRIVATE_KEY
```

`dependabot-auto-merge.yml`

Uses the separate Fluxzero Dependabot App via Dependabot secrets. The job checks
both bot actor and PR author, executes no PR code, and requests only Contents/PR
write for this repository. Verified patch/minor updates use native rebase
auto-merge behind strict required `Build and smoke test`; majors need a separate
assessment. The scheduled package watcher retains the existing fluxzero-bot
Actions credentials (`FLUXZERO_BOT_CLIENT_ID` / `FLUXZERO_BOT_PRIVATE_KEY`)
and a similarly bounded token. The merge job uses only
`DEPENDABOT_AUTOMERGE_APP_CLIENT_ID` / `DEPENDABOT_AUTOMERGE_APP_PRIVATE_KEY`
from the Dependabot secret category. Keep the two credential families separate.

## Archived Bullseye target

PGDG ended Bullseye updates on 31 August 2026 and moved its packages to the
[official archive](https://www.postgresql.org/message-id/apWm8-epjef2xpkM%40msg.df7cb.de).
`docker/pg18-bullseye/configure-pgdg.sh` makes both the build and package checker
use that archive, retaining APT signature verification and the package checksum.
RUM 1.3.15 remains the final available package for this target. A successful
archive check proves reproducibility, not continuing security updates.

Keep this target compatible with existing Bullseye PostgreSQL 18 consumers.
A supported Debian target needs its own directory/version file and coordinated
downstream qualification; do not relabel a Bookworm/Trixie build as Bullseye.
Docker major upgrades are excluded; the scripts reject another PostgreSQL major
and the archive setup rejects another distro. Image publication does not update
the downstream database configuration.

For a downstream compatibility check, `SMOKE_BASE_IMAGE` can select the existing
PostgreSQL 18 consumer image while testing the built extension image.

## Consuming The Image

Consumer repositories should reference the published image from their
CloudNativePG extension configuration. This repository does not run
`CREATE EXTENSION rum` in production and does not manage Fluxzero Runtime
settings.

Example values shape:

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

For Fluxzero Runtime search configuration, keep extension creation owned by the
CloudNativePG `Database` resource:

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

## References

- [CloudNativePG Image Volume Extensions](https://cloudnative-pg.io/documentation/current/imagevolume_extensions/)
- [CloudNativePG extension image repository](https://github.com/cloudnative-pg/postgres-extensions-containers)
- [CloudNativePG extension catalogs](https://github.com/cloudnative-pg/artifacts/tree/main/image-catalogs-extensions)
- [RUM upstream source](https://github.com/postgrespro/rum)
- [PGDG apt repository](https://apt.postgresql.org/)
