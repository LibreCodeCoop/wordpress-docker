# Wordpress

[It will be necessary to have the docker installed in its operating system to execute this project.](https://docs.docker.com/get-docker/)


## Setup

### Production

After clone:

```bash
docker compose build
docker network create reverse-proxy
docker network create mariadb
docker compose up -d
```

### Development

```bash
wp search-replace --all-tables --report-changed-only <domain-without-protocol> localhost
wp search-replace --all-tables --report-changed-only https://localhost http://localhost
wp user reset-password <username> --show-password --skip-email
```

## Update

```bash
docker compose exec --user www-data wordpress wp core update
docker compose exec --user www-data wordpress wp core update-db
docker compose exec --user www-data wordpress wp plugin update --all
docker compose exec --user www-data wordpress wp language core update
docker compose exec --user www-data wordpress wp language plugin update --all
```

* [Ambiente de desenvolvimento](docs/ambiente-dev-local.md)
* [Atualização de versão de WordPress e plugins](docs/atualizacao.md)

## Checking if have files changed at core

You need to put the `.git` folder of current version of WordPress at root directory of current site and run `git status`

```bash
git clone --progress -b <tag-version> --single-branch --depth 1 https://github.com/WordPress/WordPress.git
mv WordPress/.git volumes/wordpress
rm -rf WordPress
cd volumes/wordpress
git status
```