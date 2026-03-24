#!/usr/bin/env bash
# hermes-admin — restricted privileged helper for Hermes Agent
#
# Root-owned. Lives at /usr/local/sbin/hermes-admin
# Called via: sudo -n /usr/local/sbin/hermes-admin <subcommand> [args]
#
# Do NOT make this writable by non-root users.

set -euo pipefail

SCRIPT_NAME="hermes-admin"
LOG_TAG="hermes-admin"

# --- Configuration -----------------------------------------------------------

# Services that can be targeted by restart-service, service-status, service-logs.
# Edit this list for your setup.
ALLOWED_SERVICES=(
    "hermes-gateway"
    "nginx"
    "docker"
    "tailscaled"
)

# --- Helpers -----------------------------------------------------------------

log_action() {
    logger -t "$LOG_TAG" "user=$(whoami) subcommand=$1 args=${*:2}"
}

die() {
    echo "ERROR: $*" >&2
    logger -t "$LOG_TAG" "DENIED: $*"
    exit 1
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME <subcommand> [args]

Subcommands:
  tailscale-status          Show Tailscale connection status
  install-tailscale         Install Tailscale (Debian/Ubuntu)
  tailscale-up              Run 'tailscale up' and return login URL
  restart-service <name>    Restart an allowlisted systemd service
  service-status <name>     Show status of an allowlisted service
  service-logs <name>       Show recent journal entries for a service
  check-disk                Show disk usage summary
  check-memory              Show memory usage summary
  need-reboot               Check if a reboot is required
  update-check              Run apt update (safe — does not upgrade)
EOF
    exit 1
}

validate_service() {
    local svc="$1"
    for allowed in "${ALLOWED_SERVICES[@]}"; do
        if [[ "$svc" == "$allowed" ]]; then
            return 0
        fi
    done
    die "Service '$svc' is not in the allowlist"
}

# --- Subcommands -------------------------------------------------------------

cmd_tailscale_status() {
    tailscale status 2>&1 || echo "Tailscale may not be installed or running."
}

cmd_install_tailscale() {
    if command -v tailscale &>/dev/null; then
        echo "Tailscale is already installed."
        tailscale version
        return 0
    fi
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    systemctl enable --now tailscaled
    echo "Tailscale installed and service started."
    tailscale version
}

cmd_tailscale_up() {
    echo "Starting Tailscale login flow..."
    # --timeout 60 prevents indefinite hangs
    tailscale up --timeout 60 2>&1 || true
    echo ""
    echo "If a login URL appeared above, open it in your browser to authorize this node."
}

cmd_restart_service() {
    local svc="${1:?Service name required}"
    validate_service "$svc"
    systemctl restart "$svc"
    echo "Restarted $svc"
    systemctl status "$svc" --no-pager -l 2>&1 | head -20
}

cmd_service_status() {
    local svc="${1:?Service name required}"
    validate_service "$svc"
    systemctl status "$svc" --no-pager -l 2>&1 | head -30
}

cmd_service_logs() {
    local svc="${1:?Service name required}"
    validate_service "$svc"
    journalctl -u "$svc" -n 50 --no-pager 2>&1
}

cmd_check_disk() {
    echo "=== Filesystem usage ==="
    df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs 2>/dev/null || df -h
    echo ""
    echo "=== Large directories in /home ==="
    du -sh /home/*/ 2>/dev/null | sort -rh | head -10
}

cmd_check_memory() {
    echo "=== Memory ==="
    free -h
    echo ""
    echo "=== Top processes by memory ==="
    ps aux --sort=-%mem | head -10
}

cmd_need_reboot() {
    if [[ -f /var/run/reboot-required ]]; then
        echo "REBOOT REQUIRED"
        cat /var/run/reboot-required.pkgs 2>/dev/null || true
    else
        echo "No reboot required."
    fi
}

cmd_update_check() {
    echo "Running apt update (check only, no upgrades)..."
    apt-get update -qq 2>&1
    echo ""
    echo "=== Available upgrades ==="
    apt list --upgradable 2>/dev/null || true
}

# --- Main dispatch -----------------------------------------------------------

if [[ $# -lt 1 ]]; then
    usage
fi

SUBCOMMAND="$1"
shift

log_action "$SUBCOMMAND" "$@"

case "$SUBCOMMAND" in
    tailscale-status)   cmd_tailscale_status ;;
    install-tailscale)  cmd_install_tailscale ;;
    tailscale-up)       cmd_tailscale_up ;;
    restart-service)    cmd_restart_service "$@" ;;
    service-status)     cmd_service_status "$@" ;;
    service-logs)       cmd_service_logs "$@" ;;
    check-disk)         cmd_check_disk ;;
    check-memory)       cmd_check_memory ;;
    need-reboot)        cmd_need_reboot ;;
    update-check)       cmd_update_check ;;
    *)                  die "Unknown subcommand: $SUBCOMMAND" ;;
esac
