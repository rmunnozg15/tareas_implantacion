#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
IP="$1"
NAME="$2"
apt-get update
apt-get install -y apache2 php libapache2-mod-php php-mysql mariadb-client ufw
cat > /var/www/html/index.php <<PHP
<?php
\$db = @new mysqli('192.168.56.13', 'app', 'VagrantDemo2026!', 'demo');
\$estado = \$db->connect_error ? 'Sin conexión con la base de datos: ' . htmlspecialchars(\$db->connect_error) : htmlspecialchars(\$db->query('SELECT mensaje FROM estado WHERE id=1')->fetch_row()[0]);
?>
<!doctype html><html lang="es"><meta charset="utf-8"><title>Laboratorio Vagrant</title>
<style>body{font:1.2rem Arial;max-width:760px;margin:4rem auto;background:#f4f7fb;color:#182338}main{background:white;padding:2rem;border-radius:1rem}code{color:#0759a5}</style>
<main><h1>Aplicación web de tres capas</h1><p>Servidor atendiendo: <strong>${NAME}</strong></p><p>IP privada: <code>${IP}</code></p><p>Base de datos: <strong><?php echo \$estado; ?></strong></p></main></html>
PHP
rm -f /var/www/html/index.html
systemctl enable --now apache2
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow from 192.168.56.10 to any port 80 proto tcp
ufw --force enable
