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

## FIPS 140-3 — not claimed

The images are **not** FIPS 140-3 validated, and we make no FIPS claims.
A valid claim requires a crypto module with a CMVP certificate, built and
operated exactly as described in that certificate's security policy, with
non-approved algorithms disabled.

Planned `-fips` variants:

- **OpenSSL-based images** (`php-apache`): OpenSSL FIPS provider at a
  CMVP-validated version, configured as the default provider, FIPS mode
  enforced, verified with a CI test that non-approved algorithms fail.
- **Go images**: Go's native FIPS 140-3 module (`GOFIPS140`, `GODEBUG=fips140=on`).
  We will only label images "FIPS" once the module version shipped has a
  certificate, and document which one.

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
