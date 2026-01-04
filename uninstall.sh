#!/bin/bash
# uninstall.sh - Complete uninstaller for AdminLTE Finance Portal
# Version: 1.1 - Fixed MySQL removal

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logo
echo -e "${RED}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     AdminLTE Finance Portal - Uninstaller v1.1           ║
║                                                           ║
║     ⚠️  WARNING: This will remove ALL components!        ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

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
        echo -e "${RED}Cannot detect OS.${NC}"
        exit 1
    fi

    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt"
            WEB_USER="www-data"
            ;;
        rhel|centos|rocky|almalinux|fedora)
            PKG_MANAGER="yum"
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            fi
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
echo -e "${RED}║                    FINAL WARNING!                         ║${NC}"
echo -e "${RED}║  This action CANNOT be undone!                            ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}You are about to remove:${NC}"
[[ $REMOVE_PROJECT =~ ^[Yy]$ ]] && echo -e "  • Project files"
[[ $REMOVE_DATABASE =~ ^[Yy]$ ]] && echo -e "  • Database (ALL DATA)"
[[ $REMOVE_MYSQL =~ ^[Yy]$ ]] && echo -e "  • MySQL server"
[[ $REMOVE_WEBSERVER =~ ^[Yy]$ ]] && echo -e "  • Web server"
[[ $REMOVE_PHP =~ ^[Yy]$ ]] && echo -e "  • PHP"
[[ $REMOVE_NODEJS =~ ^[Yy]$ ]] && echo -e "  • Node.js"
[[ $REMOVE_SSL =~ ^[Yy]$ ]] && echo -e "  • SSL certificates"

echo ""
read -p "Type 'REMOVE' to continue: " CONFIRMATION

if [ "$CONFIRMATION" != "REMOVE" ]; then
    echo -e "${GREEN}Cancelled.${NC}"
    exit 0
fi

echo -e "\n${BLUE}Starting Uninstallation...${NC}\n"

# Create backup directory
BACKUP_DIR="${HOME}/adminlte_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup database
if [[ $REMOVE_DATABASE =~ ^[Yy]$ ]] && command -v mysql &> /dev/null; then
    echo -e "${YELLOW}Backing up database...${NC}"
    read -p "MySQL Root Username [root]: " MYSQL_ROOT_USER
    MYSQL_ROOT_USER=${MYSQL_ROOT_USER:-root}
    read -sp "MySQL Root Password: " MYSQL_ROOT_PASS
    echo ""
    read -p "Database Name [adminlte_finance]: " DB_NAME
    DB_NAME=${DB_NAME:-adminlte_finance}

    if mysqldump -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}.sql" 2>/dev/null; then
        echo -e "${GREEN}✓ Database backed up${NC}"
    else
        echo -e "${YELLOW}! Backup failed or database doesn't exist${NC}"
    fi
fi

# 1. Remove SSL
if [[ $REMOVE_SSL =~ ^[Yy]$ ]] && [ ! -z "$DOMAIN" ]; then
    echo -e "\n${YELLOW}[1/7] Removing SSL...${NC}"
    certbot delete --cert-name "$DOMAIN" --non-interactive 2>/dev/null || true
    echo -e "${GREEN}✓ SSL removed${NC}"
fi

# 2. Remove web server config
echo -e "\n${YELLOW}[2/7] Removing web server config...${NC}"
if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
    rm -f "/etc/nginx/sites-enabled/${PROJECT_NAME}" 2>/dev/null || true
    rm -f "/etc/nginx/sites-available/${PROJECT_NAME}" 2>/dev/null || true
    rm -f "/etc/apache2/sites-available/${PROJECT_NAME}.conf" 2>/dev/null || true
    a2dissite "${PROJECT_NAME}" 2>/dev/null || true
else
    rm -f "/etc/nginx/conf.d/${PROJECT_NAME}.conf" 2>/dev/null || true
    rm -f "/etc/httpd/conf.d/${PROJECT_NAME}.conf" 2>/dev/null || true
fi
systemctl reload nginx 2>/dev/null || true
systemctl reload apache2 2>/dev/null || true
systemctl reload httpd 2>/dev/null || true
echo -e "${GREEN}✓ Config removed${NC}"

# 3. Remove project files
if [[ $REMOVE_PROJECT =~ ^[Yy]$ ]] && [ -d "$PROJECT_DIR" ]; then
    echo -e "\n${YELLOW}[3/7] Removing project files...${NC}"
    cp "${PROJECT_DIR}/api/db.ini" "$BACKUP_DIR/" 2>/dev/null || true
    cp "${PROJECT_DIR}/INSTALLATION_INFO.txt" "$BACKUP_DIR/" 2>/dev/null || true
    rm -rf "$PROJECT_DIR"
    echo -e "${GREEN}✓ Project removed${NC}"
fi

