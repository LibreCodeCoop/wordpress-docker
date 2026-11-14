#!/bin/sh

set -eu

web_install_enabled="$(printf '%s' "${WORDPRESS_WEB_INSTALL_ENABLED:-0}" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

case "$web_install_enabled" in
	1|true|yes|on)
		cat > /tmp/web-install.conf <<'EOF'
location = /wp-admin/install.php {
	include /etc/nginx/snippets/php-fpm.conf;
}
location = /wp-admin/setup-config.php {
	include /etc/nginx/snippets/php-fpm.conf;
}
EOF
		;;
	0|false|no|off)
		cat > /tmp/web-install.conf <<'EOF'
location = /wp-admin/install.php {
	return 404;
}
location = /wp-admin/setup-config.php {
	return 404;
}
EOF
		;;
	*)
		echo "ERROR: WORDPRESS_WEB_INSTALL_ENABLED must be one of 1, true, yes, on, 0, false, no, off; got: $web_install_enabled" >&2
		exit 1
		;;
esac
