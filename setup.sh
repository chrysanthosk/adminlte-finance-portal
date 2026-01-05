#!/bin/bash
# setup.sh - Complete installer for AdminLTE Finance Portal
# Version: 2.1 - With PHP-FPM Fix, MySQL improvements, npm fixes, and Angular build fix
# Supports: Ubuntu/Debian and RHEL/CentOS/Rocky/AlmaLinux

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Script version
VERSION="2.1"

# Display logo
clear
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     AdminLTE Finance Portal - Automated Installer        ║
║                      Version 2.1                          ║
║                                                           ║
║  Complete setup with MySQL, PHP, Nginx, Angular & SSL    ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root or with sudo${NC}"
    exit 1
fi

# Detect OS and configure package manager
detect_os() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  Step 1: Detecting Operating System${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        OS_NAME=$NAME
    else
        echo -e "${RED}Cannot detect OS. Unsupported system.${NC}"
        exit 1
    fi

    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt"
            UPDATE_CMD="apt update"
            INSTALL_CMD="apt install -y"
            WEB_SERVER="nginx"
            WEB_USER="www-data"
            WEB_GROUP="www-data"
            PHP_VERSION="8.2"
            NGINX_CONF_DIR="/etc/nginx/sites-available"
            NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
            ;;
        rhel|centos|rocky|almalinux|fedora)
            PKG_MANAGER="yum"
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            fi
            UPDATE_CMD="$PKG_MANAGER update -y"
            INSTALL_CMD="$PKG_MANAGER install -y"
            WEB_SERVER="nginx"
            WEB_USER="nginx"
            WEB_GROUP="nginx"
            PHP_VERSION="8.2"
            NGINX_CONF_DIR="/etc/nginx/conf.d"
            NGINX_ENABLED_DIR="/etc/nginx/conf.d"
            ;;
        *)
            echo -e "${RED}Unsupported OS: $OS${NC}"
            echo -e "${YELLOW}This script supports: Ubuntu, Debian, RHEL, CentOS, Rocky Linux, AlmaLinux${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}✓ Operating System: ${OS_NAME}${NC}"
    echo -e "${GREEN}✓ Version: ${VER}${NC}"
    echo -e "${GREEN}✓ Package Manager: ${PKG_MANAGER}${NC}"
    echo -e "${GREEN}✓ Web Server: ${WEB_SERVER}${NC}"
}

detect_os

# Get configuration from user
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 2: Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

read -p "Project directory name [adminlte-finance]: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-adminlte-finance}
PROJECT_DIR="/var/www/${PROJECT_NAME}"

read -p "Domain name (e.g., finance.example.com): " DOMAIN
read -p "Your email for SSL (e.g., admin@example.com): " EMAIL

# Database configuration
echo -e "\n${YELLOW}Database Configuration:${NC}"
read -p "MySQL Root Username [root]: " MYSQL_ROOT_USER
MYSQL_ROOT_USER=${MYSQL_ROOT_USER:-root}

