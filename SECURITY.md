# Security policy

## Reporting a vulnerability

Please report vulnerabilities **privately** via
[GitHub Security Advisories](https://github.com/kopexa-grc/images/security/advisories/new).
Do not open a public issue.

We aim to acknowledge reports within 3 business days.

## What is in scope

- Configuration in this repository (e.g. httpd/php hardening, image
  composition, CI pipeline and signing).
- A published image containing a vulnerable package **for which a fixed
  package exists in the Wolfi repository** but was not picked up.

Vulnerabilities in upstream software itself (PHP, Apache, Go, ...) should be
reported to the respective upstream project; we pick up fixes automatically
through the daily rebuild.

## Supported tags

Only the most recent build of each maintained version is supported
(`php-apache:8.4`, `go:1.27`, `go:1.26`, ...). Dated tags are kept for
reproducibility and rollback but do not receive fixes.
