#!/bin/bash
# uninstall.sh - Complete uninstaller for AdminLTE Finance Portal
# This script removes all components installed by setup.sh
# Version: 1.0

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logo
echo -e "${RED}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     AdminLTE Finance Portal - Uninstaller v1.0           ║
║                                                           ║
║     ⚠️  WARNING: This will remove ALL components!        ║
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
            REMOVE_CMD="apt remove -y"
            AUTOREMOVE_CMD="apt autoremove -y"
            WEB_USER="www-data"
            ;;
        rhel|centos|rocky|almalinux|fedora)
            PKG_MANAGER="yum"
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            fi
            REMOVE_CMD="$PKG_MANAGER remove -y"
            AUTOREMOVE_CMD="$PKG_MANAGER autoremove -y"
            WEB_USER="apache"
            ;;
        *)
            echo -e "${RED}Unsupported OS: $OS${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}✓ Detected OS: $OS $VER${NC}"
}

detect_os

# Configuration
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Uninstallation Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

read -p "Project directory name [adminlte-finance]: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-adminlte-finance}
PROJECT_DIR="/var/www/${PROJECT_NAME}"

read -p "Domain name (e.g., finance.example.com): " DOMAIN

echo -e "\n${YELLOW}Select what to remove:${NC}\n"
read -p "Remove project files? [Y/n]: " REMOVE_PROJECT
REMOVE_PROJECT=${REMOVE_PROJECT:-Y}

read -p "Remove database? (WARNING: This deletes all data!) [y/N]: " REMOVE_DATABASE
REMOVE_DATABASE=${REMOVE_DATABASE:-N}

read -p "Remove MySQL completely? [y/N]: " REMOVE_MYSQL
REMOVE_MYSQL=${REMOVE_MYSQL:-N}

read -p "Remove web server (Nginx/Apache)? [y/N]: " REMOVE_WEBSERVER
REMOVE_WEBSERVER=${REMOVE_WEBSERVER:-N}

read -p "Remove PHP? [y/N]: " REMOVE_PHP
REMOVE_PHP=${REMOVE_PHP:-N}

read -p "Remove Node.js and npm? [y/N]: " REMOVE_NODEJS
REMOVE_NODEJS=${REMOVE_NODEJS:-N}

read -p "Remove SSL certificates? [y/N]: " REMOVE_SSL
REMOVE_SSL=${REMOVE_SSL:-N}

# Final confirmation
echo -e "\n${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                                                           ║${NC}"
echo -e "${RED}║                    FINAL WARNING!                         ║${NC}"
echo -e "${RED}║                                                           ║${NC}"
echo -e "${RED}║  This action CANNOT be undone!                            ║${NC}"
echo -e "${RED}║                                                           ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}You are about to remove:${NC}"
[[ $REMOVE_PROJECT =~ ^[Yy]$ ]] && echo -e "  • Project files from ${PROJECT_DIR}"
[[ $REMOVE_DATABASE =~ ^[Yy]$ ]] && echo -e "  • Database (ALL DATA WILL BE LOST!)"
[[ $REMOVE_MYSQL =~ ^[Yy]$ ]] && echo -e "  • MySQL server"
[[ $REMOVE_WEBSERVER =~ ^[Yy]$ ]] && echo -e "  • Web server (Nginx/Apache)"
[[ $REMOVE_PHP =~ ^[Yy]$ ]] && echo -e "  • PHP"
[[ $REMOVE_NODEJS =~ ^[Yy]$ ]] && echo -e "  • Node.js and npm"
[[ $REMOVE_SSL =~ ^[Yy]$ ]] && echo -e "  • SSL certificates"

echo ""
read -p "Type 'REMOVE' to continue: " CONFIRMATION

if [ "$CONFIRMATION" != "REMOVE" ]; then
    echo -e "${GREEN}Uninstallation cancelled.${NC}"
    exit 0
fi

