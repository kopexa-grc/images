#!/usr/bin/env bash
# Local build for development: builds our melange packages and one matrix
# entry for the host architecture, loads it into Docker and runs its tests.
#
#   scripts/build-local.sh php-apache 8.4         # -> kopexa/php-apache:local
#   scripts/build-local.sh php-apache 8.4 dev     # -> kopexa/php-apache-dev:local
#   scripts/build-local.sh go 1.27
#   scripts/build-local.sh static
#
# Requires: melange, apko, yq, jq, docker.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
image="${1:?usage: build-local.sh <image> [version] [variant]}"
version="${2:-}" variant="${3:-}"
name="$image${variant:+-$variant}"
arch="$(uname -m)"; [[ "$arch" == "arm64" ]] && arch=aarch64
out=.build; mkdir -p "$out/sbom-$name"

[[ -f $out/local-melange.rsa ]] || melange keygen "$out/local-melange.rsa" >/dev/null
for pkg in packages/*/melange.yaml; do
  dir="$(dirname "$pkg")"
  melange build "$pkg" --arch "$arch" --runner docker \
    --signing-key "$out/local-melange.rsa" --out-dir "$out/packages" --source-dir "$dir" \
    >"$out/melange-$(basename "$dir").log" 2>&1 || { tail -20 "$out/melange-$(basename "$dir").log"; exit 1; }
done

scripts/render.sh "$image" "$version" "$variant" > "$out/$name.yaml"
apko build "$out/$name.yaml" "kopexa/$name:local" "$out/$name.tar" --arch "$arch" \
  -r "$root/$out/packages" -k "$out/local-melange.rsa.pub" --sbom-path "$out/sbom-$name" \
  >"$out/apko-$name.log" 2>&1 || { tail -20 "$out/apko-$name.log"; exit 1; }
ref="$(docker load -i "$out/$name.tar" | sed -n 's/^Loaded image: //p' | tail -1)"
echo "built $ref"
echo "testing $ref"
"images/$image/tests/test.sh" "$ref" "${variant:-$version}"
