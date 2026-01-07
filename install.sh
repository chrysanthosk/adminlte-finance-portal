
#!/bin/bash

# ==============================================================================
# Finance Portal Installation Script
# ==============================================================================
# This script automates the deployment of the Finance Portal on a fresh
# Linux server (Ubuntu/Debian or Red Hat/CentOS/Fedora).
#
# It will:
#   1. Detect the Linux distribution.
#   2. Install dependencies: Nginx, PostgreSQL, Node.js (v20), PM2.
#   3. Set up a PostgreSQL database and user.
#   4. Configure the backend API with a .env file.
#   5. Build the Angular frontend for production.
#   6. Configure Nginx, Domain, and SSL (Let's Encrypt or Manual/Wildcard).
#   7. Start the API server with PM2 for process management.
#
# USAGE:
#   1. Point your domain's A record to this server's IP address.
#   2. Upload your project folder to the server.
#   3. Navigate into the project folder.
#   4. Make this script executable: chmod +x install.sh
#   5. Run with sudo: sudo ./install.sh
# ==============================================================================

# --- Configuration ---
NODE_MAJOR=20
APP_DIR=$(pwd)
NGINX_CONF_FILE="/etc/nginx/sites-available/finance-portal"
NGINX_LINK_FILE="/etc/nginx/sites-enabled/finance-portal"

# --- Script Setup ---
set -e # Exit immediately if a command exits with a non-zero status.

# --- Helper Functions ---
print_info() {
    echo -e "\n\e[1;34m[INFO]\e[0m $1"
}

print_success() {
    echo -e "\e[1;32m[SUCCESS]\e[0m $1"
}

print_error() {
    echo -e "\e[1;31m[ERROR]\e[0m $1" >&2
    exit 1
}

# --- Main Script ---

# 1. Root Check
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root. Please use sudo."
fi

print_info "Starting Finance Portal setup..."
print_info "Application Directory: $APP_DIR"

# 2. Detect Distribution and Install Dependencies
print_info "Detecting Linux distribution and installing dependencies..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    print_error "Cannot detect Linux distribution."
fi

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    PKG_MANAGER="apt-get"
    $PKG_MANAGER update
    $PKG_MANAGER install -y curl nginx postgresql postgresql-contrib software-properties-common
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" || "$OS" == "almalinux" ]]; then
    PKG_MANAGER="dnf"
    if ! command -v dnf &> /dev/null; then PKG_MANAGER="yum"; fi
    $PKG_MANAGER install -y curl nginx postgresql-server epel-release
    postgresql-setup --initdb
else
    print_error "Unsupported distribution: $OS"
fi

# Install Node.js and PM2
print_info "Installing Node.js v$NODE_MAJOR and PM2..."
curl -fsSL "https://deb.nodesource.com/setup_$NODE_MAJOR.x" | bash -
$PKG_MANAGER install -y nodejs
npm install -g pm2

print_success "All system dependencies installed."

# 3. PostgreSQL Setup
print_info "Configuring PostgreSQL database..."
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    systemctl start postgresql
    systemctl enable postgresql
else
    systemctl start postgresql
    systemctl enable postgresql
fi

read -p "Enter database name [finance_portal]: " DB_NAME
DB_NAME=${DB_NAME:-finance_portal}
read -p "Enter database user [finance_user]: " DB_USER
DB_USER=${DB_USER:-finance_user}
read -s -p "Enter password for new database user: " DB_PASS
echo
if [ -z "$DB_PASS" ]; then
    print_error "Password cannot be empty."
fi

sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" &>/dev/null || print_info "Database '$DB_NAME' already exists."
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" &>/dev/null || print_info "User '$DB_USER' already exists. Setting password."
sudo -u postgres psql -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

print_info "Populating database schema from db_setup.txt..."
cat "$APP_DIR/db_setup.txt" | sudo -u postgres psql -v ON_ERROR_STOP=1 -d $DB_NAME
print_success "Database setup is complete."

# 4. Backend Configuration
print_info "Configuring Node.js backend..."
cd "$APP_DIR/api"
cat > .env << EOF
DB_HOST=localhost
DB_PORT=5432
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASS
DB_DATABASE=$DB_NAME
EOF
print_info "Installing backend dependencies (npm install)..."
npm install
cd "$APP_DIR"
print_success "Backend configured."

# 5. Frontend Build
print_info "Installing frontend build tools and building the app..."
npm install
npm run build
print_success "Frontend built successfully into '$APP_DIR/dist'."

print_info "Setting permissions for Nginx..."
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    chown -R www-data:www-data "$APP_DIR/dist"
else
    chown -R nginx:nginx "$APP_DIR/dist"
fi
print_success "Web directory permissions set."

# 6. Nginx, Domain, and SSL Configuration
print_info "Configuring Nginx reverse proxy, domain, and SSL..."
read -p "Enter the domain name for this application (e.g., finance.yourcompany.com): " DOMAIN_NAME
if [ -z "$DOMAIN_NAME" ]; then
    print_error "Domain name cannot be empty."
