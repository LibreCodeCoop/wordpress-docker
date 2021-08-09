# Atualização do WordPress

## Etapas no PHP56

* Fazer um dump do banco de produção
  ```
  mysqldump --single-transaction -u root -p --databases php5 > amperj-novo.sql
  ```
* Restaurar o dump em um novo banco
* Atualizar o arquivo `.php56.env` com os dados do banco novo
* Realizar substituições no banco de dados
  ```bash
  docker-compose exec -u www-data php56 wp search-replace http://<DOMINIO_ATUAL> https://<DOMINIO_NOVO> --all-tables
  docker-compose exec -u www-data php56 wp search-replace <DOMINIO_ATUAL> <DOMINIO_NOVO> --all-tables
  docker-compose exec -u www-data php56 wp search-replace <EMAIL_ADMIN_ATUAL> <EMAIL_ADMIN_NOVO> --all-tables
  ```
* Atualizar a environment `DOMAIN_CURRENT_SITE` para conter `<DOMINIO_NOVO>`
* Criar superadmin
  ```bash
  wp user create <username> <email> --role=administrator --display_name=<displayname> --user_pass=<password>
  wp super-admin add <username>
  ```
* Desativar todos os plugins
  ```bash
  docker-compose exec -u www-data php56 wp plugin deactivate --all --network
  ```
* Fazer backup de banco
  ```
  mysqldump --single-transaction -u root -p --databases php5 > amperj-novo.sql
  ```

## Etapas no PHP8
* Copiar arquivos do PHP56
  ```bash
  cp -r volumes/site/www/wp-content/ volumes/wordpress/
  cp volumes/site/www/wp-config.php volumes/wordpress/
  cp volumes/site/www/.htaccess volumes/wordpress/
  ```
* Corrigir permissões:
  ```bash
  chown -R www-data:www-data volumes/wordpress/
  ```
* Restaurar backup do banco PHP56 para o banco do PHP56
* Levantar container
* acessar /wp-admin
* atualizar banco de dados
  `/wp-admin/upgrade.php`
* Atualizar plugins e temas
  ```bash
  docker-compose exec -u www-data wordpress wp plugin update --all
  docker-compose exec -u www-data wordpress wp theme update --all
  ```
* Instalar plugin para aceitar apenas cpf como username:
  ```bash
  git clone https://github.com/LibreCodeCoop/wp-cpf-as-username volumes/wordpress/wp-content/plugins/wp-cpf-as-username
  ```
* Ativar plugins
  ```bash
  docker-compose exec -u www-data wordpress wp plugin activate wp-cpf-as-username
  ```
* Corrigir permissões:
  ```bash
  chown -R www-data:www-data volumes/wordpress/
  ```
* fazer login com um super admin
* Ativar plugins
  ```bash
  docker-compose exec -u www-data wordpress wp plugin activate 3d-flipbook-dflip-lite advanced-custom-fields-google-map-extended acf-to-rest-api admin-menu-editor advanced-custom-fields amperj-plugin/amperj amperj-slider better-rest-api-featured-images classic-editor cookie-notice custom-post-type-ui export-import-menus json-api json-api-auth json-api-user ml-slider og-tags photo-gallery popup-builder really-simple-ssl google-captcha regenerate-thumbnails shortcodes-ultimate show-current-template theme-my-login toggle-wpautop widget-importer-exporter wp-mail-bank wp-user-avatar --network
  # docker-compose exec -u www-data wordpress wp plugin activate wordpress-importer
  ```
* Aplicar atualizações
  http://<URL>/wp-admin/network/update-core.php
* O plugin `theme-my-login` na versão mais nova não está compatível com o site.
  * Downgrade de versão de plugin:
    * Remover a versão mais nova do plugin `theme-my-login`
      ```bash
      rm -rf volumes/wordpress/wp-content/plugins/theme-my-login/
      ```
    * Copiar a versão antiga:
      ```bash
      cp -r volumes/site/www/wp-content/plugins/theme-my-login/ volumes/wordpress/wp-content/plugins/theme-my-login/
      ```