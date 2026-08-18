#!/bin/sh

set -eu

case "${WORDPRESS_XMLRPC_ENABLED:-0}" in
	1|true|yes|on)
		cat > /tmp/xmlrpc-hardening.conf <<'EOF'
# XML-RPC explicitly enabled for this environment.
EOF
		;;
	*)
		cat > /tmp/xmlrpc-hardening.conf <<'EOF'
location = /xmlrpc.php {
	return 403;
}
EOF
		;;
esac