fi

USE_SSL=""
read -p "Do you want to configure SSL (HTTPS) for this domain? (Recommended) (y/n): " response
if [[ "$response" == "y" || "$response" == "Y" ]]; then
    USE_SSL="true"
fi

if [ "$USE_SSL" == "true" ]; then
    USE_CERTBOT=""
    read -p "Use a free certificate from Let's Encrypt (Certbot)? (Requires a public server) (y/n): " response
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        USE_CERTBOT="true"
    fi

    if [ "$USE_CERTBOT" == "true" ]; then
        print_info "Setting up SSL with Certbot..."
        if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            add-apt-repository -y ppa:certbot/certbot
            apt-get update
            apt-get install -y certbot python3-certbot-nginx
        else
            dnf install -y certbot python3-certbot-nginx
        fi
        
        print_info "Creating initial Nginx config for Certbot validation..."
        cat > $NGINX_CONF_FILE << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME};
    root ${APP_DIR}/dist;
    index index.html;
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
        ln -s -f $NGINX_CONF_FILE $NGINX_LINK_FILE
        systemctl reload nginx

        read -p "Enter your email for Let's Encrypt renewal notices: " CERTBOT_EMAIL
        if [ -z "$CERTBOT_EMAIL" ]; then
            print_error "Email is required for Certbot."
        fi

        print_info "Running Certbot... This may take a moment."
        certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos -m $CERTBOT_EMAIL --redirect
        
        print_info "Updating Nginx config to include API proxy..."
        cat > $NGINX_CONF_FILE << EOF
server {
    server_name ${DOMAIN_NAME};
    root ${APP_DIR}/dist;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    listen [::]:443 ssl ipv6only=on;
    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
server {
    if (\$host = ${DOMAIN_NAME}) {
        return 301 https://\$host\$request_uri;
    }
    listen 80;
    server_name ${DOMAIN_NAME};
    return 404;
}
EOF
    else
        print_info "Configuring manual SSL. This is the correct option for commercial or wildcard certificates."
        read -p "Enter the full path to your SSL certificate file (e.g., /etc/ssl/certs/fullchain.pem): " SSL_CERT_PATH
        read -p "Enter the full path to your SSL private key file (e.g., /etc/ssl/private/privkey.pem): " SSL_KEY_PATH
        if [ ! -f "$SSL_CERT_PATH" ] || [ ! -f "$SSL_KEY_PATH" ]; then
            print_error "One or both certificate files not found at the specified paths."
        fi
        
        cat > $NGINX_CONF_FILE << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME};
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name ${DOMAIN_NAME};

    ssl_certificate ${SSL_CERT_PATH};
    ssl_certificate_key ${SSL_KEY_PATH};
    ssl_protocols TLSv1.2 TLSv1.3;

    root ${APP_DIR}/dist;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    fi
else
    print_info "Configuring Nginx without SSL. This is not recommended for production."
    cat > $NGINX_CONF_FILE << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME};
    root ${APP_DIR}/dist;
    index index.html;
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
fi

if [ -f /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
fi
ln -s -f $NGINX_CONF_FILE $NGINX_LINK_FILE

print_info "Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 'Nginx Full'
    ufw allow ssh
    ufw --force enable
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
fi

nginx -t
systemctl reload nginx
print_success "Nginx configured and reloaded."

# 7. Start API with PM2
print_info "Starting API server with PM2..."
cd "$APP_DIR/api"
pm2 start index.js --name "finance-api"
pm2 save
pm2 startup

print_success "API server is running under PM2."

# --- Final Instructions ---
echo
echo -e "\e[1;32m================================================================"
echo -e "           🚀 INSTALLATION COMPLETE! 🚀"
echo -e "================================================================"
echo
echo "Your Finance Portal is now running."
if [ "$USE_SSL" == "true" ]; then
    echo "You can access it at: \e[1;36mhttps://${DOMAIN_NAME}\e[0m"
else
    echo "You can access it at: \e[1;36mhttp://${DOMAIN_NAME}\e[0m"
fi
echo
echo "To ensure your API server restarts automatically on server reboot, please"
echo "run the following command (generated by PM2), then press Enter:"
echo
echo -e "\e[1;33m"
PM2_STARTUP_CMD=$(pm2 startup | tail -n 1)
echo "$PM2_STARTUP_CMD"
echo -e "\e[0m"
read -p "Copy the command above, paste it, and run it in your terminal now. Then press Enter here to finish."
echo
echo "Management commands:"
echo "  - To view API logs: \e[1;36mpm2 logs finance-api\e[0m"
echo "  - To stop the API: \e[1;36mpm2 stop finance-api\e[0m"
echo "  - To restart the API: \e[1;36mpm2 restart finance-api\e[0m"
