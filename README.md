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
        # Plugins installed directly from the WordPress.org repository.
        wordpress_org_plugins:
          - advanced-custom-fields
          - woocommerce

        # Plugins installed from a .zip URL (e.g. GitHub Releases or S3).
        wordpress_archive_plugins:
          - slug: my-premium-plugin
            source: https://example.com/releases/my-premium-plugin-1.0.0.zip

        # Plugins cloned from a Git repository.
        # Optional: post_install_commands — list of shell commands run after cloning
        # (and on every container start if the plugin directory already exists).
        # Commands run from the WordPress root (/var/www/html) with --allow-root.
        # The env var PLUGIN_DIR is set to the absolute plugin directory path.
        wordpress_custom_plugins:
          - slug: my-plugin
            source: https://github.com/org/my-plugin.git
          - slug: my-plugin-with-fixup
            source: https://github.com/org/my-plugin-with-fixup.git
            post_install_commands:
              - ln -sfn real-dir "$PLUGIN_DIR/expected-dir"
              - wp --allow-root option update my_plugin_option value

        # Themes cloned from a Git repository.
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

### Local e-mail (mailpit)

When you add the `mailpit` service to your override, all outgoing WordPress e-mails are captured and visible at <http://localhost:8025>.

To route WordPress mail through mailpit, install the [wp-simple-smtp](https://github.com/LibreCodeCoop/wp-simple-smtp) plugin and add the following `post_install_commands` to its entry:

```yaml
- slug: wp-simple-smtp
  source: https://github.com/LibreCodeCoop/wp-simple-smtp.git
  post_install_commands:
    - wp --allow-root option update smtp_host mailpit
    - wp --allow-root option update smtp_port 1025
    - wp --allow-root option update smtp_auth 0
    - wp --allow-root option update smtp_secure ''
```

mailpit's SMTP port inside the Docker network is **1025**; the web UI is exposed on host port **8025**.

## Checking if have files changed at core

You need to put the `.git` folder of current version of WordPress at root directory of current site and run `git status`

```bash
git clone --progress -b <tag-version> --single-branch --depth 1 https://github.com/WordPress/WordPress.git
mv WordPress/.git volumes/wordpress
rm -rf WordPress
cd volumes/wordpress
git status
```
