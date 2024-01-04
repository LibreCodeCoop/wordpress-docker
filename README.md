# Execução

[Será necessário que possua o Docker instalado em seu sistema operacional para executar esse projeto.](https://docs.docker.com/get-docker/)

Após a instalação:

`docker compose build`

`docker network create reverse-proxy`

`docker network create mariadb`

`docker compose up -d`

# Atualização Wordpress

WordPress rodando em container com documentação de como atualizar de uma versão antiga para uma versão mais nova.

Documentação não é generalista mas pode ser adaptada de acordo com cada necessidade.

* [Ambiente de desenvolvimento](docs/ambiente-dev-local.md)
* [Atualização de versão de WordPress e plugins](docs/atualizacao.md)
