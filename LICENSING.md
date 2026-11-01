# Licensing

## This repository

Everything in this repository — apko/melange configuration, scripts, tests,
workflows and documentation — is licensed under the
[Apache License 2.0](LICENSE).

## Tools we use (not redistributed)

| Tool | License | Use |
|---|---|---|
| [apko](https://github.com/chainguard-dev/apko) | Apache-2.0 | assembles images from packages |
| [melange](https://github.com/chainguard-dev/melange) | Apache-2.0 | builds our configuration packages |
| [cosign](https://github.com/sigstore/cosign) | Apache-2.0 | signing |
| [grype](https://github.com/anchore/grype) | Apache-2.0 | vulnerability scanning |
| [dockle](https://github.com/goodwithtech/dockle) | Apache-2.0 | CIS Docker Benchmark checks |

These tools run in CI only; they are not part of the published images.

## Package source

All packages come from the **open Wolfi repository**
`https://packages.wolfi.dev/os`, verified with its published signing key.
We do **not** use Chainguard's commercial package repository
(`apk.cgr.dev/chainguard`) or Chainguard container images (`cgr.dev/...`).

Per [wolfi-dev/os/LICENSE](https://github.com/wolfi-dev/os/blob/main/LICENSE):

> The Wolfi build recipes themselves are provided under the Apache License
> 2.0. The underlying packages are provided under the license terms provided
> by each FOSS project supplying the packages. Any image built from Wolfi (or
> any other distribution) is provided under the combination of license terms
> resulting from the use of individual packages.

## Licenses inside an image

Each published image therefore carries the combined licenses of its packages
(e.g. Apache-2.0 for httpd, PHP-3.01 for PHP, BSD-3-Clause for Go, BSD-2-Clause
for restic, GPL-2.0 for busybox, GPL-3.0-or-later for bash).

- The authoritative list is the **SPDX SBOM** attached to every image
  (see README → *Verifying an image*). Every package entry has its declared
  license.
- CI writes a per-image license table to the workflow summary and stores it as
  an artifact (`sbom-*` → `licenses.md`).
- CI **fails** if a package declares a license on our deny list
  (non-free / source-available licenses such as BUSL, SSPL, Commons Clause).

## Corresponding source for copyleft components

For GPL/LGPL-licensed packages, the corresponding source is available from
the Wolfi build recipes, which pin the exact upstream source (URL + checksum
or git commit) and any patches applied:
`https://github.com/wolfi-dev/os/blob/main/<package>.yaml`.
The exact package versions in an image are listed in its SBOM and in the
`config.lock.json` CI artifact. If you need a copy of the corresponding
source for a specific image, open an issue and we will provide it.

## Trademarks

"Wolfi", "Chainguard", "Apache", "PHP", "Go" and other names are trademarks
of their respective owners. They are used here only to describe the software
contained in the images. This project is not affiliated with or endorsed by
any of them.
