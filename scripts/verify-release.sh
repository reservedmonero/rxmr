#!/usr/bin/env bash

set -euo pipefail

VERSION="${RXMR_RELEASE_VERSION:-}"
PLATFORM="${RXMR_RELEASE_PLATFORM:-}"
REPO="${RXMR_REPOSITORY:-happybigmtn/rXMR}"

usage() {
    cat <<'EOF'
Download and verify a published rXMR release tarball.

Usage:
  ./scripts/verify-release.sh --version TAG --platform linux-x86_64
EOF
}

error() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

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
    local tmp tarball checksums checksum_cmd

    parse_args "$@"
    [ -n "$VERSION" ] || error "A release tag is required"
    [ -n "$PLATFORM" ] || error "A platform is required"
    command -v curl >/dev/null 2>&1 || error "curl is required"
    if command -v sha256sum >/dev/null 2>&1; then
        checksum_cmd='sha256sum -c -'
    elif command -v shasum >/dev/null 2>&1; then
        checksum_cmd='shasum -a 256 -c -'
    else
        error "Need sha256sum or shasum to verify releases"
    fi

    tmp="$(mktemp -d)"
    tarball="rxmr-${VERSION}-${PLATFORM}.tar.gz"
    checksums="SHA256SUMS"

    curl -fsSLo "$tmp/$tarball" "https://github.com/$REPO/releases/download/$VERSION/$tarball"
    curl -fsSLo "$tmp/$checksums" "https://github.com/$REPO/releases/download/$VERSION/$checksums"

    (
        cd "$tmp"
        grep " $tarball\$" "$checksums" | sh -c "$checksum_cmd"
    )

    python3 - "$tmp/$tarball" "$VERSION" "$PLATFORM" <<'PY'
import json
import sys
import tarfile

tarball_path, expected_version, expected_platform = sys.argv[1:4]
prefix = f"rxmr-{expected_version}-{expected_platform}/"

with tarfile.open(tarball_path, "r:gz") as archive:
    manifest_name = prefix + "release-manifest.json"
    try:
        manifest_member = archive.getmember(manifest_name)
    except KeyError as exc:
        raise SystemExit(f"missing {manifest_name} in release tarball") from exc

    manifest = json.load(archive.extractfile(manifest_member))
    if manifest.get("version") != expected_version:
        raise SystemExit("release manifest version mismatch")
    if manifest.get("platform") != expected_platform:
        raise SystemExit("release manifest platform mismatch")

    names = set(archive.getnames())
    for artifact in manifest.get("artifacts", []):
        candidate = prefix + artifact
        if candidate not in names:
            raise SystemExit(f"missing {artifact} in release tarball")
PY
}

main "$@"
