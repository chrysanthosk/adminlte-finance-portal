#!/bin/bash
# setup.sh - Complete deployment script for AdminLTE Finance Portal
# Supports: Ubuntu/Debian and RHEL/CentOS/Rocky/AlmaLinux
# Version: 2.1 - Improved password handling

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logo
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     AdminLTE Finance Portal - Auto Installer v2.1        ║
║                                                           ║
║     MySQL + PHP + Nginx/Apache + SSL + Angular           ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        echo -e "${RED}Cannot detect OS. Unsupported system.${NC}"
        exit 1
    fi

    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt"
            INSTALL_CMD="apt install -y"
            UPDATE_CMD="apt update"
            PHP_VERSION="8.2"
            WEB_USER="www-data"
            ;;
        rhel|centos|rocky|almalinux|fedora)
            PKG_MANAGER="yum"
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            fi
            INSTALL_CMD="$PKG_MANAGER install -y"
            UPDATE_CMD="$PKG_MANAGER update -y"
            PHP_VERSION="8.2"
            WEB_USER="apache"
            ;;
        *)
            echo -e "${RED}Unsupported OS: $OS${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}✓ Detected OS: $OS $VER${NC}"
}

# Check and install MySQL
install_mysql() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  Step 1: MySQL Installation Check${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

    if command -v mysql &> /dev/null; then
        echo -e "${GREEN}✓ MySQL is already installed${NC}"
        mysql --version
        return 0
    fi

    echo -e "${YELLOW}MySQL not found. Installing...${NC}"

    case $OS in
        ubuntu|debian)
            $UPDATE_CMD
            $INSTALL_CMD mysql-server mysql-client
            systemctl start mysql
            systemctl enable mysql
            ;;
        rhel|centos|rocky|almalinux)
            $INSTALL_CMD mysql-server mysql
            systemctl start mysqld
            systemctl enable mysqld

            # Get temporary root password for RHEL-based systems
            if [ -f /var/log/mysqld.log ]; then
                TEMP_PASS=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}' | tail -1)
                if [ ! -z "$TEMP_PASS" ]; then
                    echo -e "${YELLOW}Temporary MySQL root password: $TEMP_PASS${NC}"
                    echo -e "${YELLOW}You may need to change it during setup${NC}"
                fi
            fi
            ;;
        fedora)
            $INSTALL_CMD community-mysql-server
            systemctl start mysqld
            systemctl enable mysqld
            ;;
    esac

    echo -e "${GREEN}✓ MySQL installed successfully${NC}"

    # Run mysql_secure_installation
    echo -e "\n${YELLOW}Running MySQL secure installation...${NC}"
    mysql_secure_installation || true
}

# Check and install Node.js and Angular CLI
install_nodejs() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  Step 2: Node.js & Angular CLI${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

    if command -v node &> /dev/null; then
        echo -e "${GREEN}✓ Node.js is already installed${NC}"
        node --version
    else
        echo -e "${YELLOW}Installing Node.js...${NC}"

        case $OS in
            ubuntu|debian)
                curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
                $INSTALL_CMD nodejs
                ;;
            rhel|centos|rocky|almalinux|fedora)
                curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
                $INSTALL_CMD nodejs
                ;;
        esac

        echo -e "${GREEN}✓ Node.js installed successfully${NC}"
    fi

    # Install Angular CLI
    if ! command -v ng &> /dev/null; then
        echo -e "${YELLOW}Installing Angular CLI...${NC}"
        npm install -g @angular/cli
        echo -e "${GREEN}✓ Angular CLI installed${NC}"
    else
        echo -e "${GREEN}✓ Angular CLI already installed${NC}"
    fi
}

