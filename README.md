# Wordpress

This repository provides a Docker setup to run a WordPress stack with plugins and themes.

The main goal is to make local development, onboarding, and environment recovery quick, without manual server setup.

It is useful when you need to:
- Run WordPress with MariaDB and Nginx the same way on any machine.
- Import production-like data and remap URLs for local usage.
- Install plugins and themes automatically, including custom Git repositories.
- Configure local integrations (for example SMTP with mailpit, or other plugin-specific settings) during startup.

Prerequisite: [Docker](https://docs.docker.com/get-docker/) must be installed on your operating system.


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
      # Local-only password override for imported users (do not use in production).
      # Set one shared password and choose one strategy:
      # - reset all local users, or
      # - reset only one specific user login/email/ID.
      WORDPRESS_LOCAL_USERS_PASSWORD: ${WORDPRESS_LOCAL_USERS_PASSWORD:-admin}
      WORDPRESS_LOCAL_RESET_ALL_USERS_PASSWORDS: ${WORDPRESS_LOCAL_RESET_ALL_USERS_PASSWORDS:-1}
      WORDPRESS_LOCAL_RESET_PASSWORD_FOR_USER: ${WORDPRESS_LOCAL_RESET_PASSWORD_FOR_USER:-}
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
        # Commands run as www-data from the WordPress root (/var/www/html).
        # The env var PLUGIN_DIR is set to the absolute plugin directory path.
        wordpress_custom_plugins:
          - slug: my-plugin
            source: https://github.com/org/my-plugin.git
          - slug: my-plugin-with-fixup
            source: https://github.com/org/my-plugin-with-fixup.git
            post_install_commands:
              - ln -sfn real-dir "$$PLUGIN_DIR/expected-dir"
              - wp option update my_plugin_option value

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
```

On each startup (when WordPress is already installed), the entrypoint can automatically reset local user passwords:
- `WORDPRESS_LOCAL_RESET_ALL_USERS_PASSWORDS=1`: reset all users to `WORDPRESS_LOCAL_USERS_PASSWORD`.
- `WORDPRESS_LOCAL_RESET_PASSWORD_FOR_USER=<login|email|id>`: reset only one user.

Use only one strategy at a time. For local environments importing production data, resetting all users is usually the simplest approach.

### Database dump

If you need to bootstrap the environment with existing data, place your SQL dump in the folder below:

`volumes/mariadb/dump/`

How it works:
- Files in this folder are mounted at `/docker-entrypoint-initdb.d` inside MariaDB.
- They are imported automatically only when the MariaDB data directory is empty (first initialization).

If your database is already initialized and you want to import a dump manually:

```bash
docker compose exec -T mariadb sh -lc 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' < volumes/mariadb/dump/your-dump.sql
```

If you want to force automatic re-import from `/docker-entrypoint-initdb.d`, remove the existing database files in `volumes/mariadb/data` and start the stack again.

### Local e-mail (mailpit)

When you add the `mailpit` service to your override, all outgoing WordPress e-mails are captured and visible at <http://localhost:8025>.

To route WordPress mail through mailpit, install the [wp-simple-smtp](https://github.com/LibreCodeCoop/wp-simple-smtp) plugin and add the following `post_install_commands` to its entry:

```yaml
- slug: wp-simple-smtp
  source: https://github.com/LibreCodeCoop/wp-simple-smtp.git
  post_install_commands:
    - wp option update smtp_host mailpit
    - wp option update smtp_port 1025
    - wp option update smtp_auth 0
    - wp option update smtp_secure ''
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
