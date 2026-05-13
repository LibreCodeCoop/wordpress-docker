# Wordpress

[It will be necessary to have the docker installed in its operating system to execute this project.](https://docs.docker.com/get-docker/)


## Setup

### Production

After clone:

```bash
docker compose build
docker compose up -d
```

### Development

Create a local file named `docker-compose.override.yml` in the project root with this content:

```yaml
services:
  wordpress:
    environment:
      - XDEBUG_MODE=${XDEBUG_MODE:-debug}

  nginx:
    ports:
      - 80:80

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
docker compose exec --user www-data wordpress wp search-replace --all-tables --report-changed-only <domain-without-protocol> localhost
docker compose exec --user www-data wordpress wp search-replace --all-tables --report-changed-only https://localhost http://localhost
docker compose exec --user www-data wordpress wp user reset-password <username> --show-password --skip-email
```

## Update

```bash
docker compose exec --user www-data wordpress wp core update
docker compose exec --user www-data wordpress wp core update-db
docker compose exec --user www-data wordpress wp plugin update --all
docker compose exec --user www-data wordpress wp language core update
docker compose exec --user www-data wordpress wp language plugin update --all
docker compose exec --user www-data wordpress wp theme update --all
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
