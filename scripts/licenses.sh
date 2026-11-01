#!/usr/bin/env bash
# Summarise the declared licenses of all packages in an apko SPDX SBOM and
# fail if a package carries a license from the deny list (non-free or
# source-available licenses we do not want to redistribute).
#
#   scripts/licenses.sh <sbom.spdx.json> [summary.md]
set -euo pipefail
sbom="${1:?usage: licenses.sh <sbom.spdx.json> [summary.md]}"
out="${2:-/dev/stdout}"
deny='BUSL|SSPL|Commons-Clause|Elastic-2\.0|LicenseRef-.*[Pp]roprietary|CC-BY-NC'

pkgs="$(jq -r '.packages[] | select(.name != null and (.SPDXID | startswith("SPDXRef-Package-")))
  | [.name, (.versionInfo // ""), (.licenseDeclared // "NOASSERTION")] | @tsv' "$sbom" | sort -u)"

{
  echo "| Package | Version | License |"
  echo "|---|---|---|"
  awk -F'\t' '{printf "| %s | %s | %s |\n", $1, $2, $3}' <<<"$pkgs"
} >"$out"

if bad="$(awk -F'\t' -v re="$deny" '$3 ~ re' <<<"$pkgs")" && [[ -n "$bad" ]]; then
  echo "::error::denied licenses found:" >&2
  echo "$bad" >&2
  exit 1
fi
unknown="$(awk -F'\t' '$3 == "NOASSERTION" || $3 == ""' <<<"$pkgs" || true)"
[[ -z "$unknown" ]] || { echo "::warning::packages without declared license:" >&2; echo "$unknown" >&2; }
