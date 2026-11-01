# Hardening and compliance

This document states what the images do today, how that maps to common
frameworks, and — just as important — what we do **not** claim yet.

## Baseline (all images)

| Control | How |
|---|---|
| Minimal content | Composed by apko from an explicit package list; runtime images have no package manager and (except `restic`) no shell |
| Non-root | Runtime images run as `65532:65532` (`nonroot`); listening ports are > 1024 |
| No setuid/setgid | Tested in CI; `suexec` in `php-apache` has its setuid bit removed |
| Read-only rootfs | Runtime images write only to `/tmp` (mount an `emptyDir`/tmpfs) |
| Signed inputs | Every package is verified against the Wolfi signing key; our own packages are signed with a per-run key |
| Reproducible | Package versions are locked per build; identical inputs produce identical digests |
| Fresh | Rebuilt daily; Renovate keeps tools and actions current |
| Vulnerability gate | grype, fail on high/critical with an available fix |
| Signed outputs | cosign keyless signatures, SPDX SBOM attestation, SLSA provenance |
| Supply chain of CI | All GitHub Actions pinned to commit SHAs; tool downloads verified by checksum |

Build variants (`*-dev`, `go`) intentionally run as root and contain a shell —
they are for build stages only and must never be deployed.

## CIS Docker Benchmark — Section 4 (container images)

Checked in CI with [dockle](https://github.com/goodwithtech/dockle) at level
`warn`.

| # | Recommendation | Status |
|---|---|---|
| 4.1 | Create a user for the container | ✅ runtime images (`USER 65532`) |
| 4.2 | Use trusted base images | ✅ built by us from signed Wolfi packages |
| 4.3 | Do not install unnecessary packages | ✅ minimal; known exception: `perl` is a hard dependency of Wolfi's `apache2` package |
| 4.4 | Scan and rebuild images to include security patches | ✅ daily rebuild + grype gate |
| 4.5 | Enable content trust | ✅ via cosign signatures (Docker Content Trust itself is not used) |
| 4.6 | Add HEALTHCHECK | ➖ not emitted by apko; `php-apache` exposes `/healthz` for Kubernetes probes |
| 4.8 | Remove setuid/setgid permissions | ✅ tested in CI |
| 4.10 | Do not store secrets in images | ✅ |
| 4.11 | Install verified packages only | ✅ apk signature verification |

## CIS Apache HTTP Server 2.4 Benchmark (`php-apache`)

Implemented in [`packages/php-apache-config/httpd.conf`](../packages/php-apache-config/httpd.conf):
only required modules loaded; `ServerTokens Prod`, `ServerSignature Off`,
`TraceEnable Off`, `FileETag None`; deny-by-default `<Directory />`;
dotfiles and VCS directories denied; HTTP methods restricted; request
timeouts and limits set; logs to stdout/stderr; runs as non-root.

Out of scope by design: TLS (terminated at the ingress/gateway) and
mod_security (WAF belongs in front of the workload).

## Kubernetes Pod Security Standards

Runtime images are compatible with the **restricted** profile:
`runAsNonRoot`, `allowPrivilegeEscalation: false`, `capabilities: drop: [ALL]`,
`seccompProfile: RuntimeDefault`, `readOnlyRootFilesystem: true` (+ `/tmp`
`emptyDir`).

## FIPS 140-3

### Go (`go:*-fips`) — available

The `-fips` variants of the Go image build every binary against the
**Go Cryptographic Module selected by `GOFIPS140=certified`** — currently
**v1.0.0, CMVP certificate #5247** — and enable FIPS 140-3 mode by default
(`DefaultGODEBUG=fips140=on`). In this mode the module runs its integrity and
known-answer self-tests, `crypto/rand` uses an SP 800-90A DRBG, and
`crypto/tls` negotiates only approved algorithms
([Go documentation](https://go.dev/doc/security/fips140)).

Wolfi's Go packages do not ship the frozen module snapshots, so we add them
from the official Go source release (`packages/go-fips140-snapshots`). Each
snapshot is verified against the release tarball's SHA-256 and against the
checksums in Go's own `fips140.sum`; CI checks that a test binary reports
FIPS mode and was built with the certified module version.

What this does **not** claim: that your application is FIPS 140-3
compliant. That depends on using the module as described in its Security
Policy, running on a validated operating environment, and using only
approved algorithms in your code and dependencies. `GODEBUG=fips140=only`
helps find non-approved algorithm use during testing (not for production).

### OpenSSL-based images (`php-apache`) — not available yet

The open Wolfi repository has no OpenSSL FIPS provider. Offering a `-fips`
variant requires building the provider at a CMVP-validated OpenSSL version
exactly as its Security Policy prescribes and enforcing it as the default
provider. Until then we make **no FIPS claim** for `php-apache` or images
built on it.

## DISA STIG — not claimed

There is no DISA STIG for Wolfi. Applicable guidance is the *Container
Platform SRG*, the *General Purpose Operating System SRG* and the *Apache
Server 2.4 UNIX STIG* (for `php-apache`). Many of their requirements
(minimal software, non-root, logging, no unnecessary services, method
restrictions, information disclosure) are covered by the controls above.

Planned: a control-by-control mapping and an OpenSCAP scan with a tailored
profile in CI. Until then, treat the images as "hardened following STIG
guidance", not "STIG compliant".

## Known gaps / roadmap

- `perl` in `php-apache` (pulled in by `apache2`) — package our own httpd
  without the dependency.
- Wolfi OS packages can lag behind Chainguard's commercial repository for some
  fixes (seen with Node.js 22). The grype gate catches this; affected images
  then move to a maintained major or a self-built package.
- No `ext-imap` in PHP 8.4 images: it was removed from PHP core and depends on
  the unmaintained c-client library.
