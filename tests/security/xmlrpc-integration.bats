#!/usr/bin/env bats

load 'helpers/nginx.bash'

setup() {
	nginx_hardening_integration_setup
}

teardown() {
	nginx_hardening_integration_stop
}

@test "real nginx config allows XML-RPC by default through PHP-FPM" {
	nginx_hardening_integration_start
	nginx_hardening_config_is_valid

	run nginx_hardening_request GET /xmlrpc.php
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 200 "${output}"
	nginx_hardening_assert_upstream_reached
}

@test "real nginx config blocks XML-RPC before PHP-FPM when disabled" {
	nginx_hardening_integration_start 0
	nginx_hardening_config_is_valid

	run nginx_hardening_request GET /xmlrpc.php
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 403 "${output}"
	nginx_hardening_assert_upstream_not_reached
}
