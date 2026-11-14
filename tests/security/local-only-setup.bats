#!/usr/bin/env bats

load 'helpers/entrypoint.bash'

setup() {
	entrypoint_setup
}

teardown() {
	entrypoint_teardown
}

@test "password reset is skipped when the environment type is not set" {
	run entrypoint_run WORDPRESS_LOCAL_USERS_PASSWORD=admin WORDPRESS_LOCAL_RESET_ALL_USERS_PASSWORDS=1
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"ERROR: WORDPRESS_LOCAL_USERS_PASSWORD"* ]]
	[[ "$(entrypoint_wp_calls)" != *"user update"* ]]
}

@test "password reset is skipped in production" {
	run entrypoint_run WP_ENVIRONMENT_TYPE=production WORDPRESS_LOCAL_USERS_PASSWORD=admin WORDPRESS_LOCAL_RESET_PASSWORD_FOR_USER=admin
	[ "${status}" -eq 0 ]
	[[ "$(entrypoint_wp_calls)" != *"user update"* ]]
}

@test "password reset runs in a local environment" {
	run entrypoint_run WP_ENVIRONMENT_TYPE=local WORDPRESS_LOCAL_USERS_PASSWORD=admin WORDPRESS_LOCAL_RESET_ALL_USERS_PASSWORDS=1
	[ "${status}" -eq 0 ]
	[[ "$(entrypoint_wp_calls)" == *"user update 1 --user_pass=admin"* ]]
}

@test "URL synchronization is skipped outside local environments" {
	run entrypoint_run WP_ENVIRONMENT_TYPE=staging PROD_SITE_URL=https://example.com
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"ERROR: PROD_SITE_URL"* ]]
	[[ "$(entrypoint_wp_calls)" != *"search-replace"* ]]
}

@test "URL synchronization runs in a development environment" {
	run entrypoint_run WP_ENVIRONMENT_TYPE=development PROD_SITE_URL=https://example.com
	[ "${status}" -eq 0 ]
	[[ "$(entrypoint_wp_calls)" == *"search-replace https://example.com http://localhost"* ]]
}
