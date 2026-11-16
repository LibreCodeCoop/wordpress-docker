#!/usr/bin/env bash

entrypoint_root="${BATS_TEST_DIRNAME}/../.."
entrypoint_tmp="${BATS_TEST_TMPDIR}/entrypoint"
entrypoint_network=""
entrypoint_database_container=""

entrypoint_setup() {
	entrypoint_network="entrypoint-bats-${BATS_TEST_NUMBER:-0}-$$"
	mkdir -p "${entrypoint_tmp}/document-root" "${entrypoint_tmp}/bin" "${entrypoint_tmp}/log"
	touch "${entrypoint_tmp}/document-root/wp-load.php" "${entrypoint_tmp}/document-root/wp-config.php"
	chmod 777 "${entrypoint_tmp}/log"

	cat > "${entrypoint_tmp}/bin/wp" <<'WP_STUB'
#!/bin/sh
echo "wp $*" >> /var/log/entrypoint/wp-calls
case "$1 $2" in
	"user list") echo 1 ;;
	"user get") echo 1 ;;
esac
exit 0
WP_STUB
	printf '%s\n' '#!/bin/sh' 'exit 0' > "${entrypoint_tmp}/bin/php-fpm"
	chmod 755 "${entrypoint_tmp}/bin/wp" "${entrypoint_tmp}/bin/php-fpm"

	printf '%s\n' 'server { listen 3306; return 444; }' > "${entrypoint_tmp}/database.conf"
	docker network create "${entrypoint_network}" >/dev/null
	entrypoint_database_container="$(docker run -d --rm \
		--network "${entrypoint_network}" --network-alias mariadb \
		-v "${entrypoint_tmp}/database.conf:/etc/nginx/conf.d/default.conf:ro" \
		nginx:latest)"
}

entrypoint_teardown() {
	if [ -n "${entrypoint_database_container}" ]; then
		docker rm -f "${entrypoint_database_container}" >/dev/null 2>&1 || true
		entrypoint_database_container=""
	fi
	if [ -n "${entrypoint_network}" ]; then
		docker network rm "${entrypoint_network}" >/dev/null 2>&1 || true
		entrypoint_network=""
	fi
}

entrypoint_run() {
	local -a environment_args=()
	local variable

	for variable in "$@"; do
		environment_args+=(-e "${variable}")
	done

	docker run --rm \
		--network "${entrypoint_network}" \
		-e "HOST_UID=$(id -u)" -e "HOST_GID=$(id -g)" \
		"${environment_args[@]}" \
		-v "${entrypoint_root}/.docker/wordpress/entrypoint.sh:/var/www/scripts/entrypoint.sh:ro" \
		-v "${entrypoint_tmp}/bin/wp:/usr/local/bin/wp:ro" \
		-v "${entrypoint_tmp}/bin/php-fpm:/usr/local/sbin/php-fpm:ro" \
		-v "${entrypoint_tmp}/log:/var/log/entrypoint" \
		-v "${entrypoint_tmp}/document-root:/var/www/html" \
		php:8.3-fpm bash /var/www/scripts/entrypoint.sh
}

entrypoint_wp_calls() {
	cat "${entrypoint_tmp}/log/wp-calls" 2>/dev/null || true
}
