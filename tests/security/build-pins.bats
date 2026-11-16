#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/../.."
}

@test "the WordPress image does not download floating artifacts" {
	run grep -nE 'releases/latest|gh-pages|^ADD ' .docker/wordpress/Dockerfile
	[ "${status}" -eq 1 ]
}

@test "images copied into the WordPress image are pinned by digest" {
	run grep -nE '^COPY --from=' .docker/wordpress/Dockerfile
	[ "${status}" -eq 0 ]
	run grep -nvE '^COPY --from=[^ ]+:[^ @]+@sha256:[a-f0-9]{64} ' <(grep -E '^COPY --from=' .docker/wordpress/Dockerfile)
	[ "${status}" -eq 1 ]
}

@test "WP-CLI is downloaded from a release and verified" {
	grep -qE 'curl -fsSL https://github.com/wp-cli/wp-cli/releases/download/v[0-9.]+/wp-cli-[0-9.]+\.phar' .docker/wordpress/Dockerfile
	grep -qE 'sha512sum -c' .docker/wordpress/Dockerfile
}

@test "nginx and MariaDB images are pinned" {
	grep -qE '^    image: nginx:[0-9.]+@sha256:[a-f0-9]{64}$' common-services.yml
	grep -qE '^FROM mariadb:[0-9.]+@sha256:[a-f0-9]{64}$' .docker/mariadb/Dockerfile
}

@test "workflow actions are pinned by commit" {
	run grep -hnE '^\s*-?\s*uses: ' .github/workflows/*.yml
	[ "${status}" -eq 0 ]
	run grep -hE '^\s*-?\s*uses: ' .github/workflows/*.yml
	! printf '%s\n' "${output}" | grep -vE 'uses: [^@]+@[a-f0-9]{40} # v?[0-9]+\.[0-9]+\.[0-9]+$'
}
