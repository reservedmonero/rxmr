#!/usr/bin/env bash

set -euo pipefail

RXMR_CONFIG="${RXMR_CONFIG:-}"
RXMR_DATADIR="${RXMR_DATADIR:-}"
HEALTHY=1
CONFIG_PATH=""
OUTPUT_JSON=0
STRICT=0
EXPECT_PUBLIC=0
EXPECT_MINER=0
WARNINGS=()

usage() {
    cat <<'EOF'
Verify that a local rXMR node is healthy enough to serve peers and mine.

Usage:
  ./scripts/doctor.sh [--config PATH] [--datadir DIR] [--json] [--strict] [--expect-public] [--expect-miner]
  rxmr-doctor [same flags]

Environment:
  RXMR_CONFIG   Config path (default: ~/.rxmr/rxmr.conf)
  RXMR_DATADIR  Datadir (default: ~/.rxmr)
EOF
}

info() {
    if [ "$OUTPUT_JSON" -eq 0 ]; then
        printf '[INFO] %s\n' "$1"
    fi
}

warn() {
    if [ "$OUTPUT_JSON" -eq 0 ]; then
        printf '[WARN] %s\n' "$1"
    fi
    HEALTHY=0
    WARNINGS+=("$1")
}

error() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --config)
                [ $# -ge 2 ] || error "--config requires a path"
                RXMR_CONFIG="$2"
                shift 2
                ;;
            --datadir)
                [ $# -ge 2 ] || error "--datadir requires a path"
                RXMR_DATADIR="$2"
                shift 2
                ;;
            --json)
                OUTPUT_JSON=1
                shift
                ;;
            --strict)
                STRICT=1
                shift
                ;;
            --expect-public)
                EXPECT_PUBLIC=1
                shift
                ;;
            --expect-miner)
                EXPECT_MINER=1
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

resolve_config_path() {
    CONFIG_PATH="$HOME/.rxmr/rxmr.conf"
    if [ -n "$RXMR_CONFIG" ]; then
        CONFIG_PATH="$RXMR_CONFIG"
    elif [ -n "$RXMR_DATADIR" ] && [ -f "$RXMR_DATADIR/rxmr.conf" ]; then
        CONFIG_PATH="$RXMR_DATADIR/rxmr.conf"
    fi
}

config_value() {
    local key

    key="$1"
    [ -f "$CONFIG_PATH" ] || return 1
    sed -n "s/^[[:space:]]*$key[[:space:]]*=[[:space:]]*//p" "$CONFIG_PATH" | tail -1
}

json_value() {
    python3 -c '
import json
import sys

path = [part for part in sys.argv[1].split(".") if part]
payload = json.loads(sys.argv[2])
value = payload
for part in path:
    if not isinstance(value, dict):
        raise SystemExit(1)
    value = value.get(part)
    if value is None:
        raise SystemExit(1)

if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
' "$1" "$(cat)"
}

warnings_json() {
    python3 - <<'PY' "${WARNINGS[@]}"
import json
import sys
print(json.dumps(sys.argv[1:]))
PY
}

print_json_status() {
    local rpc_ok="$1"
    local public_reachable="$2"
    local miner_configured="$3"
    local miner_running="$4"
    local ready="$5"
    local warning_json="$6"
    local services_json="$7"

    python3 - "$rpc_ok" "$public_reachable" "$miner_configured" "$miner_running" \
        "$ready" "${height:-0}" "${target_height:-0}" "${incoming:-0}" \
        "${outgoing:-0}" "${synchronized:-false}" "${busy_syncing:-false}" \
        "${nettype:-unknown}" "${p2p_port:-18880}" "${address:-}" \
        "${threads:-0}" "${speed:-0}" "$warning_json" "$services_json" <<'PY'
import json
import sys

def as_bool(value: str) -> bool:
    return value == "true"

def as_int(value: str) -> int:
    try:
        return int(value)
    except Exception:
        return 0

payload = {
    "rpc_ok": as_bool(sys.argv[1]),
    "public_reachable": as_bool(sys.argv[2]),
    "miner_configured": as_bool(sys.argv[3]),
    "miner_running": as_bool(sys.argv[4]),
    "ready": as_bool(sys.argv[5]),
    "height": as_int(sys.argv[6]),
    "target_height": as_int(sys.argv[7]),
    "connections_in": as_int(sys.argv[8]),
    "connections_out": as_int(sys.argv[9]),
    "synchronized": as_bool(sys.argv[10]),
    "busy_syncing": as_bool(sys.argv[11]),
    "nettype": sys.argv[12],
    "p2p_port": as_int(sys.argv[13]),
    "mining_address": sys.argv[14],
    "mining_threads": as_int(sys.argv[15]),
    "mining_hashrate_hps": as_int(sys.argv[16]),
    "warnings": json.loads(sys.argv[17]),
    "services": json.loads(sys.argv[18]),
}
print(json.dumps(payload, indent=2))
PY
}

