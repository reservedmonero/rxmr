#!/usr/bin/env bash

set -euo pipefail

RELEASE_VERSION="${RXMR_VERSION:-}"
SOURCE_REF="${RXMR_SOURCE_REF:-}"
DEFAULT_SOURCE_REF="master"
INSTALL_DIR="${RXMR_INSTALL_DIR:-$HOME/.local/bin}"
DATA_DIR="${RXMR_DATA_DIR:-$HOME/.rxmr}"
REPO="happybigmtn/rXMR"
GITHUB_URL="https://github.com/$REPO"
GITHUB_API_URL="https://api.github.com/repos/$REPO"
TEMP_SOURCE_ROOT=""
TEMP_RELEASE_ROOT=""
SOURCE_DIR=""
RELEASE_DIR=""

PUBLIC_SEEDS=(
    "95.111.227.14:18880"
    "95.111.229.108:18880"
    "95.111.239.142:18880"
    "161.97.83.147:18880"
    "161.97.97.83:18880"
    "161.97.114.192:18880"
    "161.97.117.0:18880"
    "194.163.144.177:18880"
    "185.218.126.23:18880"
    "185.239.209.227:18880"
)

FORCE=0
ADD_PATH=0
SKIP_DEPS=0
NO_CONFIG=0
SOURCE_STATIC="${RXMR_SOURCE_STATIC:-}"

usage() {
    cat <<'EOF'
rXMR installer

Usage:
  ./install.sh [--force] [--add-path] [--skip-deps] [--no-config]

Environment:
  RXMR_VERSION      Optional release tag to install from GitHub releases
  RXMR_SOURCE_REF   Git ref to build from source (default: master)
  RXMR_INSTALL_DIR  Binary install dir (default: ~/.local/bin)
  RXMR_DATA_DIR     Datadir/config dir (default: ~/.rxmr)
EOF
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
success() { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; exit 1; }

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --force)
                FORCE=1
                shift
                ;;
            --add-path)
                ADD_PATH=1
                shift
                ;;
            --skip-deps)
                SKIP_DEPS=1
                shift
                ;;
            --no-config)
                NO_CONFIG=1
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

download_file() {
    local url dest

    url="$1"
    dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSLo "$dest" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$dest" "$url"
    else
        error "Need curl or wget to download files"
    fi
}

download_to_stdout() {
    local url

    url="$1"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O - "$url"
    else
        error "Need curl or wget to download files"
    fi
}

cpu_count() {
    nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 1
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

have_pkg_config_lib() {
    local name
    name="$1"
    if ! have_cmd pkg-config; then
        return 1
    fi
    pkg-config --exists "$name" >/dev/null 2>&1
}

have_unbound_dev() {
    if have_pkg_config_lib libunbound; then
        return 0
    fi
    if [ -f /usr/include/unbound.h ] || [ -f /usr/include/unbound/unbound.h ]; then
        if have_cmd ldconfig && ldconfig -p 2>/dev/null | grep -q 'libunbound\.so'; then
            return 0
        fi
        for libdir in /usr/lib /usr/lib64 /usr/lib/x86_64-linux-gnu /usr/lib/aarch64-linux-gnu /usr/local/lib; do
            if [ -e "$libdir/libunbound.so" ] || [ -e "$libdir/libunbound.a" ]; then
                return 0
            fi
        done
    fi
    return 1
}

source_build_deps_ready() {
    have_cmd cmake && have_cmd git && have_cmd make && have_cmd g++ && have_unbound_dev
}

detect_platform() {
    local os arch

    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"

    case "$os" in
        linux*)
            os="linux"
            ;;
        darwin*)
            os="macos"
            ;;
        *)
            error "Unsupported OS: $os"
            ;;
    esac

    case "$arch" in
        x86_64|amd64) arch="x86_64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) error "Unsupported architecture: $arch" ;;
    esac

    PLATFORM="${os}-${arch}"
    info "Detected platform: $PLATFORM"
}

check_binary_available() {
    case "$PLATFORM" in
        linux-x86_64|linux-arm64|macos-x86_64|macos-arm64)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

