#!/usr/bin/env bash
# Smoke + hardening tests for php-apache (runtime and dev variants).
source "$(dirname "$0")/../../../scripts/lib-test.sh"
variant="${3:-}"

for ext in apcu bcmath ctype curl dom exif fileinfo gd iconv intl mbstring mysqli \
           openssl pcntl PDO pdo_mysql posix SimpleXML sockets sodium xml zip "Zend OPcache"; do
  run --entrypoint /usr/bin/php "$IMG" -m | grep -qx "$ext" || fail "php extension missing: $ext"
done
pass "php extensions present"
run --entrypoint /usr/bin/httpd "$IMG" -t -f /etc/kopexa/httpd/httpd.conf 2>&1 | grep -q "Syntax OK" \
  && pass "httpd config valid" || fail "httpd -t failed"

if [[ "$variant" == "dev" ]]; then
  run --entrypoint /usr/bin/composer "$IMG" --version >/dev/null && pass "composer works"
  run --entrypoint /usr/bin/node "$IMG" --version >/dev/null && pass "node works"
  exit 0
fi

assert_nonroot
assert_no_setuid
assert_no_shell

# Serve a page with a read-only rootfs, all caps dropped.
www="$(mktemp -d)"; chmod 755 "$www"
echo '<?php echo "ok ", PHP_VERSION;' >"$www/index.php"
echo 'secret' >"$www/.env"
chmod 644 "$www"/index.php "$www"/.env
cid="$(docker run -d --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges \
  -v "$www:/app/public:ro" -p 127.0.0.1::8080 "$IMG")"
trap 'docker rm -f "$cid" >/dev/null; rm -rf "$www"' EXIT
port="$(docker port "$cid" 8080/tcp | head -1 | sed 's/.*://')"
for _ in $(seq 1 20); do curl -fs "localhost:$port/healthz" >/dev/null && break; sleep 0.5; done

code() { curl -s -o /dev/null -w '%{http_code}' -X "${2:-GET}" "localhost:$port$1"; }
[[ "$(curl -s "localhost:$port/")" == ok\ 8.* ]] && pass "serves PHP" || { docker logs "$cid"; fail "PHP not served"; }
[[ "$(code /healthz)" == 200 ]] && pass "/healthz 200" || fail "/healthz"
[[ "$(code /.env)" == 403 ]] && pass "dotfiles denied" || fail "dotfile served"
[[ "$(code / TRACE)" == 405 ]] && pass "TRACE disabled" || fail "TRACE allowed"
[[ "$(code / PROPFIND)" == 403 ]] && pass "uncommon methods denied" || fail "PROPFIND allowed"
curl -sI "localhost:$port/" | grep -qi '^server: apache\s*$' && pass "no version in Server header" || fail "Server header leaks version"
! curl -sI "localhost:$port/" | grep -qi '^x-powered-by' && pass "no X-Powered-By" || fail "X-Powered-By present"
