#!/usr/bin/env bats

load 'helpers/nginx.bash'

setup() {
	setup_nginx_fixture
}

teardown() {
	nginx_hardening_stop
}

@test "XML-RPC is allowed when the variable is absent" {
	nginx_hardening_start
	nginx_hardening_config_is_valid

	run nginx_hardening_request GET /xmlrpc.php
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 200 "${output}"
	nginx_hardening_assert_upstream_reached
}

@test "XML-RPC is allowed when explicitly enabled" {
	nginx_hardening_start 1
	nginx_hardening_config_is_valid

	run nginx_hardening_request GET /xmlrpc.php
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 200 "${output}"
	nginx_hardening_assert_upstream_reached
}

@test "XML-RPC GET is blocked when disabled" {
	nginx_hardening_start 0
	nginx_hardening_config_is_valid

	run nginx_hardening_request GET /xmlrpc.php
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 403 "${output}"
	nginx_hardening_assert_upstream_not_reached
}

@test "XML-RPC POST is blocked when disabled" {
	nginx_hardening_start 0
	nginx_hardening_config_is_valid

	run curl -sS -X POST -d security-test \
		-o "${nginx_hardening_tmp}/response-body" \
		-w '%{http_code}' "http://127.0.0.1:${nginx_hardening_port}/xmlrpc.php"
	[ "${status}" -eq 0 ]
	nginx_hardening_assert_status 403 "${output}"
	nginx_hardening_assert_upstream_not_reached
}

@test "XML-RPC rejects an invalid configuration value" {
	run docker run --rm -e WORDPRESS_XMLRPC_ENABLED=invalid \
		-v "${nginx_hardening_script}:/docker-entrypoint.d/40-xmlrpc-hardening.sh:ro" \
		nginx:latest

	[ "${status}" -ne 0 ]
	[[ "${output}" == *"ERROR: WORDPRESS_XMLRPC_ENABLED must be one of"* ]]
}