# Start uninstallation
echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Starting Uninstallation...${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

# Backup database before removal
if [[ $REMOVE_DATABASE =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Creating database backup before removal...${NC}"
    read -p "MySQL Root Username [root]: " MYSQL_ROOT_USER
    MYSQL_ROOT_USER=${MYSQL_ROOT_USER:-root}
    read -sp "MySQL Root Password: " MYSQL_ROOT_PASS
    echo ""
    read -p "Database Name [adminlte_finance]: " DB_NAME
    DB_NAME=${DB_NAME:-adminlte_finance}

    BACKUP_DIR="${HOME}/adminlte_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    if mysqldump -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}.sql" 2>/dev/null; then
        echo -e "${GREEN}✓ Database backed up to: $BACKUP_DIR/${DB_NAME}.sql${NC}"
    else
        echo -e "${YELLOW}! Database backup failed (may not exist)${NC}"
    fi
fi

# 1. Remove SSL Certificates
if [[ $REMOVE_SSL =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[1/7] Removing SSL certificates...${NC}"
    if command -v certbot &> /dev/null && [ ! -z "$DOMAIN" ]; then
        certbot delete --cert-name "$DOMAIN" --non-interactive || echo -e "${YELLOW}! SSL removal failed${NC}"
        echo -e "${GREEN}✓ SSL certificates removed${NC}"
    else
        echo -e "${YELLOW}! Certbot not found or domain not specified${NC}"
    fi
else
    echo -e "\n${CYAN}[1/7] Skipping SSL certificates removal${NC}"
fi

# 2. Remove Web Server Configuration
echo -e "\n${YELLOW}[2/7] Removing web server configuration...${NC}"

if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    # Nginx
    if [ -f "/etc/nginx/sites-available/${PROJECT_NAME}" ]; then
        rm -f "/etc/nginx/sites-enabled/${PROJECT_NAME}"
        rm -f "/etc/nginx/sites-available/${PROJECT_NAME}"
        systemctl reload nginx 2>/dev/null || true
        echo -e "${GREEN}✓ Nginx configuration removed${NC}"
    fi

    # Apache
    if [ -f "/etc/apache2/sites-available/${PROJECT_NAME}.conf" ]; then
        a2dissite "${PROJECT_NAME}" 2>/dev/null || true
        rm -f "/etc/apache2/sites-available/${PROJECT_NAME}.conf"
        systemctl reload apache2 2>/dev/null || true
        echo -e "${GREEN}✓ Apache configuration removed${NC}"
    fi
else
    # RHEL-based
    if [ -f "/etc/nginx/conf.d/${PROJECT_NAME}.conf" ]; then
        rm -f "/etc/nginx/conf.d/${PROJECT_NAME}.conf"
        systemctl reload nginx 2>/dev/null || true
        echo -e "${GREEN}✓ Nginx configuration removed${NC}"
    fi

    if [ -f "/etc/httpd/conf.d/${PROJECT_NAME}.conf" ]; then
        rm -f "/etc/httpd/conf.d/${PROJECT_NAME}.conf"
        systemctl reload httpd 2>/dev/null || true
        echo -e "${GREEN}✓ Apache configuration removed${NC}"
    fi
fi

# 3. Remove Project Files
if [[ $REMOVE_PROJECT =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[3/7] Removing project files...${NC}"
    if [ -d "$PROJECT_DIR" ]; then
        # Backup important files
        BACKUP_DIR="${HOME}/adminlte_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"

        if [ -f "${PROJECT_DIR}/api/db.ini" ]; then
            cp "${PROJECT_DIR}/api/db.ini" "$BACKUP_DIR/" 2>/dev/null || true
        fi

        if [ -f "${PROJECT_DIR}/INSTALLATION_INFO.txt" ]; then
            cp "${PROJECT_DIR}/INSTALLATION_INFO.txt" "$BACKUP_DIR/" 2>/dev/null || true
        fi

        echo -e "${CYAN}Backing up configuration to: $BACKUP_DIR${NC}"

        rm -rf "$PROJECT_DIR"
        echo -e "${GREEN}✓ Project files removed${NC}"
    else
        echo -e "${YELLOW}! Project directory not found: $PROJECT_DIR${NC}"
    fi
else
    echo -e "\n${CYAN}[3/7] Skipping project files removal${NC}"
fi

# 4. Remove Database
if [[ $REMOVE_DATABASE =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[4/7] Removing database...${NC}"

    read -p "Database User [finance_user]: " DB_USER
    DB_USER=${DB_USER:-finance_user}

    if mysql -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" <<MYSQL_SCRIPT 2>/dev/null
DROP DATABASE IF EXISTS ${DB_NAME};
DROP USER IF EXISTS '${DB_USER}'@'localhost';
DROP USER IF EXISTS '${DB_USER}'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    then
        echo -e "${GREEN}✓ Database and user removed${NC}"
    else
        echo -e "${RED}✗ Failed to remove database${NC}"
    fi
else
    echo -e "\n${CYAN}[4/7] Skipping database removal${NC}"
fi

# 5. Remove MySQL
if [[ $REMOVE_MYSQL =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[5/7] Removing MySQL...${NC}"

    case $OS in
        ubuntu|debian)
            systemctl stop mysql 2>/dev/null || true
            $REMOVE_CMD mysql-server mysql-client
            rm -rf /var/lib/mysql
            rm -rf /etc/mysql
            ;;
        rhel|centos|rocky|almalinux|fedora)
            systemctl stop mysqld 2>/dev/null || true
            $REMOVE_CMD mysql-server mysql
            rm -rf /var/lib/mysql
            rm -rf /etc/my.cnf
            ;;
    esac

    echo -e "${GREEN}✓ MySQL removed${NC}"
else
    echo -e "\n${CYAN}[5/7] Skipping MySQL removal${NC}"
fi

# 6. Remove Web Server
if [[ $REMOVE_WEBSERVER =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[6/7] Removing web server...${NC}"

    case $OS in
        ubuntu|debian)
            if systemctl is-active --quiet nginx; then
                systemctl stop nginx
                $REMOVE_CMD nginx
                rm -rf /etc/nginx
                echo -e "${GREEN}✓ Nginx removed${NC}"
            fi

            if systemctl is-active --quiet apache2; then
                systemctl stop apache2
                $REMOVE_CMD apache2
                rm -rf /etc/apache2
                echo -e "${GREEN}✓ Apache removed${NC}"
            fi
            ;;
        rhel|centos|rocky|almalinux|fedora)
            if systemctl is-active --quiet nginx; then
                systemctl stop nginx
                $REMOVE_CMD nginx
                rm -rf /etc/nginx
                echo -e "${GREEN}✓ Nginx removed${NC}"
            fi

            if systemctl is-active --quiet httpd; then
                systemctl stop httpd
                $REMOVE_CMD httpd
                rm -rf /etc/httpd
                echo -e "${GREEN}✓ Apache removed${NC}"
            fi
            ;;
    esac
else
    echo -e "\n${CYAN}[6/7] Skipping web server removal${NC}"
fi

# 7. Remove PHP
if [[ $REMOVE_PHP =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[7/7] Removing PHP...${NC}"

    case $OS in
        ubuntu|debian)
            # Detect installed PHP version
            PHP_VERSIONS=$(dpkg -l | grep -oP 'php\d+\.\d+' | sort -u)

            for PHP_VER in $PHP_VERSIONS; do
                echo -e "${CYAN}Removing PHP $PHP_VER...${NC}"
                systemctl stop ${PHP_VER}-fpm 2>/dev/null || true
                $REMOVE_CMD ${PHP_VER}* libapache2-mod-${PHP_VER}
            done

            rm -rf /etc/php
            ;;
        rhel|centos|rocky|almalinux|fedora)
            systemctl stop php-fpm 2>/dev/null || true
            $REMOVE_CMD php php-*
            rm -rf /etc/php.ini
            rm -rf /etc/php-fpm.d
            ;;
    esac

    echo -e "${GREEN}✓ PHP removed${NC}"
else
    echo -e "\n${CYAN}[7/7] Skipping PHP removal${NC}"
fi

# 8. Remove Node.js (Bonus)
if [[ $REMOVE_NODEJS =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[Bonus] Removing Node.js and npm...${NC}"

    # Remove global Angular CLI
    npm uninstall -g @angular/cli 2>/dev/null || true

    case $OS in
        ubuntu|debian)
            $REMOVE_CMD nodejs npm
            rm -rf /etc/apt/sources.list.d/nodesource.list
            rm -rf ~/.npm
            rm -rf /usr/lib/node_modules
            ;;
        rhel|centos|rocky|almalinux|fedora)
            $REMOVE_CMD nodejs npm
            rm -rf /etc/yum.repos.d/nodesource*.repo
            rm -rf ~/.npm
            rm -rf /usr/lib/node_modules
            ;;
    esac

    echo -e "${GREEN}✓ Node.js and npm removed${NC}"
fi

# Autoremove
echo -e "\n${YELLOW}Cleaning up unused packages...${NC}"
$AUTOREMOVE_CMD 2>/dev/null || true

# Final Summary
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║           Uninstallation Completed!                       ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Uninstallation Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}\n"

[[ $REMOVE_PROJECT =~ ^[Yy]$ ]] && echo -e "${GREEN}✓ Project files removed${NC}"
[[ $REMOVE_DATABASE =~ ^[Yy]$ ]] && echo -e "${GREEN}✓ Database removed${NC}"
[[ $REMOVE_MYSQL =~ ^[Yy]$ ]] && echo -e "${GREEN}✓ MySQL removed${NC}"
[[ $REMOVE_WEBSERVER =~ ^[Yy]$ ]] && echo -e "${GREEN}✓ Web server removed${NC}"
[[ $REMOVE_PHP =~ ^[Yy]$ ]] && echo -e "${GREEN}✓ PHP removed${NC}"
[[ $REMOVE_NODEJS =~ ^[Yy]$ ]] && echo -e "${GREEN}✓ Node.js removed${NC}"
[[ $REMOVE_SSL =~ ^[Yy]$ ]] && echo -e "${GREEN}✓ SSL certificates removed${NC}"

if [ -d "$BACKUP_DIR" ]; then
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  Backup Location${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"
    echo -e "${YELLOW}Configuration backup saved to:${NC}"
    echo -e "${CYAN}$BACKUP_DIR${NC}\n"
    ls -lh "$BACKUP_DIR"
fi

echo -e "\n${YELLOW}Note: Some configuration files may remain in system directories.${NC}"
echo -e "${YELLOW}You can manually remove them if needed.${NC}\n"

exit 0
