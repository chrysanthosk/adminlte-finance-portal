#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\n\033[1;32m[INFO]\033[0m $*"; }
warn(){ echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\n\033[1;31m[ERR ]\033[0m $*"; }
die() { err "$*"; exit 1; }

require_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run as root: sudo $0"; }

prompt() { # var, msg, default
  local var="$1" msg="$2" def="${3:-}" val=""
  if [[ -n "$def" ]]; then read -r -p "$msg [$def]: " val; val="${val:-$def}"
  else read -r -p "$msg: " val; fi
  printf -v "$var" "%s" "$val"
}

prompt_secret() { # var, msg
  local var="$1" msg="$2" val=""
  read -r -s -p "$msg: " val; echo
  printf -v "$var" "%s" "$val"
}

yesno(){ # msg, default(y/n)
  local msg="$1" def="${2:-y}" ans=""
  local s="[y/N]"; [[ "$def" == "y" ]] && s="[Y/n]"
  read -r -p "$msg $s: " ans
  ans="${ans,,}"
  [[ -z "$ans" ]] && { [[ "$def" == "y" ]] && return 0 || return 1; }
  [[ "$ans" == "y" || "$ans" == "yes" ]]
}

detect_os(){
  [[ -f /etc/os-release ]] || die "Missing /etc/os-release"
  # shellcheck disable=SC1091
  source /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_LIKE="${ID_LIKE:-}"
  if [[ "$OS_ID" =~ (ubuntu|debian) ]] || [[ "$OS_LIKE" =~ (debian) ]]; then
    OS_FAMILY="debian"
  elif [[ "$OS_ID" =~ (rocky|almalinux|rhel|centos|fedora) ]] || [[ "$OS_LIKE" =~ (rhel|fedora|centos) ]]; then
    OS_FAMILY="rhel"
  else
    die "Unsupported OS: $OS_ID ($OS_LIKE)"
  fi
}

install_packages_debian(){
  log "Installing packages (Debian/Ubuntu)..."
  apt-get update -y
  apt-get install -y ca-certificates curl git unzip zip gnupg lsb-release software-properties-common

  apt-get install -y nginx mysql-server

  if [[ "$OS_ID" == "ubuntu" ]]; then
    add-apt-repository -y ppa:ondrej/php
    apt-get update -y
  fi

  apt-get install -y \
    php8.2 php8.2-fpm php8.2-cli php8.2-mbstring php8.2-xml php8.2-curl php8.2-zip php8.2-mysql \
    php8.2-bcmath php8.2-intl php8.2-gd

  log "Installing Node.js (LTS)..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  apt-get install -y nodejs

  apt-get install -y certbot python3-certbot-nginx
}

install_packages_rhel(){
  log "Installing packages (RHEL/Rocky/Alma)..."
  dnf -y install ca-certificates curl git unzip zip tar

  dnf -y install epel-release || true
  dnf -y install nginx

  log "Installing MariaDB (MySQL-compatible)..."
  dnf -y install mariadb-server mariadb

  log "Installing PHP 8.2 via Remi..."
  dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm || true
  dnf -y module reset php || true
  dnf -y module enable php:remi-8.2 || true
  dnf -y install php php-fpm php-cli php-mbstring php-xml php-curl php-zip php-mysqlnd php-bcmath php-intl php-gd

  log "Installing Node.js (LTS)..."
  curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
  dnf -y install nodejs

  dnf -y install certbot python3-certbot-nginx || warn "Certbot install failed; install manually if needed."
}

install_composer(){
  if command -v composer >/dev/null 2>&1; then
    log "Composer already installed."
    return
  fi
  log "Installing Composer..."
  curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
  php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
  rm -f /tmp/composer-setup.php
}

enable_services(){
  log "Enabling services..."
  systemctl enable --now nginx
  if [[ "$OS_FAMILY" == "debian" ]]; then
    systemctl enable --now mysql
    systemctl enable --now php8.2-fpm
    PHP_FPM_SERVICE="php8.2-fpm"
    DB_SERVICE="mysql"
    PHP_FPM_UPSTREAM="unix:/run/php/php8.2-fpm.sock"
  else
    systemctl enable --now mariadb
    systemctl enable --now php-fpm
    PHP_FPM_SERVICE="php-fpm"
    DB_SERVICE="mariadb"
    PHP_FPM_UPSTREAM="127.0.0.1:9000"
    # ensure php-fpm listens on 127.0.0.1:9000
    if [[ -f /etc/php-fpm.d/www.conf ]]; then
      sed -i 's|^listen = .*|listen = 127.0.0.1:9000|g' /etc/php-fpm.d/www.conf || true
      systemctl restart php-fpm
    fi
  fi
}

create_app_user_and_dirs(){
  log "Creating Linux user and directories..."
  if ! id "$APP_USER" >/dev/null 2>&1; then
    useradd --system --create-home --shell /bin/bash "$APP_USER"
  fi
  mkdir -p "$APP_DIR" "$BACKUP_DIR"
  chown -R "$APP_USER":"$APP_USER" "$APP_DIR" "$BACKUP_DIR"
}

clone_or_update_repo(){
  log "Deploying repo to $APP_DIR..."
  if [[ -d "$APP_DIR/.git" ]]; then
    sudo -u "$APP_USER" git -C "$APP_DIR" fetch --all
    sudo -u "$APP_USER" git -C "$APP_DIR" checkout "$GIT_BRANCH"
    sudo -u "$APP_USER" git -C "$APP_DIR" pull
  else
    sudo -u "$APP_USER" git clone --branch "$GIT_BRANCH" "$GIT_REPO" "$APP_DIR"
  fi
}

configure_local_db(){
  if [[ "$DB_HOST" != "127.0.0.1" && "$DB_HOST" != "localhost" ]]; then
    warn "Remote DB detected; skipping DB/user creation. Ensure DB and user exist."
    return
  fi

  log "Creating database + user locally..."
  # Works on MySQL (Ubuntu/Debian default root via socket) and MariaDB similarly
  mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%'; FLUSH PRIVILEGES;"
}

setup_env(){
  log "Configuring .env..."
  if [[ ! -f "$APP_DIR/.env" ]]; then
    [[ -f "$APP_DIR/.env.example" ]] || die "No .env or .env.example in repo."
    sudo -u "$APP_USER" cp "$APP_DIR/.env.example" "$APP_DIR/.env"
  fi

  sudo -u "$APP_USER" sed -i "s/^APP_NAME=.*/APP_NAME=\"${APP_NAME}\"/g" "$APP_DIR/.env" || true
  sudo -u "$APP_USER" sed -i "s|^APP_URL=.*|APP_URL=${APP_URL}|g" "$APP_DIR/.env" || true
  sudo -u "$APP_USER" sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/g" "$APP_DIR/.env" || true
  sudo -u "$APP_USER" sed -i "s/^DB_HOST=.*/DB_HOST=${DB_HOST}/g" "$APP_DIR/.env" || true
  sudo -u "$APP_USER" sed -i "s/^DB_PORT=.*/DB_PORT=${DB_PORT}/g" "$APP_DIR/.env" || true
  sudo -u "$APP_USER" sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${DB_NAME}/g" "$APP_DIR/.env" || true
  sudo -u "$APP_USER" sed -i "s/^DB_USERNAME=.*/DB_USERNAME=${DB_USER}/g" "$APP_DIR/.env" || true

  local esc_db_pass
  esc_db_pass="$(printf '%s' "$DB_PASS" | sed 's/[&/\]/\\&/g')"
  sudo -u "$APP_USER" sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${esc_db_pass}/g" "$APP_DIR/.env" || true

  mkdir -p "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
  chown -R "$APP_USER":"$APP_USER" "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
  chmod -R ug+rwX "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
}

install_app_deps(){
  log "Installing Composer deps..."
  sudo -u "$APP_USER" composer -d "$APP_DIR" install --no-interaction --prefer-dist --optimize-autoloader

  if [[ -f "$APP_DIR/package.json" ]]; then
    log "Building frontend assets..."
    sudo -u "$APP_USER" bash -lc "cd '$APP_DIR' && npm install && npm run build"
  else
    warn "No package.json found; skipping npm build."
  fi
}

run_artisan(){
  log "Running artisan tasks..."
  sudo -u "$APP_USER" bash -lc "cd '$APP_DIR' && php artisan key:generate --force"
  sudo -u "$APP_USER" bash -lc "cd '$APP_DIR' && php artisan migrate --force"
  if [[ "$RUN_SEED" == "yes" ]]; then
    sudo -u "$APP_USER" bash -lc "cd '$APP_DIR' && php artisan db:seed --force" || warn "Seeding failed (no seeders yet?)."
  fi
  sudo -u "$APP_USER" bash -lc "cd '$APP_DIR' && php artisan config:cache && php artisan route:cache && php artisan view:cache" || true
}

nginx_site_path(){
  if [[ "$OS_FAMILY" == "debian" ]]; then
    echo "/etc/nginx/sites-available/${PROJECT_SLUG}.conf"
  else
    echo "/etc/nginx/conf.d/${PROJECT_SLUG}.conf"
  fi
}

write_nginx_http(){
  local site_conf="$1"
  cat > "$site_conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root ${APP_DIR}/public;
    index index.php index.html;

    client_max_body_size 25M;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_pass ${PHP_FPM_UPSTREAM};
        fastcgi_index index.php;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
}

write_nginx_ssl_existing(){
  local site_conf="$1"
  cat > "$site_conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate     ${CERT_FULLCHAIN};
    ssl_certificate_key ${CERT_PRIVKEY};

    root ${APP_DIR}/public;
    index index.php index.html;

    client_max_body_size 25M;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_pass ${PHP_FPM_UPSTREAM};
        fastcgi_index index.php;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
}

configure_nginx(){
  local site_conf
  site_conf="$(nginx_site_path)"
  log "Configuring Nginx: $site_conf"

  # Default to HTTP; HTTPS step will upgrade if chosen
  write_nginx_http "$site_conf"

  if [[ "$OS_FAMILY" == "debian" ]]; then
    ln -sf "$site_conf" "/etc/nginx/sites-enabled/${PROJECT_SLUG}.conf"
    rm -f /etc/nginx/sites-enabled/default || true
  fi

  nginx -t
  systemctl reload nginx
}

enable_https(){
  if [[ "$ENABLE_HTTPS" != "yes" ]]; then
    warn "HTTPS not enabled."
    return
  fi

  if [[ "$DOMAIN" == "_" || "$DOMAIN" == "localhost" || "$DOMAIN" == "127.0.0.1" ]]; then
    warn "No real domain set; skipping HTTPS automation."
    return
  fi

  local site_conf
  site_conf="$(nginx_site_path)"

  if [[ "$SSL_MODE" == "existing" ]]; then
    [[ -f "$CERT_FULLCHAIN" ]] || die "Cert fullchain not found: $CERT_FULLCHAIN"
    [[ -f "$CERT_PRIVKEY" ]]   || die "Cert privkey not found: $CERT_PRIVKEY"
    log "Enabling HTTPS using existing certificates..."
    write_nginx_ssl_existing "$site_conf"
    if [[ "$OS_FAMILY" == "debian" ]]; then
      ln -sf "$site_conf" "/etc/nginx/sites-enabled/${PROJECT_SLUG}.conf"
      rm -f /etc/nginx/sites-enabled/default || true
    fi
    nginx -t
    systemctl reload nginx
    return
  fi

  log "Enabling HTTPS using Let's Encrypt (certbot)..."
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$LE_EMAIL" --redirect || die "Certbot failed."
}

setup_systemd_queue(){
  if [[ "$SETUP_QUEUE" != "yes" ]]; then
    warn "Skipping queue worker service."
    return
  fi

  log "Creating queue worker service..."
  local svc="/etc/systemd/system/${PROJECT_SLUG}-queue.service"
  cat > "$svc" <<EOF
[Unit]
Description=${PROJECT_SLUG} Laravel Queue Worker
After=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/php ${APP_DIR}/artisan queue:work --sleep=3 --tries=3 --timeout=120
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "${PROJECT_SLUG}-queue.service"
}

setup_scheduler_cron(){
  if [[ "$SETUP_SCHEDULER" != "yes" ]]; then
    warn "Skipping scheduler cron."
    return
  fi

  log "Adding scheduler cron..."
  cat > "/etc/cron.d/${PROJECT_SLUG}-scheduler" <<EOF
* * * * * ${APP_USER} cd ${APP_DIR} && /usr/bin/php artisan schedule:run >> /var/log/${PROJECT_SLUG}-scheduler.log 2>&1
EOF
}

setup_backups(){
  log "Setting up daily mysqldump backups..."

  local backup_script="/usr/local/bin/${PROJECT_SLUG}-backup.sh"
  cat > "$backup_script" <<EOF
#!/usr/bin/env bash
set -euo pipefail
TS=\$(date +%F_%H%M%S)
OUT="${BACKUP_DIR}/${DB_NAME}_\${TS}.sql.gz"

mysqldump -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" | gzip > "\$OUT"
find "${BACKUP_DIR}" -type f -name "*.sql.gz" -mtime +${BACKUP_RETENTION_DAYS} -delete
EOF
  chmod 700 "$backup_script"
  chown "$APP_USER":"$APP_USER" "$backup_script" || true

  cat > "/etc/cron.d/${PROJECT_SLUG}-backup" <<EOF
0 2 * * * ${APP_USER} ${backup_script} >> /var/log/${PROJECT_SLUG}-backup.log 2>&1
EOF
}

summary(){
  cat <<EOF

========================================
✅ INSTALL COMPLETE
========================================
Project slug:   ${PROJECT_SLUG}
App dir:        ${APP_DIR}
Linux user:     ${APP_USER}
Domain:         ${DOMAIN}
App URL:        ${APP_URL}

DB:             ${DB_HOST}:${DB_PORT}/${DB_NAME}
DB user:        ${DB_USER}

Nginx conf:     $(nginx_site_path)
Backups:        ${BACKUP_DIR} (02:00 daily, retention ${BACKUP_RETENTION_DAYS} days)
Logs:           /var/log/${PROJECT_SLUG}-backup.log, /var/log/${PROJECT_SLUG}-scheduler.log

Services:
- nginx:        systemctl status nginx
- php-fpm:      systemctl status ${PHP_FPM_SERVICE}
- db:           systemctl status ${DB_SERVICE}
EOF

  if [[ "$SETUP_QUEUE" == "yes" ]]; then
    echo "- queue:        systemctl status ${PROJECT_SLUG}-queue.service"
  fi
  if [[ "$SETUP_SCHEDULER" == "yes" ]]; then
    echo "- scheduler:    /etc/cron.d/${PROJECT_SLUG}-scheduler"
  fi

  cat <<EOF

How to test (quick):
1) Check Nginx:
   curl -I ${APP_URL}
2) Check app routes:
   curl -I ${APP_URL}/login
3) Check PHP-FPM:
   sudo tail -n 100 /var/log/nginx/error.log
4) Check Laravel health:
   sudo -u ${APP_USER} bash -lc "cd ${APP_DIR} && php artisan about"

