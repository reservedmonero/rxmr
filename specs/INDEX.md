# rXMR Specification Index

rXMR is a Monero-derived privacy chain with its own runtime identity, ports, seeds, binaries, and 60-second block target.

| Spec | File | Scope |
|---|---|---|
| Genesis | [genesis.md](genesis.md) | Canonical genesis handling and historical memo preservation |
| Network | [network.md](network.md) | Network IDs, ports, seed peers |
| Addresses | [addresses.md](addresses.md) | Prefix values and address examples |
| Consensus | [consensus.md](consensus.md) | RandomX, block timing, emission |
| Branding | [branding.md](branding.md) | Binaries, datadir, URI scheme, units |

## High-Signal Deltas From Monero

| Surface | Monero | rXMR |
|---|---|---|
| Daemon | `monerod` | `rxmrd` |
| Wallet CLI | `monero-wallet-cli` | `rxmr-wallet-cli` |
| URI scheme | `monero:` | `rxmr:` |
| Mainnet ports | `18080/18081/18082` | `18880/18881/18882` |
| Block target | 120 seconds | 60 seconds |
| Datadir | `.bitmonero` | `.rxmr` |

The chain rename is a runtime and operator-surface change, not a new mainnet reset.
