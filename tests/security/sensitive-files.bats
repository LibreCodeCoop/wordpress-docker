#!/usr/bin/env bats

load 'helpers/nginx.bash'

secret='SENSITIVE_CONTENT_SERVED'

setup() {
	nginx_hardening_integration_setup
	for path in \
		wp-config.php.bak \
		wp-config.php.old \
		wp-config.php.orig \
		wp-config.php.save \
		wp-config.php~ \
		.wp-config.php.swp \
		dump.sql \
		wp-content/uploads/dump.sql \
		wp-content/uploads/wordpress.tar.gz \
		wp-content/uploads/site.tgz \
		wp-content/uploads/site.7z \
		wp-content/uploads/site.rar \
		wp-content/debug.log \
		wp-content/uploads/wc-logs/stripe.log \
		wp-content/uploads/wc-logs/stripe.txt \
		wp-content/uploads/woocommerce_uploads/product.pdf \
		wp-content/updraft/backup.txt \
		wp-content/ai1wm-backups/site.wpress \
		wp-content/aiowps_backups/backup.txt \
		wp-content/backups-2025/site.txt \
		wp-content/upgrade/package.txt \
		wp-content/plugins/plugin/plugin.zip \
		backup.zip \
		wp-content/uploads/backup.zip \
		deploy.sh \
		.env \
		.git/config \
		wp-content/uploads/wc-logs/.htaccess \
		wp-content/plugins/plugin/composer.json \
		wp-content/plugins/plugin/composer.lock \
		wp-content/plugins/plugin/package.json \
		wp-content/plugins/plugin/package-lock.json \
		wp-content/plugins/plugin/phpunit.xml \
		wp-content/plugins/plugin/phpunit.xml.dist \
		wp-content/uploads/2024/12/attachment.zip \
		wp-content/uploads/2024/12/photo.png \
		wp-content/plugins/plugin/style.css \
		.well-known/acme-challenge/token; do
		nginx_hardening_document_root_file "${path}" "${secret}"
	done
	nginx_hardening_integration_start
	nginx_hardening_config_is_valid
}

teardown() {
	nginx_hardening_integration_stop
}

assert_denied() {
	local path
	for path in "$@"; do
		run nginx_hardening_request GET "${path}"
		[ "${status}" -eq 0 ]
		if [ "${output}" != "403" ] || grep -q "${secret}" "${nginx_hardening_tmp}/response-body"; then
			echo "Expected ${path} to be denied, got HTTP ${output}" >&2
			return 1
		fi
	done
}

assert_served() {
	local path
	for path in "$@"; do
		run nginx_hardening_request GET "${path}"
		[ "${status}" -eq 0 ]
		if [ "${output}" != "200" ] || ! grep -q "${secret}" "${nginx_hardening_tmp}/response-body"; then
			echo "Expected ${path} to be served, got HTTP ${output}" >&2
			return 1
		fi
	done
}

@test "configuration backups and editor files are denied" {
	assert_denied /wp-config.php.bak /wp-config.php.old /wp-config.php.orig /wp-config.php.save /wp-config.php~ /.wp-config.php.swp
}

@test "database dumps and archives are denied" {
	assert_denied /dump.sql /wp-content/uploads/dump.sql /wp-content/uploads/wordpress.tar.gz /wp-content/uploads/site.tgz /wp-content/uploads/site.7z /wp-content/uploads/site.rar
}

@test "logs are denied even with an htaccess next to them" {
	assert_denied /wp-content/debug.log /wp-content/uploads/wc-logs/stripe.log /wp-content/uploads/wc-logs/stripe.txt /wp-content/uploads/wc-logs/.htaccess
}

@test "backup plugin and WordPress working folders are denied" {
	assert_denied /wp-content/updraft/backup.txt /wp-content/ai1wm-backups/site.wpress /wp-content/aiowps_backups/backup.txt /wp-content/backups-2025/site.txt /wp-content/upgrade/package.txt /wp-content/uploads/woocommerce_uploads/product.pdf
}

@test "zip files outside dated uploads are denied" {
	assert_denied /backup.zip /wp-content/uploads/backup.zip /wp-content/plugins/plugin/plugin.zip
}

@test "shell scripts and dotfiles are denied" {
	assert_denied /deploy.sh /.env /.git/config
}

@test "dependency manifests and test configuration are denied" {
	assert_denied /wp-content/plugins/plugin/composer.json /wp-content/plugins/plugin/composer.lock /wp-content/plugins/plugin/package.json /wp-content/plugins/plugin/package-lock.json /wp-content/plugins/plugin/phpunit.xml /wp-content/plugins/plugin/phpunit.xml.dist
}

@test "media, assets and ACME challenges are still served" {
	assert_served /wp-content/uploads/2024/12/attachment.zip /wp-content/uploads/2024/12/photo.png /wp-content/plugins/plugin/style.css /.well-known/acme-challenge/token
}