EOF
}

# -------- main --------
require_root
detect_os
log "Laravel All-in-One installer"

prompt PROJECT_SLUG "PROJECT_SLUG (folder/user/service name)" "laravelapp"
prompt GIT_REPO "GitHub repo URL (https or ssh)" ""
[[ -n "$GIT_REPO" ]] || die "GIT_REPO required"
prompt GIT_BRANCH "Git branch" "main"

prompt DOMAIN "Domain (e.g. portal.example.com). Use _ for none yet" "_"
prompt APP_NAME "APP_NAME" "Laravel Portal"

# URL: if domain is _, use http://127.0.0.1
if [[ "$DOMAIN" == "_" ]]; then
  APP_URL="http://127.0.0.1"
else
  APP_URL="http://${DOMAIN}"
fi

prompt DB_HOST "DB host" "127.0.0.1"
prompt DB_PORT "DB port" "3306"
prompt DB_NAME "DB name" "${PROJECT_SLUG}"
prompt DB_USER "DB user" "${PROJECT_SLUG}_user"
prompt_secret DB_PASS "DB password for ${DB_USER}"

# SSL selection
ENABLE_HTTPS="no"
SSL_MODE="none"
CERT_FULLCHAIN=""
CERT_PRIVKEY=""
LE_EMAIL=""

