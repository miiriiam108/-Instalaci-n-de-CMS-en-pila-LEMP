#!/usr/bin/env bash
set -euo pipefail

if [ -f /vagrant/.env ]; then
  set -a
  source /vagrant/.env
  set +a
fi

WP_URL="${WP_URL:-https://localhost:8443}"
WP_DIR="/var/www/wordpress"
SSL_DIR="/etc/nginx/ssl"
PHP_FPM_SOCK=$(find /run/php/ -name "php*-fpm.sock" | sort | tail -n 1)

apt-get install -y openssl

mkdir -p "$SSL_DIR"

# Generar certificado autofirmado con SAN para localhost y 127.0.0.1
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${SSL_DIR}/wordpress.key" \
  -out "${SSL_DIR}/wordpress.crt" \
  -subj "/C=ES/ST=Extremadura/L=Merida/O=LEMP-WordPress/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

chmod 600 "${SSL_DIR}/wordpress.key"
chmod 644 "${SSL_DIR}/wordpress.crt"

# Configurar Nginx con redirección HTTP (8080) -> HTTPS (8443) y HTTP/2
cat << NGINXCONF > /etc/nginx/sites-available/wordpress
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name localhost _;

    return 301 https://\$host:8443\$request_uri;
}

server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name localhost _;

    ssl_certificate ${SSL_DIR}/wordpress.crt;
    ssl_certificate_key ${SSL_DIR}/wordpress.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    root ${WP_DIR};
    index index.php index.html;

    client_max_body_size 64M;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${PHP_FPM_SOCK};
        fastcgi_param HTTPS on;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINXCONF

# Asegurar URLs de WordPress en HTTPS sin contenido mixto
sudo -u www-data wp option update home "$WP_URL" --path="$WP_DIR"
sudo -u www-data wp option update siteurl "$WP_URL" --path="$WP_DIR"

nginx -t
systemctl reload nginx
