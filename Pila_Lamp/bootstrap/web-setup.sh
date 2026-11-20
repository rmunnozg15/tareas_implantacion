
#!/bin/bash
set -e

# Instala Apache, PHP y el módulo de conexión con MySQL/MariaDB.
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apache2 php libapache2-mod-php php-mysql

# Activa Apache y lo inicia.
systemctl enable --now apache2

# Comprueba que Apache está activo.
systemctl is-active --quiet apache2
