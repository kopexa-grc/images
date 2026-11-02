#!/usr/bin/env bash
source "$(dirname "$0")/../../../scripts/lib-test.sh"
assert_nonroot
assert_no_setuid
# Only the bash pulled in by posix-libc-utils (ldd) is tolerated, see apko.yaml.
shells="$(run --entrypoint /usr/bin/valkey-server "$IMG" --version >/dev/null; docker create "$IMG" | xargs -I{} sh -c 'docker export {} | tar -t; docker rm {} >/dev/null' | grep -E '^(usr/)?bin/(sh|bash|ash|dash|zsh|busybox)$' | sort -u | tr '\n' ' ')"
[[ "$shells" == "usr/bin/bash " ]] && pass "only the bash required by posix-libc-utils (ldd)" || fail "unexpected shells: $shells"
run "$IMG" --version | grep -q '^Valkey server' && pass "valkey-server runs" || fail "valkey-server --version"
name="valkey-test-$$"
docker run -d --rm --name "$name" --read-only --cap-drop ALL --security-opt no-new-privileges \
  "$IMG" --requirepass s3cret --save "" --appendonly no >/dev/null
sleep 2
cli() { docker run --rm --network "container:$name" --entrypoint /usr/bin/valkey-cli "$IMG" -a s3cret --no-auth-warning "$@"; }
[[ "$(cli SET k v)" == OK && "$(cli GET k)" == v ]] && pass "set/get with password (read-only rootfs, no capabilities)" || { docker logs "$name" | tail -5; docker rm -f "$name" >/dev/null; fail "set/get"; }
[[ "$(docker run --rm --network "container:$name" --entrypoint /usr/bin/valkey-cli "$IMG" GET k 2>&1)" == *NOAUTH* ]] && pass "password required" || { docker rm -f "$name" >/dev/null; fail "no auth enforced"; }
docker rm -f "$name" >/dev/null
