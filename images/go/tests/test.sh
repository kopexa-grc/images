#!/usr/bin/env bash
# Builds a static and a cgo binary with the toolchain image.
source "$(dirname "$0")/../../../scripts/lib-test.sh"
version="${2:-}"

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
