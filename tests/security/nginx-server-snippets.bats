#!/usr/bin/env bats

load 'helpers/nginx.bash'

setup() {
	nginx_hardening_integration_setup
	head -c 2048 /dev/zero > "${nginx_hardening_tmp}/request-body"
}

teardown() {
	nginx_hardening_integration_stop
}

@test "real nginx config starts without server snippets" {
	nginx_hardening_integration_start
	nginx_hardening_config_is_valid

	run nginx_hardening_request POST /xmlrpc.php "${nginx_hardening_tmp}/request-body"
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 200 "${output}"
	nginx_hardening_assert_upstream_reached
}

@test "real nginx config applies server snippets" {
	nginx_hardening_server_snippet client-max-body-size.conf 'client_max_body_size 1k;'
	nginx_hardening_integration_start
	nginx_hardening_config_is_valid

	run nginx_hardening_request POST /xmlrpc.php "${nginx_hardening_tmp}/request-body"
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 413 "${output}"
	nginx_hardening_assert_upstream_not_reached
}
