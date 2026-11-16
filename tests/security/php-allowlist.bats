#!/usr/bin/env bats

load 'helpers/nginx.bash'

php_script='<?php echo "PHP_UPSTREAM" . "_REACHED";'

setup() {
	nginx_hardening_integration_setup
	for path in \
		index.php \
		wp-login.php \
		wp-cron.php \
		z.php \
		x.PHP \
		wp-config.php \
		wp-admin/index.php \
		wp-admin/admin-ajax.php \
		wp-admin/network/index.php \
		wp-admin/includes/admin.php \
		wp-admin/install.php \
		wp-admin/setup-config.php \
		wp-includes/version.php \
		wp-includes/js/tinymce/wp-tinymce.php \
		wp-content/cache/x.php \
		wp-content/languages/x.php \
		wp-content/uploads/x.php \
		wp-content/uploads/2024/12/shell.phtml \
		wp-content/plugins/x/lib/b.php \
		wp-content/plugins/x/shell.phar \
		wp-content/themes/x/functions.php5; do
		nginx_hardening_document_root_file "${path}" "${php_script}"
	done
}

teardown() {
	nginx_hardening_integration_stop
}

assert_php_runs() {
	run nginx_hardening_request GET "$1"
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 200 "${output}"
	nginx_hardening_assert_upstream_reached
}

assert_php_refused() {
	local expected_status="$1"
	run nginx_hardening_request GET "$2"
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status "${expected_status}" "${output}"
	nginx_hardening_assert_upstream_not_reached
}

@test "WordPress front controllers run through PHP-FPM" {
	nginx_hardening_integration_start
	nginx_hardening_config_is_valid

	assert_php_runs /
	assert_php_runs /index.php
	assert_php_runs /sample-page/
	assert_php_runs /wp-login.php
	assert_php_runs /wp-cron.php
	assert_php_runs /wp-json/
}

@test "wp-admin scripts run through PHP-FPM" {
	nginx_hardening_integration_start
	nginx_hardening_config_is_valid

	assert_php_runs /wp-admin/
	assert_php_runs /wp-admin/admin-ajax.php
	assert_php_runs /wp-admin/network/index.php
	assert_php_runs /wp-includes/js/tinymce/wp-tinymce.php
}

@test "an unknown PHP file at the document root is not executed" {
	nginx_hardening_integration_start
	assert_php_refused 404 /z.php
	assert_php_refused 404 /foo/z.php
}

@test "PHP under wp-content cache and languages is not executed" {
	nginx_hardening_integration_start
	assert_php_refused 404 /wp-content/cache/x.php
	assert_php_refused 404 /wp-content/languages/x.php
}

@test "PHP under uploads stays denied" {
	nginx_hardening_integration_start
	assert_php_refused 403 /wp-content/uploads/x.php
}

@test "plugin and theme PHP files are not reachable directly" {
	nginx_hardening_integration_start
	assert_php_refused 404 /wp-content/plugins/x/lib/b.php
	assert_php_refused 404 /wp-content/plugins/x/shell.phar
	assert_php_refused 404 /wp-content/themes/x/functions.php5
}

@test "alternative PHP extensions are neither executed nor served as source" {
	nginx_hardening_integration_start
	assert_php_refused 404 /wp-content/uploads/2024/12/shell.phtml
	assert_php_refused 404 /x.PHP
}

@test "WordPress internals are not reachable directly" {
	nginx_hardening_integration_start
	assert_php_refused 404 /wp-config.php
	assert_php_refused 404 /wp-admin/includes/admin.php
	assert_php_refused 404 /wp-includes/version.php
}

@test "web installer is closed by default" {
	nginx_hardening_integration_start
	nginx_hardening_config_is_valid

	assert_php_refused 404 /wp-admin/install.php
	assert_php_refused 404 /wp-admin/setup-config.php
}

@test "web installer runs when explicitly enabled" {
	nginx_hardening_integration_start __UNSET__ 1
	nginx_hardening_config_is_valid

	assert_php_runs /wp-admin/install.php
	assert_php_runs /wp-admin/setup-config.php
}

@test "web installer rejects an invalid configuration value" {
	run docker run --rm -e WORDPRESS_WEB_INSTALL_ENABLED=invalid \
		-v "${nginx_web_install_script}:/docker-entrypoint.d/41-web-install.sh:ro" \
		nginx:latest

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"ERROR: WORDPRESS_WEB_INSTALL_ENABLED must be one of"* ]]
}

@test "a server snippet can allow a specific plugin PHP endpoint" {
	nginx_hardening_server_snippet plugin-endpoint.conf 'location ^~ /wp-content/plugins/x/lib/b.php { include /etc/nginx/snippets/php-fpm.conf; }'
	nginx_hardening_integration_start
	nginx_hardening_config_is_valid

	assert_php_runs /wp-content/plugins/x/lib/b.php
	assert_php_refused 404 /wp-content/plugins/x/shell.phar
}
