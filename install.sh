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
# Helpers / safety
# -------------------------
log() { echo -e "\n\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\n\033[1;31m[ERR ]\033[0m $*" >&2; }
die() { err "$*"; exit 1; }

# Print the line that failed (so we never “exit silently” again)
trap 'err "Installer failed at line ${LINENO}. Command: ${BASH_COMMAND}"; exit 1' ERR

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Please run as root: sudo $0"
  fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Always read from the controlling terminal to avoid sudo/stdin issues
TTY_IN="/dev/tty"
if [[ ! -r "$TTY_IN" ]]; then
  die "No TTY available for interactive prompts. Run this script in an interactive terminal."
fi

prompt() {
  # prompt "Question" "default"
  local q="$1"
  local def="${2:-}"
  local ans=""

  if [[ -n "$def" ]]; then
    printf "%s [%s]: " "$q" "$def" >"$TTY_IN"
  else
    printf "%s: " "$q" >"$TTY_IN"
  fi

  IFS= read -r ans <"$TTY_IN" || die "Failed to read input from TTY."
  if [[ -z "${ans}" && -n "$def" ]]; then
    echo "$def"
  else
    echo "$ans"
  fi
}

prompt_secret() {
  local q="$1"
  local ans=""
  printf "%s: " "$q" >"$TTY_IN"
  stty -echo <"$TTY_IN"
  IFS= read -r ans <"$TTY_IN" || { stty echo <"$TTY_IN"; die "Failed to read secret from TTY."; }
  stty echo <"$TTY_IN"
  printf "\n" >"$TTY_IN"
  echo "$ans"
}

prompt_yesno() {
  # prompt_yesno "Enable HTTPS?" "y"
  local q="$1"
  local def="${2:-y}"   # y or n
  local ans=""
  while true; do
    printf "%s [%s/%s]: " "$q" "$def" "$( [[ "$def" == "y" ]] && echo "n" || echo "y" )" >"$TTY_IN"
    IFS= read -r ans <"$TTY_IN" || die "Failed to read y/n from TTY."
    ans="${ans:-$def}"
    case "$ans" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
      *) printf "Please answer y or n.\n" >"$TTY_IN" ;;
    esac
  done
}

sanitize_slug() {
  local s="$1"
  if [[ ! "$s" =~ ^[a-z0-9-]{3,32}$ ]]; then
    die "PROJECT_SLUG must match ^[a-z0-9-]{3,32}$ (example: finance-portal)"
  fi
}

os_family() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-unknown}" in
      ubuntu|debian) echo "debian" ;;
      rhel|centos|rocky|almalinux|fedora) echo "rhel" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

install_packages_debian() {
  log "Installing packages (Debian/Ubuntu)..."
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg git rsync nginx postgresql postgresql-contrib

  if ! command_exists node || [[ "$(node -v | sed 's/v//;s/\..*//')" -lt 20 ]]; then
    log "Installing Node.js 20 (NodeSource)..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  fi
}

