#!/usr/bin/env bash

set -euo pipefail

SERVICE_USER="${RXMR_SERVICE_USER:-rxmr}"
SERVICE_GROUP="${RXMR_SERVICE_GROUP:-$SERVICE_USER}"
INSTALL_BIN_DIR="${RXMR_SYSTEM_BIN_DIR:-/usr/local/bin}"
CONFIG_DIR="${RXMR_SYSTEM_CONFIG_DIR:-/etc/rxmr}"
DATA_DIR="${RXMR_SYSTEM_DATA_DIR:-/var/lib/rxmrd}"
SERVICE_DIR="${RXMR_SYSTEMD_DIR:-/etc/systemd/system}"
DAEMON_PATH="${RXMR_DAEMON_PATH:-}"
WALLET_RPC_PATH="${RXMR_WALLET_RPC_PATH:-}"
WALLET_CLI_PATH="${RXMR_WALLET_CLI_PATH:-}"
ENABLE_NOW=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'EOF'
Install rXMR as a public systemd node on this host.

Usage:
  sudo rxmr-install-public-node [--enable-now]

Environment:
  RXMR_SERVICE_USER       Service user (default: rxmr)
  RXMR_SERVICE_GROUP      Service group (default: rxmr)
  RXMR_SYSTEM_BIN_DIR     Binary install dir (default: /usr/local/bin)
  RXMR_SYSTEM_CONFIG_DIR  Config dir (default: /etc/rxmr)
  RXMR_SYSTEM_DATA_DIR    Datadir (default: /var/lib/rxmrd)
  RXMR_SYSTEMD_DIR        systemd unit dir (default: /etc/systemd/system)
EOF
}

info() { printf '[INFO] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1" >&2; }
error() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --enable-now)
                ENABLE_NOW=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown argument: $1"
                ;;
        esac
    done
}

require_root() {
    [ "$(id -u)" -eq 0 ] || error "Run this script as root"
}

resolve_binary() {
    local explicit_name command_name

    explicit_name="$1"
    command_name="$2"

    if [ -n "$explicit_name" ]; then
        [ -x "$explicit_name" ] || error "Not executable: $explicit_name"
        printf '%s\n' "$explicit_name"
        return
    fi

    command -v "$command_name" 2>/dev/null || error "Could not locate $command_name"
}

resolve_asset() {
    local relpath

    relpath="$1"
    if [ -f "$SCRIPT_DIR/$(basename "$relpath")" ]; then
        printf '%s\n' "$SCRIPT_DIR/$(basename "$relpath")"
        return
    fi
    if [ -f "$SCRIPT_DIR/$relpath" ]; then
        printf '%s\n' "$SCRIPT_DIR/$relpath"
        return
    fi
    if [ -f "$SCRIPT_DIR/../$relpath" ]; then
        printf '%s\n' "$SCRIPT_DIR/../$relpath"
        return
    fi
    error "Required asset not found: $relpath"
}

ensure_service_user() {
    if ! getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
        groupadd --system "$SERVICE_GROUP"
    fi

    if ! id "$SERVICE_USER" >/dev/null 2>&1; then
        useradd --system --home-dir "$DATA_DIR" --create-home --gid "$SERVICE_GROUP" \
            --shell /usr/sbin/nologin "$SERVICE_USER"
    fi
}

write_default_config() {
    local template_path config_path rpc_password

    template_path="$(resolve_asset contrib/init/rxmr.conf.example)"
    config_path="$CONFIG_DIR/rxmr.conf"

    if [ -f "$config_path" ]; then
        warn "Config already exists at $config_path; leaving it unchanged"
        return
    fi

    rpc_password="$(openssl rand -hex 16 2>/dev/null || od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
    sed "s#replace-this-password#$rpc_password#g" "$template_path" > "$config_path"
    chown root:"$SERVICE_GROUP" "$config_path"
    chmod 0640 "$config_path"
}

install_assets() {
    local service_template

    service_template="$(resolve_asset contrib/init/rxmrd.service)"

    install -d -m 0755 "$INSTALL_BIN_DIR"
    install -d -m 0755 "$SERVICE_DIR"
    install -d -o root -g "$SERVICE_GROUP" -m 0750 "$CONFIG_DIR"
    install -d -o "$SERVICE_USER" -g "$SERVICE_GROUP" -m 0750 "$DATA_DIR"

    install -m 0755 "$DAEMON_PATH" "$INSTALL_BIN_DIR/rxmrd"
    install -m 0755 "$WALLET_CLI_PATH" "$INSTALL_BIN_DIR/rxmr-wallet-cli"
    install -m 0755 "$WALLET_RPC_PATH" "$INSTALL_BIN_DIR/rxmr-wallet-rpc"

    for helper in doctor.sh start-miner.sh install-public-miner.sh public-apply.sh; do
        if [ -f "$SCRIPT_DIR/$helper" ]; then
            case "$helper" in
                doctor.sh) install -m 0755 "$SCRIPT_DIR/$helper" "$INSTALL_BIN_DIR/rxmr-doctor" ;;
                start-miner.sh) install -m 0755 "$SCRIPT_DIR/$helper" "$INSTALL_BIN_DIR/rxmr-start-miner" ;;
                install-public-miner.sh) install -m 0755 "$SCRIPT_DIR/$helper" "$INSTALL_BIN_DIR/rxmr-install-public-miner" ;;
                public-apply.sh) install -m 0755 "$SCRIPT_DIR/$helper" "$INSTALL_BIN_DIR/rxmr-public-apply" ;;
            esac
        fi
    done

    sed \
        -e "s#/usr/bin/rxmrd#$INSTALL_BIN_DIR/rxmrd#g" \
        -e "s#/etc/rxmr#$CONFIG_DIR#g" \
        -e "s#/var/lib/rxmrd#$DATA_DIR#g" \
        "$service_template" > "$SERVICE_DIR/rxmrd.service"
    chmod 0644 "$SERVICE_DIR/rxmrd.service"

    write_default_config
}

main() {
    parse_args "$@"
    require_root

    DAEMON_PATH="$(resolve_binary "$DAEMON_PATH" rxmrd)"
    WALLET_CLI_PATH="$(resolve_binary "$WALLET_CLI_PATH" rxmr-wallet-cli)"
    WALLET_RPC_PATH="$(resolve_binary "$WALLET_RPC_PATH" rxmr-wallet-rpc)"

    ensure_service_user
    install_assets

    systemctl daemon-reload
    if [ "$ENABLE_NOW" -eq 1 ]; then
        systemctl enable --now rxmrd
    fi

    info "Installed public-node assets."
    info "Next steps:"
    printf '       sudo systemctl enable --now rxmrd\n'
    printf '       sudo ufw allow 18880/tcp\n'
    printf '       sudo -u %s %s/rxmr-doctor --config %s/rxmr.conf --datadir %s\n' \
        "$SERVICE_USER" "$INSTALL_BIN_DIR" "$CONFIG_DIR" "$DATA_DIR"
}

main "$@"
