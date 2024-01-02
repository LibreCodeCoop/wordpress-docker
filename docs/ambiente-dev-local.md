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
UPDATE wp_options SET option_value = 'a:15:{s:12:"site_has_ssl";b:0;s:4:"hsts";b:0;s:22:"htaccess_warning_shown";b:0;s:19:"review_notice_shown";b:0;s:25:"ssl_success_message_shown";b:0;s:26:"autoreplace_insecure_links";b:1;s:17:"plugin_db_version";s:5:"3.2.7";s:5:"debug";b:0;s:20:"do_not_edit_htaccess";b:0;s:17:"htaccess_redirect";b:0;s:11:"ssl_enabled";b:0;s:19:"javascript_redirect";b:0;s:11:"wp_redirect";b:0;s:31:"switch_mixed_content_fixer_hook";b:0;s:19:"dismiss_all_notices";b:0;}'
WHERE option_value = 'a:15:{s:12:"site_has_ssl";b:0;s:4:"hsts";b:0;s:22:"htaccess_warning_shown";b:0;s:19:"review_notice_shown";b:0;s:25:"ssl_success_message_shown";b:0;s:26:"autoreplace_insecure_links";b:1;s:17:"plugin_db_version";s:5:"3.2.7";s:5:"debug";b:0;s:20:"do_not_edit_htaccess";b:0;s:17:"htaccess_redirect";b:0;s:11:"ssl_enabled";b:0;s:19:"javascript_redirect";b:0;s:11:"wp_redirect";b:0;s:31:"switch_mixed_content_fixer_hook";b:0;s:19:"dismiss_all_notices";b:0;}'
```

## Desabilitar o recaptcha para conseguir fazer login local
```bash
docker-compose exec -u www-data wordpress wp plugin deactivate google-captcha --network
```