verify_release_asset() {
    local asset_path checksums_path asset_name

    asset_path="$1"
    checksums_path="$2"
    asset_name="$(basename "$asset_path")"

    if command -v sha256sum >/dev/null 2>&1; then
        (
            cd "$(dirname "$asset_path")"
            grep " $asset_name\$" "$checksums_path" | sha256sum -c -
        ) || error "Checksum verification failed for $asset_name"
    elif command -v shasum >/dev/null 2>&1; then
        (
            cd "$(dirname "$asset_path")"
            grep " $asset_name\$" "$checksums_path" | shasum -a 256 -c -
        ) || error "Checksum verification failed for $asset_name"
    else
        warn "No checksum tool found; skipping verification"
    fi
}

fetch_latest_release_version() {
    local response

    response="$(download_to_stdout "$GITHUB_API_URL/releases" 2>/dev/null || true)"
    [ -n "$response" ] || return 1
    python3 -c '
import json
import sys

platform = sys.argv[1]
tarball_suffix = f"-{platform}.tar.gz"

try:
    payload = json.loads(sys.argv[2])
except Exception:
    raise SystemExit(1)

if not isinstance(payload, list):
    raise SystemExit(1)

for release in payload:
    tag = release.get("tag_name")
    if not tag:
        continue
    assets = {asset.get("name") for asset in (release.get("assets") or [])}
    if f"rxmr-{tag}{tarball_suffix}" in assets and "SHA256SUMS" in assets:
        print(tag)
        raise SystemExit(0)

raise SystemExit(1)
' "$PLATFORM" "$response"
}

install_asset_if_present() {
    local source_path target_name mode

    source_path="$1"
    target_name="$2"
    mode="$3"

    if [ -f "$source_path" ]; then
        install -m "$mode" "$source_path" "$INSTALL_DIR/$target_name"
    fi
}

binary_runtime_ready() {
    local binary_path

    binary_path="$1"
    [ -x "$binary_path" ] || return 1

    if command -v ldd >/dev/null 2>&1; then
        if ldd "$binary_path" 2>/dev/null | grep -q "not found"; then
            return 1
        fi
    fi

    return 0
}

source_static_value() {
    if [ -n "$SOURCE_STATIC" ]; then
        case "$SOURCE_STATIC" in
            1|true|TRUE|on|ON|yes|YES)
                printf 'ON\n'
                return
                ;;
            0|false|FALSE|off|OFF|no|NO)
                printf 'OFF\n'
                return
                ;;
            *)
                error "RXMR_SOURCE_STATIC must be one of: on/off, true/false, yes/no, 1/0"
                ;;
        esac
    fi

    printf 'OFF\n'
}

install_from_release() {
    local version tarball checksums temp_root

    version="$1"
    check_binary_available || return 1

    tarball="rxmr-${version}-${PLATFORM}.tar.gz"
    temp_root="$(mktemp -d)"
    TEMP_RELEASE_ROOT="$temp_root"

    download_file "$GITHUB_URL/releases/download/$version/$tarball" "$temp_root/$tarball" || return 1
    download_file "$GITHUB_URL/releases/download/$version/SHA256SUMS" "$temp_root/SHA256SUMS" || return 1
    verify_release_asset "$temp_root/$tarball" "$temp_root/SHA256SUMS"

    tar -xzf "$temp_root/$tarball" -C "$temp_root"
    RELEASE_DIR="$(find "$temp_root" -mindepth 1 -maxdepth 1 -type d | head -1)"
    [ -n "$RELEASE_DIR" ] || error "Could not find extracted release payload"

    install -d -m 0755 "$INSTALL_DIR"
    install -m 0755 "$RELEASE_DIR/rxmrd" "$INSTALL_DIR/rxmrd"
    install -m 0755 "$RELEASE_DIR/rxmr-wallet-cli" "$INSTALL_DIR/rxmr-wallet-cli"
    install -m 0755 "$RELEASE_DIR/rxmr-wallet-rpc" "$INSTALL_DIR/rxmr-wallet-rpc"

    install_asset_if_present "$RELEASE_DIR/rxmr-start-miner" "rxmr-start-miner" 0755
    install_asset_if_present "$RELEASE_DIR/rxmr-doctor" "rxmr-doctor" 0755
    install_asset_if_present "$RELEASE_DIR/rxmr-install-public-node" "rxmr-install-public-node" 0755
    install_asset_if_present "$RELEASE_DIR/rxmr-install-public-miner" "rxmr-install-public-miner" 0755
    install_asset_if_present "$RELEASE_DIR/rxmr-public-apply" "rxmr-public-apply" 0755
    install_asset_if_present "$RELEASE_DIR/rxmrd.service" "rxmrd.service" 0644
    install_asset_if_present "$RELEASE_DIR/rxmr.conf.example" "rxmr.conf.example" 0644
    install_asset_if_present "$RELEASE_DIR/PUBLIC-NODE.md" "PUBLIC-NODE.md" 0644

    if ! binary_runtime_ready "$INSTALL_DIR/rxmrd" || \
        ! binary_runtime_ready "$INSTALL_DIR/rxmr-wallet-cli" || \
        ! binary_runtime_ready "$INSTALL_DIR/rxmr-wallet-rpc"; then
        warn "Tagged release $version is missing required runtime libraries on this host"
        return 1
    fi

    success "Installed tagged release $version"
    return 0
}

