#!/bin/bash

# toggle_root_ssh.sh
# Enable or disable root SSH login safely on CentOS, AlmaLinux, Debian, Ubuntu
# enable or siable using enable or diable args

set -euo pipefail

LOGFILE="/var/log/toggle_root_ssh.log"
CONFIG="/etc/ssh/sshd_config"
BACKUP_DIR="/etc/ssh/backup_configs"
MAX_BACKUPS=5

function log {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOGFILE"
}

function usage {
  echo "Usage: $0 enable|disable"
  exit 1
}

function check_root {
  if [[ $EUID -ne 0 ]]; then
    log "ERROR: Please run as root."
    exit 1
  fi
}

function backup_config {
  mkdir -p "$BACKUP_DIR"
  local backup_file="$BACKUP_DIR/sshd_config.$(date +%F_%H%M%S).bak"
  cp "$CONFIG" "$backup_file"
  log "Backup created at $backup_file"

  # Cleanup old backups, keep latest MAX_BACKUPS
  local backups_count
  backups_count=$(ls -1 "$BACKUP_DIR"/sshd_config.*.bak 2>/dev/null | wc -l || echo 0)
  if (( backups_count > MAX_BACKUPS )); then
    ls -1tr "$BACKUP_DIR"/sshd_config.*.bak | head -n $((backups_count - MAX_BACKUPS)) | xargs -r rm -f
    log "Old backups cleaned up, kept latest $MAX_BACKUPS."
  fi
}

function set_permit_root_login {
  local value=$1

  # Escape forward slash for sed
  local escaped_value
  escaped_value=$(printf '%s\n' "$value" | sed 's/[\/&]/\\&/g')

  # Use sed to uncomment and set PermitRootLogin or add if missing
  if grep -q -E '^\s*#?\s*PermitRootLogin\s+' "$CONFIG"; then
    sed -ri "s|^\s*#?\s*PermitRootLogin\s+.*|PermitRootLogin $escaped_value|" "$CONFIG"
  else
    echo "PermitRootLogin $value" >> "$CONFIG"
  fi

  log "Set PermitRootLogin to $value in $CONFIG"
}

function detect_ssh_service {
  if systemctl list-unit-files | grep -q '^sshd\.service'; then
    echo "sshd"
  elif systemctl list-unit-files | grep -q '^ssh\.service'; then
    echo "ssh"
  else
    # Fallback for SysVinit or unknown
    if command -v service >/dev/null 2>&1; then
      echo "service"
    else
      log "ERROR: Could not detect sshd service manager (systemctl or service)."
      exit 1
    fi
  fi
}

function restart_ssh_service {
  local svc="$1"
  if [[ "$svc" == "sshd" || "$svc" == "ssh" ]]; then
    log "Restarting systemd service $svc..."
    systemctl restart "$svc"
  elif [[ "$svc" == "service" ]]; then
    log "Restarting ssh service using service command..."
    service sshd restart 2>/dev/null || service ssh restart || {
      log "ERROR: Failed to restart sshd/ssh service using service command."
      exit 1
    }
  else
    log "ERROR: Unknown ssh service manager: $svc"
    exit 1
  fi
  log "SSH service restarted."
}

function validate_sshd_config {
  if sshd -t 2>&1 | tee -a "$LOGFILE" | grep -q 'error'; then
    log "ERROR: sshd_config syntax is invalid after change. Restoring backup."
    cp "$BACKUP_DIR"/sshd_config.*.bak "$CONFIG"
    exit 1
  fi
  log "sshd_config syntax is valid."
}

### MAIN ###

check_root

if [[ $# -ne 1 ]]; then
  usage
fi

case "$1" in
  enable) val="yes" ;;
  disable) val="no" ;;
  *)
    usage
    ;;
esac

backup_config
set_permit_root_login "$val"
validate_sshd_config

svc=$(detect_ssh_service)
restart_ssh_service "$svc"

log "Root SSH login toggled $1 successfully."

exit 0
