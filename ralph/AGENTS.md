# AGENTS.md - rXMR Build Guide

## Build & Run

rXMR is a Monero v0.18.4.5 fork. Build with:

```bash
# Dependencies (Ubuntu/Debian)
sudo apt-get install build-essential cmake pkg-config \
    libboost-all-dev libssl-dev libzmq3-dev libunbound-dev \
    libsodium-dev libhidapi-dev libudev-dev libusb-1.0-0-dev \
    libreadline-dev libexpat1-dev libpgm-dev qttools5-dev-tools

# Dependencies (Arch Linux)
sudo pacman -S cmake boost openssl zeromq unbound libsodium \
    hidapi libusb readline expat qt5-tools

# Initialize submodules
git submodule update --init --force --recursive

# Build
make -j$(nproc)

# Binaries will be in build/release/bin/
```

## Validation

Run these after implementing to get immediate feedback:

- Build: `make -j$(nproc)`
- Unit tests: `ctest --test-dir build/Linux/master/release --output-on-failure`
- Specific test suite: `ctest --test-dir build/Linux/master/release -R <suite_name>`

## Binaries

After build, binaries are in `build/Linux/master/release/bin/` (path includes OS and git branch):
- `rxmrd` - Full node daemon
- `rxmr-wallet-cli` - Command-line wallet
- `rxmr-wallet-rpc` - Wallet RPC server
- `rxmr-blockchain-import` - Import blockchain
- `rxmr-blockchain-export` - Export blockchain

## Operational Notes

- Source is in `src/`
- Configuration: `src/cryptonote_config.h`
- Data directory: `~/.rxmr` (Linux), `~/Library/Application Support/rxmr` (macOS)
- Config file: `rxmr.conf`

## Key Files to Modify

- `src/cryptonote_config.h` - Network parameters, address prefixes, ports
- `src/hardforks/hardforks.cpp` - Hardfork schedule
- `src/checkpoints/checkpoints.cpp` - Blockchain checkpoints
- `src/p2p/net_node.inl` - Seed nodes
- `CMakeLists.txt` - Build configuration
- `src/daemon/CMakeLists.txt` - Daemon binary name
- `src/simplewallet/CMakeLists.txt` - Wallet binary names

## Network Configuration

| Network   | P2P Port | RPC Port | ZMQ Port | Address Prefix |
|-----------|----------|----------|----------|----------------|
| Mainnet   | 18880    | 18881    | 18882    | 'B' (66)       |
| Testnet   | 28880    | 28881    | 28882    | 'T' (136)      |
| Stagenet  | 38880    | 38881    | 38882    | 'S' (86)       |

## Genesis Block Generation

To generate a new genesis block (required for fresh chain):

```bash
# Generate genesis transaction hex
./build/Linux/master/release/bin/rxmrd --print-genesis-tx

# Copy the output hex to GENESIS_TX in src/cryptonote_config.h
# Then run daemon to mine valid nonce - check logs for GENESIS_NONCE
```

## Unit Tests

Run rXMR-specific unit tests:
```bash
ctest --test-dir build/Linux/master/release -R rxmr_ --output-on-failure
```

Test suites:
- `rxmr_network` - Network identity, ports, consensus params
- `rxmr_address` - Address prefix verification
- `rxmr_branding` - Data directory, message signing domain
- `rxmr_chain` - Genesis block, hardforks, checkpoints