install_packages_rhel() {
  log "Installing packages (RHEL/Fedora/Rocky/Alma)..."
  if command_exists dnf; then
    dnf -y install ca-certificates curl git rsync nginx postgresql-server postgresql-contrib
  else
    yum -y install ca-certificates curl git rsync nginx postgresql-server postgresql-contrib
  fi

  # Init DB if first time
  if [[ ! -f /var/lib/pgsql/data/PG_VERSION && ! -f /var/lib/pgsql/*/data/PG_VERSION ]]; then
    log "Initializing PostgreSQL..."
    if command_exists postgresql-setup; then
      postgresql-setup --initdb
    elif [[ -x /usr/bin/postgresql-setup ]]; then
      /usr/bin/postgresql-setup --initdb
    else
      warn "postgresql-setup not found. You may need to initdb manually."
    fi
  fi

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

ensure_services() {
  log "Enabling and starting Nginx..."
  systemctl enable --now nginx

  log "Enabling and starting PostgreSQL..."
  systemctl enable --now postgresql || systemctl enable --now postgresql.service || true
  systemctl start postgresql || true
}

create_linux_user() {
  local user="$1"
  if id "$user" >/dev/null 2>&1; then
    log "Linux user '$user' already exists."
  else
    log "Creating Linux user '$user'..."
    useradd --system --create-home --shell /usr/sbin/nologin "$user"
  fi
}

random_secret() {
  # Avoid SIGPIPE issues with `set -o pipefail`.
  # Prefer openssl; fallback to python; final fallback uses urandom safely.
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
    return 0
  fi

  # Last resort: generate from urandom without pipefail-triggering pipelines
  # 64 bytes -> base64 -> strip non-alnum -> take 48 chars
  local out=""
  out="$(dd if=/dev/urandom bs=64 count=1 2>/dev/null | base64 | tr -dc 'A-Za-z0-9' | head -c 48 || true)"
  if [[ -z "$out" ]]; then
    die "Could not generate random secret (missing openssl/python3 and fallback failed)."
  fi
  echo "$out"
}

pg_exec() {
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "$1" >/dev/null
}

create_postgres_db_and_user() {
  local db="$1"
  local u="$2"
  local p="$3"

  [[ "$db" =~ ^[a-zA-Z0-9_]{1,32}$ ]] || die "DB name must be letters/numbers/_ only"
  [[ "$u"  =~ ^[a-zA-Z0-9_]{1,32}$ ]] || die "DB user must be letters/numbers/_ only"

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

  pg_exec "ALTER DATABASE ${db} OWNER TO ${u};"
}

write_api_env() {
  local env_dir="$1"
  local env_file="$2"
  local frontend_origin="$3"
  local port="$4"
  local pg_db="$5"
  local pg_user="$6"
  local pg_pass="$7"
  local jwt_secret="$8"

  mkdir -p "$env_dir"
  chmod 750 "$env_dir"

  cat >"$env_file" <<EOF
# Generated by install.sh
PORT=${port}
FRONTEND_ORIGIN=${frontend_origin}

JWT_SECRET=${jwt_secret}

PGHOST=127.0.0.1
PGPORT=5432
PGDATABASE=${pg_db}
PGUSER=${pg_user}
PGPASSWORD=${pg_pass}
EOF

  chmod 640 "$env_file"
}

deploy_project_files() {
  local src_dir="$1"
  local dest_dir="$2"
  local owner="$3"

  log "Deploying project to ${dest_dir} ..."
  mkdir -p "$dest_dir"

  rsync -a --delete \
    --exclude ".git" \
    --exclude "node_modules" \
    --exclude "api/node_modules" \
    --exclude "dist" \
    --exclude "__MACOSX" \
    --exclude ".DS_Store" \
    --exclude ".env" \
    --exclude "api/.env" \
    "$src_dir"/ "$dest_dir"/

  chown -R "$owner":"$owner" "$dest_dir"
}

build_frontend_and_api() {
  local dest_dir="$1"
  local owner="$2"

  log "Installing root npm deps and building frontend..."
  sudo -u "$owner" bash -lc "cd '$dest_dir' && npm install"
  sudo -u "$owner" bash -lc "cd '$dest_dir' && npm run build"

  log "Installing API deps..."
  sudo -u "$owner" bash -lc "cd '$dest_dir/api' && npm install"
}

apply_schema() {
  local dest_dir="$1"
  local db="$2"
  local schema_file="$dest_dir/db_setup.txt"

  if [[ -f "$schema_file" ]]; then
    log "Applying schema from db_setup.txt..."
    sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$db" -f "$schema_file" >/dev/null
  else
    warn "db_setup.txt not found. Skipping schema import."
  fi
}

write_systemd_service_api() {
  local slug="$1"
  local user="$2"
  local workdir="$3"
  local env_file="$4"

  local svc="/etc/systemd/system/${slug}-api.service"

  cat >"$svc" <<EOF
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
}

install_certbot_if_needed() {
  if command_exists certbot; then return 0; fi

  log "Installing certbot..."
  local fam
  fam="$(os_family)"
  if [[ "$fam" == "debian" ]]; then
    apt-get update -y
    apt-get install -y certbot python3-certbot-nginx
  else
    if command_exists dnf; then
      dnf -y install epel-release || true
      dnf -y install certbot python3-certbot-nginx || dnf -y install certbot
    else
      yum -y install epel-release || true
      yum -y install certbot python3-certbot-nginx || yum -y install certbot
    fi
  fi
}

write_nginx_conf_http() {
  local slug="$1"
  local domain="$2"
  local app_dir="$3"
  local api_port="$4"

  local fam
  fam="$(os_family)"
  local conf
  if [[ "$fam" == "debian" ]]; then
    conf="/etc/nginx/sites-available/${slug}.conf"
  else
    conf="/etc/nginx/conf.d/${slug}.conf"
  fi

  cat >"$conf" <<EOF
server {
  listen 80;
  server_name ${domain};

  root ${app_dir}/dist;
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

  if [[ "$fam" == "debian" ]]; then
    ln -sf "$conf" "/etc/nginx/sites-enabled/${slug}.conf"
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
  fi

  nginx -t
  systemctl reload nginx
}

write_nginx_conf_https_manual() {
  local slug="$1"
  local domain="$2"
  local app_dir="$3"
  local api_port="$4"
  local cert="$5"
  local key="$6"

  local fam
  fam="$(os_family)"
  local conf
  if [[ "$fam" == "debian" ]]; then
    conf="/etc/nginx/sites-available/${slug}.conf"
  else
    conf="/etc/nginx/conf.d/${slug}.conf"
  fi

  cat >"$conf" <<EOF
server {
  listen 80;
  server_name ${domain};
  return 301 https://\$host\$request_uri;
}

server {
  listen 443 ssl http2;
  server_name ${domain};

  ssl_certificate     ${cert};
  ssl_certificate_key ${key};

  root ${app_dir}/dist;
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

  if [[ "$fam" == "debian" ]]; then
    ln -sf "$conf" "/etc/nginx/sites-enabled/${slug}.conf"
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
  fi

  nginx -t
  systemctl reload nginx
}

setup_pg_dump_cron() {
  local slug="$1"
  local db="$2"
  local user="$3"
  local pass="$4"
  local retention="$5"

  local backup_dir="/var/backups/${slug}/postgres"
  mkdir -p "$backup_dir"
  chmod 750 "$backup_dir"

  local cron="/etc/cron.d/${slug}-pgdump"
  cat >"$cron" <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Daily at 02:10
10 2 * * * root export PGPASSWORD='${pass}' && \
  pg_dump -h 127.0.0.1 -U '${user}' -d '${db}' -F c -f '${backup_dir}/${db}-\$(date +\%F).dump' && \
  find '${backup_dir}' -type f -name '${db}-*.dump' -mtime +${retention} -delete
EOF
  chmod 644 "$cron"
}

# -------------------------
# Main
# -------------------------
need_root

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "${SCRIPT_DIR}/package.json" ]] || die "Run this script from repo root (package.json not found)."

log "AdminLTE Finance Portal installer (systemd) starting..."

PROJECT_SLUG="$(prompt "Enter PROJECT_SLUG (used for paths/services/user)" "finance-portal")"
PROJECT_SLUG="$(echo "$PROJECT_SLUG" | tr '[:upper:]' '[:lower:]')"
sanitize_slug "$PROJECT_SLUG"

APP_USER="${PROJECT_SLUG}"
APP_DIR="/var/www/${PROJECT_SLUG}"
ENV_DIR="/etc/${PROJECT_SLUG}"
API_ENV="${ENV_DIR}/api.env"

DOMAIN="$(prompt "Enter domain (or server IP) to use in Nginx server_name" "$(hostname -f 2>/dev/null || echo "localhost")")"
API_PORT="$(prompt "Enter API port (local only)" "3000")"

DB_NAME="$(prompt "Postgres database name" "$(echo "${PROJECT_SLUG}" | tr '-' '_')")"
DB_USER="$(prompt "Postgres app username" "$(echo "${PROJECT_SLUG}" | tr '-' '_')")"
DB_PASS="$(prompt_secret "Postgres app user password (leave empty to auto-generate)")"
if [[ -z "$DB_PASS" ]]; then
  DB_PASS="$(random_secret)"
  log "Generated DB password."
fi

JWT_SECRET="$(random_secret)"

USE_HTTPS="no"
CERT_MODE="none"
CERT_PATH=""
KEY_PATH=""
LE_EMAIL=""

if prompt_yesno "Enable HTTPS?" "y"; then
  USE_HTTPS="yes"
  if prompt_yesno "Do you already have certificate/key files?" "n"; then
    CERT_MODE="existing"
    CERT_PATH="$(prompt "Full path to certificate (fullchain.pem)" "")"
    KEY_PATH="$(prompt "Full path to private key (privkey.pem)" "")"
    [[ -f "$CERT_PATH" ]] || die "Certificate not found: $CERT_PATH"
    [[ -f "$KEY_PATH" ]] || die "Key not found: $KEY_PATH"
  else
    CERT_MODE="letsencrypt"
    LE_EMAIL="$(prompt "Email for Let's Encrypt registration" "admin@${DOMAIN}")"
  fi
fi

RETENTION_DAYS="$(prompt "pg_dump retention days" "14")"
[[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || die "Retention must be a number."

FAM="$(os_family)"
case "$FAM" in
  debian) install_packages_debian ;;
  rhel) install_packages_rhel ;;
  *) die "Unsupported OS family." ;;
esac

ensure_services
create_linux_user "$APP_USER"
deploy_project_files "$SCRIPT_DIR" "$APP_DIR" "$APP_USER"
build_frontend_and_api "$APP_DIR" "$APP_USER"

create_postgres_db_and_user "$DB_NAME" "$DB_USER" "$DB_PASS"
apply_schema "$APP_DIR" "$DB_NAME"

FRONTEND_ORIGIN="http://${DOMAIN}"
if [[ "$USE_HTTPS" == "yes" ]]; then FRONTEND_ORIGIN="https://${DOMAIN}"; fi

write_api_env "$ENV_DIR" "$API_ENV" "$FRONTEND_ORIGIN" "$API_PORT" "$DB_NAME" "$DB_USER" "$DB_PASS" "$JWT_SECRET"

write_systemd_service_api "$PROJECT_SLUG" "$APP_USER" "$APP_DIR" "$API_ENV"

# Nginx config (HTTP first; needed for certbot challenge)
write_nginx_conf_http "$PROJECT_SLUG" "$DOMAIN" "$APP_DIR" "$API_PORT"

if [[ "$USE_HTTPS" == "yes" && "$CERT_MODE" == "existing" ]]; then
  write_nginx_conf_https_manual "$PROJECT_SLUG" "$DOMAIN" "$APP_DIR" "$API_PORT" "$CERT_PATH" "$KEY_PATH"
elif [[ "$USE_HTTPS" == "yes" && "$CERT_MODE" == "letsencrypt" ]]; then
  install_certbot_if_needed
  log "Running certbot for ${DOMAIN}..."
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$LE_EMAIL" --redirect
  # certbot writes its own config; keep ours consistent by re-writing with expected LE paths:
  CERT_PATH="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
  KEY_PATH="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
  write_nginx_conf_https_manual "$PROJECT_SLUG" "$DOMAIN" "$APP_DIR" "$API_PORT" "$CERT_PATH" "$KEY_PATH"
fi

setup_pg_dump_cron "$PROJECT_SLUG" "$DB_NAME" "$DB_USER" "$DB_PASS" "$RETENTION_DAYS"

log "✅ Installation complete!"
echo "App dir:       $APP_DIR"
echo "API env:       $API_ENV"
echo "Service:       systemctl status ${PROJECT_SLUG}-api --no-pager"
echo "Logs:          journalctl -u ${PROJECT_SLUG}-api -f"
echo "Backups:       /var/backups/${PROJECT_SLUG}/postgres (daily @ 02:10; keep ${RETENTION_DAYS} days)"
echo "URL:           ${FRONTEND_ORIGIN}"