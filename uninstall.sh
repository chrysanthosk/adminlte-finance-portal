#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\n\033[1;32m[INFO]\033[0m $*"; }
warn(){ echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\n\033[1;31m[ERR ]\033[0m $*"; }
die() { err "$*"; exit 1; }

require_root(){ [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run as root: sudo $0"; }

prompt() { local var="$1" msg="$2" def="${3:-}" val="";
  if [[ -n "$def" ]]; then read -r -p "$msg [$def]: " val; val="${val:-$def}";
  else read -r -p "$msg: " val; fi
  printf -v "$var" "%s" "$val"
}

detect_os(){
  [[ -f /etc/os-release ]] || die "Missing /etc/os-release"
  # shellcheck disable=SC1091
  source /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_LIKE="${ID_LIKE:-}"
  if [[ "$OS_ID" =~ (ubuntu|debian) ]] || [[ "$OS_LIKE" =~ (debian) ]]; then
    OS_FAMILY="debian"
    DB_SERVICE="mysql"
    PHP_FPM_SERVICE="php8.2-fpm"
  elif [[ "$OS_ID" =~ (rocky|almalinux|rhel|centos|fedora) ]] || [[ "$OS_LIKE" =~ (rhel|fedora|centos) ]]; then
    OS_FAMILY="rhel"
    DB_SERVICE="mariadb"
    PHP_FPM_SERVICE="php-fpm"
  else
    die "Unsupported OS: $OS_ID ($OS_LIKE)"
  fi
}

nginx_site_path(){
  if [[ "$OS_FAMILY" == "debian" ]]; then
    echo "/etc/nginx/sites-available/${PROJECT_SLUG}.conf"
  else
    echo "/etc/nginx/conf.d/${PROJECT_SLUG}.conf"
  fi
}

confirm_destroy(){
  echo
  echo "⚠️  This will REMOVE the project completely."
  echo "Project slug: $PROJECT_SLUG"
  echo "App dir:      /opt/$PROJECT_SLUG"
  echo "Linux user:   $PROJECT_SLUG"
  echo "Backups:      /var/backups/$PROJECT_SLUG"
  echo "DB name:      $DB_NAME"
  echo "DB user:      $DB_USER"
  echo
  read -r -p "Type the project slug EXACTLY to confirm: " typed
  [[ "$typed" == "$PROJECT_SLUG" ]] || die "Confirmation failed."
}

remove_nginx(){
  log "Removing Nginx config..."
  local conf
  conf="$(nginx_site_path)"
  rm -f "$conf" || true
  if [[ "$OS_FAMILY" == "debian" ]]; then
    rm -f "/etc/nginx/sites-enabled/${PROJECT_SLUG}.conf" || true
  fi
  nginx -t && systemctl reload nginx || warn "Nginx reload failed (maybe nginx removed or config changed)."
}

remove_systemd(){
  log "Removing systemd queue service..."
  systemctl stop "${PROJECT_SLUG}-queue.service" >/dev/null 2>&1 || true
  systemctl disable "${PROJECT_SLUG}-queue.service" >/dev/null 2>&1 || true
  rm -f "/etc/systemd/system/${PROJECT_SLUG}-queue.service" || true
  systemctl daemon-reload || true
}

remove_cron(){
  log "Removing cron entries..."
  rm -f "/etc/cron.d/${PROJECT_SLUG}-scheduler" || true
  rm -f "/etc/cron.d/${PROJECT_SLUG}-backup" || true
}

remove_backups(){
  log "Removing backups..."
  rm -rf "/var/backups/${PROJECT_SLUG}" || true
  rm -f "/usr/local/bin/${PROJECT_SLUG}-backup.sh" || true
}

remove_app(){
  log "Removing app directory..."
  rm -rf "/opt/${PROJECT_SLUG}" || true
}

remove_user(){
  log "Removing Linux user..."
  if id "$PROJECT_SLUG" >/dev/null 2>&1; then
    userdel -r "$PROJECT_SLUG" || warn "Could not fully remove user home; remove manually if needed."
  fi
}

drop_db_local(){
  if [[ "$DB_HOST" != "127.0.0.1" && "$DB_HOST" != "localhost" ]]; then
    warn "Remote DB host specified; I will NOT drop remote DB/user."
    return
  fi
  log "Dropping local database and user..."
  mysql -u root -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;" || true
  mysql -u root -e "DROP USER IF EXISTS '${DB_USER}'@'%'; FLUSH PRIVILEGES;" || true
}

remove_packages_optional(){
  if [[ "$REMOVE_PACKAGES" != "yes" ]]; then
    warn "Skipping package removal."
    return
  fi

  log "Removing packages (optional)..."
  if [[ "$OS_FAMILY" == "debian" ]]; then
    apt-get remove -y nginx mysql-server certbot python3-certbot-nginx nodejs || true
    apt-get autoremove -y || true
  else
    dnf -y remove nginx mariadb-server certbot nodejs php php-fpm || true
  fi
}

# ---- main ----
require_root
detect_os

prompt PROJECT_SLUG "PROJECT_SLUG to uninstall" ""
[[ -n "$PROJECT_SLUG" ]] || die "PROJECT_SLUG required"

prompt DB_HOST "DB host used (127.0.0.1 for local)" "127.0.0.1"
prompt DB_NAME "DB name" "$PROJECT_SLUG"
prompt DB_USER "DB user" "${PROJECT_SLUG}_user"

REMOVE_PACKAGES="no"
read -r -p "Also remove installed packages (nginx/php/mysql/node/certbot)? [y/N]: " ans
ans="${ans,,}"
[[ "$ans" == "y" || "$ans" == "yes" ]] && REMOVE_PACKAGES="yes"

confirm_destroy

remove_systemd
remove_cron
remove_nginx
remove_backups
drop_db_local
remove_app
remove_user
remove_packages_optional

log "✅ Uninstall complete."