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
  docker-compose exec -u www-data php56 wp plugin deactivate --all
  ```
* Fazer backup de banco
  ```
  mysqldump --single-transaction -u root -p --databases php5 > amperj-novo.sql
  ```

## Etapas no PHP8
* Copiar arquivos do PHP56
  ```bash
  cp -r volumes/site/www/.git volumes/wordpress/
  cp -r volumes/site/www/wp-content/ volumes/wordpress/
  cd volumes/wordpress
  git checkout -- .
  cd -
  ```
* Corrigir permissões:
  ```bash
  chown -R www-data:www-data volumes/wordpress/
  ```
* Restaurar backup do banco PHP56 para o banco do PHP56
* Levantar container
* Desativar todos os plugins
  ```bash
  docker-compose exec -u www-data wordpress wp plugin deactivate --all --network
  docker-compose exec -u www-data wordpress wp plugin deactivate --all
  ```
* Remover plugins sem uso
  ```
  docker-compose exec -u www-data wordpress wp plugin delete 3d-flipbook-dflip-lite popup-builder
  ```
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
  docker-compose exec -u www-data wordpress wp plugin activate advanced-custom-fields-google-map-extended acf-to-rest-api admin-menu-editor advanced-custom-fields amperj-plugin/amperj amperj-slider better-rest-api-featured-images classic-editor cookie-notice custom-post-type-ui export-import-menus json-api json-api-auth json-api-user ml-slider og-tags photo-gallery really-simple-ssl google-captcha regenerate-thumbnails shortcodes-ultimate show-current-template theme-my-login toggle-wpautop widget-importer-exporter wp-mail-bank wp-user-avatar wp-cpf-as-username --network
  ```
* Corrigir permissões:
  ```bash
  chown -R www-data:www-data volumes/wordpress/
  ```
* Desativar plugin `og-tags` na rede e mantê-lo ativo apenas para o site principal
  ```
  docker-compose exec -u www-data wordpress wp plugin deactivate og-tags --network
  docker-compose exec -u www-data wordpress wp plugin activate og-tags
  ```
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
* acessar /wp-admin
* fazer login com um super admin
* atualizar banco de dados
  `/wp-admin/upgrade.php`
* Aplicar atualizações
  http://<URL>/wp-admin/network/update-core.php