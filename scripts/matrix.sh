#!/usr/bin/env bash
# Emit the GitHub Actions build matrix as JSON: one entry per
# image × version × variant, read from images/*/image.yaml.
#
#   scripts/matrix.sh            # all images
#   scripts/matrix.sh go static  # selected images
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/images"
images=("$@")
if [[ ${#images[@]} -eq 0 ]]; then
  for d in */image.yaml; do images+=("${d%/image.yaml}"); done
fi
for img in "${images[@]}"; do
  yq -o=json "$img/image.yaml" | jq -c --arg img "$img" \
    '.variants as $vs | .versions[] as $v | $vs[] | {image: $img, version: $v, variant: .}'
done | jq -cs '{include: .}'
