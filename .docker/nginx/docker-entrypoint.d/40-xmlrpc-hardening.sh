#!/bin/sh

set -eu

xmlrpc_enabled="$(printf '%s' "${WORDPRESS_XMLRPC_ENABLED:-1}" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

case "$xmlrpc_enabled" in
	1|true|yes|on)
		cat > /tmp/xmlrpc-hardening.conf <<'EOF'
# XML-RPC explicitly enabled for this environment.
EOF
		;;
	0|false|no|off)
		cat > /tmp/xmlrpc-hardening.conf <<'EOF'
location = /xmlrpc.php {
	return 403;
}
EOF
		;;
	*)
		echo "ERROR: WORDPRESS_XMLRPC_ENABLED must be one of 1, true, yes, on, 0, false, no, off; got: $xmlrpc_enabled" >&2
		exit 1
		;;
esac
