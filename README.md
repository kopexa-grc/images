# Kopexa hardened container images

[![build](https://github.com/kopexa-grc/images/actions/workflows/build.yml/badge.svg)](https://github.com/kopexa-grc/images/actions/workflows/build.yml) [![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/kopexa-grc/images/badge)](https://scorecard.dev/viewer/?uri=github.com/kopexa-grc/images) [![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

> Maintained by **[Kopexa](https://kopexa.com)** — GRC and compliance automation. Part of our open source work on transparent, verifiable software supply chains.

Minimal, non-root, signed container images — built transparently in the open
with [apko](https://github.com/chainguard-dev/apko) and
[melange](https://github.com/chainguard-dev/melange) from the open
[Wolfi](https://github.com/wolfi-dev/os) package repository.

Every image is rebuilt **daily**, gated on **vulnerability scans** and the
**CIS Docker Benchmark**, signed with **cosign** (keyless), and published with
an **SPDX SBOM** and **SLSA build provenance**. Versioned tags are kept, so you
can pin `8.4.27` or `1.27.3` — not just `latest`.

## Images

| Image | Tags | Purpose |
|---|---|---|
| `ghcr.io/kopexa-grc/php-apache` | `8.4`, `8.4.x`, `8`, `latest` | Apache httpd 2.4 + mod_php (prefork), port 8080, uid 65532 |
| `ghcr.io/kopexa-grc/php-apache` | `8.4-dev`, `8.4.x-dev`, `latest-dev` | Build stage: + shell, composer, git, Node.js 24 |
| `ghcr.io/kopexa-grc/go` | `1.27`, `1.27.x`, `1`, `latest`, `1.26`, `1.26.x` | Go toolchain for build stages (follows Go's release policy) |
| `ghcr.io/kopexa-grc/go` | `1.27-fips`, `1.27.x-fips`, `latest-fips`, `1.26-fips`, … | Same, building against the **CMVP-validated Go Cryptographic Module** with FIPS 140-3 mode on by default |
| `ghcr.io/kopexa-grc/static` | `latest` | Runtime for static binaries: no shell, no libc, no package manager |
| `ghcr.io/kopexa-grc/restic` | `0.19`, `0.19.x`, `latest` | restic backup client (+ busybox for job scripting) |
| `ghcr.io/kopexa-grc/valkey` | `9.1`, `9.1.x`, `9`, `latest` | Valkey (Redis-compatible) for caches and sessions, with `valkey-cli` |

Every build also gets an immutable dated tag, e.g. `8.4.27-20261101`.

### Example: Go service

```dockerfile
FROM ghcr.io/kopexa-grc/go:1.27 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/app

FROM ghcr.io/kopexa-grc/static:latest
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
```

### Example: FIPS 140-3 mode for a Go service

```dockerfile
FROM ghcr.io/kopexa-grc/go:1.27-fips AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/app ./cmd/app

FROM ghcr.io/kopexa-grc/static:latest
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
```

The binary links the Go Cryptographic Module selected by
`GOFIPS140=certified` (currently v1.0.0, CMVP certificate #5247) and runs in
FIPS 140-3 mode by default — check with `go version -m app | grep GOFIPS140`
or `crypto/fips140.Enabled()`. See [docs/hardening.md](docs/hardening.md#fips-140-3)
for what this does and does not mean.

### Example: PHP application

```dockerfile
FROM ghcr.io/kopexa-grc/php-apache:8.4-dev AS build
WORKDIR /app
COPY . .
RUN composer install --no-dev --classmap-authoritative

FROM ghcr.io/kopexa-grc/php-apache:8.4
COPY --from=build /app /app
ENV APACHE_DOCUMENT_ROOT=/app/public
```

`php-apache` is configured via environment variables (`APACHE_*`, `PHP_*`,
see [`images/php-apache/apko.yaml`](images/php-apache/apko.yaml)) and loads
extra vhost snippets from `/etc/kopexa/httpd/conf.d/*.conf`. It works with a
read-only root filesystem if `/tmp` is writable (e.g. an `emptyDir`).

## Verifying an image

```bash
cosign verify ghcr.io/kopexa-grc/php-apache:8.4 \
  --certificate-identity-regexp '^https://github.com/kopexa-grc/images/\.github/workflows/build\.yml@refs/heads/main$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

```bash
gh attestation verify oci://ghcr.io/kopexa-grc/php-apache:8.4 --owner kopexa-grc
```

```bash
cosign download attestation ghcr.io/kopexa-grc/php-apache:8.4 \
  --predicate-type https://spdx.dev/Document | jq -r '.payload' | base64 -d | jq '.predicate'
```

## How it is built

```
images/_base/base.apko.yaml   shared fragment: baselayout, CA certs, tzdata, nonroot user, archs
images/<name>/image.yaml      versions, variants, which package drives the tags
images/<name>/apko.yaml       packages, entrypoint, environment of the runtime image
images/<name>/apko.<v>.yaml   overlay for a variant (e.g. dev)
images/<name>/tests/test.sh   smoke + hardening tests, run in CI against every build
packages/<name>/melange.yaml  our own packages (configuration), built per CI run
```

apko has no `FROM`: each image is composed from signed packages, so the SBOM
is complete and a fix in a shared package rebuilds every image. The base
fragment is merged into each image by [`scripts/render.sh`](scripts/render.sh).

CI ([`build.yml`](.github/workflows/build.yml)) for every image × version × variant:

1. builds our melange packages (amd64 + arm64) with an ephemeral signing key
2. renders the apko config and **locks** all package versions
3. derives tags from the locked version (`php-8.4=8.4.27-r0` → `8.4.27`, `8.4`, `8`, `latest`)
4. builds, runs the image tests, scans with **grype** (fails on high/critical
   with an available fix), checks the **CIS Docker Benchmark** with dockle,
   and summarises **licenses** from the SBOM
5. on `main`: publishes multi-arch, signs with cosign, attests the SBOM and
   SLSA provenance

Build locally (needs `apko`, `melange`, `yq`, `jq`, `docker`):

```bash
scripts/build-local.sh php-apache 8.4
```

```bash
scripts/build-local.sh go 1.27
```

## Security and compliance

See [docs/hardening.md](docs/hardening.md) for what is hardened, how it maps
to CIS / FIPS / STIG, and what is explicitly **not** claimed yet.
Report vulnerabilities as described in [SECURITY.md](SECURITY.md).

## Licensing

The build configuration in this repository is Apache-2.0. The images contain
packages under their own licenses — see [LICENSING.md](LICENSING.md).

This project is not affiliated with or endorsed by Chainguard. "Wolfi" and
"Chainguard" are used only to describe where packages and tools come from.

---

Made with care by [Kopexa](https://kopexa.com) · [kopexa-grc on GitHub](https://github.com/kopexa-grc)
