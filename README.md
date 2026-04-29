# rXMR

Time = privacy.

ReservedMonero (RXMR) is a privacy-focused cryptocurrency for reserving (locking) RXMR funds for specific purposes such as escrow, pending transactions, or liquidity allocation. It introduces a structured way to temporarily hold XMR in a “reserved” state, enabling more reliable interactions in privacy-focused environments. Also it keeps ring signatures, stealth addresses, RingCT, and RandomX CPU mining, but runs on its own network identity, ports, seeds, binaries, and data directory.

**Current release: v0.1.0.1** — based on Monero v0.18.4.6


```

## Quick Mining

```bash
# 1. Create a wallet and save the seed phrase.
rxmr-wallet-cli --generate-new-wallet=mywallet

# 2. Start mining against your local config.
rxmr-start-miner --address YOUR_RXMR_ADDRESS

# 3. Verify sync and mining health.
rxmr-doctor
```

Mainnet defaults:

| Parameter | Value |
|---|---|
| Algorithm | RandomX |
| Target block time | 60 seconds |
| P2P port | 18880 |
| RPC port | 18881 |
| ZMQ RPC port | 18882 |
| Default datadir | `~/.rxmr` |
| Mainnet URI scheme | `rxmr:` |


## Seed Nodes

These public seeds are baked into the installer, the daemon fallback list, and the example public-node config:

```text
95.111.227.14:18880
95.111.229.108:18880
95.111.239.142:18880
161.97.83.147:18880
161.97.97.83:18880
161.97.114.192:18880
161.97.117.0:18880
194.163.144.177:18880
185.218.126.23:18880
185.239.209.227:18880
```

## Public VPS Node

To run a public peer that accepts inbound connections:

```bash
sudo rxmr-public-apply --address YOUR_RXMR_ADDRESS --enable-now
```

That single command installs the public node, enables persistent mining, and verifies health. To inspect health without mutating the host:

```bash
rxmr-doctor --json --strict --expect-public --expect-miner
```

Operator notes are in [docs/public-node.md](docs/public-node.md).

## Build From Source

If you need an unreleased build:

```bash
sudo apt-get install -y \
  build-essential cmake pkg-config git python3 \
  libboost-all-dev libssl-dev libzmq3-dev libunbound-dev \
  libsodium-dev libhidapi-dev liblzma-dev libreadline-dev \
  libexpat1-dev libpgm-dev libusb-1.0-0-dev libudev-dev \
  libevent-dev

git clone --recursive https://github.com/reservedmonero/rxmr.git
cd rXMR
cmake -S . -B build -D BUILD_TESTS=OFF -D CMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)" --target daemon simplewallet wallet_rpc_server
```

Expected binaries land in `build/bin/`:

- `rxmrd`
- `rxmr-wallet-cli`
- `rxmr-wallet-rpc`

## Useful Commands

```bash
curl -fsS http://127.0.0.1:18881/get_info
curl -fsS http://127.0.0.1:18881/mining_status
pkill rxmrd
```

## What Changed From Monero

The high-signal runtime differences from upstream are:

- chain identity: distinct network IDs, ports, prefixes, seeds, and datadir
- product identity: `rxmrd`, `rxmr-wallet-cli`, `rxmr-wallet-rpc`, `rxmr:` URIs
- mining defaults: first-class CPU-mining helpers and public-node installers
- policy/docs: tagged releases and operator helpers are part of the public surface

The underlying privacy model and core transaction format remain Monero-derived.

## License

See [LICENSE](LICENSE).
