#!/usr/bin/env bash

set -euo pipefail

VERSION="${RXMR_RELEASE_VERSION:-}"
PLATFORM="${RXMR_RELEASE_PLATFORM:-}"
BUILD_DIR="${RXMR_BUILD_DIR:-build}"
OUTPUT_DIR="${RXMR_RELEASE_OUTPUT_DIR:-dist}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}"
SKIP_BUILD=0
RELEASE_ASSETS=()

usage() {
    cat <<'EOF'
Package a deterministic rXMR release tarball.

Usage:
  ./scripts/build-release.sh [--version TAG] [--platform PLATFORM] [--build-dir DIR] [--output-dir DIR] [--skip-build]
EOF
}

info() { printf '[INFO] %s\n' "$1"; }
error() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

cpu_count() {
    nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 1
}

detect_platform() {
    local os arch

    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"

    case "$os" in
        linux*) os="linux" ;;
        darwin*) os="macos" ;;
        *) error "Unsupported OS for release packaging: $os" ;;
    esac

    case "$arch" in
        x86_64|amd64) arch="x86_64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) error "Unsupported architecture for release packaging: $arch" ;;
    esac

    printf '%s-%s\n' "$os" "$arch"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --version)
                [ $# -ge 2 ] || error "--version requires a value"
                VERSION="$2"
                shift 2
                ;;
            --platform)
                [ $# -ge 2 ] || error "--platform requires a value"
                PLATFORM="$2"
                shift 2
                ;;
            --build-dir)
                [ $# -ge 2 ] || error "--build-dir requires a path"
                BUILD_DIR="$2"
                shift 2
                ;;
            --output-dir)
                [ $# -ge 2 ] || error "--output-dir requires a path"
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --skip-build)
                SKIP_BUILD=1
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

resolve_version() {
    if [ -n "$VERSION" ]; then
        return
    fi
    VERSION="$(git describe --tags --exact-match 2>/dev/null || true)"
    if [ -z "$VERSION" ]; then
        VERSION="snapshot-$(git rev-parse --short HEAD)"
    fi
}

resolve_source_date_epoch() {
    if [ -n "$SOURCE_DATE_EPOCH" ]; then
        return
    fi
    SOURCE_DATE_EPOCH="$(git log -1 --format=%ct HEAD)"
}

build_binaries() {
    info "Building release binaries"
    cmake -S . -B "$BUILD_DIR" -D BUILD_TESTS=OFF -D CMAKE_BUILD_TYPE=Release
    cmake --build "$BUILD_DIR" -j"$(cpu_count)" --target daemon simplewallet wallet_rpc_server
}

maybe_strip_binary() {
    if command -v strip >/dev/null 2>&1; then
        strip "$1" 2>/dev/null || true
    fi
}

make_manifest() {
    local output commit

    output="$1"
    commit="$(git rev-parse HEAD)"
    python3 - "$output" "$VERSION" "$PLATFORM" "$commit" "$SOURCE_DATE_EPOCH" <<'PY'
import json
import sys
from pathlib import Path

Path(sys.argv[1]).write_text(
    json.dumps(
        {
            "version": sys.argv[2],
            "platform": sys.argv[3],
            "git_commit": sys.argv[4],
            "source_date_epoch": int(sys.argv[5]),
            "artifacts": [
                "rxmrd",
                "rxmr-wallet-cli",
                "rxmr-wallet-rpc",
                "rxmr-start-miner",
                "rxmr-doctor",
                "rxmr-install-public-node",
                "rxmr-install-public-miner",
                "rxmr-public-apply",
                "rxmrd.service",
                "rxmr.conf.example",
                "PUBLIC-NODE.md",
                "LICENSE",
            ],
        },
        indent=2,
        sort_keys=True,
    ) + "\n",
    encoding="ascii",
)
PY
}

copy_standalone_asset() {
    local source_path target_name mode

    source_path="$1"
    target_name="$2"
    mode="$3"

    install -m "$mode" "$source_path" "$OUTPUT_DIR/$target_name"
    RELEASE_ASSETS+=("$target_name")
}

write_checksums() {
    local asset

    : > "$OUTPUT_DIR/SHA256SUMS"
    (
        cd "$OUTPUT_DIR"
        for asset in "${RELEASE_ASSETS[@]}"; do
            if command -v sha256sum >/dev/null 2>&1; then
                sha256sum "$asset"
            elif command -v shasum >/dev/null 2>&1; then
                shasum -a 256 "$asset"
            else
                error "Need sha256sum or shasum to create SHA256SUMS"
            fi
        done
    ) > "$OUTPUT_DIR/SHA256SUMS"
}

