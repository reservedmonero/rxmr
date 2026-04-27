# rXMR Consensus

## Proof of Work

- Algorithm: RandomX
- Mining hardware target: CPUs
- Seeded/validated through the inherited Monero RandomX path

## Block Timing

| Parameter | Value |
|---|---|
| Target block time | 60 seconds |
| Difficulty window | 1440 blocks |
| Difficulty lag | 15 blocks |

The 1440-block difficulty window preserves an approximately 24-hour adjustment period despite the 60-second block target.

## Emission

| Parameter | Value |
|---|---|
| Emission speed factor per minute | 21 |
| Tail subsidy per minute | 300000000000 atomic units |
| Display decimal point | 12 |

The chain intentionally slows main emission relative to Monero to fit the faster block cadence while preserving a smaller per-block subsidy.

## Fork Policy

- rXMR starts directly at hardfork version 16
- there is no legacy pre-v16 mainnet period
- the rename does not re-roll genesis or restart the live chain
