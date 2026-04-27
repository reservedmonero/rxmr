#!/bin/bash
# Build verification test - verifies all rXMR binaries are present with correct names
# Required by IMPLEMENTATION_PLAN.md Priority 2.1: Binary Names
#
# Usage: ./tests/functional_tests/verify_binary_names.sh [build_dir]
# Example: ./tests/functional_tests/verify_binary_names.sh build/release/bin

BUILD_DIR="${1:-build/release/bin}"
BUILD_ROOT="$(cd "$(dirname "$BUILD_DIR")" && pwd)"
CMAKE_CACHE="$BUILD_ROOT/CMakeCache.txt"
BUILD_DEBUG_UTILITIES="OFF"

if [[ -f "$CMAKE_CACHE" ]]; then
  cache_flag=$(grep -m1 "^BUILD_DEBUG_UTILITIES:BOOL=" "$CMAKE_CACHE" | cut -d= -f2)
  if [[ -n "$cache_flag" ]]; then
    BUILD_DEBUG_UTILITIES="$cache_flag"
  fi
fi

# All expected rXMR binaries (renamed from Monero)
expected_binaries=(
  "rxmrd"
  "rxmr-wallet-cli"
  "rxmr-wallet-rpc"
  "rxmr-blockchain-import"
  "rxmr-blockchain-export"
  "rxmr-blockchain-mark-spent-outputs"
  "rxmr-blockchain-usage"
  "rxmr-blockchain-ancestry"
  "rxmr-blockchain-depth"
  "rxmr-blockchain-stats"
  "rxmr-blockchain-prune-known-spent-data"
  "rxmr-blockchain-prune"
  "rxmr-gen-trusted-multisig"
  "rxmr-gen-ssl-cert"
)

if [[ "$BUILD_DEBUG_UTILITIES" == "ON" ]]; then
  expected_binaries+=(
    "rxmr-utils-deserialize"
    "rxmr-utils-object-sizes"
    "rxmr-utils-dns-checks"
  )
fi

# Monero binaries that should NOT exist (to verify complete rename)
forbidden_binaries=(
  "monerod"
  "monero-wallet-cli"
  "monero-wallet-rpc"
  "monero-blockchain-import"
  "monero-blockchain-export"
  "bonerod"
  "bonero-wallet-cli"
  "bonero-wallet-rpc"
)

echo "Verifying rXMR binary names in: $BUILD_DIR"
echo "=============================================="

errors=0
found=0

# Check expected rXMR binaries exist
for binary in "${expected_binaries[@]}"; do
  if [[ -f "$BUILD_DIR/$binary" ]]; then
    echo "PASS: Found $binary"
    ((found++))
  else
    echo "FAIL: Missing binary: $binary"
    ((errors++))
  fi
done

echo ""
echo "Checking for forbidden Monero binaries..."

# Check forbidden Monero binaries do NOT exist
for binary in "${forbidden_binaries[@]}"; do
  if [[ -f "$BUILD_DIR/$binary" ]]; then
    echo "FAIL: Found forbidden Monero binary: $binary"
    ((errors++))
  fi
done

echo ""
echo "=============================================="
echo "Summary: Found $found/${#expected_binaries[@]} expected binaries"

if [[ $errors -eq 0 ]]; then
  echo "PASS: All expected binaries present, no forbidden binaries found"
  exit 0
else
  echo "FAIL: $errors error(s) found"
  exit 1
fi