# Validate password strength
validate_password() {
    local password=$1
    local min_length=8

    if [ ${#password} -lt $min_length ]; then
        return 1
    fi

    # Check for uppercase
    if ! echo "$password" | grep -q "[A-Z]"; then
        return 1
    fi

    # Check for lowercase
    if ! echo "$password" | grep -q "[a-z]"; then
        return 1
    fi

    # Check for digit
    if ! echo "$password" | grep -q "[0-9]"; then
        return 1
    fi

    # Check for special character
    if ! echo "$password" | grep -q "[^a-zA-Z0-9]"; then
        return 1
    fi

    return 0
}

# Check MySQL password policy
check_mysql_password_policy() {
    echo -e "${CYAN}Checking MySQL password policy...${NC}"

    local policy=$(mysql -h "$1" -u "$2" -p"$3" -e "SHOW VARIABLES LIKE 'validate_password%';" 2>/dev/null)

    if [ $? -eq 0 ] && [ ! -z "$policy" ]; then
        echo -e "${YELLOW}MySQL password validation is enabled with the following requirements:${NC}"
        echo "$policy"
        return 0
    else
        echo -e "${GREEN}No strict password policy detected${NC}"
        return 1
    fi
}

detect_os
install_mysql
install_nodejs

# MySQL Configuration
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 3: Database Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

read -p "MySQL Host [localhost]: " MYSQL_HOST
MYSQL_HOST=${MYSQL_HOST:-localhost}

read -p "MySQL Root Username [root]: " MYSQL_ROOT_USER
MYSQL_ROOT_USER=${MYSQL_ROOT_USER:-root}

echo -e "${CYAN}Enter MySQL Root Password (input hidden):${NC}"
read -sp "Password: " MYSQL_ROOT_PASS
echo ""

# Test MySQL connection
echo -e "\n${YELLOW}Testing MySQL connection...${NC}"
if mysql -h "$MYSQL_HOST" -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" -e "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ MySQL connection successful${NC}"
else
    echo -e "${RED}✗ MySQL connection failed. Please check credentials.${NC}"
    exit 1
fi

# Check password policy
check_mysql_password_policy "$MYSQL_HOST" "$MYSQL_ROOT_USER" "$MYSQL_ROOT_PASS"

echo ""
read -p "New Database Name [adminlte_finance]: " DB_NAME
DB_NAME=${DB_NAME:-adminlte_finance}

read -p "New Database User [finance_user]: " DB_USER
DB_USER=${DB_USER:-finance_user}

# Password input with validation
echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Database User Password Requirements:                    ║${NC}"
echo -e "${CYAN}║  • Minimum 8 characters                                   ║${NC}"
echo -e "${CYAN}║  • At least 1 uppercase letter (A-Z)                      ║${NC}"
echo -e "${CYAN}║  • At least 1 lowercase letter (a-z)                      ║${NC}"
echo -e "${CYAN}║  • At least 1 number (0-9)                                ║${NC}"
echo -e "${CYAN}║  • At least 1 special character (!@#$%^&*)                ║${NC}"
echo -e "${CYAN}║                                                           ║${NC}"
echo -e "${CYAN}║  Example: Finance@2024!                                   ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

while true; do
    read -sp "New Database User Password: " DB_PASS
    echo ""
    read -sp "Confirm Password: " DB_PASS_CONFIRM
    echo -e "\n"

    if [ "$DB_PASS" != "$DB_PASS_CONFIRM" ]; then
        echo -e "${RED}✗ Passwords do not match. Please try again.${NC}\n"
        continue
    fi

    if validate_password "$DB_PASS"; then
        echo -e "${GREEN}✓ Password meets requirements${NC}"
        break
    else
        echo -e "${RED}✗ Password does not meet requirements. Please try again.${NC}"
        echo -e "${YELLOW}Remember: Min 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special character${NC}\n"
    fi
done

# Offer to adjust MySQL password policy if creation fails
adjust_password_policy() {
    echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}  MySQL Password Policy Options${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"

    echo "Your password meets basic requirements but MySQL policy is stricter."
    echo ""
    echo "Options:"
    echo "1) Try a stronger password (recommended for production)"
    echo "2) Temporarily adjust MySQL password policy"
    echo "3) Exit and configure manually"
    echo ""
    read -p "Choose option [1]: " POLICY_OPTION
    POLICY_OPTION=${POLICY_OPTION:-1}

    case $POLICY_OPTION in
        2)
            echo -e "${YELLOW}Adjusting MySQL password policy...${NC}"
            mysql -h "$MYSQL_HOST" -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" <<POLICY_SQL
SET GLOBAL validate_password.length = 8;
SET GLOBAL validate_password.mixed_case_count = 1;
SET GLOBAL validate_password.number_count = 1;
SET GLOBAL validate_password.special_char_count = 1;
SET GLOBAL validate_password.policy = MEDIUM;
POLICY_SQL
            echo -e "${GREEN}✓ Password policy adjusted${NC}"
            return 0
            ;;
        3)
            echo -e "${YELLOW}Exiting. Please configure MySQL manually.${NC}"
            exit 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Create database and user
echo -e "\n${YELLOW}Creating database and user...${NC}"
if ! mysql -h "$MYSQL_HOST" -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
then
    echo -e "${RED}✗ Failed to create database user${NC}"

    if adjust_password_policy; then
        echo -e "${YELLOW}Retrying with adjusted policy...${NC}"
        mysql -h "$MYSQL_HOST" -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    else
        exit 1
    fi
fi

echo -e "${GREEN}✓ Database and user created successfully${NC}"

# Import schema
if [ -f "schema.sql" ]; then
    echo -e "${YELLOW}Importing database schema...${NC}"
    mysql -h "$MYSQL_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < schema.sql
    echo -e "${GREEN}✓ Schema imported${NC}"
else
    echo -e "${RED}✗ schema.sql not found. Please ensure it exists in the current directory.${NC}"
    exit 1
fi

# Domain Configuration
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 4: Domain & SSL Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

read -p "Domain name (e.g., finance.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain name is required!${NC}"
    exit 1
fi

read -p "Project directory name [adminlte-finance]: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-adminlte-finance}

PROJECT_DIR="/var/www/${PROJECT_NAME}"

read -p "Install SSL certificate? (recommended for production) [Y/n]: " INSTALL_SSL
INSTALL_SSL=${INSTALL_SSL:-Y}

if [[ $INSTALL_SSL =~ ^[Yy]$ ]]; then
    read -p "Your email for SSL certificate: " SSL_EMAIL
fi

# Web Server Selection
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 5: Web Server Installation${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

echo "1) Nginx (Recommended)"
echo "2) Apache"
read -p "Choose web server [1]: " WEB_SERVER
WEB_SERVER=${WEB_SERVER:-1}

# Install dependencies
echo -e "${YELLOW}Installing web server and PHP...${NC}"

case $OS in
    ubuntu|debian)
        $UPDATE_CMD

        if [ "$WEB_SERVER" == "1" ]; then
            # Nginx + PHP-FPM
            $INSTALL_CMD nginx php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-mbstring \
                         php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-zip \
                         php${PHP_VERSION}-gd php${PHP_VERSION}-intl
            systemctl start php${PHP_VERSION}-fpm
            systemctl enable php${PHP_VERSION}-fpm
            systemctl start nginx
            systemctl enable nginx
        else
            # Apache + mod_php
            $INSTALL_CMD apache2 php${PHP_VERSION} libapache2-mod-php${PHP_VERSION} \
                         php${PHP_VERSION}-mysql php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml \
                         php${PHP_VERSION}-curl php${PHP_VERSION}-zip php${PHP_VERSION}-gd php${PHP_VERSION}-intl
            a2enmod rewrite
            a2enmod headers
            systemctl start apache2
            systemctl enable apache2
        fi

        # Install Certbot for SSL
        if [[ $INSTALL_SSL =~ ^[Yy]$ ]]; then
            $INSTALL_CMD certbot
            if [ "$WEB_SERVER" == "1" ]; then
                $INSTALL_CMD python3-certbot-nginx
            else
                $INSTALL_CMD python3-certbot-apache
            fi
        fi
        ;;

    rhel|centos|rocky|almalinux|fedora)
        # Enable EPEL and Remi repositories
        $INSTALL_CMD epel-release
        $INSTALL_CMD https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm || true
        $PKG_MANAGER module reset php -y || true
        $PKG_MANAGER module enable php:remi-${PHP_VERSION} -y || true

        if [ "$WEB_SERVER" == "1" ]; then
            # Nginx + PHP-FPM
            $INSTALL_CMD nginx php php-fpm php-mysqlnd php-mbstring php-xml php-json \
                         php-zip php-gd php-intl
            systemctl start php-fpm
            systemctl enable php-fpm
            systemctl start nginx
            systemctl enable nginx
        else
            # Apache + mod_php
            $INSTALL_CMD httpd php php-mysqlnd php-mbstring php-xml php-json \
                         php-zip php-gd php-intl
            systemctl start httpd
            systemctl enable httpd
        fi

        # Install Certbot for SSL
        if [[ $INSTALL_SSL =~ ^[Yy]$ ]]; then
            $INSTALL_CMD certbot
            if [ "$WEB_SERVER" == "1" ]; then
                $INSTALL_CMD python3-certbot-nginx
            else
                $INSTALL_CMD python3-certbot-apache
            fi
        fi

        # Configure SELinux
        if command -v semanage &> /dev/null; then
            echo -e "${YELLOW}Configuring SELinux...${NC}"
            semanage fcontext -a -t httpd_sys_rw_content_t "${PROJECT_DIR}(/.*)?" || true
            restorecon -R ${PROJECT_DIR} 2>/dev/null || true
            setsebool -P httpd_can_network_connect_db 1
            setsebool -P httpd_can_network_connect 1
        fi

        # Configure firewall
        if command -v firewall-cmd &> /dev/null; then
            echo -e "${YELLOW}Configuring firewall...${NC}"
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --reload
        fi
        ;;
