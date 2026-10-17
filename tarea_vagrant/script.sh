#!/bin/bash
# Actualizar lista de paquetes e instalar Apache2 de forma desatendida
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y apache2

# Asegurar que el servicio Apache esté iniciado y habilitado al arranque
systemctl start apache2
systemctl enable apache2

# Crear la página de bienvenida personalizada
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Servidor Web Apache - Vagrant</title>
</head>
<body>
    <h1>¡Servidor configurado con éxito mediante Vagrant!</h1>
    <p><strong>Estudiante:</strong> Roberto Muñoz </p>
    <p><strong>Hostname de la máquina:</strong> $(hostname)</p>
</body>
</html>
EOF
