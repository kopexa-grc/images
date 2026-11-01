#!/usr/bin/env bash
# Render the final apko config for one build of the matrix by deep-merging
# the shared base fragment, the image's runtime config and (optionally) a
# variant overlay, then substituting {{version}}.
#
#   scripts/render.sh <image> [version] [variant]
#   scripts/render.sh php-apache 8.4 dev
#
# Lists are appended (*+), so packages from all fragments are combined.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
image="${1:?usage: render.sh <image> [version] [variant]}"
version="${2:-}"
variant="${3:-}"

files=("$root/images/_base/base.apko.yaml" "$root/images/$image/apko.yaml")
[[ -n "$variant" ]] && files+=("$root/images/$image/apko.$variant.yaml")
for f in "${files[@]}"; do [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }; done

yq eval-all '. as $item ireduce ({}; . *+ $item)
  | .contents.packages |= unique
  | .archs |= unique' "${files[@]}" \
  | sed "s/{{version}}/${version}/g"
