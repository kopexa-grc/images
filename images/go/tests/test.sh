#!/usr/bin/env bash
# Builds a static and a cgo binary with the toolchain image; for the fips
# variant also checks that binaries use the certified Go Cryptographic Module.
source "$(dirname "$0")/../../../scripts/lib-test.sh"
version="${2:-}"
variant="${3:-}"

v="$(run "$IMG" -c 'go version')"
[[ "$v" == *"go$version"* ]] && pass "$v" || fail "unexpected: $v"
[[ "$(run "$IMG" -c 'go env GOTOOLCHAIN')" == "local" ]] && pass "GOTOOLCHAIN=local" || fail "GOTOOLCHAIN not local"
run "$IMG" -c '
  set -e; mkdir -p /tmp/h && cd /tmp/h
  printf "package main\nimport \"fmt\"\nfunc main(){fmt.Println(\"hi\")}\n" > main.go
  go mod init example.com/h >/dev/null 2>&1
  CGO_ENABLED=0 go build -trimpath -o static . && ./static
  CGO_ENABLED=1 go build -o dyn . && ./dyn
' | grep -c hi | grep -qx 2 && pass "static and cgo builds work" || fail "go build failed"

if [[ "$variant" == "fips" ]]; then
  out="$(run "$IMG" -c '
    set -e; mkdir -p /tmp/f && cd /tmp/f
    cat > main.go <<GO
package main

import (
	"crypto/fips140"
	"fmt"
)

func main() { fmt.Println(fips140.Enabled(), fips140.Version()) }
GO
    go mod init example.com/f >/dev/null 2>&1
    CGO_ENABLED=0 go build -trimpath -o app .
    ./app
    go version -m app | grep -E "GOFIPS140|DefaultGODEBUG" || true
  ')"
  echo "$out" | sed 's/^/       /'
  head -1 <<<"$out" | grep -q '^true ' && pass "FIPS 140-3 mode enabled by default" || fail "FIPS mode not enabled"
  certified="$(run "$IMG" -c 'cat "$(go env GOROOT)/lib/fips140/certified.txt"')"
  grep -q "GOFIPS140=$certified" <<<"$out" \
    && pass "linked certified module $certified" || fail "binary not built against certified module $certified"
fi
