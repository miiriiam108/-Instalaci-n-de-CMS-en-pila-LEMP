#!/usr/bin/env bash
set -euo pipefail
[ -f /vagrant/.env ] && { set -a; source /vagrant/.env; set +a; }
DB_NAME="${DB_NAME:-wordpress}"
DB_USER="${DB_USER:-wp_user}"
DB_PASSWORD="${DB_PASSWORD:-wp_password}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-root_password}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx mariadb-server curl unzip php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-intl php-soap
PHP_FPM_SOCK=$(find /run/php/ -name "php*-fpm.sock" | sort | tail -n 1)
for ini in $(find /etc/php/ -name "php.ini"); do
  sed -i 's/^upload_max_filesize =.*/upload_max_filesize = 64M/' "$ini"
  sed -i 's/^post_max_size =.*/post_max_size = 64M/' "$ini"
  sed -i 's/^memory_limit =.*/memory_limit = 256M/' "$ini"
done
printf "[mysqld]\nbind-address = 127.0.0.1\n" > /etc/mysql/mariadb.conf.d/99-local-only.cnf
systemctl enable --now mariadb

SQL_CMDS="ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${DB_ROOT_PASSWORD}');
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;"

if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
  mysql -u root <<< "$SQL_CMDS"
else
  mysql -u root -p"${DB_ROOT_PASSWORD}" <<< "$SQL_CMDS"
fi

cat << NGINXCONF > /etc/nginx/sites-available/wordpress
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/wordpress;
    index index.php index.html;
    server_name _;
    client_max_body_size 64M;
    location / { try_files \$uri \$uri/ /index.php?\$args; }
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:${PHP_FPM_SOCK}; }
    location ~ /\.ht { deny all; }
}
NGINXCONF
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress
mkdir -p /var/www/wordpress
PHP_SERVICE=$(basename "$(ls /run/php/php*-fpm.sock | sort | tail -n 1)" .sock)
nginx -t && systemctl restart "$PHP_SERVICE" nginx mariadb
