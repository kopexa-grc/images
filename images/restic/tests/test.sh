#!/usr/bin/env bash
source "$(dirname "$0")/../../../scripts/lib-test.sh"
assert_nonroot
assert_no_setuid
run "$IMG" version | grep -q '^restic ' && pass "restic runs" || fail "restic version failed"
# Round trip against a local repository.
run --entrypoint /bin/sh -e RESTIC_PASSWORD=test "$IMG" -c '
  set -e
  restic init -r /tmp/repo -q
  echo hello > /tmp/f && restic backup -r /tmp/repo -q /tmp/f
  restic restore latest -r /tmp/repo -q --target /tmp/out
  cat /tmp/out/tmp/f' | grep -qx hello && pass "backup/restore round trip" || fail "restic round trip"
