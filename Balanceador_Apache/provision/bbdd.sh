#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y mariadb-server ufw
sed -i 's/^bind-address.*/bind-address = 192.168.56.13/' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i 's/^#skip-name-resolve/skip-name-resolve/' /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl enable mariadb
systemctl restart mariadb
systemctl is-active --quiet mariadb
mysql <<'SQL'
CREATE DATABASE IF NOT EXISTS demo;
CREATE USER IF NOT EXISTS 'app'@'192.168.56.%' IDENTIFIED BY 'VagrantDemo2026!';
GRANT SELECT ON demo.* TO 'app'@'192.168.56.%';
CREATE TABLE IF NOT EXISTS demo.estado (id INT PRIMARY KEY, mensaje VARCHAR(100) NOT NULL);
INSERT INTO demo.estado (id, mensaje) VALUES (1, 'Conexión correcta con MariaDB') ON DUPLICATE KEY UPDATE mensaje=VALUES(mensaje);
FLUSH PRIVILEGES;
SQL
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow from 192.168.56.11 to any port 3306 proto tcp
ufw allow from 192.168.56.12 to any port 3306 proto tcp
ufw --force enable
