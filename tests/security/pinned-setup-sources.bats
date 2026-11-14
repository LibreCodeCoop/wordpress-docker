#!/usr/bin/env bats

load 'helpers/entrypoint.bash'

setup() {
	entrypoint_setup
	entrypoint_image="ghcr.io/librecodecoop/wordpress-docker:latest"

	local repository="${entrypoint_tmp}/work"
	git init -q -b main "${repository}"
	git -C "${repository}" -c user.name=test -c user.email=test@example.com commit -q --allow-empty -m first
	git -C "${repository}" tag v1.0.0
	first_commit="$(git -C "${repository}" rev-parse HEAD)"
	git -C "${repository}" -c user.name=test -c user.email=test@example.com commit -q --allow-empty -m second
	second_commit="$(git -C "${repository}" rev-parse HEAD)"
	git clone -q --bare "${repository}" "${entrypoint_tmp}/sources/plugin.git"

	printf '%s\n' 'archive' > "${entrypoint_tmp}/sources/plugin.zip"
	archive_sha256="$(sha256sum "${entrypoint_tmp}/sources/plugin.zip" | cut -d' ' -f1)"
}

teardown() {
	entrypoint_teardown
}

plugin_head() {
	git -C "${entrypoint_tmp}/document-root/wp-content/plugins/$1" rev-parse HEAD
}

@test "a custom plugin pinned to a commit is checked out at that commit and activated" {
	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_plugins:
  - slug: pinned
    source: file:///sources/plugin.git
    ref: ${first_commit}"
	[ "${status}" -eq 0 ]
	[ "$(plugin_head pinned)" = "${first_commit}" ]
	[[ "$(entrypoint_wp_calls)" == *"plugin activate pinned"* ]]
}

@test "a custom plugin pinned to a tag is checked out at the tag" {
	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_plugins:
  - slug: tagged
    source: file:///sources/plugin.git
    ref: v1.0.0"
	[ "${status}" -eq 0 ]
	[ "$(plugin_head tagged)" = "${first_commit}" ]
}

@test "a custom plugin whose commit cannot be checked out is not activated" {
	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_plugins:
  - slug: missing
    source: file:///sources/plugin.git
    ref: 0123456789abcdef0123456789abcdef01234567"
	[ "${status}" -eq 0 ]
	[[ "$(entrypoint_wp_calls)" != *"plugin activate missing"* ]]
}

@test "an existing custom plugin is moved to a new pinned commit" {
	git clone -q "${entrypoint_tmp}/sources/plugin.git" "${entrypoint_tmp}/document-root/wp-content/plugins/existing"
	git -C "${entrypoint_tmp}/document-root/wp-content/plugins/existing" checkout -q --detach "${first_commit}"

	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_plugins:
  - slug: existing
    source: file:///sources/plugin.git
    ref: ${second_commit}"
	[ "${status}" -eq 0 ]
	[ "$(plugin_head existing)" = "${second_commit}" ]
}

@test "a custom theme pinned to a commit is checked out at that commit" {
	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_themes:
  - slug: theme
    source: file:///sources/plugin.git
    ref: ${first_commit}"
	[ "${status}" -eq 0 ]
	[ "$(git -C "${entrypoint_tmp}/document-root/wp-content/themes/theme" rev-parse HEAD)" = "${first_commit}" ]
}

@test "an unpinned entry is reported" {
	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_plugins:
  - slug: floating
    source: file:///sources/plugin.git"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"floating has no pin"* ]]
	[ "$(plugin_head floating)" = "${second_commit}" ]
}

@test "unpinned entries are skipped when pins are required" {
	run entrypoint_run WORDPRESS_SETUP_REQUIRE_PINNED=1 "WORDPRESS_SETUP_CONFIG_YAML=wordpress_org_plugins:
  - woocommerce
wordpress_archive_plugins:
  - slug: archived
    source: file:///sources/plugin.zip
wordpress_custom_plugins:
  - slug: floating
    source: file:///sources/plugin.git"
	[ "${status}" -eq 0 ]
	[ ! -e "${entrypoint_tmp}/document-root/wp-content/plugins/floating" ]
	[[ "$(entrypoint_wp_calls)" != *"plugin install"* ]]
	[[ "$(entrypoint_wp_calls)" != *"plugin activate"* ]]
}

@test "a wordpress.org plugin is installed at its pinned version" {
	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_org_plugins:
  - slug: woocommerce
    version: 10.3.0"
	[ "${status}" -eq 0 ]
	[[ "$(entrypoint_wp_calls)" == *"plugin install woocommerce --version=10.3.0 --force --activate"* ]]
}

@test "an archive plugin is installed only when its checksum matches" {
	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_archive_plugins:
  - slug: archived
    source: file:///sources/plugin.zip
    sha256: ${archive_sha256}"
	[ "${status}" -eq 0 ]
	[[ "$(entrypoint_wp_calls)" == *"plugin install /tmp/"*"/archived.zip --activate"* ]]
}

@test "an archive plugin with a wrong checksum is not installed" {
	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_archive_plugins:
  - slug: archived
    source: file:///sources/plugin.zip
    sha256: 0000000000000000000000000000000000000000000000000000000000000000"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"checksum"* ]]
	[[ "$(entrypoint_wp_calls)" != *"plugin install"* ]]
}
