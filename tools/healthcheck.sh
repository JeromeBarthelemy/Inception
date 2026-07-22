#!/bin/sh
# Inception stack health check. Run from the repo root.
COMPOSE="docker compose -f srcs/docker-compose.yml"
DOMAIN="https://jbarthel.42.fr"
fails=0

ok() { printf '  \033[32m[ OK ]\033[0m %s\n' "$1"; }
ko() { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; fails=$((fails + 1)); }

echo "== Waiting for the stack =="
i=0
while [ "$i" -lt 30 ]; do
    [ "$(curl -kso /dev/null -w '%{http_code}' "$DOMAIN")" = "200" ] && break
    i=$((i + 1))
    sleep 1
done
[ "$i" -lt 30 ] && ok "ready after ${i}s" || ko "not ready after 30s"

echo "== Containers running =="
for s in mariadb wordpress nginx redis adminer static ftp netdata; do
    state=$(docker inspect -f '{{.State.Status}}' "$s" 2>/dev/null)
    [ "$state" = "running" ] && ok "$s is running" || ko "$s is ${state:-absent}"
done

echo "== PID 1 is the service =="
check_pid1() {
    comm=$(docker exec "$1" cat /proc/1/comm 2>/dev/null)
    case "$comm" in
        "$2"*) ok "$1 PID 1 = $comm" ;;
        *)     ko "$1 PID 1 = ${comm:-?} (expected $2)" ;;
    esac
}
check_pid1 mariadb   mariadbd
check_pid1 wordpress php-fpm
check_pid1 nginx     nginx
check_pid1 redis     redis-server
check_pid1 adminer   php-fpm
check_pid1 static    httpd
check_pid1 ftp       vsftpd
check_pid1 netdata   netdata

echo "== HTTPS responds =="
code=$(curl -kso /dev/null -w '%{http_code}' "$DOMAIN")
[ "$code" = "200" ] && ok "GET / -> $code" || ko "GET / -> $code"

echo "== Bonus vhosts respond =="
for h in adminer static netdata; do
    code=$(curl -kso /dev/null -w '%{http_code}' "https://$h.jbarthel.42.fr")
    [ "$code" = "200" ] && ok "$h -> $code" || ko "$h -> $code"
done

echo "== FTP =="
if [ -f secrets/ftp_password.txt ]; then
    curl -so /dev/null --max-time 5 -u "nobody:$(cat secrets/ftp_password.txt)" ftp://127.0.0.1/ \
        && ok "authenticated listing" || ko "authenticated listing failed"
else
    ko "secrets/ftp_password.txt missing"
fi
curl -so /dev/null --max-time 5 ftp://127.0.0.1/ \
    && ko "anonymous FTP allowed" || ok "anonymous FTP refused"

echo "== Redis =="
[ "$(docker exec redis redis-cli ping 2>/dev/null)" = "PONG" ] \
    && ok "redis responds to PING" || ko "redis does not respond"

echo "== TLS 1.2 accepted =="
curl -kso /dev/null --tlsv1.2 --tls-max 1.2 "$DOMAIN" \
    && ok "TLS 1.2 handshake" || ko "TLS 1.2 rejected"

echo "== Port 80 closed =="
if curl -so /dev/null --max-time 3 http://jbarthel.42.fr; then
    ko "port 80 answered (should be closed)"
else
    ok "port 80 refused"
fi

echo "== Network =="
n=$(docker network inspect srcs_inception -f '{{len .Containers}}' 2>/dev/null)
[ "$n" = "8" ] && ok "8 containers on srcs_inception" || ko "${n:-0} on srcs_inception (want 8)"

echo "== Volumes =="
for v in srcs_db_data srcs_wp_data; do
    docker volume inspect "$v" >/dev/null 2>&1 && ok "$v exists" || ko "$v missing"
done

echo "== No secrets tracked by git =="
if git ls-files | grep -qE '\.env$|secrets/'; then
    ko "a secret file is tracked by git!"
else
    ok "no .env / secrets/ tracked"
fi

echo
[ "$fails" -eq 0 ] && echo "ALL GREEN" || echo "$fails CHECK(S) FAILED"
exit "$fails"
