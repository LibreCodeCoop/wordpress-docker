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

	prod_url="$(normalize_url "${PROD_SITE_URL}")"
	local_url="$(normalize_url "${LOCAL_SITE_URL:-http://localhost}")"
	prod_host="$(strip_protocol "${prod_url}")"
	local_host="$(strip_protocol "${local_url}")"

	echo "Synchronizing URLs in the database..."
	replace_url_occurrences "${prod_url}" "${local_url}"
	replace_url_occurrences "${prod_url}/" "${local_url}/"
	replace_url_occurrences "${prod_host}" "${local_host}"
}

install_plugin() {
	local plugin_slug="$1"

	if runuser -u www-data -- wp plugin is-installed "$plugin_slug" 2>/dev/null; then
		echo "  ✓ Plugin $plugin_slug is already installed"
	else
		echo "  ↓ Installing $plugin_slug..."
		if runuser -u www-data -- wp plugin install "$plugin_slug" --activate 2>/dev/null; then
			echo "  ✓ Plugin $plugin_slug installed"
		else
			echo "  ✗ Failed to install $plugin_slug"
		fi
	fi
}

install_plugin_archive() {
	local plugin_slug="$1"
	local archive_source="$2"

	if runuser -u www-data -- wp plugin is-installed "$plugin_slug" 2>/dev/null; then
		echo "  ✓ Plugin $plugin_slug is already installed"
	else
		echo "  ↓ Installing $plugin_slug from archive..."
		if runuser -u www-data -- wp plugin install "$archive_source" --activate 2>/dev/null; then
			echo "  ✓ Plugin $plugin_slug installed"
		else
			echo "  ✗ Failed to install $plugin_slug from archive"
		fi
	fi
}

clone_custom_plugin() {
	local plugin_name="$1"
	local git_url="$2"
	local plugin_dir="/var/www/html/wp-content/plugins/$plugin_name"

	if [ -d "$plugin_dir" ]; then
		echo "  ✓ Plugin $plugin_name already exists"
		return 0
	else
		echo "  ↓ Cloning $plugin_name..."
		cd /var/www/html/wp-content/plugins/
		if git clone "$git_url" "$plugin_name" 2>/dev/null; then
			echo "  ✓ Plugin $plugin_name cloned"
			return 0
		else
			echo "  ✗ Failed to clone $plugin_name"
			return 1
		fi
	fi
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

	run_custom_plugin_post_install_commands "$plugin_name" "$entry"
	chown -R www-data:www-data "$plugin_dir"
	runuser -u www-data -- wp plugin activate "$plugin_name" 2>/dev/null || true
}

clone_custom_theme() {
	local theme_name="$1"
	local git_url="$2"
	local theme_dir="/var/www/html/wp-content/themes/$theme_name"

	if [ -d "$theme_dir" ]; then
		echo "  ✓ Theme $theme_name already exists"
	else
		echo "  ↓ Cloning theme $theme_name..."
		cd /var/www/html/wp-content/themes/
		if git clone "$git_url" "$theme_name" 2>/dev/null; then
			chown -R www-data:www-data "$theme_dir"
			echo "  ✓ Theme $theme_name cloned"
		else
			echo "  ✗ Failed to clone $theme_name"
		fi
	fi
}

install_org_plugins_from_config() {
	local plugin_slug

	echo "Plugins from wordpress.org:"

	if ! yaml_sequence_has_items '(.wordpress_org_plugins // [])'; then
		echo "  - No plugins configured"
		return
	fi

	while IFS= read -r plugin_slug; do
		plugin_slug="$(trim_value "$plugin_slug")"
		if [ -z "$plugin_slug" ] || [ "$plugin_slug" = "null" ]; then
			continue
		fi
		install_plugin "$plugin_slug"
	done < <(read_yaml_values '.wordpress_org_plugins[]?')
}

install_archive_plugins_from_config() {
	local entry
	local plugin_slug
	local archive_source

	echo "Plugins from archive:"

	if ! yaml_sequence_has_items '(.wordpress_archive_plugins // [])'; then
		echo "  - No items configured"
		return
	fi

	while IFS= read -r entry; do
		plugin_slug="$(printf '%s' "$entry" | base64 -d | yq -r '.slug')"
		archive_source="$(printf '%s' "$entry" | base64 -d | yq -r '.source')"

		if [ -z "$plugin_slug" ] || [ "$plugin_slug" = "null" ] || [ -z "$archive_source" ] || [ "$archive_source" = "null" ]; then
			echo "  ✗ Invalid configuration in wordpress_archive_plugins"
			continue
		fi

		install_plugin_archive "$plugin_slug" "$archive_source"
	done < <(read_yaml_values '.wordpress_archive_plugins[]? | @base64')
}

install_git_entries() {
	local label="$1"
	local query="$2"
	local entry_type="$3"
	local entry
	local resource_name
	local source_url

	echo "$label:"

	if ! yaml_sequence_has_items "($query // [])"; then
		echo "  - No items configured"
		return
	fi

	while IFS= read -r entry; do
		resource_name="$(printf '%s' "$entry" | base64 -d | yq -r '.slug')"
		source_url="$(printf '%s' "$entry" | base64 -d | yq -r '.source')"

		if [ -z "$resource_name" ] || [ "$resource_name" = "null" ] || [ -z "$source_url" ] || [ "$source_url" = "null" ]; then
			echo "  ✗ Invalid configuration in $label"
			continue
		fi

		if [ "$entry_type" = "plugin" ]; then
			if clone_custom_plugin "$resource_name" "$source_url"; then
				finalize_custom_plugin "$resource_name" "$entry"
			fi
		else
			clone_custom_theme "$resource_name" "$source_url"
		fi
	done < <(read_yaml_values "${query}[]? | @base64")
}

wait_for_db

echo "Installing plugins and themes..."

if wordpress_is_installed; then
	sync_site_urls

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
	echo "After completing the initial setup in the browser, restart the container to run this step."
fi

echo ""
echo "Starting PHP-FPM..."
exec php-fpm