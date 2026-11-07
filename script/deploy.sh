#!/bin/bash

# Configuramos el script para que se muestren los comandos
# y finalice cuando hay un error en la ejecución
set -ex
# importamos las variables de entorno
source .env

# Evitamos diálogos interactivos durante la instalación de paquetes
export DEBIAN_FRONTEND=noninteractive

# Nos situamos en el directorio del script para que las rutas relativas funcionen
cd "$(dirname "$0")"

# Comprobamos que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ejecutarse como root (usa sudo)."
  exit 1
fi


# Actualizamos la lista de paquetes y los paquetes del sistema
apt update
apt upgrade -y


# Instalamos el servidor web Apache
apt install apache2 -y

# Copiamos nuestro archivo de configuración de VirtualHost
cp ../conf/000-default.conf /etc/apache2/sites-available/000-default.conf


# Instalamos los paquetes necesarios para tener PHP (incluye mysqli)
apt install php libapache2-mod-php php-mysql -y

# Habilitamos el módulo rewrite de Apache
a2enmod rewrite

# Habilitamos Apache en el arranque y lo reiniciamos
systemctl enable apache2
systemctl restart apache2


# Instalamos MySQL Server
apt install mysql-server -y

# Habilitamos MySQL en el arranque y nos aseguramos de que está activo
systemctl enable mysql
systemctl start mysql

# Recreamos la base de datos y el usuario (así el script se puede repetir)
mysql -e "DROP DATABASE IF EXISTS ${DB_NAME};"
mysql -e "CREATE DATABASE ${DB_NAME} CHARSET utf8mb4;"
mysql -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';"
mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Importamos la estructura de la base de datos (tabla users)
mysql "${DB_NAME}" < ../db/database.sql



# Copiamos todos los archivos de la aplicación a /var/www/html
cp ../src/* /var/www/html/


# Configuramos las credenciales de la base de datos en config.php
sed -i "s|database_name_here|${DB_NAME}|" /var/www/html/config.php
sed -i "s|username_here|${DB_USER}|" /var/www/html/config.php
sed -i "s|password_here|${DB_PASSWORD}|" /var/www/html/config.php

# Modificamos el propietario del directorio /var/www/html
chown -R www-data:www-data /var/www/html

# Restringimos config.php, que contiene la contraseña
chmod 640 /var/www/html/config.php


systemctl is-active apache2
systemctl is-active mysql

echo "Pila LAMP y aplicación desplegadas correctamente."