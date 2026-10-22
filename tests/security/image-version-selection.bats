#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "WordPress and PHP versions remain selectable" {
  grep -Fxq 'ARG VERSION_WORDPRESS' .docker/wordpress/Dockerfile
  grep -Fxq 'ARG VERSION_PHP' .docker/wordpress/Dockerfile
  grep -Fxq 'ARG WORDPRESS_BASE_IMAGE=wordpress:${VERSION_WORDPRESS}-php${VERSION_PHP}-fpm' .docker/wordpress/Dockerfile
  grep -Fxq 'FROM ${WORDPRESS_BASE_IMAGE}' .docker/wordpress/Dockerfile
}

@test "CI defaults to Renovate-managed image and allows an override" {
  run grep -Fc 'WORDPRESS_BASE_IMAGE=${{ inputs.wordpress_base_image || env.WORDPRESS_BASE_IMAGE }}' .github/workflows/docker-publish.yml
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]

  run grep -Ec 'WORDPRESS_BASE_IMAGE: wordpress:[0-9]+\.[0-9]+\.[0-9]+-php[0-9]+\.[0-9]+-fpm@sha256:[a-f0-9]{64}' .github/workflows/docker-publish.yml
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}
