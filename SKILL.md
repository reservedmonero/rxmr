---
name: rxmr-miner
version: 3.0.0
description: Mine rXMR with the repo-supported installer and local helper scripts.
homepage: https://github.com/happybigmtn/rXMR
---

# rXMR Miner

rXMR is a Monero-derived privacy chain with RandomX CPU mining, `rxmr:` payment URIs, and its own network ports and seeds.

## Install

```bash
curl -fsSLO https://raw.githubusercontent.com/happybigmtn/rXMR/master/install.sh
less install.sh
bash install.sh --add-path
```

The installer prefers the newest tagged release and falls back to building `master` if no tagged binary is available for the current platform.

## Start Mining

1. Create a wallet and save the seed phrase.

```bash
rxmr-wallet-cli --generate-new-wallet=mywallet
```

2. Start the daemon in detached mining mode.

```bash
rxmr-start-miner --address YOUR_RXMR_ADDRESS
```

3. Verify sync and mining status.

```bash
rxmr-doctor
```

## Mainnet Defaults

- P2P: `18880`
- RPC: `18881`
- ZMQ RPC: `18882`
- Datadir: `~/.rxmr`
- URI scheme: `rxmr:`
- Seeds: ten public Contabo peers on `18880`

## Public Node

```bash
sudo rxmr-install-public-node --enable-now
sudo ufw allow 18880/tcp
sudo rxmr-install-public-miner --address YOUR_RXMR_ADDRESS --enable-now
```

## Notes

- The live chain keeps the historical Bonero-era genesis memo.
- rXMR is not Monero mainnet. Addresses, ports, seeds, and binaries are different.
- Use `rxmr-doctor` before assuming mining is actually active.
