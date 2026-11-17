#!/bin/bash

set -e

echo "Configuring WordPress..."

# Set uid of host machine
usermod --non-unique --uid "${HOST_UID}" www-data
groupmod --non-unique --gid "${HOST_GID}" www-data

if [ ! -f "/var/www/html/wp-load.php" ]; then
	echo "Copying WordPress..."
	rsync -r /usr/src/wordpress/ /var/www/html/
fi

chown -R www-data:www-data /var/www/html

if [ ! -f "/var/www/html/wp-config.php" ]; then
	echo "wp-config.php not found. Generating configuration..."
	runuser -u www-data -- wp config create \
		--path=/var/www/html \
		--dbname="${WORDPRESS_DB_NAME}" \
		--dbuser="${WORDPRESS_DB_USER}" \
		--dbpass="${WORDPRESS_DB_PASSWORD}" \
		--dbhost="${WORDPRESS_DB_HOST}" \
		--dbprefix="${WORDPRESS_TABLE_PREFIX}" \
		--skip-check \
		--force
	chown www-data:www-data /var/www/html/wp-config.php
fi

wordpress_is_installed() {
	runuser -u www-data -- wp core is-installed 2>/dev/null
}

trim_value() {
	echo "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

is_truthy() {
	case "$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')" in
		1|true|yes|on)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

is_local_environment() {
	case "${WP_ENVIRONMENT_TYPE:-}" in
		local|development)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

plugins_config_exists() {
	[ -n "$(trim_value "${WORDPRESS_SETUP_CONFIG_YAML:-}")" ]
}

read_yaml_from_config() {
	local query="$1"
	printf '%s\n' "${WORDPRESS_SETUP_CONFIG_YAML}" | yq -r "$query" -
}

yaml_sequence_has_items() {
	local query="$1"

	if ! plugins_config_exists; then
		return 1
	fi

	printf '%s\n' "${WORDPRESS_SETUP_CONFIG_YAML}" | yq -e "$query | length > 0" - >/dev/null 2>&1
}

read_yaml_values() {
	local query="$1"
	read_yaml_from_config "$query"
}

wait_for_db() {
	local host="${WORDPRESS_DB_HOST:-mariadb}"
	local port=3306
	local retries=30
	local wait=2

	echo "Waiting for database at ${host}:${port}..."
	for i in $(seq 1 "$retries"); do
		if bash -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; then
			echo "Database is available."
			return 0
		fi
		echo "  Attempt ${i}/${retries}, waiting ${wait}s..."
		sleep "$wait"
	done
	echo "  ✗ Database did not respond after $((retries * wait))s. Aborting."
	exit 1
}

normalize_url() {
	local input="$1"
	echo "${input}" | sed -E 's#/*$##'
}

strip_protocol() {
	local input="$1"
	input="${input#http://}"
	input="${input#https://}"
	echo "${input}"
}

replace_url_occurrences() {
	local old_value="$1"
	local new_value="$2"

	if [ -z "${old_value}" ] || [ -z "${new_value}" ] || [ "${old_value}" = "${new_value}" ]; then
		return
	fi

	if ! runuser -u www-data -- wp search-replace "${old_value}" "${new_value}" --all-tables --report-changed-only; then
		echo "  ⚠ Failed to replace '${old_value}' with '${new_value}'"
	fi
}

sync_site_urls() {
	local prod_url
	local local_url
	local prod_host
	local local_host

	if [ -z "${PROD_SITE_URL}" ]; then
		echo "PROD_SITE_URL not set; skipping automatic URL synchronization."
		return
	fi

	if ! is_local_environment; then
		echo "ERROR: PROD_SITE_URL is set but WP_ENVIRONMENT_TYPE is not local or development; skipping URL synchronization." >&2
		return
	fi

	prod_url="$(normalize_url "${PROD_SITE_URL}")"
	local_url="$(normalize_url "${LOCAL_SITE_URL:-http://localhost}")"
	prod_host="$(strip_protocol "${prod_url}")"
	local_host="$(strip_protocol "${local_url}")"

	echo "Synchronizing URLs in the database..."
	replace_url_occurrences "${prod_url}" "${local_url}"
	replace_url_occurrences "${prod_url}/" "${local_url}/"
	replace_url_occurrences "${prod_host}" "${local_host}"
}

reset_local_user_passwords() {
	local reset_all_users="${WORDPRESS_LOCAL_RESET_ALL_USERS_PASSWORDS:-0}"
	local target_user
	local shared_password="${WORDPRESS_LOCAL_USERS_PASSWORD:-}"
	local user_id

	target_user="$(trim_value "${WORDPRESS_LOCAL_RESET_PASSWORD_FOR_USER:-}")"

	if [ -z "$shared_password" ]; then
		echo "WORDPRESS_LOCAL_USERS_PASSWORD not set; skipping local user password reset."
		return
	fi

	if ! is_local_environment; then
		echo "ERROR: WORDPRESS_LOCAL_USERS_PASSWORD is set but WP_ENVIRONMENT_TYPE is not local or development; skipping password reset." >&2
		return
	fi

	if is_truthy "$reset_all_users"; then
		echo "Resetting password for all local WordPress users..."
		while IFS= read -r user_id; do
			user_id="$(trim_value "$user_id")"
			if [ -z "$user_id" ]; then
				continue
			fi
			runuser -u www-data -- wp user update "$user_id" --user_pass="$shared_password" >/dev/null
		done < <(runuser -u www-data -- wp user list --field=ID)
		echo "  ✓ Password reset completed for all users"
		return
	fi

	if [ -n "$target_user" ]; then
		echo "Resetting password for local WordPress user '$target_user'..."
		if runuser -u www-data -- wp user get "$target_user" --field=ID >/dev/null 2>&1; then
			runuser -u www-data -- wp user update "$target_user" --user_pass="$shared_password" >/dev/null
			echo "  ✓ Password reset completed for user '$target_user'"
		else
			echo "  ⚠ User '$target_user' not found; skipping password reset"
		fi
		return
	fi

	echo "No local password reset target configured; set WORDPRESS_LOCAL_RESET_ALL_USERS_PASSWORDS=1 or WORDPRESS_LOCAL_RESET_PASSWORD_FOR_USER."
}

allow_unpinned_entry() {
	local resource_label="$1"

	if is_truthy "${WORDPRESS_SETUP_REQUIRE_PINNED:-0}"; then
		echo "  ✗ $resource_label has no pin and WORDPRESS_SETUP_REQUIRE_PINNED is enabled; skipping"
		return 1
	fi

	echo "  ⚠ $resource_label has no pin; using the latest version"
	return 0
}

install_plugin() {
	local plugin_slug="$1"
	local plugin_version="$2"
	local installed_version
	local -a version_args=()

	if [ -z "$plugin_version" ]; then
		allow_unpinned_entry "Plugin $plugin_slug" || return 0
	else
		version_args=(--version="$plugin_version" --force)
	fi

	if runuser -u www-data -- wp plugin is-installed "$plugin_slug" 2>/dev/null; then
		installed_version="$(runuser -u www-data -- wp plugin get "$plugin_slug" --field=version 2>/dev/null)"
		if [ -z "$plugin_version" ] || [ "$installed_version" = "$plugin_version" ]; then
			echo "  ✓ Plugin $plugin_slug is already installed"
			return 0
		fi
		echo "  ↻ Updating $plugin_slug to $plugin_version..."
	else
		echo "  ↓ Installing $plugin_slug..."
	fi

	if runuser -u www-data -- wp plugin install "$plugin_slug" "${version_args[@]}" --activate 2>/dev/null; then
		echo "  ✓ Plugin $plugin_slug installed"
	else
		echo "  ✗ Failed to install $plugin_slug"
	fi
}

install_plugin_archive() {
	local plugin_slug="$1"
	local archive_source="$2"
	local archive_sha256="$3"
	local download_dir
	local archive_file
	local checksum_file="/var/www/html/wp-content/plugins/$plugin_slug/.archive-sha256"
	local -a force_args=()

	if [ -z "$archive_sha256" ]; then
		allow_unpinned_entry "Plugin $plugin_slug" || return 0
	fi

	if runuser -u www-data -- wp plugin is-installed "$plugin_slug" 2>/dev/null; then
		if [ -z "$archive_sha256" ] || [ "$(cat "$checksum_file" 2>/dev/null)" = "$archive_sha256" ]; then
			echo "  ✓ Plugin $plugin_slug is already installed"
			return 0
		fi
		echo "  ↻ Reinstalling $plugin_slug from the archive with sha256 $archive_sha256..."
		force_args=(--force)
	else
		echo "  ↓ Installing $plugin_slug from archive..."
	fi

	if [ -n "$archive_sha256" ]; then
		download_dir="$(mktemp -d)"
		archive_file="$download_dir/$plugin_slug.zip"
		if ! curl -fsSL "$archive_source" -o "$archive_file"; then
			echo "  ✗ Failed to download $plugin_slug"
			rm -rf "$download_dir"
			return 0
		fi
		if ! printf '%s  %s\n' "$archive_sha256" "$archive_file" | sha256sum -c --status; then
			echo "  ✗ The archive of $plugin_slug does not match its sha256 checksum; skipping"
			rm -rf "$download_dir"
			return 0
		fi
		chown -R www-data:www-data "$download_dir"
		archive_source="$archive_file"
	fi

	if runuser -u www-data -- wp plugin install "$archive_source" "${force_args[@]}" --activate 2>/dev/null; then
		if [ -n "$archive_sha256" ] && [ -d "$(dirname "$checksum_file")" ]; then
			printf '%s\n' "$archive_sha256" | runuser -u www-data -- tee "$checksum_file" >/dev/null
		fi
		echo "  ✓ Plugin $plugin_slug installed"
	else
		echo "  ✗ Failed to install $plugin_slug from archive"
	fi

	if [ -n "$download_dir" ]; then
		rm -rf "$download_dir"
	fi
}

checkout_git_ref() {
	local target_dir="$1"
	local git_url="$2"
	local git_ref="$3"
	local head_commit

	runuser -u www-data -- git -C "$target_dir" fetch --quiet "$git_url" "$git_ref" || return 1
	runuser -u www-data -- git -C "$target_dir" checkout --quiet --detach FETCH_HEAD || return 1

	if [[ "$git_ref" =~ ^[0-9a-f]{40}$ ]]; then
		head_commit="$(runuser -u www-data -- git -C "$target_dir" rev-parse HEAD)"
		if [ "$head_commit" != "$git_ref" ]; then
			echo "  ✗ $target_dir is at $head_commit instead of $git_ref"
			return 1
		fi
	fi
}

sync_git_checkout() {
	local resource_label="$1"
	local target_dir="$2"
	local git_url="$3"
	local git_ref="$4"

	if [ -z "$git_ref" ]; then
		allow_unpinned_entry "$resource_label" || return 1
	fi

	if [ -d "$target_dir" ]; then
		if [ -z "$git_ref" ]; then
			echo "  ✓ $resource_label already exists"
			return 0
		fi
		if [ "$(runuser -u www-data -- git -C "$target_dir" rev-parse HEAD 2>/dev/null)" = "$git_ref" ]; then
			echo "  ✓ $resource_label is already at $git_ref"
			return 0
		fi
		echo "  ↻ Updating $resource_label to $git_ref..."
	else
		echo "  ↓ Cloning $resource_label..."
		if ! runuser -u www-data -- git clone --quiet "$git_url" "$target_dir"; then
			echo "  ✗ Failed to clone $resource_label"
			return 1
		fi
		if [ -z "$git_ref" ]; then
			echo "  ✓ $resource_label cloned"
			return 0
		fi
	fi

	if ! checkout_git_ref "$target_dir" "$git_url" "$git_ref"; then
		echo "  ✗ Failed to check out $git_ref for $resource_label"
		return 1
	fi
	echo "  ✓ $resource_label is at $git_ref"
}

clone_custom_plugin() {
	local plugin_name="$1"
	local git_url="$2"
	local git_ref="$3"

	sync_git_checkout "Plugin $plugin_name" "/var/www/html/wp-content/plugins/$plugin_name" "$git_url" "$git_ref"
}

run_custom_plugin_post_install_commands() {
	local plugin_name="$1"
	local entry="$2"
	local plugin_dir="/var/www/html/wp-content/plugins/$plugin_name"
	local command

	if ! printf '%s' "$entry" | base64 -d | yq -e '.post_install_commands? | length > 0' - >/dev/null 2>&1; then
		return 0
	fi

	while IFS= read -r command; do
		command="$(trim_value "$command")"
		if [ -z "$command" ] || [ "$command" = "null" ]; then
			continue
		fi

		runuser -u www-data -- bash -lc "cd /var/www/html && export PLUGIN_DIR='$plugin_dir'; $command"
	done < <(printf '%s' "$entry" | base64 -d | yq -r '.post_install_commands[]?')
}

finalize_custom_plugin() {
	local plugin_name="$1"
	local entry="$2"
	local plugin_dir="/var/www/html/wp-content/plugins/$plugin_name"

	chown -R www-data:www-data "$plugin_dir"
	run_custom_plugin_post_install_commands "$plugin_name" "$entry"
	runuser -u www-data -- wp plugin activate "$plugin_name" 2>/dev/null || true
}

clone_custom_theme() {
	local theme_name="$1"
	local git_url="$2"
	local git_ref="$3"

	sync_git_checkout "Theme $theme_name" "/var/www/html/wp-content/themes/$theme_name" "$git_url" "$git_ref" || true
}

install_org_plugins_from_config() {
	local entry
	local plugin_slug
	local plugin_version

	echo "Plugins from wordpress.org:"

	if ! yaml_sequence_has_items '(.wordpress_org_plugins // [])'; then
		echo "  - No plugins configured"
		return
	fi

	while IFS= read -r entry; do
		plugin_slug="$(trim_value "$(printf '%s' "$entry" | base64 -d | yq -r 'if type == "object" then .slug else . end')")"
		plugin_version="$(printf '%s' "$entry" | base64 -d | yq -r 'if type == "object" then (.version // "" | tostring) else "" end')"
		if [ -z "$plugin_slug" ] || [ "$plugin_slug" = "null" ]; then
			continue
		fi
		install_plugin "$plugin_slug" "$plugin_version"
	done < <(read_yaml_values '.wordpress_org_plugins[]? | @base64')
}

install_archive_plugins_from_config() {
	local entry
	local plugin_slug
	local archive_source
	local archive_sha256

	echo "Plugins from archive:"

	if ! yaml_sequence_has_items '(.wordpress_archive_plugins // [])'; then
		echo "  - No items configured"
		return
	fi

	while IFS= read -r entry; do
		plugin_slug="$(printf '%s' "$entry" | base64 -d | yq -r '.slug')"
		archive_source="$(printf '%s' "$entry" | base64 -d | yq -r '.source')"
		archive_sha256="$(printf '%s' "$entry" | base64 -d | yq -r '.sha256 // ""')"

		if [ -z "$plugin_slug" ] || [ "$plugin_slug" = "null" ] || [ -z "$archive_source" ] || [ "$archive_source" = "null" ]; then
			echo "  ✗ Invalid configuration in wordpress_archive_plugins"
			continue
		fi

		install_plugin_archive "$plugin_slug" "$archive_source" "$archive_sha256"
	done < <(read_yaml_values '.wordpress_archive_plugins[]? | @base64')
}

install_git_entries() {
	local label="$1"
	local query="$2"
	local entry_type="$3"
	local entry
	local resource_name
	local source_url
	local git_ref

	echo "$label:"

	if ! yaml_sequence_has_items "($query // [])"; then
		echo "  - No items configured"
		return
	fi

	while IFS= read -r entry; do
		resource_name="$(printf '%s' "$entry" | base64 -d | yq -r '.slug')"
		source_url="$(printf '%s' "$entry" | base64 -d | yq -r '.source')"
		git_ref="$(printf '%s' "$entry" | base64 -d | yq -r '.ref // "" | tostring')"

		if [ -z "$resource_name" ] || [ "$resource_name" = "null" ] || [ -z "$source_url" ] || [ "$source_url" = "null" ]; then
			echo "  ✗ Invalid configuration in $label"
			continue
		fi

		if [ "$entry_type" = "plugin" ]; then
			if clone_custom_plugin "$resource_name" "$source_url" "$git_ref"; then
				finalize_custom_plugin "$resource_name" "$entry"
			fi
		else
			clone_custom_theme "$resource_name" "$source_url" "$git_ref"
		fi
	done < <(read_yaml_values "${query}[]? | @base64")
}

install_wordpress_core() {
	if wordpress_is_installed; then
		return
	fi

	if [ -z "${WORDPRESS_SITE_URL:-}" ] || [ -z "${WORDPRESS_ADMIN_USER:-}" ] || [ -z "${WORDPRESS_ADMIN_PASSWORD:-}" ] || [ -z "${WORDPRESS_ADMIN_EMAIL:-}" ]; then
		return
	fi

	echo "Installing WordPress core..."
	runuser -u www-data -- wp core install \
		--url="${WORDPRESS_SITE_URL}" \
		--title="${WORDPRESS_SITE_TITLE:-WordPress}" \
		--admin_user="${WORDPRESS_ADMIN_USER}" \
		--admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
		--admin_email="${WORDPRESS_ADMIN_EMAIL}" \
		--skip-email
}

wait_for_db
install_wordpress_core

echo "Installing plugins and themes..."

if wordpress_is_installed; then
	sync_site_urls
	reset_local_user_passwords

	if plugins_config_exists; then
		install_org_plugins_from_config
		install_archive_plugins_from_config
		install_git_entries "Custom plugins" '.wordpress_custom_plugins' "plugin"
		install_git_entries "Custom themes" '.wordpress_custom_themes' "theme"
		echo "✓ Installation completed!"
	else
		echo "WORDPRESS_SETUP_CONFIG_YAML is not set; skipping automatic installation."
	fi
else
	echo "WordPress is not installed yet; skipping automatic plugin and theme installation."
	echo "Set WORDPRESS_SITE_URL, WORDPRESS_ADMIN_USER, WORDPRESS_ADMIN_PASSWORD and WORDPRESS_ADMIN_EMAIL to install it on startup, or enable WORDPRESS_WEB_INSTALL_ENABLED on nginx to use the browser installer."
fi

echo ""
echo "Starting PHP-FPM..."
exec php-fpm