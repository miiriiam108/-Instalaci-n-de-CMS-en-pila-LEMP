#!/usr/bin/env bash
set -euo pipefail

[ -f /vagrant/.env ] && { set -a; source /vagrant/.env; set +a; }

DB_NAME="${DB_NAME:-wordpress}"
DB_USER="${DB_USER:-wp_user}"
DB_PASSWORD="${DB_PASSWORD:-wp_password}"
WP_URL="${WP_URL:-https://localhost:8443}"
WP_TITLE="${WP_TITLE:-WordPress de Miriam}"
WP_LOCALE="${WP_LOCALE:-es_ES}"
WP_TIMEZONE="${WP_TIMEZONE:-Europe/Madrid}"

WP_ADMIN_USER="${WP_ADMIN_USER:-miriam_admin}"
WP_ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:-AdminMiriam2026!}"
WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL:-miriam@example.com}"

WP_EDITOR_USER="${WP_EDITOR_USER:-editor_miriam}"
WP_EDITOR_PASSWORD="${WP_EDITOR_PASSWORD:-EditorMiriam2026!}"
WP_EDITOR_EMAIL="${WP_EDITOR_EMAIL:-editor@example.com}"

WP_AUTHOR_USER="${WP_AUTHOR_USER:-autor_miriam}"
WP_AUTHOR_PASSWORD="${WP_AUTHOR_PASSWORD:-AutorMiriam2026!}"
WP_AUTHOR_EMAIL="${WP_AUTHOR_EMAIL:-autor@example.com}"

WP_CONTRIBUTOR_USER="${WP_CONTRIBUTOR_USER:-colab_miriam}"
WP_CONTRIBUTOR_PASSWORD="${WP_CONTRIBUTOR_PASSWORD:-ColabMiriam2026!}"
WP_CONTRIBUTOR_EMAIL="${WP_CONTRIBUTOR_EMAIL:-colaborador@example.com}"

WP_THEME="${WP_THEME:-astra}"
WP_PLUGINS="${WP_PLUGINS:-limit-login-attempts-reloaded classic-editor}"
WP_DIR="/var/www/wordpress"

export DEBIAN_FRONTEND=noninteractive
apt-get install -y locales
sed -i 's/^# *es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
export LC_ALL="C.UTF-8"
export LANG="C.UTF-8"

if [ ! -f /usr/local/bin/wp ]; then
  curl -sS -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /usr/local/bin/wp
fi

mkdir -p "$WP_DIR" && chown -R www-data:www-data "$WP_DIR"

if [ ! -f "${WP_DIR}/wp-load.php" ]; then
  sudo -u www-data LC_ALL=C.UTF-8 wp core download --path="$WP_DIR" --locale="$WP_LOCALE" || \
    sudo -u www-data LC_ALL=C.UTF-8 wp core download --path="$WP_DIR"
fi

if [ ! -f "${WP_DIR}/wp-config.php" ]; then
  sudo -u www-data LC_ALL=C.UTF-8 wp config create \
    --path="$WP_DIR" \
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASSWORD" \
    --dbhost="127.0.0.1" \
    --extra-php << 'PHP'
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
PHP
fi

if ! sudo -u www-data LC_ALL=C.UTF-8 wp core is-installed --path="$WP_DIR" 2>/dev/null; then
  sudo -u www-data LC_ALL=C.UTF-8 wp core install \
    --path="$WP_DIR" \
    --url="$WP_URL" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_USER" \
    --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL" \
    --skip-email
fi

sudo -u www-data LC_ALL=C.UTF-8 wp language core install "$WP_LOCALE" --path="$WP_DIR" || true
sudo -u www-data LC_ALL=C.UTF-8 wp site switch-language "$WP_LOCALE" --path="$WP_DIR" || true
sudo -u www-data LC_ALL=C.UTF-8 wp option update timezone_string "$WP_TIMEZONE" --path="$WP_DIR"
sudo -u www-data LC_ALL=C.UTF-8 wp rewrite structure '/%postname%/' --hard --path="$WP_DIR"
sudo -u www-data LC_ALL=C.UTF-8 wp rewrite flush --hard --path="$WP_DIR"

sudo -u www-data LC_ALL=C.UTF-8 wp theme install "$WP_THEME" --activate --path="$WP_DIR" || true
for plugin in $WP_PLUGINS; do
  sudo -u www-data LC_ALL=C.UTF-8 wp plugin install "$plugin" --activate --path="$WP_DIR" || true
done

for u in \
  "$WP_EDITOR_USER:$WP_EDITOR_EMAIL:editor:$WP_EDITOR_PASSWORD" \
  "$WP_AUTHOR_USER:$WP_AUTHOR_EMAIL:author:$WP_AUTHOR_PASSWORD" \
  "$WP_CONTRIBUTOR_USER:$WP_CONTRIBUTOR_EMAIL:contributor:$WP_CONTRIBUTOR_PASSWORD"; do
  IFS=: read -r uname uemail urole upass <<< "$u"
  sudo -u www-data LC_ALL=C.UTF-8 wp user get "$uname" --path="$WP_DIR" >/dev/null 2>&1 || \
    sudo -u www-data LC_ALL=C.UTF-8 wp user create "$uname" "$uemail" --role="$urole" --user_pass="$upass" --path="$WP_DIR"
done

if [ -z "$(sudo -u www-data LC_ALL=C.UTF-8 wp post list --post_type=page --name="sobre-este-proyecto" --format=ids --path="$WP_DIR")" ]; then
  sudo -u www-data LC_ALL=C.UTF-8 wp post create \
    --post_type=page \
    --post_status=publish \
    --post_author="$WP_ADMIN_USER" \
    --post_title="Sobre este proyecto" \
    --post_name="sobre-este-proyecto" \
    --post_content="Página creada automáticamente con WP-CLI." \
    --path="$WP_DIR"
fi

if [ -z "$(sudo -u www-data LC_ALL=C.UTF-8 wp post list --post_type=post --name="primera-entrada-automatizada" --format=ids --path="$WP_DIR")" ]; then
  sudo -u www-data LC_ALL=C.UTF-8 wp post create \
    --post_type=post \
    --post_status=publish \
    --post_author="$WP_ADMIN_USER" \
    --post_title="Primera entrada automatizada" \
    --post_name="primera-entrada-automatizada" \
    --post_content="Entrada publicada con WP-CLI." \
    --path="$WP_DIR"
fi

if [ -z "$(sudo -u www-data LC_ALL=C.UTF-8 wp post list --post_type=post --name="segunda-entrada-de-prueba" --format=ids --path="$WP_DIR")" ]; then
  sudo -u www-data LC_ALL=C.UTF-8 wp post create \
    --post_type=post \
    --post_status=publish \
    --post_author="$WP_ADMIN_USER" \
    --post_title="Segunda entrada de prueba" \
    --post_name="segunda-entrada-de-prueba" \
    --post_content="Entrada de verificación de enlaces permanentes y HTTPS." \
    --path="$WP_DIR"
fi

chown -R www-data:www-data "$WP_DIR"
find "$WP_DIR" -type d -exec chmod 755 {} \;
find "$WP_DIR" -type f -exec chmod 644 {} \;
chmod 640 "${WP_DIR}/wp-config.php"
