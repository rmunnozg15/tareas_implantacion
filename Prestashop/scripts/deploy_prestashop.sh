#!/usr/bin/env bash
set -euo pipefail

DB_NAME=prestashop_db
DB_USER=prestashop_user
DB_PASSWORD=
SHOP_NAME=Tienda_Roberto
SHOP_DOMAIN=localhost:8081
ADMIN_FIRSTNAME=Roberto
ADMIN_LASTNAME=Munoz
ADMIN_EMAIL=rmunnozg15@iesalbarregas.es
ADMIN_PASSWORD=prestashop123456789Aa
if [[ -f /vagrant/scripts/.env ]]; then set -a; source /vagrant/scripts/.env; set +a; fi

DOCROOT=/var/www/html
ARCHIVE=/vagrant/dist/prestashop.zip
if [[ ! -f "$ARCHIVE" ]]; then
  shopt -s nullglob
  archives=(/vagrant/dist/*.zip)
  shopt -u nullglob
  if [[ ${#archives[@]} -eq 1 ]]; then
    ARCHIVE="${archives[0]}"
  else
    echo "No encuentro un único ZIP de instalación en /vagrant/dist/. Guarda el paquete como dist/prestashop.zip." >&2
    printf 'ZIP detectado: %s\n' "${archives[@]:-ninguno}" >&2
    exit 1
  fi
fi

if [[ -z "$DB_PASSWORD" || -z "$ADMIN_EMAIL" || -z "$ADMIN_PASSWORD" ]]; then
  echo "Completa DB_PASSWORD, ADMIN_EMAIL y ADMIN_PASSWORD en scripts/.env." >&2
  exit 1
fi
if [[ ${#ADMIN_PASSWORD} -lt 12 || ! "$ADMIN_PASSWORD" =~ ^[A-Za-z0-9]+$ || ! "$ADMIN_PASSWORD" =~ [a-z] || ! "$ADMIN_PASSWORD" =~ [A-Z] || ! "$ADMIN_PASSWORD" =~ [0-9] ]]; then
  echo 'ADMIN_PASSWORD debe tener al menos 12 caracteres alfanuméricos, con mayúsculas, minúsculas y números; elige una contraseña fuerte y no predecible.' >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
unzip -q "$ARCHIVE" -d "$work/outer"

# El ZIP de la edición básica incluye un segundo archivo llamado prestashop.zip.
nested="$(find "$work/outer" -type f -iname 'prestashop.zip' -print -quit)"
if [[ -n "$nested" ]]; then
  mkdir "$work/package"
  unzip -q "$nested" -d "$work/package"
  source_dir="$work/package"
else
  source_dir="$work/outer"
fi

# Admite que el contenido del ZIP esté directamente en la raíz o dentro de una carpeta.
installer="$(find "$source_dir" -type f -path '*/install/index_cli.php' -print -quit)"
if [[ -z "$installer" ]]; then
  echo "No se encontró install/index_cli.php dentro del paquete extraído." >&2
  echo "Comprueba que descargaste la edición instalable y no el código fuente." >&2
  echo "Contenido superior del ZIP:" >&2
  find "$work/outer" -maxdepth 2 -type f -printf '%P\n' | head -n 30 >&2
  exit 1
fi
install_root="${installer%/install/index_cli.php}"

# La raíz web solo se reemplaza tras verificar que el paquete contiene el instalador CLI.
find "$DOCROOT" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "$install_root"/. "$DOCROOT"/
chown -R www-data:www-data "$DOCROOT"

php "$DOCROOT/install/index_cli.php" \
  --domain="$SHOP_DOMAIN" \
  --db_server=localhost \
  --db_name="$DB_NAME" \
  --db_user="$DB_USER" \
  --db_password="$DB_PASSWORD" \
  --db_create=0 \
  --prefix=roberto_ \
  --name="$SHOP_NAME" \
  --country=es \
  --language=es \
  --timezone=Europe/Madrid \
  --firstname="$ADMIN_FIRSTNAME" \
  --lastname="$ADMIN_LASTNAME" \
  --email="$ADMIN_EMAIL" \
  --password="$ADMIN_PASSWORD" \
  --fixtures=1

chown -R www-data:www-data "$DOCROOT"
systemctl reload apache2
echo "Instalación CLI finalizada. Comprueba http://127.0.0.1:8081"