# shellcheck shell=bash
# Shared helpers for images/*/tests/test.sh. Source this file.
set -euo pipefail
IMG="${1:?usage: test.sh <image-ref>}"
pass() { printf '  \033[32mok\033[0m   %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; exit 1; }
run()  { docker run --rm "$@"; }
cfg()  { docker inspect "$IMG" --format "$1"; }

# Hardening invariants that apply to every runtime image.
assert_nonroot() {
  local u; u="$(cfg '{{.Config.User}}')"
  [[ "$u" == "65532" ]] && pass "runs as uid 65532" || fail "user is '$u', expected 65532"
}
assert_no_setuid() {
  # Uses the image's own find if present, otherwise inspects the exported fs.
  local list
  list="$(docker create "$IMG" true | { read -r c; docker export "$c" | tar -tvf - | awk '$1 ~ /^-..s|^-.....s/ {print $6}'; docker rm "$c" >/dev/null; })"
  [[ -z "$list" ]] && pass "no setuid/setgid files" || fail "setuid/setgid files: $list"
}
assert_no_shell() {
  local c out
  c="$(docker create "$IMG" true)"
  out="$(docker export "$c" | tar -tf - | grep -E '^(bin|usr/bin)/(sh|bash|ash|busybox)$' || true)"
  docker rm "$c" >/dev/null
  [[ -z "$out" ]] && pass "no shell" || fail "shell present: $out"
}
