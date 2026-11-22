#!/usr/bin/env bash
set -euo pipefail
DB_NAME=prestashop_db
DB_USER=prestashop_user
DB_PASSWORD=
if [[ -f /vagrant/scripts/.env ]]; then set -a; source /vagrant/scripts/.env; set +a; fi
[[ -n "$DB_PASSWORD" ]] || { echo "Define DB_PASSWORD en scripts/.env." >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apache2 mariadb-server mariadb-client php libapache2-mod-php php-cli php-common php-curl php-gd php-intl php-mbstring php-mysql php-soap php-xml php-zip php-bcmath unzip curl wget ca-certificates certbot python3-certbot-apache ufw
a2enmod rewrite headers ssl
cat > /etc/php/$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')/apache2/conf.d/99-prestashop.ini <<'PHPINI'
memory_limit = 512M
max_input_vars = 5000
upload_max_filesize = 64M
post_max_size = 64M
allow_url_fopen = On
PHPINI
systemctl enable --now apache2 mariadb
systemctl restart apache2
mariadb <<SQL
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
echo "Apache: $(systemctl is-active apache2)"
echo "MariaDB: $(systemctl is-active mariadb)"
php -v | head -n 1
