#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# AdminLTE Finance Portal - Systemd Installer (PostgreSQL + Nginx)
# - Builds Angular frontend and serves via Nginx
# - Runs API (Node/Express) via systemd
# - Creates dedicated Linux user + project directory
# - Creates Postgres DB + user
# - Optional HTTPS: existing cert OR Let's Encrypt (certbot)
# - Adds daily pg_dump cron + retention
# ============================================================

# -------------------------
# Helpers
# -------------------------
log() { echo -e "\n\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\n\033[1;31m[ERR ]\033[0m $*"; }
die() { err "$*"; exit 1; }

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Please run as root: sudo $0"
  fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

sanitize_slug() {
  # allow lowercase letters, numbers, dash
  local s="$1"
  if [[ ! "$s" =~ ^[a-z0-9-]{3,32}$ ]]; then
    die "PROJECT_SLUG must match ^[a-z0-9-]{3,32}$ (example: finance-portal)"
  fi
}

read_default() {
  local prompt="$1"
  local def="${2:-}"
  local var
  if [[ -n "$def" ]]; then
    read -r -p "$prompt [$def]: " var
    echo "${var:-$def}"
  else
    read -r -p "$prompt: " var
    echo "$var"
  fi
}

yesno() {
  local prompt="$1"
  local def="${2:-y}"  # y/n
  local ans
  while true; do
    read -r -p "$prompt [${def}/$( [[ "$def" == "y" ]] && echo "n" || echo "y" )]: " ans
    ans="${ans:-$def}"
    case "$ans" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

os_detect() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID:-unknown}"
  else
    echo "unknown"
  fi
}

os_family() {
  # returns: debian|rhel|unknown
  local id
  id="$(os_detect)"
  case "$id" in
    ubuntu|debian) echo "debian" ;;
    rhel|centos|rocky|almalinux|fedora) echo "rhel" ;;
    *) echo "unknown" ;;
  esac
}

install_packages_debian() {
  log "Installing packages (Debian/Ubuntu)..."
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg git rsync nginx postgresql postgresql-contrib
  # Node.js 20 via NodeSource (Debian/Ubuntu)
  if ! command_exists node || [[ "$(node -v | sed 's/v//;s/\..*//')" -lt 20 ]]; then
    log "Installing Node.js 20 (NodeSource)..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  fi
  # certbot optional (install later only if needed)
}

