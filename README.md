# Wordpress

[It will be necessary to have the docker installed in its operating system to execute this project.](https://docs.docker.com/get-docker/)


## Setup

### Production

After clone:

```bash
docker compose up -d
```

### Development

Create a local file named `docker-compose.override.yml` in the project root with this content:

```yaml
services:
  wordpress:
    environment:
      XDEBUG_MODE: ${XDEBUG_MODE:-debug}
      # Production base URL used for automatic search-replace in the database.
      # Set this only when importing a production dump and needing URL remap.
      PROD_SITE_URL: ${PROD_SITE_URL:-}
      # Local URL that replaces PROD_SITE_URL during startup synchronization.
      # Keep as localhost for local development, or change if you use another host.
      LOCAL_SITE_URL: ${LOCAL_SITE_URL:-http://localhost}
      # Inline YAML config for automatic plugin/theme installation.
      # Use wordpress_org_plugins, wordpress_archive_plugins, wordpress_custom_plugins, and wordpress_custom_themes.
      WORDPRESS_SETUP_CONFIG_YAML: |
        wordpress_org_plugins:
          - advanced-custom-fields
        wordpress_custom_plugins:
          - slug: my-plugin
            source: https://github.com/org/my-plugin.git
        wordpress_custom_themes:
          - slug: my-theme
            source: https://github.com/org/my-theme.git

  nginx:
    ports:
      - 127.0.0.1:80:80

  mariadb:
    extends:
      file: common-services.yml
      service: mariadb

  mailpit:
    image: axllent/mailpit
    ports:
      - 127.0.0.1:${MAILPIT_PORT:-8025}:8025
```

After that, start the stack with the standard Compose command:

```bash
docker compose up -d --build
docker compose exec --user www-data wordpress wp user reset-password <username> --show-password --skip-email
```

## Checking if have files changed at core

You need to put the `.git` folder of current version of WordPress at root directory of current site and run `git status`

```bash
git clone --progress -b <tag-version> --single-branch --depth 1 https://github.com/WordPress/WordPress.git
mv WordPress/.git volumes/wordpress
rm -rf WordPress
cd volumes/wordpress
git status
```