esac

echo -e "${GREEN}✓ Web server and PHP installed${NC}"

# Create project directory
echo -e "\n${YELLOW}Creating project directories...${NC}"
mkdir -p ${PROJECT_DIR}/{dist,api}

# Set proper ownership
if [ ! -z "$SUDO_USER" ]; then
    chown -R $SUDO_USER:${WEB_USER} ${PROJECT_DIR}
else
    chown -R ${WEB_USER}:${WEB_USER} ${PROJECT_DIR}
fi
chmod -R 775 ${PROJECT_DIR}

# Update environment.prod.ts with domain
echo -e "${YELLOW}Updating Angular production environment...${NC}"
if [ -f "src/environments/environment.prod.ts" ]; then
    cat > src/environments/environment.prod.ts <<ENV_PROD
// src/environments/environment.prod.ts
export const environment = {
  production: true,
  apiUrl: 'https://${DOMAIN}/api'
};
ENV_PROD
    echo -e "${GREEN}✓ environment.prod.ts updated with domain: ${DOMAIN}${NC}"
else
    echo -e "${YELLOW}! environment.prod.ts not found, creating...${NC}"
    mkdir -p src/environments
    cat > src/environments/environment.prod.ts <<ENV_PROD
// src/environments/environment.prod.ts
export const environment = {
  production: true,
  apiUrl: 'https://${DOMAIN}/api'
};
ENV_PROD
fi