# Password validation loop
while true; do
    read -sp "MySQL Root Password (min 8 chars, include uppercase, lowercase, number): " MYSQL_ROOT_PASS
    echo ""

    if [ ${#MYSQL_ROOT_PASS} -lt 8 ]; then
        echo -e "${RED}Password too short! Must be at least 8 characters.${NC}"
        continue
    fi

    if [[ ! "$MYSQL_ROOT_PASS" =~ [A-Z] ]] || [[ ! "$MYSQL_ROOT_PASS" =~ [a-z] ]] || [[ ! "$MYSQL_ROOT_PASS" =~ [0-9] ]]; then
        echo -e "${RED}Password must contain uppercase, lowercase, and numbers!${NC}"
        continue
    fi

    break
done

read -p "Database Name [adminlte_finance]: " DB_NAME
DB_NAME=${DB_NAME:-adminlte_finance}

read -p "Database User [finance_user]: " DB_USER
DB_USER=${DB_USER:-finance_user}

while true; do
    read -sp "Database Password (min 8 chars, include uppercase, lowercase, number): " DB_PASS
    echo ""

    if [ ${#DB_PASS} -lt 8 ]; then
        echo -e "${RED}Password too short!${NC}"
        continue
    fi

    if [[ ! "$DB_PASS" =~ [A-Z] ]] || [[ ! "$DB_PASS" =~ [a-z] ]] || [[ ! "$DB_PASS" =~ [0-9] ]]; then
        echo -e "${RED}Password must contain uppercase, lowercase, and numbers!${NC}"
        continue
    fi

    break
done

read -p "API Base URL [https://${DOMAIN}/api]: " API_URL
API_URL=${API_URL:-https://${DOMAIN}/api}

# Display configuration summary
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Configuration Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"
echo -e "${CYAN}Project Directory:${NC} ${PROJECT_DIR}"
echo -e "${CYAN}Domain:${NC} ${DOMAIN}"
echo -e "${CYAN}Email:${NC} ${EMAIL}"
echo -e "${CYAN}Database:${NC} ${DB_NAME}"
echo -e "${CYAN}Database User:${NC} ${DB_USER}"
echo -e "${CYAN}API URL:${NC} ${API_URL}"
echo -e "${CYAN}Web User:${NC} ${WEB_USER}"

read -p $'\n'"Continue with installation? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled.${NC}"
    exit 0
fi

# Update system packages
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 3: Updating System Packages${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Updating package lists...${NC}"
$UPDATE_CMD

if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    echo -e "${YELLOW}Installing essential packages...${NC}"
    $INSTALL_CMD software-properties-common curl wget git unzip

    # Add PHP repository
    echo -e "${YELLOW}Adding Ondřej Surý PPA for PHP 8.2...${NC}"
    add-apt-repository -y ppa:ondrej/php
    $UPDATE_CMD
else
    echo -e "${YELLOW}Installing essential packages...${NC}"
    $INSTALL_CMD curl wget git unzip

    # Add EPEL and Remi repository for PHP
    $INSTALL_CMD epel-release
    if [ "$PKG_MANAGER" == "dnf" ]; then
        $INSTALL_CMD https://rpms.remirepo.net/enterprise/remi-release-${VER%%.*}.rpm
        dnf module reset php -y
        dnf module enable php:remi-8.2 -y
    fi
fi

echo -e "${GREEN}✓ System packages updated${NC}"

# Install MySQL
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 4: Installing MySQL Server${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

if command -v mysql &> /dev/null; then
    echo -e "${YELLOW}MySQL already installed. Version:${NC}"
    mysql --version
else
    echo -e "${YELLOW}Installing MySQL Server...${NC}"

    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        export DEBIAN_FRONTEND=noninteractive
        debconf-set-selections <<< "mysql-server mysql-server/root_password password ${MYSQL_ROOT_PASS}"
        debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${MYSQL_ROOT_PASS}"

        $INSTALL_CMD mysql-server mysql-client
    else
        $INSTALL_CMD mysql-server mysql
        systemctl start mysqld
        systemctl enable mysqld

        if [ -f /var/log/mysqld.log ]; then
            TEMP_PASS=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
            if [ ! -z "$TEMP_PASS" ]; then
                mysql -u root -p"${TEMP_PASS}" --connect-expired-password <<MYSQL_SCRIPT
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
            fi
        fi
    fi

    systemctl start mysql 2>/dev/null || systemctl start mysqld
    systemctl enable mysql 2>/dev/null || systemctl enable mysqld

    echo -e "${GREEN}✓ MySQL installed and started${NC}"
fi

# Configure MySQL password policy
echo -e "\n${YELLOW}Configuring MySQL for application...${NC}"
read -p "Adjust MySQL password policy for easier passwords? [y/N]: " ADJUST_POLICY
ADJUST_POLICY=${ADJUST_POLICY:-N}

if [[ $ADJUST_POLICY =~ ^[Yy]$ ]]; then
    mysql -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" <<MYSQL_SCRIPT
SET GLOBAL validate_password.policy = LOW;
SET GLOBAL validate_password.length = 8;
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    echo -e "${GREEN}✓ MySQL password policy adjusted${NC}"
fi

# Install PHP
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 5: Installing PHP ${PHP_VERSION}${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Installing PHP ${PHP_VERSION} and extensions...${NC}"
$INSTALL_CMD php${PHP_VERSION}-fpm \
             php${PHP_VERSION}-cli \
             php${PHP_VERSION}-common \
             php${PHP_VERSION}-mysql \
             php${PHP_VERSION}-xml \
             php${PHP_VERSION}-curl \
             php${PHP_VERSION}-mbstring \
             php${PHP_VERSION}-zip \
             php${PHP_VERSION}-gd \
             php${PHP_VERSION}-intl \
             php${PHP_VERSION}-bcmath

# PHP-FPM Configuration
echo -e "\n${YELLOW}Configuring PHP-FPM...${NC}"

systemctl stop php${PHP_VERSION}-fpm 2>/dev/null || true
killall -9 php-fpm${PHP_VERSION} 2>/dev/null || true

mkdir -p /run/php
chown ${WEB_USER}:${WEB_GROUP} /run/php
chmod 755 /run/php

rm -f /run/php/php-fpm.sock
rm -f /run/php/php${PHP_VERSION}-fpm.sock

if [ -f "/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf" ]; then
    echo -e "${CYAN}Backing up original PHP-FPM configuration...${NC}"
    cp /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf.backup

    echo -e "${CYAN}Configuring PHP-FPM pool...${NC}"
    sed -i "s/^user = .*/user = ${WEB_USER}/" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
    sed -i "s/^group = .*/group = ${WEB_GROUP}/" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
    sed -i "s|^listen = .*|listen = /run/php/php${PHP_VERSION}-fpm.sock|" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
    sed -i "s/^listen.owner = .*/listen.owner = ${WEB_USER}/" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
    sed -i "s/^listen.group = .*/listen.group = ${WEB_GROUP}/" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
    sed -i "s/^listen.mode = .*/listen.mode = 0660/" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf

    grep -q "^listen.owner" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf || echo "listen.owner = ${WEB_USER}" >> /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
    grep -q "^listen.group" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf || echo "listen.group = ${WEB_GROUP}" >> /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
    grep -q "^listen.mode" /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf || echo "listen.mode = 0660" >> /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
fi

echo -e "${YELLOW}Testing PHP-FPM configuration...${NC}"
if php-fpm${PHP_VERSION} -t 2>&1 | tee /tmp/php-fpm-test.log; then
    echo -e "${GREEN}✓ PHP-FPM configuration is valid${NC}"
else
    echo -e "${RED}✗ PHP-FPM configuration test failed${NC}"
    cat /tmp/php-fpm-test.log

    echo -e "${YELLOW}Attempting to fix dpkg state...${NC}"
    dpkg --configure -a
    apt --fix-broken install -y

    echo -e "${YELLOW}Reinstalling PHP-FPM...${NC}"
    apt install --reinstall -y php${PHP_VERSION}-fpm

    if php-fpm${PHP_VERSION} -t; then
        echo -e "${GREEN}✓ PHP-FPM configuration fixed${NC}"
    else
        echo -e "${RED}✗ PHP-FPM configuration still invalid${NC}"
        echo -e "${YELLOW}Manual intervention required. Check: /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}Starting PHP-FPM service...${NC}"
systemctl daemon-reload
systemctl start php${PHP_VERSION}-fpm
systemctl enable php${PHP_VERSION}-fpm

sleep 2
if systemctl is-active --quiet php${PHP_VERSION}-fpm; then
    echo -e "${GREEN}✓ PHP-FPM is running successfully${NC}"
    systemctl status php${PHP_VERSION}-fpm --no-pager -l
else
    echo -e "${RED}✗ PHP-FPM failed to start${NC}"
    echo -e "\n${YELLOW}Error logs:${NC}"
    journalctl -xeu php${PHP_VERSION}-fpm.service --no-pager -n 30

    echo -e "\n${YELLOW}Troubleshooting steps:${NC}"
    echo -e "1. Check configuration: ${CYAN}sudo php-fpm${PHP_VERSION} -t${NC}"
    echo -e "2. Check socket file: ${CYAN}ls -la /run/php/${NC}"
    echo -e "3. Check permissions: ${CYAN}sudo chown ${WEB_USER}:${WEB_GROUP} /run/php${NC}"
    echo -e "4. View logs: ${CYAN}sudo journalctl -xeu php${PHP_VERSION}-fpm.service${NC}"

    exit 1
fi

php -v | head -n 1
echo -e "${CYAN}Verifying JSON support...${NC}"
php -m | grep -i json && echo -e "${GREEN}✓ JSON support enabled${NC}" || echo -e "${YELLOW}! JSON support check inconclusive${NC}"

echo -e "${GREEN}✓ PHP ${PHP_VERSION} installation completed${NC}"

# Install Node.js and npm
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 6: Installing Node.js and npm${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo -e "${YELLOW}Node.js already installed: ${NODE_VERSION}${NC}"
else
    echo -e "${YELLOW}Installing Node.js 20.x LTS...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    $INSTALL_CMD nodejs
fi

echo -e "${YELLOW}Installing Angular CLI...${NC}"
npm install -g @angular/cli@18

node -v
npm -v
ng version --no-color | head -n 3

echo -e "${GREEN}✓ Node.js and Angular CLI installed${NC}"

# Build Angular application
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 7: Building Angular Application${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

if [ -f "package.json" ]; then
    NODE_MAJOR=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_MAJOR" -lt 18 ]; then
        echo -e "${RED}✗ Node.js version is too old. Angular 18+ requires Node 18+${NC}"
        exit 1
    fi

    echo -e "${CYAN}Node.js version: $(node -v) ✓${NC}"
    echo -e "${CYAN}npm version: $(npm -v) ✓${NC}\n"

    if [ -d "node_modules" ]; then
        echo -e "${YELLOW}Cleaning old node_modules...${NC}"
        rm -rf node_modules package-lock.json
    fi

    echo -e "${YELLOW}Checking package.json for version conflicts...${NC}"

    CDK_VERSION=$(grep '"@angular/cdk"' package.json | grep -oP '\d+\.\d+' | head -1)
    ANGULAR_VERSION=$(grep '"@angular/core"' package.json | grep -oP '\d+\.\d+' | head -1)

    if [ ! -z "$CDK_VERSION" ] && [ ! -z "$ANGULAR_VERSION" ]; then
        CDK_MAJOR=$(echo $CDK_VERSION | cut -d'.' -f1)
        ANG_MAJOR=$(echo $ANGULAR_VERSION | cut -d'.' -f1)

        if [ "$CDK_MAJOR" != "$ANG_MAJOR" ]; then
            echo -e "${YELLOW}⚠️  Version mismatch detected:${NC}"
            echo -e "   Angular Core: ${ANGULAR_VERSION}"
            echo -e "   Angular CDK:  ${CDK_VERSION}"
            echo -e "${YELLOW}Fixing @angular/cdk version...${NC}"

            sed -i "s/\"@angular\/cdk\": \"[^\"]*\"/\"@angular\/cdk\": \"^${ANGULAR_VERSION}\"/" package.json
            sed -i "s/\"@angular\/material\": \"[^\"]*\"/\"@angular\/material\": \"^${ANGULAR_VERSION}\"/" package.json

            echo -e "${GREEN}✓ Versions synchronized${NC}"
        fi
    fi

    echo -e "\n${YELLOW}Installing npm dependencies (this may take several minutes)...${NC}"
    echo -e "${CYAN}Progress will be shown below:${NC}\n"

    INSTALL_SUCCESS=0

    echo -e "${CYAN}Attempting install with --legacy-peer-deps --ignore-scripts...${NC}"
    if npm install --legacy-peer-deps --ignore-scripts 2>&1 | tee /tmp/npm-install.log; then
        if [ -d "node_modules" ] && [ "$(find node_modules -maxdepth 1 -type d | wc -l)" -gt 50 ]; then
            INSTALL_SUCCESS=1
            echo -e "\n${GREEN}✓ Dependencies installed successfully${NC}"
        fi
    fi

    if [ $INSTALL_SUCCESS -eq 0 ]; then
        echo -e "\n${YELLOW}⚠️  First attempt had issues, retrying with different flags...${NC}"
        rm -rf node_modules package-lock.json

        if npm install --legacy-peer-deps --force 2>&1 | tee /tmp/npm-install-force.log; then
            if [ -d "node_modules" ] && [ "$(find node_modules -maxdepth 1 -type d | wc -l)" -gt 50 ]; then
                INSTALL_SUCCESS=1
                echo -e "\n${GREEN}✓ Dependencies installed with --force${NC}"
            fi
        fi
    fi

    if [ $INSTALL_SUCCESS -eq 0 ]; then
        echo -e "\n${YELLOW}⚠️  Trying one more time with basic flags...${NC}"
        rm -rf node_modules package-lock.json

        npm config set ignore-scripts true

        if npm install --legacy-peer-deps 2>&1 | tee /tmp/npm-install-basic.log; then
            if [ -d "node_modules" ] && [ "$(find node_modules -maxdepth 1 -type d | wc -l)" -gt 50 ]; then
                INSTALL_SUCCESS=1
                echo -e "\n${GREEN}✓ Dependencies installed (postinstall scripts skipped)${NC}"
            fi
        fi

        npm config set ignore-scripts false
    fi

    if [ $INSTALL_SUCCESS -eq 0 ]; then
        echo -e "\n${RED}✗ npm install failed after multiple attempts${NC}"
        echo -e "\n${YELLOW}Error logs:${NC}"

        if [ -f /tmp/npm-install.log ]; then
            tail -50 /tmp/npm-install.log
        fi

        echo -e "\n${YELLOW}Troubleshooting steps:${NC}"
        echo -e "1. Check Node.js version: ${CYAN}node -v${NC} (should be 18+)"
        echo -e "2. Clear npm cache: ${CYAN}npm cache clean --force${NC}"
        echo -e "3. Try manual install: ${CYAN}npm install --legacy-peer-deps --ignore-scripts${NC}"
        echo -e "4. Check package.json for invalid dependencies"
        exit 1
    fi

    if [ ! -d "node_modules" ]; then
        echo -e "${RED}✗ node_modules directory not created${NC}"
        exit 1
    fi

    PKG_COUNT=$(find node_modules -maxdepth 1 -type d 2>/dev/null | wc -l)
    if [ "$PKG_COUNT" -lt 50 ]; then
        echo -e "${RED}✗ node_modules seems incomplete (only $PKG_COUNT packages)${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Installed $PKG_COUNT packages${NC}\n"

    echo -e "${YELLOW}Updating environment configuration...${NC}"

    if [ -f "src/environments/environment.prod.ts" ]; then
        sed -i "s|apiUrl: '.*'|apiUrl: '${API_URL}'|g" src/environments/environment.prod.ts
        echo -e "${GREEN}✓ Production environment updated${NC}"
    fi

    if [ -f "src/environments/environment.ts" ]; then
        sed -i "s|apiUrl: '.*'|apiUrl: '${API_URL}'|g" src/environments/environment.ts
        echo -e "${GREEN}✓ Development environment updated${NC}"
    fi

    # Angular project structure detection
    echo -e "\n${YELLOW}Detecting Angular project structure...${NC}"

    IS_STANDALONE=0
    if [ -f "src/app.component.ts" ] && [ -f "src/app.routes.ts" ] && [ ! -d "src/app" ]; then
        IS_STANDALONE=1
        echo -e "${CYAN}✓ Detected: Angular 18+ Standalone structure${NC}"
    elif [ -d "src/app" ] && [ -f "src/app/app.module.ts" ]; then
        echo -e "${CYAN}✓ Detected: Traditional module-based structure${NC}"
    else
        echo -e "${YELLOW}⚠️  Project structure unclear, attempting standalone setup...${NC}"
        IS_STANDALONE=1
    fi

    # Create required files based on structure
    if [ $IS_STANDALONE -eq 1 ]; then
        echo -e "${YELLOW}Setting up standalone Angular application files...${NC}"

        if [ ! -f "src/app.config.ts" ]; then
            echo -e "${CYAN}Creating src/app.config.ts...${NC}"
            cat > src/app.config.ts <<'APP_CONFIG'
import { ApplicationConfig } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';
import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes),
    provideHttpClient()
  ]
};
APP_CONFIG
            echo -e "${GREEN}✓ Created app.config.ts${NC}"
        fi

        if [ -f "src/main.ts" ]; then
            if ! grep -q "bootstrapApplication" src/main.ts; then
                echo -e "${CYAN}Updating src/main.ts for standalone bootstrap...${NC}"
                cat > src/main.ts <<'MAIN_TS'
import { bootstrapApplication } from '@angular/platform-browser';
import { AppComponent } from './app.component';
import { appConfig } from './app.config';

bootstrapApplication(AppComponent, appConfig)
  .catch(err => console.error(err));
MAIN_TS
                echo -e "${GREEN}✓ Updated main.ts${NC}"
            fi
        else
            echo -e "${CYAN}Creating src/main.ts...${NC}"
            cat > src/main.ts <<'MAIN_TS'
import { bootstrapApplication } from '@angular/platform-browser';
import { AppComponent } from './app.component';
import { appConfig } from './app.config';

bootstrapApplication(AppComponent, appConfig)
  .catch(err => console.error(err));
MAIN_TS
            echo -e "${GREEN}✓ Created main.ts${NC}"
        fi
    else
        if [ ! -f "src/main.ts" ]; then
            echo -e "${CYAN}Creating src/main.ts...${NC}"
            cat > src/main.ts <<'MAIN_MODULE'
import { platformBrowserDynamic } from '@angular/platform-browser-dynamic';
import { AppModule } from './app/app.module';

platformBrowserDynamic().bootstrapModule(AppModule)
  .catch(err => console.error(err));
MAIN_MODULE
            echo -e "${GREEN}✓ Created main.ts${NC}"
        fi
    fi

    # TypeScript configuration validation
    echo -e "\n${YELLOW}Validating TypeScript configuration...${NC}"

    if [ ! -f "tsconfig.app.json" ]; then
        echo -e "${YELLOW}Creating tsconfig.app.json...${NC}"
        cat > tsconfig.app.json <<'TSCONFIG_APP'
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "./out-tsc/app",
    "types": []
  },
  "files": [
    "src/main.ts"
  ],
  "include": [
    "src/**/*.d.ts"
  ]
}
TSCONFIG_APP
        echo -e "${GREEN}✓ Created tsconfig.app.json${NC}"
    else
        echo -e "${GREEN}✓ tsconfig.app.json exists${NC}"
    fi

    if [ ! -f "tsconfig.spec.json" ]; then
        echo -e "${YELLOW}Creating tsconfig.spec.json...${NC}"
        cat > tsconfig.spec.json <<'TSCONFIG_SPEC'
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "./out-tsc/spec",
    "types": [
      "jasmine"
    ]
  },
  "include": [
    "src/**/*.spec.ts",
    "src/**/*.d.ts"
  ]
}
TSCONFIG_SPEC
        echo -e "${GREEN}✓ Created tsconfig.spec.json${NC}"
    else
        echo -e "${GREEN}✓ tsconfig.spec.json exists${NC}"
    fi

    # Validate angular.json
    echo -e "\n${YELLOW}Validating angular.json configuration...${NC}"

    if [ -f "angular.json" ]; then
        echo -e "${CYAN}Checking angular.json for required properties...${NC}"

        if ! grep -q '"index"' angular.json; then
            echo -e "${YELLOW}⚠️  Missing 'index' property in angular.json${NC}"

            if [ ! -f "src/index.html" ]; then
                echo -e "${YELLOW}Creating src/index.html...${NC}"
                cat > src/index.html <<'INDEX_HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>AdminLTE Finance Portal</title>
  <base href="/">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="icon" type="image/x-icon" href="favicon.ico">
</head>
<body class="hold-transition sidebar-mini layout-fixed">
  <app-root></app-root>
</body>
</html>
INDEX_HTML
                echo -e "${GREEN}✓ Created src/index.html${NC}"
            fi

            cp angular.json angular.json.backup
            echo -e "${CYAN}Backed up angular.json${NC}"

            sed -i '/"options": {/a\            "index": "src/index.html",' angular.json
            echo -e "${GREEN}✓ Updated angular.json with 'index' property${NC}"
        else
            echo -e "${GREEN}✓ angular.json has 'index' property${NC}"
        fi

        # Verify tsConfig reference
        if ! grep -q '"tsConfig".*"tsconfig.app.json"' angular.json; then
            echo -e "${YELLOW}⚠️  Updating tsConfig reference in angular.json...${NC}"
            sed -i 's|"tsConfig": "[^"]*"|"tsConfig": "tsconfig.app.json"|' angular.json
            echo -e "${GREEN}✓ Updated tsConfig reference${NC}"
        fi
    else
        echo -e "${RED}✗ angular.json not found${NC}"
        exit 1
    fi

    # Verify critical files exist
    echo -e "\n${YELLOW}Verifying project files...${NC}"

    MISSING_FILES=0

    [ ! -f "src/main.ts" ] && echo -e "${RED}✗ Missing: src/main.ts${NC}" && MISSING_FILES=1
    [ ! -f "src/index.html" ] && echo -e "${RED}✗ Missing: src/index.html${NC}" && MISSING_FILES=1
    [ ! -f "src/app.component.ts" ] && echo -e "${RED}✗ Missing: src/app.component.ts${NC}" && MISSING_FILES=1

    if [ $MISSING_FILES -eq 1 ]; then
        echo -e "\n${RED}✗ Critical files are missing. Cannot proceed with build.${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ All required files present${NC}"

    # Build for production
    echo -e "\n${YELLOW}Building Angular application for production...${NC}"
    echo -e "${CYAN}This may take 3-5 minutes. Please be patient...${NC}\n"

    export NODE_OPTIONS="--max_old_space_size=4096"

    if ng build --configuration production 2>&1 | tee /tmp/ng-build.log; then
        if [ -d "dist" ]; then
            DIST_DIR=$(find dist -maxdepth 1 -type d -name "*" | grep -v "^dist$" | head -1)

            if [ -z "$DIST_DIR" ]; then
                DIST_DIR="dist"
            fi

            FILE_COUNT=$(find "$DIST_DIR" -type f 2>/dev/null | wc -l)
            DIST_SIZE=$(du -sh "$DIST_DIR" 2>/dev/null | cut -f1)

            if [ "$FILE_COUNT" -gt 5 ]; then
                echo -e "\n${GREEN}✓ Angular build completed successfully${NC}"
                echo -e "${GREEN}✓ Generated $FILE_COUNT files ($DIST_SIZE)${NC}"
                echo -e "${GREEN}✓ Build output: $DIST_DIR${NC}"
            else
                echo -e "${RED}✗ Build directory seems incomplete (only $FILE_COUNT files)${NC}"
                echo -e "${YELLOW}Contents:${NC}"
                ls -la "$DIST_DIR"
                exit 1
            fi
        else
            echo -e "${RED}✗ dist directory not found after build${NC}"
            echo -e "${YELLOW}Current directory structure:${NC}"
            ls -la
            exit 1
        fi
    else
        echo -e "\n${RED}✗ Build failed${NC}"
        echo -e "\n${YELLOW}Error details:${NC}"
        tail -50 /tmp/ng-build.log

        echo -e "\n${YELLOW}Common issues:${NC}"
        echo -e "1. Missing tsconfig.app.json - ${CYAN}File should now exist${NC}"
        echo -e "2. Missing src/index.html - ${CYAN}File should now exist${NC}"
        echo -e "3. TypeScript errors - ${CYAN}Check your .ts files${NC}"
        echo -e "4. Check build log: ${CYAN}cat /tmp/ng-build.log${NC}"

        exit 1
    fi
else
    echo -e "${RED}✗ package.json not found${NC}"
    echo -e "${YELLOW}Current directory: $(pwd)${NC}"
    echo -e "${YELLOW}Please ensure you're in the project root directory${NC}"
    exit 1
fi

# Create project directory and copy files
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 8: Setting Up Project Files${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Creating project directory...${NC}"
mkdir -p ${PROJECT_DIR}

# Copy Angular build
echo -e "${YELLOW}Copying Angular build files...${NC}"
if [ -d "dist" ]; then
    # Find the actual dist subdirectory (Angular 15+ creates dist/project-name)
    DIST_SUBDIR=$(find dist -mindepth 1 -maxdepth 1 -type d | head -n 1)

    if [ ! -z "$DIST_SUBDIR" ] && [ -d "$DIST_SUBDIR" ]; then
        cp -r ${DIST_SUBDIR}/* ${PROJECT_DIR}/
        echo -e "${GREEN}✓ Angular files copied from ${DIST_SUBDIR}${NC}"
    else
        cp -r dist/* ${PROJECT_DIR}/
        echo -e "${GREEN}✓ Angular files copied${NC}"
    fi
else
    echo -e "${RED}✗ dist directory not found${NC}"
    exit 1
fi

# Copy API files
echo -e "${YELLOW}Copying API files...${NC}"
if [ -d "api" ]; then
    mkdir -p ${PROJECT_DIR}/api
    cp -r api/* ${PROJECT_DIR}/api/
    echo -e "${GREEN}✓ API files copied${NC}"
else
    echo -e "${YELLOW}! No api directory found. Skipping...${NC}"
fi

# Set permissions
echo -e "${YELLOW}Setting file permissions...${NC}"
chown -R ${WEB_USER}:${WEB_GROUP} ${PROJECT_DIR}
find ${PROJECT_DIR} -type d -exec chmod 755 {} \;
find ${PROJECT_DIR} -type f -exec chmod 644 {} \;

if [ -d "${PROJECT_DIR}/api" ]; then
    chmod 750 ${PROJECT_DIR}/api
fi

echo -e "${GREEN}✓ File permissions set${NC}"

# Configure database
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 9: Configuring Database${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Creating database and user...${NC}"

mysql -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo -e "${GREEN}✓ Database created: ${DB_NAME}${NC}"
echo -e "${GREEN}✓ User created: ${DB_USER}${NC}"

# Import database schema
if [ -f "database/schema.sql" ]; then
    echo -e "${YELLOW}Importing database schema...${NC}"
    mysql -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" ${DB_NAME} < database/schema.sql
    echo -e "${GREEN}✓ Database schema imported${NC}"
else
    echo -e "${YELLOW}! No schema.sql found. You'll need to import manually.${NC}"
fi

# Create database configuration file
echo -e "${YELLOW}Creating database configuration file...${NC}"
cat > ${PROJECT_DIR}/api/db.ini <<EOF
[database]
host = localhost
dbname = ${DB_NAME}
username = ${DB_USER}
password = ${DB_PASS}
charset = utf8mb4
EOF

chmod 640 ${PROJECT_DIR}/api/db.ini
chown ${WEB_USER}:${WEB_GROUP} ${PROJECT_DIR}/api/db.ini

echo -e "${GREEN}✓ Database configuration saved${NC}"

# Install and configure Nginx
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 10: Configuring Web Server${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Installing ${WEB_SERVER}...${NC}"
$INSTALL_CMD ${WEB_SERVER}

# Create Nginx configuration
echo -e "${YELLOW}Creating Nginx configuration...${NC}"

if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    NGINX_CONF="${NGINX_CONF_DIR}/${PROJECT_NAME}"
else
    NGINX_CONF="${NGINX_CONF_DIR}/${PROJECT_NAME}.conf"
fi

cat > ${NGINX_CONF} <<'NGINX_EOF'
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER;

    root /var/www/PROJECT_NAME_PLACEHOLDER;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;

    # Angular routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API endpoint
    location /api/ {
        alias /var/www/PROJECT_NAME_PLACEHOLDER/api/;

        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/phpPHP_VERSION_PLACEHOLDER-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $request_filename;
        }
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }

    location ~ \.ini$ {
        deny all;
    }

    # Static file caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/PROJECT_NAME_PLACEHOLDER_access.log;
    error_log /var/log/nginx/PROJECT_NAME_PLACEHOLDER_error.log;
}
NGINX_EOF

# Replace placeholders
sed -i "s|DOMAIN_PLACEHOLDER|${DOMAIN}|g" ${NGINX_CONF}
sed -i "s|PROJECT_NAME_PLACEHOLDER|${PROJECT_NAME}|g" ${NGINX_CONF}
sed -i "s|PHP_VERSION_PLACEHOLDER|${PHP_VERSION}|g" ${NGINX_CONF}

# Enable site (for Ubuntu/Debian)
if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    ln -sf ${NGINX_CONF} ${NGINX_ENABLED_DIR}/${PROJECT_NAME}
fi

# Test Nginx configuration
echo -e "${YELLOW}Testing Nginx configuration...${NC}"
if nginx -t; then
    echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
else
    echo -e "${RED}✗ Nginx configuration test failed${NC}"
    exit 1
fi

# Restart Nginx
systemctl restart nginx
systemctl enable nginx

echo -e "${GREEN}✓ Nginx configured and started${NC}"

# Install SSL certificate with Certbot
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 11: Installing SSL Certificate${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

read -p "Install SSL certificate with Let's Encrypt? [Y/n]: " INSTALL_SSL
INSTALL_SSL=${INSTALL_SSL:-Y}

if [[ $INSTALL_SSL =~ ^[Yy]$ ]]; then
    # Install Certbot
    echo -e "${YELLOW}Installing Certbot...${NC}"

    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        $INSTALL_CMD certbot python3-certbot-nginx
    else
        $INSTALL_CMD certbot python3-certbot-nginx
    fi

    # Obtain SSL certificate
    echo -e "${YELLOW}Obtaining SSL certificate...${NC}"
    echo -e "${CYAN}Note: Make sure ${DOMAIN} points to this server's IP address${NC}\n"

    certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos --email ${EMAIL} --redirect

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ SSL certificate installed successfully${NC}"

        # Set up auto-renewal
        systemctl enable certbot.timer 2>/dev/null || true
        echo -e "${GREEN}✓ SSL auto-renewal enabled${NC}"
    else
        echo -e "${YELLOW}! SSL installation failed. You can try manually later with:${NC}"
        echo -e "${CYAN}sudo certbot --nginx -d ${DOMAIN}${NC}"
    fi
else
    echo -e "${YELLOW}Skipping SSL installation${NC}"
    echo -e "${CYAN}You can install it later with: sudo certbot --nginx -d ${DOMAIN}${NC}"
fi

# Create installation info file
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 12: Creating Installation Info${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

INFO_FILE="${PROJECT_DIR}/INSTALLATION_INFO.txt"

cat > ${INFO_FILE} <<EOF
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     AdminLTE Finance Portal - Installation Details       ║
║                 $(date)                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

SYSTEM INFORMATION
==================
Operating System: ${OS_NAME} ${VER}
Web Server: ${WEB_SERVER}
PHP Version: ${PHP_VERSION}
Node.js Version: $(node -v)
npm Version: $(npm -v)
Angular CLI: $(ng version --no-color | head -n 1)

PROJECT CONFIGURATION
=====================
Project Name: ${PROJECT_NAME}
Project Directory: ${PROJECT_DIR}
Domain: ${DOMAIN}
Admin Email: ${EMAIL}
API URL: ${API_URL}

DATABASE INFORMATION
====================
Database Name: ${DB_NAME}
Database User: ${DB_USER}
Database Host: localhost
MySQL Version: $(mysql --version)

IMPORTANT PATHS
===============
Nginx Config: ${NGINX_CONF}
PHP-FPM Socket: /run/php/php${PHP_VERSION}-fpm.sock
Database Config: ${PROJECT_DIR}/api/db.ini
SSL Certificates: /etc/letsencrypt/live/${DOMAIN}/ (if installed)

ACCESS INFORMATION
==================
Application URL: https://${DOMAIN}
HTTP URL: http://${DOMAIN} (redirects to HTTPS if SSL installed)
API Endpoint: ${API_URL}

SERVICES
========
Nginx Status: $(systemctl is-active nginx)
PHP-FPM Status: $(systemctl is-active php${PHP_VERSION}-fpm)
MySQL Status: $(systemctl is-active mysql 2>/dev/null || systemctl is-active mysqld)

USEFUL COMMANDS
===============
Restart Nginx: sudo systemctl restart nginx
Restart PHP-FPM: sudo systemctl restart php${PHP_VERSION}-fpm
Restart MySQL: sudo systemctl restart mysql (or mysqld)

View Nginx Logs: sudo tail -f /var/log/nginx/${PROJECT_NAME}_error.log
View PHP-FPM Logs: sudo journalctl -xeu php${PHP_VERSION}-fpm.service
View MySQL Logs: sudo tail -f /var/log/mysql/error.log

Test Nginx Config: sudo nginx -t
Test PHP-FPM Config: sudo php-fpm${PHP_VERSION} -t

SSL Certificate Renewal: sudo certbot renew --dry-run

DEFAULT CREDENTIALS
===================
You need to create an admin user in the database or via the API.
Refer to the API documentation for user creation endpoints.

SECURITY RECOMMENDATIONS
========================
1. Change database passwords regularly
2. Keep system packages updated: sudo apt update && sudo apt upgrade
3. Monitor logs for suspicious activity
4. Set up firewall rules (ufw or firewalld)
5. Enable fail2ban for brute-force protection
6. Regular database backups

BACKUP COMMANDS
===============
Database Backup:
mysqldump -u ${DB_USER} -p ${DB_NAME} > backup_$(date +%Y%m%d).sql

Restore Database:
mysql -u ${DB_USER} -p ${DB_NAME} < backup_file.sql

TROUBLESHOOTING
===============
If the application doesn't load:
1. Check Nginx: sudo systemctl status nginx
2. Check PHP-FPM: sudo systemctl status php${PHP_VERSION}-fpm
3. Check permissions: sudo chown -R ${WEB_USER}:${WEB_GROUP} ${PROJECT_DIR}
4. Check logs in /var/log/nginx/

If API calls fail:
1. Check database connection in ${PROJECT_DIR}/api/db.ini
2. Verify PHP-FPM is running
3. Check API logs in Nginx error log

SUPPORT
=======
For issues or questions, check:
- Nginx docs: https://nginx.org/en/docs/
- PHP-FPM docs: https://www.php.net/manual/en/install.fpm.php
- Angular docs: https://angular.io/docs
- MySQL docs: https://dev.mysql.com/doc/

═══════════════════════════════════════════════════════════

Installation completed successfully!
Generated by setup.sh v${VERSION}

EOF

chmod 644 ${INFO_FILE}
chown ${WEB_USER}:${WEB_GROUP} ${INFO_FILE}

echo -e "${GREEN}✓ Installation info saved to: ${INFO_FILE}${NC}"

# Display final summary
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║     Installation Completed Successfully! 🎉              ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Installation Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

echo -e "${CYAN}✓ System Packages:${NC} Updated and installed"
echo -e "${CYAN}✓ MySQL Server:${NC} Installed and configured"
echo -e "${CYAN}✓ PHP ${PHP_VERSION}:${NC} Installed with FPM"
echo -e "${CYAN}✓ Node.js & npm:${NC} Installed ($(node -v))"
echo -e "${CYAN}✓ Angular CLI:${NC} Installed globally"
echo -e "${CYAN}✓ Application:${NC} Built and deployed"
echo -e "${CYAN}✓ Database:${NC} ${DB_NAME} created"
echo -e "${CYAN}✓ Nginx:${NC} Configured and running"

if [[ $INSTALL_SSL =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}✓ SSL Certificate:${NC} Installed"
fi

echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Access Information${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

if [[ $INSTALL_SSL =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🌐 Application URL:${NC} ${CYAN}https://${DOMAIN}${NC}"
else
    echo -e "${GREEN}🌐 Application URL:${NC} ${CYAN}http://${DOMAIN}${NC}"
fi

echo -e "${GREEN}🔌 API Endpoint:${NC} ${CYAN}${API_URL}${NC}"
echo -e "${GREEN}📁 Project Directory:${NC} ${CYAN}${PROJECT_DIR}${NC}"
echo -e "${GREEN}📄 Installation Info:${NC} ${CYAN}${INFO_FILE}${NC}"

echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Service Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Nginx:${NC} $(systemctl is-active nginx)"
echo -e "${YELLOW}PHP-FPM:${NC} $(systemctl is-active php${PHP_VERSION}-fpm)"
echo -e "${YELLOW}MySQL:${NC} $(systemctl is-active mysql 2>/dev/null || systemctl is-active mysqld)"

echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Next Steps${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

echo -e "1. ${CYAN}Access your application:${NC} https://${DOMAIN}"
echo -e "2. ${CYAN}Create admin user:${NC} Use the API or database"
echo -e "3. ${CYAN}Configure firewall:${NC} sudo ufw allow 'Nginx Full'"
echo -e "4. ${CYAN}Set up backups:${NC} Regular database dumps"
echo -e "5. ${CYAN}Monitor logs:${NC} Check ${PROJECT_DIR}/INSTALLATION_INFO.txt"

echo -e "\n${YELLOW}═══════════════════════════════════════${NC}"
echo -e "${YELLOW}  Important Security Notes${NC}"
echo -e "${YELLOW}═══════════════════════════════════════${NC}\n"

echo -e "⚠️  Database credentials are stored in: ${CYAN}${PROJECT_DIR}/api/db.ini${NC}"
echo -e "⚠️  Make sure this file is not publicly accessible"
echo -e "⚠️  Change default passwords regularly"
echo -e "⚠️  Keep your system updated: ${CYAN}sudo apt update && sudo apt upgrade${NC}"

echo -e "\n${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  Useful Commands${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}\n"

echo -e "Restart Nginx:     ${CYAN}sudo systemctl restart nginx${NC}"
echo -e "Restart PHP-FPM:   ${CYAN}sudo systemctl restart php${PHP_VERSION}-fpm${NC}"
echo -e "Restart MySQL:     ${CYAN}sudo systemctl restart mysql${NC}"
echo -e "View Error Logs:   ${CYAN}sudo tail -f /var/log/nginx/${PROJECT_NAME}_error.log${NC}"
echo -e "Test Nginx Config: ${CYAN}sudo nginx -t${NC}"
echo -e "Renew SSL:         ${CYAN}sudo certbot renew${NC}"

echo -e "\n${GREEN}Thank you for using AdminLTE Finance Portal Setup!${NC}\n"
echo -e "${BLUE}For support and updates, visit the project repository.${NC}\n"

# Create a quick status check script
cat > /usr/local/bin/finance-status <<'STATUS_EOF'
#!/bin/bash
echo "AdminLTE Finance Portal - System Status"
echo "========================================"
echo ""
echo "Services:"
echo "  Nginx:   $(systemctl is-active nginx)"
echo "  PHP-FPM: $(systemctl is-active phpPHP_VERSION_PLACEHOLDER-fpm)"
echo "  MySQL:   $(systemctl is-active mysql 2>/dev/null || systemctl is-active mysqld)"
echo ""
echo "Disk Usage:"
df -h /var/www/PROJECT_NAME_PLACEHOLDER | tail -n 1
echo ""
echo "Recent Errors (last 5):"
sudo tail -n 5 /var/log/nginx/PROJECT_NAME_PLACEHOLDER_error.log 2>/dev/null || echo "No errors"
STATUS_EOF

sed -i "s|PHP_VERSION_PLACEHOLDER|${PHP_VERSION}|g" /usr/local/bin/finance-status
sed -i "s|PROJECT_NAME_PLACEHOLDER|${PROJECT_NAME}|g" /usr/local/bin/finance-status
chmod +x /usr/local/bin/finance-status

echo -e "${CYAN}Quick status check command created: ${GREEN}finance-status${NC}\n"

exit 0

