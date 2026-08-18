#!/usr/bin/env bash

nginx_hardening_root="${BATS_TEST_DIRNAME}/../.."
nginx_hardening_script="${nginx_hardening_root}/.docker/nginx/docker-entrypoint.d/40-xmlrpc-hardening.sh"
nginx_hardening_tmp="${BATS_TEST_TMPDIR}/nginx"
nginx_hardening_container=""
nginx_hardening_port=""

setup_nginx_fixture() {
	mkdir -p "${nginx_hardening_tmp}"
	cat > "${nginx_hardening_tmp}/default.conf" <<'NGINX_CONF'
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
}

nginx_hardening_logs() {
	if [ -n "${nginx_hardening_container}" ]; then
		echo "--- nginx container logs (${nginx_hardening_container}) ---" >&2
		docker logs "${nginx_hardening_container}" >&2 || true
	fi
}

nginx_hardening_start() {
	local value="${1-__UNSET__}"
	local -a environment_args=()

	if [ "${value}" != "__UNSET__" ]; then
		environment_args=(-e "WORDPRESS_XMLRPC_ENABLED=${value}")
	fi

	nginx_hardening_container="$(docker run -d --rm "${environment_args[@]}" \
		-v "${nginx_hardening_script}:/docker-entrypoint.d/40-xmlrpc-hardening.sh:ro" \
		-v "${nginx_hardening_tmp}/default.conf:/etc/nginx/conf.d/default.conf:ro" \
		-p 127.0.0.1::80 nginx:latest)"

	nginx_hardening_port="$(docker port "${nginx_hardening_container}" 80/tcp | sed 's/.*://')"

	local attempts=0
	while ! curl -sS -o /dev/null "http://127.0.0.1:${nginx_hardening_port}/xmlrpc.php" >/dev/null 2>&1; do
		attempts=$((attempts + 1))
		if [ "${attempts}" -ge 30 ]; then
			nginx_hardening_logs
			return 1
		fi
		sleep 1
	done
}

nginx_hardening_stop() {
	if [ -n "${nginx_hardening_container}" ]; then
		docker rm -f "${nginx_hardening_container}" >/dev/null 2>&1 || true
		nginx_hardening_container=""
	fi
}

nginx_hardening_config_is_valid() {
	docker exec "${nginx_hardening_container}" nginx -t >/dev/null || {
		nginx_hardening_logs
		return 1
	}
}

nginx_hardening_request() {
	local method="$1"
	local path="$2"
	local body_file="${nginx_hardening_tmp}/response-body"

	curl -sS -X "${method}" -o "${body_file}" -w '%{http_code}' \
		"http://127.0.0.1:${nginx_hardening_port}${path}"
}

nginx_hardening_assert_status() {
	local expected="$1"
	local actual="$2"

	if [ "${actual}" != "${expected}" ]; then
		echo "Expected HTTP ${expected}, got ${actual}" >&2
		nginx_hardening_logs
		return 1
	fi
}

nginx_hardening_assert_upstream_reached() {
	if ! grep -q 'PHP_UPSTREAM_REACHED' "${nginx_hardening_tmp}/response-body"; then
		echo "Expected the controlled PHP upstream to be reached" >&2
		nginx_hardening_logs
		return 1
	fi
}

nginx_hardening_assert_upstream_not_reached() {
	if grep -q 'PHP_UPSTREAM_REACHED' "${nginx_hardening_tmp}/response-body"; then
		echo "The controlled PHP upstream was reached unexpectedly" >&2
		nginx_hardening_logs
		return 1
	fi
}
