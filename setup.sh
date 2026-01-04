#!/bin/bash
# setup.sh - Complete deployment script

set -e

echo "======================================"
echo " AdminLTE Finance Portal Installer"
echo "======================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# MySQL Configuration
echo -e "${GREEN}Step 1: MySQL Configuration${NC}"
read -p "MySQL Host [localhost]: " MYSQL_HOST
MYSQL_HOST=${MYSQL_HOST:-localhost}

read -p "MySQL Root Username [root]: " MYSQL_ROOT_USER
MYSQL_ROOT_USER=${MYSQL_ROOT_USER:-root}

read -sp "MySQL Root Password: " MYSQL_ROOT_PASS
echo ""

read -p "New Database Name [adminlte_finance]: " DB_NAME
DB_NAME=${DB_NAME:-adminlte_finance}

read -p "New Database User [finance_user]: " DB_USER
DB_USER=${DB_USER:-finance_user}

read -sp "New Database User Password: " DB_PASS
echo ""
echo ""

# Test MySQL connection
echo -e "${YELLOW}Testing MySQL connection...${NC}"
mysql -h "$MYSQL_HOST" -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" -e "SELECT 1;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ MySQL connection successful${NC}"
else
    echo -e "${RED}✗ MySQL connection failed${NC}"
    exit 1
fi

# Create database and user
echo -e "${YELLOW}Creating database and user...${NC}"
mysql -h "$MYSQL_HOST" -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo -e "${GREEN}✓ Database created${NC}"

# Import schema
echo -e "${YELLOW}Importing database schema...${NC}"
mysql -h "$MYSQL_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < schema.sql
echo -e "${GREEN}✓ Schema imported${NC}"

# Web Server Selection
echo ""
echo -e "${GREEN}Step 2: Web Server Installation${NC}"
echo "1) Nginx"
echo "2) Apache"
read -p "Choose web server [1]: " WEB_SERVER
WEB_SERVER=${WEB_SERVER:-1}

# Get domain/project name
read -p "Domain name (e.g., finance.example.com): " DOMAIN
read -p "Project directory name [adminlte-finance]: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-adminlte-finance}

PROJECT_DIR="/var/www/${PROJECT_NAME}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"

if [ "$WEB_SERVER" == "1" ]; then
    # Nginx + PHP-FPM
    sudo apt update
    sudo apt install -y nginx php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-xml php8.2-curl
    
    # Nginx configuration
    sudo tee /etc/nginx/sites-available/${PROJECT_NAME} > /dev/null <<NGINX_CONF
server {
    listen 80;
    server_name ${DOMAIN};
    root ${PROJECT_DIR}/dist;
    index index.html;

    # Angular routes
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # PHP API
    location /api {
        alias ${PROJECT_DIR}/api;
        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
        }
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX_CONF

    sudo ln -sf /etc/nginx/sites-available/${PROJECT_NAME} /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
    echo -e "${GREEN}✓ Nginx configured${NC}"
    
else
    # Apache + mod_php
    sudo apt update
    sudo apt install -y apache2 php8.2 libapache2-mod-php8.2 php8.2-mysql php8.2-mbstring php8.2-xml php8.2-curl
    sudo a2enmod rewrite
    
    # Apache configuration
    sudo tee /etc/apache2/sites-available/${PROJECT_NAME}.conf > /dev/null <<APACHE_CONF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    DocumentRoot ${PROJECT_DIR}/dist

    <Directory ${PROJECT_DIR}/dist>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Angular routing
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>

    Alias /api ${PROJECT_DIR}/api
    <Directory ${PROJECT_DIR}/api>
        Options -Indexes
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${PROJECT_NAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${PROJECT_NAME}_access.log combined
</VirtualHost>
APACHE_CONF

    sudo a2ensite ${PROJECT_NAME}
    sudo systemctl reload apache2
    echo -e "${GREEN}✓ Apache configured${NC}"
fi

# Create project directory
echo -e "${YELLOW}Creating project directories...${NC}"
sudo mkdir -p ${PROJECT_DIR}/{dist,api}
sudo chown -R $USER:www-data ${PROJECT_DIR}
sudo chmod -R 775 ${PROJECT_DIR}

# Copy files
echo -e "${YELLOW}Copying project files...${NC}"
cp -r dist/* ${PROJECT_DIR}/dist/
cp -r api/* ${PROJECT_DIR}/api/

# Create database config
cat > ${PROJECT_DIR}/api/db.ini <<DB_INI
host=${MYSQL_HOST}
database=${DB_NAME}
username=${DB_USER}
password=${DB_PASS}
DB_INI

sudo chmod 600 ${PROJECT_DIR}/api/db.ini
sudo chown www-data:www-data ${PROJECT_DIR}/api/db.ini

echo ""
echo -e "${GREEN}======================================"
echo " Installation Complete!"
echo "======================================${NC}"
echo ""
echo "Database: ${DB_NAME}"
echo "Database User: ${DB_USER}"
echo "Domain: ${DOMAIN}"
echo "Project Directory: ${PROJECT_DIR}"
echo ""
echo "Default Login:"
echo "  Username: admin"
echo "  Password: password"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update DNS to point ${DOMAIN} to this server"
echo "2. Install SSL: sudo certbot --nginx -d ${DOMAIN}"
echo "3. Build Angular project: ng build --configuration production"
echo "4. Update API URL in environment.prod.ts"
echo ""
