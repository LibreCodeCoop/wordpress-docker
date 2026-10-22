#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "WordPress and PHP versions remain configurable Docker build arguments" {
  grep -Fxq 'ARG VERSION_WORDPRESS' .docker/wordpress/Dockerfile
  grep -Fxq 'ARG VERSION_PHP' .docker/wordpress/Dockerfile
  grep -Fxq 'FROM wordpress:${VERSION_WORDPRESS}-php${VERSION_PHP}-fpm' .docker/wordpress/Dockerfile
}

@test "both CI image builds forward the selected WordPress and PHP versions" {
  run grep -Fc 'VERSION_WORDPRESS=${{ env.VERSION_WORDPRESS }}' .github/workflows/docker-publish.yml
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]

  run grep -Fc 'VERSION_PHP=${{ env.VERSION_PHP }}' .github/workflows/docker-publish.yml
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
}
