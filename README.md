# Montagem de ambiente

## Troca da URL no banco:

```bash
docker-compose exec -u www-data php56 wp search-replace http://<DOMINIO_ATUAL> https://<DOMINIO_NOVO> --all-tables
docker-compose exec -u www-data php56 wp search-replace <DOMINIO_ATUAL> <DOMINIO_NOVO> --all-tables
docker-compose exec -u www-data php56 wp search-replace <EMAIL_ADMIN_ATUAL> <EMAIL_ADMIN_NOVO> --all-tables
```

## Criar superadmin

```bash
wp user create <username> <email> --role=administrator --display_name=<displayname> --user_pass=<password>
wp super-admin add <username>
```
## Desabilitar SSL para ambiente de desenvolvimento:

```sql
SELECT * FROM wp_options WHERE option_name like '%ssl%'
UPDATE wp_options SET option_value = 'a:15:{s:12:"site_has_ssl";b:0;s:4:"hsts";b:0;s:22:"htaccess_warning_shown";b:0;s:19:"review_notice_shown";b:0;s:25:"ssl_success_message_shown";b:1;s:26:"autoreplace_insecure_links";b:1;s:17:"plugin_db_version";s:5:"3.2.7";s:5:"debug";b:0;s:20:"do_not_edit_htaccess";b:0;s:17:"htaccess_redirect";b:0;s:11:"ssl_enabled";b:0;s:19:"javascript_redirect";b:0;s:11:"wp_redirect";b:1;s:31:"switch_mixed_content_fixer_hook";b:0;s:19:"dismiss_all_notices";b:0;}'
WHERE option_value = 'a:15:{s:12:"site_has_ssl";b:1;s:4:"hsts";b:0;s:22:"htaccess_warning_shown";b:0;s:19:"review_notice_shown";b:0;s:25:"ssl_success_message_shown";b:1;s:26:"autoreplace_insecure_links";b:1;s:17:"plugin_db_version";s:5:"3.2.7";s:5:"debug";b:0;s:20:"do_not_edit_htaccess";b:0;s:17:"htaccess_redirect";b:0;s:11:"ssl_enabled";b:1;s:19:"javascript_redirect";b:0;s:11:"wp_redirect";b:1;s:31:"switch_mixed_content_fixer_hook";b:0;s:19:"dismiss_all_notices";b:0;}'
```

## Desabilitar o recaptcha para conseguir fazer login local
```bash
docker-compose exec -u www-data wordpress wp plugin deactivate google-captcha --network
```

# Atualização do WordPress

* No PHP56
  > OBS: É preciso que `DOMAIN_CURRENT_SITE` esteja de acordo com o que consta no banco, ou seja, igual ao site de destino
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
* No PHP8
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
  * Restaurar backup do banco PHP56
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
    http://localhost:8080/wp-admin/network/update-core.php