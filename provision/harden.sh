#!/usr/bin/env bash
set -euo pipefail
WP_DIR="/var/www/wordpress"
PHP_INI_FPM=$(find /etc/php/ -path "*/fpm/php.ini" | sort | tail -n 1)
[ -n "$PHP_INI_FPM" ] && sed -i 's/^expose_php =.*/expose_php = Off/' "$PHP_INI_FPM"
sed -i 's/server_tokens on;/server_tokens off;/' /etc/nginx/nginx.conf || true

sudo -u www-data wp config set DISALLOW_FILE_EDIT true --raw --path="$WP_DIR"

cat << 'SEC' > /etc/nginx/snippets/wp-hardening.conf
server_tokens off;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
location = /xmlrpc.php {
    deny all;
    access_log off;
    log_not_found off;
}
location ~* /(?:uploads|files)/.*\.php$ {
    deny all;
}
SEC

if ! grep -q "wp-hardening.conf" /etc/nginx/sites-available/wordpress; then
  sed -i '/include snippets\/fastcgi-php.conf;/a \        include snippets/wp-hardening.conf;' /etc/nginx/sites-available/wordpress
fi

PHP_SERVICE=$(basename "$(ls /run/php/php*-fpm.sock | sort | tail -n 1)" .sock)
nginx -t && systemctl restart "$PHP_SERVICE" nginx