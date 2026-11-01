#!/usr/bin/env bash
# Print the tags for one matrix build, derived from the resolved package
# version in an apko lock file. Mirrors the official image conventions:
#
#   php-apache 8.4 (php-8.4=8.4.27-r0) -> 8.4.27  8.4  8  latest  8.4.27-20261101
#   php-apache 8.4 dev                 -> 8.4.27-dev  8.4-dev  8-dev  latest-dev  ...
#   go 1.26 (not "latest")             -> 1.26.10  1.26  1.26.10-20261101
#   static (no version package)        -> latest  20261101
#
#   scripts/tags.sh <image> <version> <variant> <lockfile>
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
image="$1" version="$2" variant="$3" lock="$4"
meta="$root/images/$image/image.yaml"
date="${BUILD_DATE:-$(date -u +%Y%m%d)}"
suffix="${variant:+-$variant}"

pkg="$(yq '.version-package' "$meta" | sed "s/{{version}}/$version/g")"
latest="$(yq '.latest' "$meta")"
is_latest=false; [[ "$version" == "$latest" ]] && is_latest=true

if [[ -z "$pkg" || "$pkg" == "null" ]]; then
  echo "latest${suffix}"
  echo "${date}${suffix}"
  exit 0
fi

full="$(jq -r --arg p "$pkg" '[.contents.packages[] | select(.name == $p)][0].version // empty' "$lock")"
[[ -n "$full" ]] || { echo "package $pkg not found in $lock" >&2; exit 1; }
full="${full%-r*}"            # 8.4.27-r0 -> 8.4.27
full="${full%%_*}"            # strip Wolfi suffixes like _p1
IFS=. read -r major minor _ <<<"$full"

echo "${full}${suffix}"
echo "${major}.${minor}${suffix}"
if $is_latest; then
  [[ "$major" != "0" ]] && echo "${major}${suffix}"
  [[ -n "$suffix" ]] && echo "latest${suffix}" || echo "latest"
fi
echo "${full}-${date}${suffix}"