in_source_tree() {
    [ -f "$PWD/CMakeLists.txt" ] && [ -d "$PWD/src" ] && [ -f "$PWD/install.sh" ]
}

install_deps() {
    if [ "$SKIP_DEPS" -eq 1 ]; then
        warn "Skipping dependency installation"
        return
    fi

    if source_build_deps_ready; then
        info "Source build dependencies already present; skipping package-manager dependency install"
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        info "Installing build dependencies via apt"
        sudo apt-get update
        sudo apt-get install -y \
            build-essential cmake pkg-config git python3 \
            libboost-all-dev libssl-dev libzmq3-dev libunbound-dev \
            libsodium-dev libhidapi-dev liblzma-dev libreadline-dev \
            libexpat1-dev libpgm-dev libusb-1.0-0-dev libudev-dev \
            libevent-dev
        return
    fi

    if command -v brew >/dev/null 2>&1; then
        info "Installing build dependencies via Homebrew"
        brew install cmake boost openssl zmq unbound libsodium hidapi readline expat
        return
    fi

    warn "No supported package manager found; make sure the rXMR build dependencies are installed manually"
}

prepare_source_tree() {
    local ref temp_root

    ref="$1"
    if in_source_tree && [ "$ref" = "$DEFAULT_SOURCE_REF" ]; then
        SOURCE_DIR="$PWD"
        return
    fi

    temp_root="$(mktemp -d)"
    TEMP_SOURCE_ROOT="$temp_root"
    git clone "$GITHUB_URL.git" "$temp_root/rXMR"
    (
        cd "$temp_root/rXMR"
        git checkout "$ref"
        git submodule update --init --recursive
    )
    SOURCE_DIR="$temp_root/rXMR"
}

install_from_source() {
    local ref build_dir static_value

    ref="$1"
    install_deps
    prepare_source_tree "$ref"
    static_value="$(source_static_value)"

    build_dir="$SOURCE_DIR/build"
    info "Building rXMR from source at $ref (STATIC=$static_value)"
    cmake -S "$SOURCE_DIR" -B "$build_dir" -D BUILD_TESTS=OFF -D CMAKE_BUILD_TYPE=Release -D STATIC="$static_value"
    cmake --build "$build_dir" -j"$(cpu_count)" --target daemon simplewallet wallet_rpc_server

    install -d -m 0755 "$INSTALL_DIR"
    install -m 0755 "$build_dir/bin/rxmrd" "$INSTALL_DIR/rxmrd"
    install -m 0755 "$build_dir/bin/rxmr-wallet-cli" "$INSTALL_DIR/rxmr-wallet-cli"
    install -m 0755 "$build_dir/bin/rxmr-wallet-rpc" "$INSTALL_DIR/rxmr-wallet-rpc"
    install -m 0755 "$SOURCE_DIR/scripts/start-miner.sh" "$INSTALL_DIR/rxmr-start-miner"
    install -m 0755 "$SOURCE_DIR/scripts/doctor.sh" "$INSTALL_DIR/rxmr-doctor"
    install -m 0755 "$SOURCE_DIR/scripts/install-public-node.sh" "$INSTALL_DIR/rxmr-install-public-node"
    install -m 0755 "$SOURCE_DIR/scripts/install-public-miner.sh" "$INSTALL_DIR/rxmr-install-public-miner"
    install -m 0755 "$SOURCE_DIR/scripts/public-apply.sh" "$INSTALL_DIR/rxmr-public-apply"
    install_asset_if_present "$SOURCE_DIR/contrib/init/rxmrd.service" "rxmrd.service" 0644
    install_asset_if_present "$SOURCE_DIR/contrib/init/rxmr.conf.example" "rxmr.conf.example" 0644
    install_asset_if_present "$SOURCE_DIR/docs/public-node.md" "PUBLIC-NODE.md" 0644

    if ! binary_runtime_ready "$INSTALL_DIR/rxmrd" || \
        ! binary_runtime_ready "$INSTALL_DIR/rxmr-wallet-cli" || \
        ! binary_runtime_ready "$INSTALL_DIR/rxmr-wallet-rpc"; then
        error "Source build completed but installed binaries are missing required runtime libraries"
    fi

    success "Built and installed rXMR from source"
}