package_release() {
    local package_root stage_root tarball

    mkdir -p "$OUTPUT_DIR"
    package_root="rxmr-${VERSION}-${PLATFORM}"
    stage_root="$(mktemp -d)/$package_root"
    mkdir -p "$stage_root"

    cp "$BUILD_DIR/bin/rxmrd" "$stage_root/rxmrd"
    cp "$BUILD_DIR/bin/rxmr-wallet-cli" "$stage_root/rxmr-wallet-cli"
    cp "$BUILD_DIR/bin/rxmr-wallet-rpc" "$stage_root/rxmr-wallet-rpc"
    cp scripts/start-miner.sh "$stage_root/rxmr-start-miner"
    cp scripts/doctor.sh "$stage_root/rxmr-doctor"
    cp scripts/install-public-node.sh "$stage_root/rxmr-install-public-node"
    cp scripts/install-public-miner.sh "$stage_root/rxmr-install-public-miner"
    cp scripts/public-apply.sh "$stage_root/rxmr-public-apply"
    cp contrib/init/rxmrd.service "$stage_root/rxmrd.service"
    cp contrib/init/rxmr.conf.example "$stage_root/rxmr.conf.example"
    cp docs/public-node.md "$stage_root/PUBLIC-NODE.md"
    cp LICENSE "$stage_root/LICENSE"

    chmod 0755 "$stage_root/rxmrd" "$stage_root/rxmr-wallet-cli" "$stage_root/rxmr-wallet-rpc" \
        "$stage_root/rxmr-start-miner" "$stage_root/rxmr-doctor" \
        "$stage_root/rxmr-install-public-node" "$stage_root/rxmr-install-public-miner" \
        "$stage_root/rxmr-public-apply"
    chmod 0644 "$stage_root/rxmrd.service" "$stage_root/rxmr.conf.example" \
        "$stage_root/PUBLIC-NODE.md" "$stage_root/LICENSE"

    maybe_strip_binary "$stage_root/rxmrd"
    maybe_strip_binary "$stage_root/rxmr-wallet-cli"
    maybe_strip_binary "$stage_root/rxmr-wallet-rpc"
    make_manifest "$stage_root/release-manifest.json"

    tarball="$OUTPUT_DIR/${package_root}.tar.gz"

    python3 - "$stage_root" "$tarball" "$SOURCE_DATE_EPOCH" <<'PY'
import gzip
import os
import tarfile
import sys
from pathlib import Path

source_root = Path(sys.argv[1]).resolve()
tarball = Path(sys.argv[2]).resolve()
mtime = int(sys.argv[3])

def normalized_mode(path: Path) -> int:
    if path.is_dir():
        return 0o755
    if os.access(path, os.X_OK):
        return 0o755
    return 0o644

with tarball.open("wb") as raw:
    with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=mtime) as gz:
        with tarfile.open(fileobj=gz, mode="w", format=tarfile.PAX_FORMAT) as archive:
            for path in [source_root, *sorted(source_root.rglob("*"))]:
                arcname = path.relative_to(source_root.parent).as_posix()
                info = archive.gettarinfo(str(path), arcname)
                info.uid = 0
                info.gid = 0
                info.uname = "root"
                info.gname = "root"
                info.mtime = mtime
                info.mode = normalized_mode(path)
                if path.is_file():
                    with path.open("rb") as handle:
                        archive.addfile(info, handle)
                else:
                    archive.addfile(info)
PY

    RELEASE_ASSETS+=("$(basename "$tarball")")
    info "Built $tarball"
}

publish_release_assets() {
    copy_standalone_asset install.sh install.sh 0755
    copy_standalone_asset scripts/verify-release.sh verify-release.sh 0755
    copy_standalone_asset scripts/public-apply.sh rxmr-public-apply 0755
    copy_standalone_asset docs/public-node.md PUBLIC-NODE.md 0644
    copy_standalone_asset SECURITY.md SECURITY.md 0644
}

main() {
    parse_args "$@"

    if [ -z "$PLATFORM" ]; then
        PLATFORM="$(detect_platform)"
    fi

    resolve_version
    resolve_source_date_epoch

    if [ "$SKIP_BUILD" -ne 1 ]; then
        build_binaries
    fi

    [ -x "$BUILD_DIR/bin/rxmrd" ] || error "Missing $BUILD_DIR/bin/rxmrd"
    [ -x "$BUILD_DIR/bin/rxmr-wallet-cli" ] || error "Missing $BUILD_DIR/bin/rxmr-wallet-cli"
    [ -x "$BUILD_DIR/bin/rxmr-wallet-rpc" ] || error "Missing $BUILD_DIR/bin/rxmr-wallet-rpc"

    package_release
    publish_release_assets
    write_checksums
}

main "$@"
