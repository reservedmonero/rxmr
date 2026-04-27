#!/usr/bin/env bash

set -euo pipefail

SERVICE_NAME="${RXMR_SYSTEMD_SERVICE_NAME:-rxmrd.service}"
SERVICE_DIR="${RXMR_SYSTEMD_DIR:-/etc/systemd/system}"
INSTALL_BIN_DIR="${RXMR_SYSTEM_BIN_DIR:-/usr/local/bin}"
CONFIG_DIR="${RXMR_SYSTEM_CONFIG_DIR:-/etc/rxmr}"
DATA_DIR="${RXMR_SYSTEM_DATA_DIR:-/var/lib/rxmrd}"
MINE_ADDRESS="${RXMR_ADDRESS:-}"
THREADS="${RXMR_MINING_THREADS:-}"
ENABLE_NOW=0
REMOVE_OVERRIDE=0

usage() {
    cat <<'EOF'
Install or remove a persistent mining override for the rxmrd systemd service.

Usage:
  sudo rxmr-install-public-miner --address RXMR_ADDRESS [--threads N] [--enable-now]
  sudo rxmr-install-public-miner --remove [--enable-now]
EOF
}

info() { printf '[INFO] %s\n' "$1"; }
error() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

cpu_count() {
    nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 1
}

default_threads() {
    local threads
    threads="$(cpu_count)"
    if [ "$threads" -gt 1 ]; then
        threads=$((threads - 1))
    fi
    if [ "$threads" -lt 1 ]; then
        threads=1
    fi
    printf '%s\n' "$threads"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --address)
                [ $# -ge 2 ] || error "--address requires a value"
                MINE_ADDRESS="$2"
                shift 2
                ;;
            --threads)
                [ $# -ge 2 ] || error "--threads requires a value"
                THREADS="$2"
                shift 2
                ;;
            --enable-now)
                ENABLE_NOW=1
                shift
                ;;
            --remove)
                REMOVE_OVERRIDE=1
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

dropin_dir() {
    printf '%s/%s.d\n' "$SERVICE_DIR" "$SERVICE_NAME"
}

dropin_path() {
    printf '%s/mining.conf\n' "$(dropin_dir)"
}

install_override() {
    [ -x "$INSTALL_BIN_DIR/rxmrd" ] || error "rxmrd not found at $INSTALL_BIN_DIR/rxmrd"
    [ -f "$SERVICE_DIR/$SERVICE_NAME" ] || error "Base service $SERVICE_DIR/$SERVICE_NAME not found"

    if [ -z "$THREADS" ]; then
        THREADS="$(default_threads)"
    fi

    install -d -m 0755 "$(dropin_dir)"
    cat > "$(dropin_path)" <<EOF
[Service]
Nice=19
ExecStart=
ExecStart=$INSTALL_BIN_DIR/rxmrd --non-interactive --config-file $CONFIG_DIR/rxmr.conf --data-dir $DATA_DIR --start-mining $MINE_ADDRESS --mining-threads $THREADS
EOF

    chmod 0644 "$(dropin_path)"
    systemctl daemon-reload
    info "Installed mining override at $(dropin_path)"
    if [ "$ENABLE_NOW" -eq 1 ]; then
        systemctl enable --now "$SERVICE_NAME"
    fi
}

remove_override() {
    if [ -f "$(dropin_path)" ]; then
        rm -f "$(dropin_path)"
        rmdir --ignore-fail-on-non-empty "$(dropin_dir)" 2>/dev/null || true
        systemctl daemon-reload
        info "Removed mining override"
    else
        info "No mining override present"
    fi

    if [ "$ENABLE_NOW" -eq 1 ]; then
        systemctl restart "$SERVICE_NAME"
    fi
}

main() {
    parse_args "$@"
    require_root

    if [ "$REMOVE_OVERRIDE" -eq 1 ]; then
        remove_override
        exit 0
    fi

    [ -n "$MINE_ADDRESS" ] || error "A payout address is required (--address)"
    install_override
}

main "$@"