setup_config() {
    local config_path rpc_password

    if [ "$NO_CONFIG" -eq 1 ]; then
        warn "Skipping config creation (--no-config)"
        return
    fi

    mkdir -p "$DATA_DIR"
    config_path="$DATA_DIR/rxmr.conf"
    if [ -f "$config_path" ]; then
        info "Keeping existing config at $config_path"
        return
    fi

    rpc_password="$(openssl rand -hex 16 2>/dev/null || od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
    {
        printf 'data-dir=%s\n' "$DATA_DIR"
        printf 'log-file=%s/rxmrd.log\n' "$DATA_DIR"
        printf 'log-level=0\n'
        printf 'non-interactive=1\n'
        printf 'check-updates=disabled\n'
        printf 'no-igd=1\n'
        printf 'p2p-bind-ip=0.0.0.0\n'
        printf 'p2p-bind-port=18880\n'
        printf 'confirm-external-bind=1\n'
        printf 'rpc-bind-ip=127.0.0.1\n'
        printf 'rpc-bind-port=18881\n'
        printf 'zmq-rpc-bind-ip=127.0.0.1\n'
        printf 'zmq-rpc-bind-port=18882\n'
        printf 'rpc-login=agent:%s\n' "$rpc_password"
        for seed in "${PUBLIC_SEEDS[@]}"; do
            printf 'add-peer=%s\n' "$seed"
        done
    } > "$config_path"

    chmod 0600 "$config_path"
    success "Wrote $config_path"
}

add_to_path() {
    local shell_rc

    shell_rc=""
    if [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    if [ -n "$shell_rc" ] && ! grep -q "$INSTALL_DIR" "$shell_rc" 2>/dev/null; then
        printf 'export PATH="%s:$PATH"\n' "$INSTALL_DIR" >> "$shell_rc"
        success "Added $INSTALL_DIR to PATH in $shell_rc"
    fi
}

cleanup() {
    [ -n "$TEMP_SOURCE_ROOT" ] && rm -rf "$TEMP_SOURCE_ROOT"
    [ -n "$TEMP_RELEASE_ROOT" ] && rm -rf "$TEMP_RELEASE_ROOT"
}

main() {
    local latest_release=""

    trap cleanup EXIT
    parse_args "$@"
    detect_platform

    if [ "$FORCE" -eq 0 ] && command -v rxmrd >/dev/null 2>&1; then
        error "rxmrd is already present. Rerun with --force to reinstall."
    fi

    if [ -z "$RELEASE_VERSION" ]; then
        latest_release="$(fetch_latest_release_version || true)"
        if [ -n "$latest_release" ]; then
            RELEASE_VERSION="$latest_release"
        fi
    fi

    if [ -n "$RELEASE_VERSION" ]; then
        if ! install_from_release "$RELEASE_VERSION"; then
            warn "Falling back to source build because tagged release $RELEASE_VERSION was not usable for this platform"
            RELEASE_VERSION=""
        fi
    fi

    if [ -z "$RELEASE_VERSION" ]; then
        if [ -z "$SOURCE_REF" ]; then
            SOURCE_REF="$DEFAULT_SOURCE_REF"
        fi
        install_from_source "$SOURCE_REF"
    fi

    setup_config

    if [ "$ADD_PATH" -eq 1 ]; then
        add_to_path
    fi

    cat <<EOF

rXMR install complete.

  Binaries:   $INSTALL_DIR
  Datadir:    $DATA_DIR

Next steps:
  1. Create a wallet:
     rxmr-wallet-cli --generate-new-wallet=mywallet

  2. Start mining:
     rxmr-start-miner --address YOUR_RXMR_ADDRESS

  3. Check health:
     rxmr-doctor --config $DATA_DIR/rxmr.conf --datadir $DATA_DIR

Public node:
  sudo rxmr-public-apply --address YOUR_RXMR_ADDRESS --enable-now
EOF
}

main "$@"
