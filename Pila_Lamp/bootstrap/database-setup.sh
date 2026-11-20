
#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

# Desactiva temporalmente el cortafuegos durante la instalación.
systemctl stop nftables 2>/dev/null || true

# Datos de conexión de la base de datos.
DB_NAME="${DB_NAME:-lamp_db}"
DB_USER="${DB_USER:-lamp_roberto}"
DB_PASS="${DB_PASS:-8888}"
WEB_IP="192.168.56.10"
DB_IP="192.168.56.20"

# Instala MariaDB y nftables.
apt-get update
apt-get install -y mariadb-server nftables

# Configura MariaDB para escuchar en la IP privada.
CONFIG_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"

if grep -qE '^[#[:space:]]*bind-address[[:space:]]*=' "$CONFIG_FILE"; then
    sed -i -E "s/^[#[:space:]]*bind-address[[:space:]]*=.*/bind-address = ${DB_IP}/" "$CONFIG_FILE"
else
    printf '\nbind-address = %s\n' "$DB_IP" >> "$CONFIG_FILE"
fi

# Inicia MariaDB.
systemctl enable --now mariadb
systemctl restart mariadb

# Crea la base de datos y el usuario de la aplicación.
mariadb <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
DROP USER IF EXISTS '${DB_USER}'@'${WEB_IP}';
CREATE USER '${DB_USER}'@'${WEB_IP}' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'${WEB_IP}';
FLUSH PRIVILEGES;
SQL

# Importa la estructura de las tablas.
mariadb "$DB_NAME" < /vagrant/aplicacion/db/database.sql

# Configura el cortafuegos.
# Permite SSH, conexiones establecidas y MySQL desde Apache.
# Bloquea nuevas conexiones de salida hacia Internet.
cat > /etc/nftables.conf <<NFT
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif lo accept
        ct state established,related accept
        tcp dport 22 accept
        udp sport 67 udp dport 68 accept
        ip saddr ${WEB_IP} ip daddr ${DB_IP} tcp dport 3306 accept
        ip protocol icmp accept
    }

    chain output {
        type filter hook output priority 0; policy drop;
        oif lo accept
        ct state established,related accept
        udp dport 67 accept
        ip daddr 192.168.56.0/24 accept
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }
}
NFT

# Activa el cortafuegos.
systemctl enable nftables
systemctl restart nftables

# Comprueba que los servicios están activos.
systemctl is-active --quiet mariadb
systemctl is-active --quiet nftables
