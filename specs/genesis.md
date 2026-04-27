# rXMR Genesis

## Canonical Genesis Transaction

The canonical genesis transaction hex is stored in `src/cryptonote_config.h` for mainnet, testnet, and stagenet.

`rxmrd --print-genesis-tx` prints those baked-in canonical values directly.

## Historical Memo

The live chain preserves the original Bonero-era genesis memo. The rename to rXMR does not create a new genesis block.

That is intentional:

- existing chain history stays valid
- miners stay on one chain
- the public runtime branding changes without forcing a second network reset
