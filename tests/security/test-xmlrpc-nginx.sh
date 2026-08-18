#!/bin/sh

set -eu

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$project_root/.docker/nginx/docker-entrypoint.d/40-xmlrpc-hardening.sh"
fixture_dir="$(mktemp -d)"
container_id=""

cleanup() {
	if [ -n "$container_id" ]; then
		docker rm -f "$container_id" >/dev/null 2>&1 || true
	fi
	rm -rf "$fixture_dir"
}
trap cleanup EXIT INT TERM

cat > "$fixture_dir/default.conf" <<'NGINX_CONF'
server {
	listen 8081;
	location / {
		return 200 "PHP_UPSTREAM_REACHED\n";
	}
}

server {
	listen 80;
	root /var/www/html;
	include /tmp/xmlrpc-hardening.conf;
	location / {
		try_files $uri =404;
	}
	location ~ \.php$ {
		proxy_pass http://127.0.0.1:8081;
	}
}
NGINX_CONF

run_allowed_case() {
	name="$1"
	value="$2"

	echo "Running XML-RPC case: $name"
	if [ "$value" = "__UNSET__" ]; then
		container_id="$(docker run -d --rm \
			-v "$script:/docker-entrypoint.d/40-xmlrpc-hardening.sh:ro" \
			-v "$fixture_dir/default.conf:/etc/nginx/conf.d/default.conf:ro" \
			-p 127.0.0.1::80 nginx:latest)"
	else
		container_id="$(docker run -d --rm -e WORDPRESS_XMLRPC_ENABLED="$value" \
			-v "$script:/docker-entrypoint.d/40-xmlrpc-hardening.sh:ro" \
			-v "$fixture_dir/default.conf:/etc/nginx/conf.d/default.conf:ro" \
			-p 127.0.0.1::80 nginx:latest)"
	fi
	port="$(docker port "$container_id" 80/tcp | sed 's/.*://')"

	tries=0
	while ! curl -fsS "http://127.0.0.1:$port/xmlrpc.php" >/dev/null 2>&1; do
		tries=$((tries + 1))
		if [ "$tries" -ge 30 ]; then
			docker logs "$container_id" >&2 || true
			return 1
		fi
		sleep 1
	done

	docker exec "$container_id" nginx -t
	status="$(curl -sS -o "$fixture_dir/body" -w '%{http_code}' "http://127.0.0.1:$port/xmlrpc.php")"
	test "$status" = 200
	grep -q PHP_UPSTREAM_REACHED "$fixture_dir/body"

	docker rm -f "$container_id" >/dev/null
	container_id=""
}

run_allowed_case "variable absent" __UNSET__
run_allowed_case "explicit enabled" 1

echo "Running XML-RPC case: explicit disabled"
container_id="$(docker run -d --rm -e WORDPRESS_XMLRPC_ENABLED=0 \
	-v "$script:/docker-entrypoint.d/40-xmlrpc-hardening.sh:ro" \
	-v "$fixture_dir/default.conf:/etc/nginx/conf.d/default.conf:ro" \
	-p 127.0.0.1::80 nginx:latest)"
port="$(docker port "$container_id" 80/tcp | sed 's/.*://')"
tries=0
while ! docker exec "$container_id" nginx -t >/dev/null 2>&1; do
	tries=$((tries + 1))
	if [ "$tries" -ge 30 ]; then
		docker logs "$container_id" >&2 || true
		exit 1
	fi
	sleep 1
done

status="$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/xmlrpc.php")"
test "$status" = 403
status="$(curl -sS -o /dev/null -w '%{http_code}' -X POST -d security-test "http://127.0.0.1:$port/xmlrpc.php")"
test "$status" = 403
docker rm -f "$container_id" >/dev/null
container_id=""

echo "Running XML-RPC case: invalid value"
if docker run --rm -e WORDPRESS_XMLRPC_ENABLED=invalid \
	-v "$script:/docker-entrypoint.d/40-xmlrpc-hardening.sh:ro" nginx:latest \
	>"$fixture_dir/invalid.stdout" 2>"$fixture_dir/invalid.stderr"; then
	echo "ERROR: invalid value was accepted" >&2
	exit 1
fi
grep -q 'ERROR: WORDPRESS_XMLRPC_ENABLED must be one of' "$fixture_dir/invalid.stderr"

echo "XML-RPC nginx tests: PASS"
