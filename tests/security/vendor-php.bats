#!/usr/bin/env bats

load 'helpers/nginx.bash'

setup() {
	nginx_hardening_integration_setup
	nginx_hardening_document_root_file wp-content/themes/theme/vendor/wordpress/wp-admin/setup-config.php '<?php echo "PHP_UPSTREAM_REACHED";'
	nginx_hardening_document_root_file wp-content/plugins/plugin/vendor/autoload.php '<?php echo "PHP_UPSTREAM_REACHED";'
	nginx_hardening_document_root_file wp-content/plugins/plugin/vendor-bin/tool/run.php '<?php echo "PHP_UPSTREAM_REACHED";'
	nginx_hardening_document_root_file wp-content/plugins/plugin/vendor/package/style.css 'body {}'
	nginx_hardening_document_root_file wp-content/plugins/plugin/plugin.php '<?php echo "PHP_UPSTREAM_REACHED";'
	nginx_hardening_integration_start
	nginx_hardening_config_is_valid
}

teardown() {
	nginx_hardening_integration_stop
}

@test "real nginx config blocks PHP under a theme vendor folder" {
	run nginx_hardening_request GET /wp-content/themes/theme/vendor/wordpress/wp-admin/setup-config.php
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 403 "${output}"
	nginx_hardening_assert_upstream_not_reached
}

@test "real nginx config blocks PHP under a plugin vendor folder" {
	run nginx_hardening_request GET /wp-content/plugins/plugin/vendor/autoload.php
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 403 "${output}"
	nginx_hardening_assert_upstream_not_reached
}

@test "real nginx config blocks PHP under a plugin vendor-bin folder" {
	run nginx_hardening_request GET /wp-content/plugins/plugin/vendor-bin/tool/run.php
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 403 "${output}"
	nginx_hardening_assert_upstream_not_reached
}

@test "real nginx config blocks PHP under a vendor folder regardless of case" {
	run nginx_hardening_request GET /wp-content/plugins/plugin/VENDOR/autoload.php
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 403 "${output}"
	nginx_hardening_assert_upstream_not_reached
}

@test "real nginx config blocks PHP under a vendor folder reached through an encoded path" {
	run nginx_hardening_request GET /wp-content/plugins/plugin/%76endor/autoload.php
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 403 "${output}"
	nginx_hardening_assert_upstream_not_reached
}

@test "real nginx config serves static files under a vendor folder" {
	run nginx_hardening_request GET /wp-content/plugins/plugin/vendor/package/style.css
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 200 "${output}"
}

@test "real nginx config still runs plugin PHP outside vendor folders" {
	run nginx_hardening_request GET /wp-content/plugins/plugin/plugin.php
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 200 "${output}"
	nginx_hardening_assert_upstream_reached
}