# 4. Remove database
if [[ $REMOVE_DATABASE =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[4/7] Removing database...${NC}"
    read -p "Database User [finance_user]: " DB_USER
    DB_USER=${DB_USER:-finance_user}

    mysql -u "$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASS" <<MYSQL_SCRIPT 2>/dev/null || true
DROP DATABASE IF EXISTS ${DB_NAME};
DROP USER IF EXISTS '${DB_USER}'@'localhost';
DROP USER IF EXISTS '${DB_USER}'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    echo -e "${GREEN}✓ Database removed${NC}"
fi

# 5. Remove MySQL (FIXED)
if [[ $REMOVE_MYSQL =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[5/7] Removing MySQL properly...${NC}"

    case $OS in
        ubuntu|debian)
            # Stop MySQL
            systemctl stop mysql 2>/dev/null || true
            killall -9 mysqld 2>/dev/null || true

            # Complete purge
            echo -e "${CYAN}Purging MySQL packages...${NC}"
            apt remove --purge -y mysql-server mysql-server-* mysql-client mysql-common mysql-community-server 2>/dev/null || true
            apt autoremove -y
            apt autoclean

            # Remove all MySQL directories
            echo -e "${CYAN}Removing MySQL directories...${NC}"
            rm -rf /var/lib/mysql
            rm -rf /var/log/mysql
            rm -rf /etc/mysql
            rm -rf /var/run/mysqld
            rm -rf /usr/lib/mysql
            rm -rf /usr/share/mysql

            # Clean dpkg state
            echo -e "${CYAN}Cleaning dpkg state...${NC}"
            dpkg --configure -a
            apt --fix-broken install -y

            # Remove MySQL user/group
            userdel mysql 2>/dev/null || true
            groupdel mysql 2>/dev/null || true
            ;;

        rhel|centos|rocky|almalinux|fedora)
            systemctl stop mysqld 2>/dev/null || true
            killall -9 mysqld 2>/dev/null || true

            $PKG_MANAGER remove -y mysql-server mysql mysql-common
            $PKG_MANAGER clean all

            rm -rf /var/lib/mysql
            rm -rf /var/log/mysql
            rm -rf /etc/my.cnf
            rm -rf /etc/my.cnf.d

            userdel mysql 2>/dev/null || true
            groupdel mysql 2>/dev/null || true
            ;;
    esac

    echo -e "${GREEN}✓ MySQL completely removed${NC}"
fi

# 6. Remove web server
if [[ $REMOVE_WEBSERVER =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[6/7] Removing web server...${NC}"

    case $OS in
        ubuntu|debian)
            if systemctl is-active --quiet nginx; then
                systemctl stop nginx
                apt remove --purge -y nginx nginx-common nginx-core
                rm -rf /etc/nginx
            fi

            if systemctl is-active --quiet apache2; then
                systemctl stop apache2
                apt remove --purge -y apache2 apache2-*
                rm -rf /etc/apache2
            fi
            ;;
        *)
            if systemctl is-active --quiet nginx; then
                systemctl stop nginx
                $PKG_MANAGER remove -y nginx
                rm -rf /etc/nginx
            fi

            if systemctl is-active --quiet httpd; then
                systemctl stop httpd
                $PKG_MANAGER remove -y httpd
                rm -rf /etc/httpd
            fi
            ;;
    esac
    echo -e "${GREEN}✓ Web server removed${NC}"
fi

# 7. Remove PHP
if [[ $REMOVE_PHP =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[7/7] Removing PHP...${NC}"

    case $OS in
        ubuntu|debian)
            # Stop all PHP-FPM services
            for svc in $(systemctl list-units --type=service | grep php.*fpm | awk '{print $1}'); do
                systemctl stop $svc 2>/dev/null || true
            done

            # Remove all PHP packages
            apt remove --purge -y php* libapache2-mod-php*
            rm -rf /etc/php
            ;;
        *)
            systemctl stop php-fpm 2>/dev/null || true
            $PKG_MANAGER remove -y php php-*
            rm -rf /etc/php.ini
            rm -rf /etc/php-fpm.d
            ;;
    esac
    echo -e "${GREEN}✓ PHP removed${NC}"
fi

# 8. Remove Node.js
if [[ $REMOVE_NODEJS =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[Bonus] Removing Node.js...${NC}"
    npm uninstall -g @angular/cli 2>/dev/null || true

    case $OS in
        ubuntu|debian)
            apt remove --purge -y nodejs npm
            rm -rf /etc/apt/sources.list.d/nodesource.list
            ;;
        *)
            $PKG_MANAGER remove -y nodejs npm
            rm -rf /etc/yum.repos.d/nodesource*.repo
            ;;
    esac

    rm -rf ~/.npm
    rm -rf /usr/lib/node_modules
    echo -e "${GREEN}✓ Node.js removed${NC}"
fi

# Final cleanup
echo -e "\n${YELLOW}Final cleanup...${NC}"
case $OS in
    ubuntu|debian)
        apt autoremove -y
        apt autoclean
        dpkg --configure -a
        apt --fix-broken install -y
        ;;
    *)
        $PKG_MANAGER autoremove -y
        $PKG_MANAGER clean all
        ;;
esac

# Summary
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Uninstallation Completed Successfully!           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Backup saved to:${NC} ${CYAN}$BACKUP_DIR${NC}\n"
ls -lh "$BACKUP_DIR" 2>/dev/null || true

echo -e "${GREEN}System is now clean and ready for fresh installation!${NC}\n"

exit 0