show_config_peers() {
    if [ ! -f "$CONFIG_PATH" ]; then
        warn "Config not found at $CONFIG_PATH"
        return
    fi

    if [ "$OUTPUT_JSON" -eq 1 ]; then
        return
    fi

    info "Configured peers from $CONFIG_PATH:"
    grep '^add-peer=' "$CONFIG_PATH" || warn "No add-peer entries found"
}

main() {
    local rpc_host rpc_port rpc_login info_json mining_json
    local height target_height incoming outgoing busy_syncing synchronized nettype
    local active address threads speed p2p_port
    local rpc_ok public_reachable miner_configured miner_running ready
    local warning_json services_json

    parse_args "$@"
    resolve_config_path

    command -v curl >/dev/null 2>&1 || error "curl is required"
    command -v python3 >/dev/null 2>&1 || error "python3 is required"

    rpc_host="$(config_value rpc-bind-ip || true)"
    rpc_port="$(config_value rpc-bind-port || true)"
    rpc_login="$(config_value rpc-login || true)"
    p2p_port="$(config_value p2p-bind-port || true)"

    [ -n "$rpc_host" ] || rpc_host="127.0.0.1"
    [ -n "$rpc_port" ] || rpc_port="18881"
    [ -n "$p2p_port" ] || p2p_port="18880"

    RPC_BASE="http://$rpc_host:$rpc_port"
    CURL_AUTH=()
    if [ -n "$rpc_login" ]; then
        CURL_AUTH=(--digest -u "$rpc_login")
    fi

    info "RPC endpoint: $RPC_BASE"

    info_json="$(curl -fsS "${CURL_AUTH[@]}" -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' \
        "$RPC_BASE/json_rpc" 2>/dev/null || true)"
    if [ -z "$info_json" ]; then
        rpc_ok=false
        public_reachable=false
        miner_configured=false
        miner_running=false
        ready=false
        warn "Could not reach rxmrd RPC. Start the daemon first."
        show_config_peers
        warning_json="$(warnings_json)"
        services_json='{"rxmrd":"unreachable"}'
        if [ "$OUTPUT_JSON" -eq 1 ]; then
            print_json_status "$rpc_ok" "$public_reachable" "$miner_configured" \
                "$miner_running" "$ready" "$warning_json" "$services_json"
        fi
        exit 1
    fi
    rpc_ok=true

    mining_json="$(curl -fsS "${CURL_AUTH[@]}" -H 'Content-Type: application/json' \
        -d '{}' "$RPC_BASE/mining_status" 2>/dev/null || true)"

    height="$(printf '%s' "$info_json" | json_value result.height 2>/dev/null || true)"
    target_height="$(printf '%s' "$info_json" | json_value result.target_height 2>/dev/null || true)"
    incoming="$(printf '%s' "$info_json" | json_value result.incoming_connections_count 2>/dev/null || true)"
    outgoing="$(printf '%s' "$info_json" | json_value result.outgoing_connections_count 2>/dev/null || true)"
    busy_syncing="$(printf '%s' "$info_json" | json_value result.busy_syncing 2>/dev/null || true)"
    synchronized="$(printf '%s' "$info_json" | json_value result.synchronized 2>/dev/null || true)"
    nettype="$(printf '%s' "$info_json" | json_value result.nettype 2>/dev/null || true)"

    [ -n "$nettype" ] && info "Nettype: $nettype"
    [ -n "$height" ] && info "Height: $height"
    [ -n "$target_height" ] && info "Target height: $target_height"
    [ -n "$incoming" ] && info "Inbound peers: $incoming"
    [ -n "$outgoing" ] && info "Outbound peers: $outgoing"
    [ -n "$busy_syncing" ] && info "Busy syncing: $busy_syncing"
    [ -n "$synchronized" ] && info "Synchronized: $synchronized"

    if [ "${nettype:-mainnet}" != "mainnet" ]; then
        warn "Daemon is not on mainnet"
    fi
    if [ "${outgoing:-0}" -eq 0 ]; then
        warn "No outbound peers yet"
    fi
    if [ "${busy_syncing:-false}" = "true" ] || [ "${synchronized:-false}" != "true" ]; then
        warn "Daemon is still syncing"
    fi

    public_reachable=false
    if [ "${incoming:-0}" -gt 0 ]; then
        public_reachable=true
    elif [ "$EXPECT_PUBLIC" -eq 1 ]; then
        warn "Expected a public node, but inbound reachability is not yet proven"
    else
        info "Inbound reachability is not proven yet. Open TCP/18880 if this host should serve peers."
    fi

    miner_configured=false
    miner_running=false
    if [ -n "$mining_json" ]; then
        active="$(printf '%s' "$mining_json" | json_value active 2>/dev/null || true)"
        address="$(printf '%s' "$mining_json" | json_value address 2>/dev/null || true)"
        threads="$(printf '%s' "$mining_json" | json_value threads_count 2>/dev/null || true)"
        speed="$(printf '%s' "$mining_json" | json_value speed 2>/dev/null || true)"
        miner_configured=true

        [ -n "$active" ] && info "Mining active: $active"
        [ -n "$address" ] && info "Mining address: $address"
        [ -n "$threads" ] && info "Mining threads: $threads"
        [ -n "$speed" ] && info "Reported hashrate: ${speed} H/s"

        if [ "${active:-false}" = "true" ]; then
            miner_running=true
        elif [ "$EXPECT_MINER" -eq 1 ]; then
            warn "Expected mining to be active, but mining_status reports inactive"
        else
            info "Mining is not active. Start it with rxmr-start-miner --address YOUR_RXMR_ADDRESS"
        fi
    else
        warn "Could not read /mining_status"
    fi

    if command -v ss >/dev/null 2>&1; then
        if ss -ltn 2>/dev/null | grep -q "[.:]$p2p_port[[:space:]]"; then
            info "P2P port listening: $p2p_port"
        else
            warn "P2P port $p2p_port is not listening"
        fi
    fi

    show_config_peers

    services_json="$(python3 - <<'PY' "$(systemctl is-active rxmrd.service 2>/dev/null || printf unknown)" "${active:-unknown}" "${threads:-0}"
import json
import sys
print(json.dumps({"rxmrd": {"service": sys.argv[1], "mining_active": sys.argv[2], "mining_threads": sys.argv[3]}}))
PY
)"
    warning_json="$(warnings_json)"

    ready=false
    if [ "$rpc_ok" = true ] && [ "${outgoing:-0}" -gt 0 ] && \
        [ "${busy_syncing:-false}" != "true" ] && [ "${synchronized:-false}" = "true" ] && \
        { [ "$EXPECT_PUBLIC" -eq 0 ] || [ "$public_reachable" = true ]; } && \
        { [ "$EXPECT_MINER" -eq 0 ] || [ "$miner_running" = true ]; }; then
        ready=true
    fi

    if [ "$OUTPUT_JSON" -eq 1 ]; then
        print_json_status "$rpc_ok" "$public_reachable" "$miner_configured" \
            "$miner_running" "$ready" "$warning_json" "$services_json"
    fi

    if [ "$ready" = true ]; then
        info "Node looks healthy for the live rXMR network"
        exit 0
    fi

    if [ "$STRICT" -eq 1 ] || [ "$EXPECT_PUBLIC" -eq 1 ] || [ "$EXPECT_MINER" -eq 1 ]; then
        exit 1
    fi

    warn "Node needs attention before it is fully ready for public mining"
    exit 1
}

main "$@"
