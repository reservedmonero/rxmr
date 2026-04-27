# rXMR Address Specification

## Base58 Prefix Values

| Network | Standard | Integrated | Subaddress |
|---|---:|---:|---:|
| Mainnet | 66 | 67 | 98 |
| Testnet | 136 | 137 | 146 |
| Stagenet | 86 | 87 | 108 |

## Typical Human-Visible Starts

These come from the current test vectors in the repo, not from a simple one-byte mapping:

| Network | Standard example | Integrated example | Subaddress example |
|---|---|---|---|
| Mainnet | `C...` | `CD...` | `H...` |
| Testnet | `P...` | `Pv...` | `R...` |
| Stagenet | `F...` | `Fg...` | `K...` |

## Notes

- rXMR addresses are not valid Monero mainnet addresses.
- `rxmr:` is the canonical payment URI scheme.
