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
	git -C "${repository}" -c user.name=test -c user.email=test@example.com tag -a v2.0.0 -m v2.0.0
	annotated_tag_object="$(git -C "${repository}" rev-parse v2.0.0)"
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

@test "a custom plugin pinned to an annotated tag object is checked out at the tagged commit" {
	local config="WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_plugins:
  - slug: annotated
    source: file:///sources/plugin.git
    ref: ${annotated_tag_object}"

	[ "${annotated_tag_object}" != "${second_commit}" ]

	run entrypoint_run "${config}"
	[ "${status}" -eq 0 ]
	[ "$(plugin_head annotated)" = "${second_commit}" ]
	[[ "$(entrypoint_wp_calls)" == *"plugin activate annotated"* ]]

	run entrypoint_run "${config}"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"annotated is already at ${annotated_tag_object}"* ]]
}

@test "an existing checkout moved to an annotated tag pin stays there after gc without its source" {
	local plugin_dir="${entrypoint_tmp}/document-root/wp-content/plugins/existing"
	local config="WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_plugins:
  - slug: existing
    source: file:///sources/plugin.git
    ref: ${annotated_tag_object}"

	git clone -q --no-tags "${entrypoint_tmp}/sources/plugin.git" "${plugin_dir}"
	git -C "${plugin_dir}" checkout -q --detach "${first_commit}"

	run entrypoint_run "${config}"
	[ "${status}" -eq 0 ]
	[ "$(plugin_head existing)" = "${second_commit}" ]

	git -C "${plugin_dir}" -c gc.reflogExpire=now -c gc.reflogExpireUnreachable=now reflog expire --all
	git -C "${plugin_dir}" gc -q --prune=now
	mv "${entrypoint_tmp}/sources/plugin.git" "${entrypoint_tmp}/sources/offline.git"

	: > "${entrypoint_tmp}/log/wp-calls"
	run entrypoint_run "${config}"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"existing is already at ${annotated_tag_object}"* ]]
	[[ "$(entrypoint_wp_calls)" == *"plugin activate existing"* ]]
}

@test "a fresh clone whose pinned SHA is not a commit is removed and not activated" {
	local repository="${entrypoint_tmp}/tree-work"
	git init -q -b main "${repository}"
	printf '%s\n' '<?php' > "${repository}/plugin.php"
	git -C "${repository}" add plugin.php
	git -C "${repository}" -c user.name=test -c user.email=test@example.com commit -q -m tree
	local tree_sha
	tree_sha="$(git -C "${repository}" rev-parse 'HEAD^{tree}')"
	git clone -q --bare "${repository}" "${entrypoint_tmp}/sources/tree.git"

	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_plugins:
  - slug: tree
    source: file:///sources/tree.git
    ref: ${tree_sha}
wordpress_custom_themes:
  - slug: tree-theme
    source: file:///sources/tree.git
    ref: ${tree_sha}"
	[ "${status}" -eq 0 ]
	[ ! -e "${entrypoint_tmp}/document-root/wp-content/plugins/tree" ]
	[ ! -e "${entrypoint_tmp}/document-root/wp-content/themes/tree-theme" ]
	[[ "$(entrypoint_wp_calls)" != *"plugin activate tree"* ]]
}

@test "a custom plugin that references a tag follows the tag and is reported as movable" {
	local config="WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_plugins:
  - slug: tagged
    source: file:///sources/plugin.git
    ref: v1.0.0"

	run entrypoint_run "${config}"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"tagged uses v1.0.0, which can move to another commit"* ]]
	[ "$(plugin_head tagged)" = "${first_commit}" ]

	git -C "${entrypoint_tmp}/sources/plugin.git" tag -f v1.0.0 "${second_commit}" >/dev/null

	run entrypoint_run "${config}"
	[ "${status}" -eq 0 ]
	[ "$(plugin_head tagged)" = "${second_commit}" ]
}

@test "a custom plugin that references a tag is skipped when pins are required" {
	run entrypoint_run WORDPRESS_SETUP_REQUIRE_PINNED=1 "WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_plugins:
  - slug: tagged
    source: file:///sources/plugin.git
    ref: v1.0.0"
	[ "${status}" -eq 0 ]
	[ ! -e "${entrypoint_tmp}/document-root/wp-content/plugins/tagged" ]
	[[ "$(entrypoint_wp_calls)" != *"plugin activate tagged"* ]]
}

@test "a custom plugin pinned to a commit is accepted when pins are required" {
	run entrypoint_run WORDPRESS_SETUP_REQUIRE_PINNED=1 "WORDPRESS_SETUP_CONFIG_YAML=wordpress_custom_plugins:
  - slug: pinned
    source: file:///sources/plugin.git
    ref: ${first_commit}"
	[ "${status}" -eq 0 ]
	[ "$(plugin_head pinned)" = "${first_commit}" ]
	[[ "$(entrypoint_wp_calls)" == *"plugin activate pinned"* ]]
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

@test "an archive plugin is reinstalled when its pinned checksum changes" {
	cat > "${entrypoint_tmp}/bin/wp" <<'WP_STUB'
#!/bin/sh
echo "wp $*" >> /var/log/entrypoint/wp-calls
plugins=/var/www/html/wp-content/plugins
case "$1 $2" in
	"plugin is-installed") [ -d "$plugins/$3" ]; exit ;;
	"plugin install")
		slug="$(basename "$3" .zip)"
		rm -rf "${plugins:?}/$slug"
		mkdir -p "$plugins/$slug"
		cp "$3" "$plugins/$slug/archive"
		exit 0 ;;
	"user list"|"user get") echo 1 ;;
esac
exit 0
WP_STUB
	printf '%s\n' 'updated archive' > "${entrypoint_tmp}/sources/plugin-updated.zip"
	local updated_sha256
	updated_sha256="$(sha256sum "${entrypoint_tmp}/sources/plugin-updated.zip" | cut -d' ' -f1)"
	local installed_archive="${entrypoint_tmp}/document-root/wp-content/plugins/archived/archive"

	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_archive_plugins:
  - slug: archived
    source: file:///sources/plugin.zip
    sha256: ${archive_sha256}"
	[ "${status}" -eq 0 ]
	[ "$(cat "${installed_archive}")" = "archive" ]

	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_archive_plugins:
  - slug: archived
    source: file:///sources/plugin-updated.zip
    sha256: ${updated_sha256}"
	[ "${status}" -eq 0 ]
	[ "$(cat "${installed_archive}")" = "updated archive" ]
	[[ "$(entrypoint_wp_calls)" == *"plugin install /tmp/"*"/archived.zip --force --activate"* ]]

	: > "${entrypoint_tmp}/log/wp-calls"
	run entrypoint_run "WORDPRESS_SETUP_CONFIG_YAML=wordpress_archive_plugins:
  - slug: archived
    source: file:///sources/plugin-updated.zip
    sha256: ${updated_sha256}"
	[ "${status}" -eq 0 ]
	[[ "${output}" == *"archived is already installed"* ]]
	[[ "$(entrypoint_wp_calls)" != *"plugin install"* ]]
}