if yesno "Enable HTTPS?" "y"; then
  ENABLE_HTTPS="yes"
  if yesno "Use your own certificate files (fullchain + privkey)?" "y"; then
    SSL_MODE="existing"
    prompt CERT_FULLCHAIN "Path to fullchain.pem" "/etc/ssl/certs/fullchain.pem"
    prompt CERT_PRIVKEY   "Path to privkey.pem" "/etc/ssl/private/privkey.pem"
  else
    SSL_MODE="letsencrypt"
    prompt LE_EMAIL "Email for Let's Encrypt" "admin@${DOMAIN//_/example.com}"
  fi
fi

SETUP_QUEUE="no"
SETUP_SCHEDULER="yes"
RUN_SEED="yes"

if yesno "Setup queue worker (systemd)?" "n"; then SETUP_QUEUE="yes"; fi
if yesno "Add scheduler cron (every minute)?" "y"; then SETUP_SCHEDULER="yes"; else SETUP_SCHEDULER="no"; fi
if yesno "Run seeders after migrate?" "y"; then RUN_SEED="yes"; else RUN_SEED="no"; fi

prompt BACKUP_RETENTION_DAYS "Backup retention days" "14"

APP_USER="${PROJECT_SLUG}"
APP_DIR="/opt/${PROJECT_SLUG}"
BACKUP_DIR="/var/backups/${PROJECT_SLUG}/mysql"

if [[ "$OS_FAMILY" == "debian" ]]; then
  install_packages_debian
else
  install_packages_rhel
fi

install_composer
enable_services

create_app_user_and_dirs
clone_or_update_repo
configure_local_db
setup_env
install_app_deps
run_artisan

configure_nginx

# update URL if https chosen
if [[ "$ENABLE_HTTPS" == "yes" && "$DOMAIN" != "_" ]]; then
  APP_URL="https://${DOMAIN}"
  sudo -u "$APP_USER" sed -i "s|^APP_URL=.*|APP_URL=${APP_URL}|g" "$APP_DIR/.env" || true
fi

enable_https

setup_systemd_queue
setup_scheduler_cron
setup_backups

systemctl restart nginx
systemctl restart "$PHP_FPM_SERVICE"
systemctl restart "$DB_SERVICE" || true

summary