# Build Angular application
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 6: Building Angular Application${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

if [ -f "package.json" ]; then
    echo -e "${YELLOW}Installing npm dependencies...${NC}"
    npm install

    echo -e "${YELLOW}Building Angular application for production...${NC}"
    ng build --configuration production

    if [ -d "dist" ]; then
        echo -e "${GREEN}✓ Angular build completed${NC}"
    else
        echo -e "${RED}✗ Build failed. Please check for errors.${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ package.json not found. Are you in the project root directory?${NC}"
    exit 1
fi

# Copy files
echo -e "${YELLOW}Copying project files...${NC}"
if [ -d "dist/adminlte-finance-portal/browser" ]; then
    cp -r dist/adminlte-finance-portal/browser/* ${PROJECT_DIR}/dist/
elif [ -d "dist/browser" ]; then
    cp -r dist/browser/* ${PROJECT_DIR}/dist/
else
    cp -r dist/* ${PROJECT_DIR}/dist/
fi

cp -r api/* ${PROJECT_DIR}/api/

# Create database config
cat > ${PROJECT_DIR}/api/db.ini <<DB_INI
host=${MYSQL_HOST}
database=${DB_NAME}
username=${DB_USER}
password=${DB_PASS}
DB_INI

chmod 600 ${PROJECT_DIR}/api/db.ini
chown ${WEB_USER}:${WEB_USER} ${PROJECT_DIR}/api/db.ini

echo -e "${GREEN}✓ Files copied${NC}"

# Configure Web Server
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 7: Web Server Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

if [ "$WEB_SERVER" == "1" ]; then
    # Nginx configuration
    NGINX_CONF_FILE="/etc/nginx/sites-available/${PROJECT_NAME}"

    cat > ${NGINX_CONF_FILE} <<'NGINX_CONF'
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER;
    root PROJECT_DIR_PLACEHOLDER/dist;
    index index.html;

    # Angular routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # PHP API
    location /api {
        alias PROJECT_DIR_PLACEHOLDER/api;

        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/phpPHP_VERSION_PLACEHOLDER-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $request_filename;
        }
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location ~ /\.ht {
        deny all;
    }
}
NGINX_CONF

    # Replace placeholders
    sed -i "s|DOMAIN_PLACEHOLDER|${DOMAIN}|g" ${NGINX_CONF_FILE}
    sed -i "s|PROJECT_DIR_PLACEHOLDER|${PROJECT_DIR}|g" ${NGINX_CONF_FILE}
    sed -i "s|PHP_VERSION_PLACEHOLDER|${PHP_VERSION}|g" ${NGINX_CONF_FILE}

    # Enable site
    if [ -d "/etc/nginx/sites-enabled" ]; then
        ln -sf ${NGINX_CONF_FILE} /etc/nginx/sites-enabled/
    else
        # For RHEL-based systems
        cp ${NGINX_CONF_FILE} /etc/nginx/conf.d/${PROJECT_NAME}.conf
    fi

    nginx -t && systemctl reload nginx
    echo -e "${GREEN}✓ Nginx configured${NC}"

else
    # Apache configuration
    if [ -d "/etc/apache2/sites-available" ]; then
        APACHE_CONF_FILE="/etc/apache2/sites-available/${PROJECT_NAME}.conf"
    else
        APACHE_CONF_FILE="/etc/httpd/conf.d/${PROJECT_NAME}.conf"
    fi

    cat > ${APACHE_CONF_FILE} <<'APACHE_CONF'
<VirtualHost *:80>
    ServerName DOMAIN_PLACEHOLDER
    DocumentRoot PROJECT_DIR_PLACEHOLDER/dist

    <Directory PROJECT_DIR_PLACEHOLDER/dist>
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

    Alias /api PROJECT_DIR_PLACEHOLDER/api
    <Directory PROJECT_DIR_PLACEHOLDER/api>
        Options -Indexes
        AllowOverride All
        Require all granted

        <FilesMatch \.php$>
            SetHandler "proxy:unix:/var/run/php/phpPHP_VERSION_PLACEHOLDER-fpm.sock|fcgi://localhost"
        </FilesMatch>
    </Directory>

    # Security headers
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"

    ErrorLog ${APACHE_LOG_DIR}/PROJECT_NAME_PLACEHOLDER_error.log
    CustomLog ${APACHE_LOG_DIR}/PROJECT_NAME_PLACEHOLDER_access.log combined
</VirtualHost>
APACHE_CONF

    # Replace placeholders
    sed -i "s|DOMAIN_PLACEHOLDER|${DOMAIN}|g" ${APACHE_CONF_FILE}
    sed -i "s|PROJECT_DIR_PLACEHOLDER|${PROJECT_DIR}|g" ${APACHE_CONF_FILE}
    sed -i "s|PROJECT_NAME_PLACEHOLDER|${PROJECT_NAME}|g" ${APACHE_CONF_FILE}
    sed -i "s|PHP_VERSION_PLACEHOLDER|${PHP_VERSION}|g" ${APACHE_CONF_FILE}

    # Enable site
    if [ -d "/etc/apache2/sites-available" ]; then
        a2ensite ${PROJECT_NAME}
        systemctl reload apache2
    else
        systemctl reload httpd
    fi

    echo -e "${GREEN}✓ Apache configured${NC}"
fi

# Install SSL Certificate
if [[ $INSTALL_SSL =~ ^[Yy]$ ]]; then
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  Step 8: SSL Certificate Installation${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

    echo -e "${YELLOW}Installing SSL certificate for ${DOMAIN}...${NC}"

    if [ "$WEB_SERVER" == "1" ]; then
        certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos --email ${SSL_EMAIL} || {
            echo -e "${YELLOW}! Automatic SSL installation failed. You can run it manually later:${NC}"
            echo -e "${YELLOW}  sudo certbot --nginx -d ${DOMAIN}${NC}"
        }
    else
        certbot --apache -d ${DOMAIN} --non-interactive --agree-tos --email ${SSL_EMAIL} || {
            echo -e "${YELLOW}! Automatic SSL installation failed. You can run it manually later:${NC}"
            echo -e "${YELLOW}  sudo certbot --apache -d ${DOMAIN}${NC}"
        }
    fi

    # Test automatic renewal
    echo -e "${YELLOW}Testing SSL certificate auto-renewal...${NC}"
    certbot renew --dry-run || echo -e "${YELLOW}! Auto-renewal test failed. Please check certbot configuration.${NC}"
fi

# Final Summary
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║           Installation Completed Successfully!           ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE*
