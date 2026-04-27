#!/usr/bin/env bash

set -euo pipefail

RXMR_DAEMON="${RXMR_DAEMON:-rxmrd}"
CONFIG_PATH="${RXMR_CONFIG:-$HOME/.rxmr/rxmr.conf}"
DATA_DIR="${RXMR_DATADIR:-$HOME/.rxmr}"
MINE_ADDRESS="${RXMR_ADDRESS:-}"
THREADS="${RXMR_MINING_THREADS:-}"

usage() {
    cat <<'EOF'
Start rxmrd in detached CPU-mining mode against an existing local config.

Usage:
  rxmr-start-miner --address RXMR_ADDRESS [--threads N] [--config PATH] [--datadir DIR]

Environment:
  RXMR_DAEMON          rxmrd binary path (default: rxmrd)
  RXMR_CONFIG          Config path (default: ~/.rxmr/rxmr.conf)
  RXMR_DATADIR         Datadir (default: ~/.rxmr)
  RXMR_ADDRESS         Payout address if not passed by --address
  RXMR_MINING_THREADS  Thread count (default: half the host CPUs, minimum 1)
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
        threads=$((threads / 2))
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
            --config)
                [ $# -ge 2 ] || error "--config requires a path"
                CONFIG_PATH="$2"
                shift 2
                ;;
            --datadir)
                [ $# -ge 2 ] || error "--datadir requires a path"
                DATA_DIR="$2"
                shift 2
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

main() {
    parse_args "$@"

    command -v "$RXMR_DAEMON" >/dev/null 2>&1 || error "rxmrd not found: $RXMR_DAEMON"
    [ -n "$MINE_ADDRESS" ] || error "A payout address is required (--address)"
    [ -f "$CONFIG_PATH" ] || error "Config file not found: $CONFIG_PATH"

    if [ -z "$THREADS" ]; then
        THREADS="$(default_threads)"
    fi

    case "$THREADS" in
        ''|*[!0-9]*)
            error "Thread count must be a positive integer"
            ;;
    esac

    if pgrep -x "$(basename "$RXMR_DAEMON")" >/dev/null 2>&1; then
        error "rxmrd already appears to be running; stop it first before starting a miner instance"
    fi

    mkdir -p "$DATA_DIR"

    info "Starting rxmrd in detached mining mode"
    "$RXMR_DAEMON" \
        --detach \
        --non-interactive \
        --config-file "$CONFIG_PATH" \
        --data-dir "$DATA_DIR" \
        --start-mining "$MINE_ADDRESS" \
        --mining-threads "$THREADS"

    sleep 5
    if command -v rxmr-doctor >/dev/null 2>&1; then
        rxmr-doctor --config "$CONFIG_PATH" --datadir "$DATA_DIR" || true
    else
        info "Started. Verify with curl http://127.0.0.1:18881/get_info or install rxmr-doctor."
    fi
}

main "$@"