install_packages_rhel() {
  log "Installing packages (RHEL/Fedora/Rocky/Alma)..."
  if command_exists dnf; then
    dnf -y install ca-certificates curl git rsync nginx postgresql-server postgresql-contrib
  else
    yum -y install ca-certificates curl git rsync nginx postgresql-server postgresql-contrib
  fi

  # Initialize postgres on first install (RHEL family)
  if [[ ! -f /var/lib/pgsql/data/PG_VERSION && ! -f /var/lib/pgsql/*/data/PG_VERSION ]]; then
    log "Initializing PostgreSQL database..."
    if command_exists postgresql-setup; then
      postgresql-setup --initdb
    elif command_exists /usr/bin/postgresql-setup; then
      /usr/bin/postgresql-setup --initdb
    else
      warn "Could not find postgresql-setup. You may need to initdb manually."
    fi
  fi

  # Node.js 20 via NodeSource (RPM)
  if ! command_exists node || [[ "$(node -v | sed 's/v//;s/\..*//')" -lt 20 ]]; then
    log "Installing Node.js 20 (NodeSource RPM)..."
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    if command_exists dnf; then
      dnf -y install nodejs
    else
      yum -y install nodejs
    fi
  fi
}

ensure_services_enabled() {
  local fam
  fam="$(os_family)"
  log "Enabling and starting Nginx + PostgreSQL..."
  systemctl enable --now nginx

  # postgres service name differs
  if systemctl list-unit-files | grep -q '^postgresql\.service'; then
    systemctl enable --now postgresql
  elif systemctl list-unit-files | grep -q '^postgresql-[0-9]\+\.service'; then
    # Debian sometimes uses postgresql@ or versioned; start generic
    systemctl enable --now postgresql || true
  elif systemctl list-unit-files | grep -q '^postgresql-[0-9]\+\.socket'; then
    systemctl enable --now postgresql || true
  elif systemctl list-unit-files | grep -q '^postgresql-.*\.service'; then
    systemctl enable --now postgresql || true
  elif systemctl list-unit-files | grep -q '^postgresql\.service'; then
    systemctl enable --now postgresql
  else
    # common on RHEL
    systemctl enable --now postgresql || systemctl enable --now postgresql.service || true
  fi

  # RHEL family common actual service is "postgresql"
  if [[ "$fam" == "rhel" ]]; then
    systemctl enable --now postgresql || true
  fi
}

create_linux_user() {
  local user="$1"
  if id "$user" >/dev/null 2>&1; then
    log "Linux user '$user' already exists."
  else
    log "Creating Linux user '$user' (system user)..."
    useradd --system --create-home --shell /usr/sbin/nologin "$user"
  fi
}

random_secret() {
  # 48 chars
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48
}

pg_exec() {
  # Run SQL as postgres superuser
  # Usage: pg_exec "SQL..."
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "$1" >/dev/null
}

create_postgres_db_and_user() {
  local db="$1"
  local u="$2"
  local p="$3"

  # Basic safe naming
  if [[ ! "$db" =~ ^[a-zA-Z0-9_]{1,32}$ ]]; then
    die "DB name must match ^[a-zA-Z0-9_]{1,32}$"
  fi
  if [[ ! "$u" =~ ^[a-zA-Z0-9_]{1,32}$ ]]; then
    die "DB user must match ^[a-zA-Z0-9_]{1,32}$"
  fi

  log "Creating Postgres role/user + database (idempotent)..."
  pg_exec "DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${u}') THEN
    CREATE ROLE ${u} LOGIN PASSWORD '${p}';
  END IF;
END
\$\$;"

  pg_exec "DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${db}') THEN
    CREATE DATABASE ${db} OWNER ${u};
  END IF;
END
\$\$;"

  # Ensure privileges
  pg_exec "ALTER DATABASE ${db} OWNER TO ${u};"
}

write_api_env() {
  local env_dir="$1"
  local env_file="$2"
  local frontend_origin="$3"
  local port="$4"
  local pg_host="$5"
  local pg_port="$6"
  local pg_db="$7"
  local pg_user="$8"
  local pg_pass="$9"
  local jwt_secret="${10}"

  mkdir -p "$env_dir"
  chmod 750 "$env_dir"

  cat >"$env_file" <<EOF
# Generated by install.sh
PORT=${port}
FRONTEND_ORIGIN=${frontend_origin}

JWT_SECRET=${jwt_secret}

PGHOST=${pg_host}
PGPORT=${pg_port}
PGDATABASE=${pg_db}
PGUSER=${pg_user}
PGPASSWORD=${pg_pass}
# Set to 'require' only if you use remote PG with SSL
# PGSSLMODE=require
EOF

  chmod 640 "$env_file"
}

deploy_project_files() {
  local src_dir="$1"
  local dest_dir="$2"
  local owner="$3"

  log "Deploying project to ${dest_dir} ..."
  mkdir -p "$dest_dir"

  # Rsync repo content, excluding big/host-specific dirs
  rsync -a --delete \
    --exclude ".git" \
    --exclude "node_modules" \
    --exclude "api/node_modules" \
    --exclude "dist" \
    --exclude ".env" \
    --exclude "api/.env" \
    "$src_dir"/ "$dest_dir"/

  chown -R "$owner":"$owner" "$dest_dir"
}

build_frontend_and_api() {
  local dest_dir="$1"
  local owner="$2"

  log "Installing root npm deps and building Angular frontend..."
  sudo -u "$owner" bash -lc "cd '$dest_dir' && npm install"
  sudo -u "$owner" bash -lc "cd '$dest_dir' && npm run build"

  log "Installing API npm deps..."
  sudo -u "$owner" bash -lc "cd '$dest_dir/api' && npm install"
}

install_db_schema_if_present() {
  local dest_dir="$1"
  local db="$2"
  local db_user="$3"

  # Look for likely schema file names in repo root
  local schema_file=""
  for f in "db_setup.txt" "db_setup.sql" "schema.sql"; do
    if [[ -f "$dest_dir/$f" ]]; then
      schema_file="$dest_dir/$f"
      break
    fi
  done

  if [[ -n "$schema_file" ]]; then
    log "Applying DB schema from $(basename "$schema_file") ..."
    # Use psql with provided app user
    PGPASSWORD="$(grep '^PGPASSWORD=' /etc/*/api.env 2>/dev/null | head -n1 | cut -d= -f2- || true)"
    # safer: just run as postgres but set role owner by default
    sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$db" -f "$schema_file" >/dev/null || {
      warn "Schema apply failed. You may need to adjust schema file for PostgreSQL."
      return 0
    }
    log "Schema applied."
  else
    warn "No schema file found (db_setup.txt/db_setup.sql/schema.sql). Skipping schema import."
  fi
}

write_systemd_service_api() {
  local slug="$1"
  local user="$2"
  local workdir="$3"
  local env_file="$4"
  local api_port="$5"

  local service="/etc/systemd/system/${slug}-api.service"

  cat >"$service" <<EOF
[Unit]
Description=${slug} API (Node/Express)
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=${user}
WorkingDirectory=${workdir}/api
EnvironmentFile=${env_file}
ExecStart=/usr/bin/node ${workdir}/api/index.js
Restart=on-failure
RestartSec=2
# Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=${workdir}

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "${slug}-api.service"

  log "Systemd service installed: ${slug}-api.service (listening on localhost:${api_port})"
}

write_nginx_conf() {
  local slug="$1"
  local domain="$2"
  local root_dir="$3"
  local api_port="$4"
  local use_https="$5"
  local cert_path="${6:-}"
  local key_path="${7:-}"

  local fam
  fam="$(os_family)"

  local nginx_conf=""
  if [[ "$fam" == "debian" ]]; then
    nginx_conf="/etc/nginx/sites-available/${slug}.conf"
  else
    nginx_conf="/etc/nginx/conf.d/${slug}.conf"
  fi

  local dist_dir="${root_dir}/dist"
  [[ -d "$dist_dir" ]] || die "Frontend dist directory not found at ${dist_dir}. Build failed?"

  log "Writing Nginx config: ${nginx_conf}"

  if [[ "$use_https" == "yes" ]]; then
    [[ -n "$cert_path" && -n "$key_path" ]] || die "HTTPS enabled but cert/key paths missing."
    cat >"$nginx_conf" <<EOF
server {
  listen 80;
  server_name ${domain};
  return 301 https://\$host\$request_uri;
}

server {
  listen 443 ssl http2;
  server_name ${domain};

  ssl_certificate     ${cert_path};
  ssl_certificate_key ${key_path};

  # Security headers (basic)
  add_header X-Content-Type-Options nosniff always;
  add_header X-Frame-Options SAMEORIGIN always;
  add_header Referrer-Policy strict-origin-when-cross-origin always;

  root ${dist_dir};
  index index.html;

  location / {
    try_files \$uri \$uri/ /index.html;
  }

  location /api/ {
    proxy_pass http://127.0.0.1:${api_port}/api/;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}
EOF
  else
    cat >"$nginx_conf" <<EOF
server {
  listen 80;
  server_name ${domain};

  root ${dist_dir};
  index index.html;

  location / {
    try_files \$uri \$uri/ /index.html;
  }

  location /api/ {
    proxy_pass http://127.0.0.1:${api_port}/api/;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}
EOF
  fi

  if [[ "$fam" == "debian" ]]; then
    ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/${slug}.conf"
    # Ensure nginx includes sites-enabled
    if ! grep -q "sites-enabled" /etc/nginx/nginx.conf 2>/dev/null; then
      warn "Your nginx.conf may not include sites-enabled/*.conf. If Nginx fails, add: include /etc/nginx/sites-enabled/*;"
    fi
  fi

  nginx -t
  systemctl reload nginx
}

install_certbot_if_needed() {
  local fam
  fam="$(os_family)"
  if command_exists certbot; then
    return 0
  fi

  log "Installing certbot..."
  if [[ "$fam" == "debian" ]]; then
    apt-get update -y
    apt-get install -y certbot python3-certbot-nginx
  elif [[ "$fam" == "rhel" ]]; then
    if command_exists dnf; then
      dnf -y install certbot python3-certbot-nginx || dnf -y install certbot
    else
      yum -y install certbot python3-certbot-nginx || yum -y install certbot
    fi
  else
    die "Unknown OS family; cannot install certbot automatically."
  fi
}

obtain_letsencrypt_cert() {
  local domain="$1"
  local email="$2"
  install_certbot_if_needed

  log "Obtaining Let's Encrypt certificate for ${domain}..."
  # Must have nginx config on :80 first and domain pointing correctly
  certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$email" --redirect
}

setup_pg_dump_cron() {
  local slug="$1"
  local db="$2"
  local user="$3"
  local pass="$4"
  local retention_days="$5"
  local backup_dir="/var/backups/${slug}/postgres"

  mkdir -p "$backup_dir"
  chmod 750 "$backup_dir"

  local cron_file="/etc/cron.d/${slug}-pgdump"
  log "Setting up daily pg_dump cron with ${retention_days} days retention: ${cron_file}"

  cat >"$cron_file" <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Daily at 02:10
10 2 * * * root export PGPASSWORD='${pass}' && \
  mkdir -p '${backup_dir}' && \
  pg_dump -h 127.0.0.1 -U '${user}' -d '${db}' -F c -f '${backup_dir}/${db}-\$(date +\%F).dump' && \
  find '${backup_dir}' -type f -name '${db}-*.dump' -mtime +${retention_days} -delete
EOF

  chmod 644 "$cron_file"
}

# -------------------------
# Main
# -------------------------
need_root

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "${SCRIPT_DIR}/package.json" ]]; then
  die "Run this script from the repo root (where package.json exists)."
fi

log "AdminLTE Finance Portal installer (systemd) starting..."

PROJECT_SLUG="$(read_default "Enter PROJECT_SLUG (used for paths/services/user)" "finance-portal")"
PROJECT_SLUG="$(echo "$PROJECT_SLUG" | tr '[:upper:]' '[:lower:]')"
sanitize_slug "$PROJECT_SLUG"

APP_USER="${PROJECT_SLUG}"
APP_DIR="/var/www/${PROJECT_SLUG}"
ENV_DIR="/etc/${PROJECT_SLUG}"
API_ENV="${ENV_DIR}/api.env"

DOMAIN="$(read_default "Enter domain (or server IP) to use in Nginx server_name" "$(hostname -f 2>/dev/null || echo "localhost")")"
API_PORT="$(read_default "Enter API port (local only)" "3000")"

# PostgreSQL local setup
DB_NAME="$(read_default "Postgres database name" "$(echo "${PROJECT_SLUG}" | tr '-' '_')")"
DB_USER="$(read_default "Postgres app username" "$(echo "${PROJECT_SLUG}" | tr '-' '_')")"
DB_PASS="$(read_default "Postgres app user password (leave empty to auto-generate)" "")"
if [[ -z "$DB_PASS" ]]; then
  DB_PASS="$(random_secret)"
  log "Generated DB password."
fi

# JWT secret
JWT_SECRET="$(random_secret)"

# HTTPS selection
USE_HTTPS="no"
CERT_MODE="none"
CERT_PATH=""
KEY_PATH=""

if yesno "Enable HTTPS?" "y"; then
  USE_HTTPS="yes"
  if yesno "Do you already have a certificate/key files?" "n"; then
    CERT_MODE="existing"
    CERT_PATH="$(read_default "Full path to SSL certificate (fullchain.pem)" "")"
    KEY_PATH="$(read_default "Full path to SSL private key (privkey.pem)" "")"
    [[ -f "$CERT_PATH" ]] || die "Certificate file not found: $CERT_PATH"
    [[ -f "$KEY_PATH" ]] || die "Key file not found: $KEY_PATH"
  else
    CERT_MODE="letsencrypt"
    LE_EMAIL="$(read_default "Email for Let's Encrypt registration" "admin@${DOMAIN}")"
  fi
fi

RETENTION_DAYS="$(read_default "pg_dump retention days" "14")"
[[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || die "Retention must be a number."

# Install packages
FAM="$(os_family)"
case "$FAM" in
  debian) install_packages_debian ;;
  rhel) install_packages_rhel ;;
  *) die "Unsupported OS. Supported: Debian/Ubuntu and RHEL-family (Rocky/Alma/CentOS/Fedora)." ;;
esac

ensure_services_enabled

# Create linux user + deploy
create_linux_user "$APP_USER"
deploy_project_files "$SCRIPT_DIR" "$APP_DIR" "$APP_USER"

# Build
build_frontend_and_api "$APP_DIR" "$APP_USER"

# DB + env
create_postgres_db_and_user "$DB_NAME" "$DB_USER" "$DB_PASS"
write_api_env "$ENV_DIR" "$API_ENV" \
  "http${USE_HTTPS/yes/s}://${DOMAIN}" \
  "$API_PORT" \
  "127.0.0.1" "5432" "$DB_NAME" "$DB_USER" "$DB_PASS" "$JWT_SECRET"

# systemd for API
write_systemd_service_api "$PROJECT_SLUG" "$APP_USER" "$APP_DIR" "$API_ENV" "$API_PORT"

# Nginx baseline HTTP config (needed for LE http-01 challenge)
if [[ "$USE_HTTPS" == "yes" && "$CERT_MODE" == "letsencrypt" ]]; then
  # Write temporary HTTP-only config for certbot
  write_nginx_conf "$PROJECT_SLUG" "$DOMAIN" "$APP_DIR" "$API_PORT" "no"
  obtain_letsencrypt_cert "$DOMAIN" "$LE_EMAIL"
  # Certbot already rewrites nginx config; we still ensure proxy + SPA behavior:
  # Re-write nginx config as HTTPS with certbot paths (standard)
  CERT_PATH="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
  KEY_PATH="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
  write_nginx_conf "$PROJECT_SLUG" "$DOMAIN" "$APP_DIR" "$API_PORT" "yes" "$CERT_PATH" "$KEY_PATH"
elif [[ "$USE_HTTPS" == "yes" && "$CERT_MODE" == "existing" ]]; then
  write_nginx_conf "$PROJECT_SLUG" "$DOMAIN" "$APP_DIR" "$API_PORT" "yes" "$CERT_PATH" "$KEY_PATH"
else
  write_nginx_conf "$PROJECT_SLUG" "$DOMAIN" "$APP_DIR" "$API_PORT" "no"
fi

# Cron backup
setup_pg_dump_cron "$PROJECT_SLUG" "$DB_NAME" "$DB_USER" "$DB_PASS" "$RETENTION_DAYS"

log "✅ Installation complete!"
echo ""
echo "Project:        ${PROJECT_SLUG}"
echo "App directory:  ${APP_DIR}"
echo "API service:    systemctl status ${PROJECT_SLUG}-api"
echo "Nginx:          systemctl status nginx"
echo "API env file:   ${API_ENV} (chmod 640)"
echo "Backups:        /var/backups/${PROJECT_SLUG}/postgres (daily @ 02:10, keep ${RETENTION_DAYS} days)"
echo ""
echo "URL:"
if [[ "$USE_HTTPS" == "yes" ]]; then
  echo "  https://${DOMAIN}"
else
  echo "  http://${DOMAIN}"
fi
echo ""
echo "If you updated backend to require JWT, ensure your frontend sends Bearer tokens (as we fixed in ApiService)."