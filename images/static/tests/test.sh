#!/usr/bin/env bash
source "$(dirname "$0")/../../../scripts/lib-test.sh"
assert_nonroot
assert_no_setuid
assert_no_shell
c="$(docker create "$IMG" true)"
files="$(docker export "$c" | tar -tf -)"
docker rm "$c" >/dev/null
grep -qx 'etc/ssl/certs/ca-certificates.crt' <<<"$files" && pass "CA bundle present" || fail "no CA bundle"
grep -qx 'usr/share/zoneinfo/UTC' <<<"$files" && pass "tzdata present" || fail "no tzdata"
