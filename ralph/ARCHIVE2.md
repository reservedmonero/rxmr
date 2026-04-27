# Implementation Plan Archive

## Review Signoff (2026-01-30) - SIGNED OFF

- [x] Change NETWORK_ID for mainnet to `{0xB0, 0x9E, 0x80, 0x71, 0x61, 0x04, 0x41, 0x61, 0x17, 0x31, 0x00, 0x82, 0x16, 0xA1, 0xA1, 0x10}`

- [x] Change NETWORK_ID for testnet (ending `0x11`)

- [x] Change NETWORK_ID for stagenet (ending `0x12`)

- [x] Change P2P_DEFAULT_PORT from 18080 to 18880

- [x] Change RPC_DEFAULT_PORT from 18081 to 18881

- [x] Change ZMQ_RPC_DEFAULT_PORT from 18082 to 18882

- [x] Update testnet ports: 28880/28881/28882

- [x] Update stagenet ports: 38880/38881/38882

**File:** `src/cryptonote_config.h` (lines 230-294)

**Current → Target:**
| Parameter | Current | Target |
|-----------|---------|--------|
| Mainnet P2P | 18080 | 18880 |
| Mainnet RPC | 18081 | 18881 |
| NETWORK_ID[0:3] | `0x12, 0x30, 0xF1` | `0xB0, 0x9E, 0x80` |

**Required Tests:**
```cpp
// tests/unit_tests/rxmr_network.cpp (NEW FILE)
#include "gtest/gtest.h"
#include "cryptonote_config.h"

TEST(network_identity, mainnet_ports)
{
  ASSERT_EQ(config::P2P_DEFAULT_PORT, 18880);
  ASSERT_EQ(config::RPC_DEFAULT_PORT, 18881);
  ASSERT_EQ(config::ZMQ_RPC_DEFAULT_PORT, 18882);
}

TEST(network_identity, testnet_ports)
{
  ASSERT_EQ(config::testnet::P2P_DEFAULT_PORT, 28880);
  ASSERT_EQ(config::testnet::RPC_DEFAULT_PORT, 28881);
}

TEST(network_identity, stagenet_ports)
{
  ASSERT_EQ(config::stagenet::P2P_DEFAULT_PORT, 38880);
  ASSERT_EQ(config::stagenet::RPC_DEFAULT_PORT, 38881);
}

TEST(network_identity, network_id_differs_from_monero)
{
  // Monero mainnet NETWORK_ID starts with 0x12, 0x30
  ASSERT_EQ(config::NETWORK_ID.data[0], 0xB0);
  ASSERT_EQ(config::NETWORK_ID.data[1], 0x9E);
  ASSERT_EQ(config::NETWORK_ID.data[2], 0x80);
}
```

**Validation Command:** `ctest --test-dir build -R network_identity`

---

### 1.2 Address Prefixes ✅ COMPLETED

- [x] Set mainnet CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX to 66 ('B')

- [x] Set mainnet CRYPTONOTE_PUBLIC_INTEGRATED_ADDRESS_BASE58_PREFIX to 67 ('Bi')

- [x] Set mainnet CRYPTONOTE_PUBLIC_SUBADDRESS_BASE58_PREFIX to 98 ('Bo')

- [x] Set testnet prefixes: 136 ('T'), 137 ('Ti'), 146 ('To')

- [x] Set stagenet prefixes: 86 ('S'), 87 ('Si'), 108 ('So')

**File:** `src/cryptonote_config.h` (lines 227-229, 270-272, 285-287)

**Current → Target:**
| Network | Type | Current | Target | Note |
|---------|------|---------|--------|------|
| Mainnet | Standard | 18 | 66 | Base58 tag (does not directly map to first character) |
| Mainnet | Integrated | 19 | 67 | Base58 tag (does not directly map to first character) |
| Mainnet | Subaddress | 42 | 98 | Base58 tag (does not directly map to first character) |
| Testnet | Standard | 53 | 136 | Base58 tag (does not directly map to first character) |
| Stagenet | Standard | 24 | 86 | Base58 tag (does not directly map to first character) |

**Required Tests:**
```cpp
// tests/unit_tests/rxmr_address.cpp (NEW FILE)
#include "gtest/gtest.h"
#include "common/base58.h"
#include "cryptonote_config.h"
#include "cryptonote_basic/account.h"
#include "cryptonote_basic/cryptonote_basic_impl.h"

TEST(address_prefix, mainnet_standard_encodes_prefix)
{
  ASSERT_EQ(config::CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX, 66);

  cryptonote::account_base account;
  account.generate();
  std::string address = cryptonote::get_account_address_as_str(
    cryptonote::MAINNET, false, account.get_keys().m_account_address);
  uint64_t tag = 0;
  std::string data;
  ASSERT_TRUE(tools::base58::decode_addr(address, tag, data));
  ASSERT_EQ(tag, config::CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX);
}

TEST(address_prefix, mainnet_integrated_prefix_67)
{
  ASSERT_EQ(config::CRYPTONOTE_PUBLIC_INTEGRATED_ADDRESS_BASE58_PREFIX, 67);
}

TEST(address_prefix, mainnet_subaddress_prefix_98)
{
  ASSERT_EQ(config::CRYPTONOTE_PUBLIC_SUBADDRESS_BASE58_PREFIX, 98);
}

TEST(address_prefix, testnet_prefix_136)
{
  ASSERT_EQ(config::testnet::CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX, 136);
}

TEST(address_prefix, monero_addresses_rejected)
{
  // Monero mainnet prefix is 18, our addresses use 66
  // Verify parsing rejects Monero-prefixed addresses
  std::string monero_addr = "44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A";
  cryptonote::address_parse_info info;
  bool result = cryptonote::get_account_address_from_str(
    info, cryptonote::MAINNET, monero_addr);
  ASSERT_FALSE(result);  // Should fail - wrong prefix
}
```

**Validation Command:** `build/Linux/master/release/tests/unit_tests/unit_tests --gtest_filter=address_prefix.*`

---

### 1.3 Data Directory ✅ COMPLETED

- [x] Change CRYPTONOTE_NAME from "bitmonero" to "rxmr"

**File:** `src/cryptonote_config.h` (line 165)

**Required Tests:**
```cpp
// tests/unit_tests/rxmr_branding.cpp (NEW FILE)
#include "gtest/gtest.h"
#include "cryptonote_config.h"

TEST(branding, data_directory_name)
{
  ASSERT_STREQ(CRYPTONOTE_NAME, "rxmr");
}
```

**Functional Test:**
```bash

- [x] Change daemon OUTPUT_NAME from "rxmrd" to "rxmrd"

- [x] Change wallet CLI OUTPUT_NAME from "rxmr-wallet-cli" to "rxmr-wallet-cli"

- [x] Change wallet RPC OUTPUT_NAME from "rxmr-wallet-rpc" to "rxmr-wallet-rpc"

- [x] Rename all blockchain utilities from "monero-blockchain-*" to "rxmr-blockchain-*"

- [x] Rename debug utilities from "monero-utils-*" to "rxmr-utils-*"

- [x] Rename gen utilities from "monero-gen-*" to "rxmr-gen-*"

**Files:**
- `src/daemon/CMakeLists.txt` (line 74)
- `src/simplewallet/CMakeLists.txt` (line 64)
- `src/wallet/CMakeLists.txt`
- `src/blockchain_utilities/CMakeLists.txt` (9 entries)
- `src/debug_utilities/CMakeLists.txt` (3 entries)
- `src/gen_multisig/CMakeLists.txt`
- `src/gen_ssl_cert/CMakeLists.txt`

**Required Tests:**
```bash

- [x] Change project(monero) to project(rxmr) in CMakeLists.txt

**File:** `CMakeLists.txt` (line 49)

**Required Tests:**
```bash

- [x] Change "piconero" to "picobon" in cryptonote_format_utils.cpp

- [x] Update unit names in simplewallet.cpp (monero→rxmr, millinero→millibon, etc.)

- [x] Update unit names in wallet2.cpp

**Files:**
- `src/cryptonote_basic/cryptonote_format_utils.cpp` (line 1162)
- `src/simplewallet/simplewallet.cpp` (lines 2726, 3523, 4032)
- `src/wallet/wallet2.cpp` (lines 15893-15894)

**Required Tests:**
```cpp
// Add to tests/unit_tests/rxmr_branding.cpp
TEST(branding, currency_unit_name)
{
  // Verify smallest unit is "picobon" not "piconero"
  // This requires checking the format_utils output
}
```

---

- [x] Change DIFFICULTY_TARGET_V2 from 120 to 60 seconds

- [x] Change DIFFICULTY_WINDOW to 1440 (maintain 24h window)

**File:** `src/cryptonote_config.h` (lines 80-82)

**Rationale:** 60s blocks match faster confirmation for AI agents. Window of 1440 blocks × 60s = 24 hours.

**Required Tests:**
```cpp
// tests/unit_tests/rxmr_consensus.cpp (NEW FILE)
#include "gtest/gtest.h"
#include "cryptonote_config.h"

TEST(consensus, block_time_60_seconds)
{
  ASSERT_EQ(DIFFICULTY_TARGET_V2, 60);
}

TEST(consensus, difficulty_window_24h)
{
  // 1440 blocks * 60 seconds = 86400 seconds = 24 hours
  ASSERT_EQ(DIFFICULTY_WINDOW * DIFFICULTY_TARGET_V2, 86400);
}

TEST(consensus, difficulty_window_blocks)
{
  ASSERT_EQ(DIFFICULTY_WINDOW, 1440);
}
```

---

### 3.2 Emission Adjustment ✅ COMPLETED

- [x] Change EMISSION_SPEED_FACTOR_PER_MINUTE from 20 to 21 (halves reward for 60s blocks)

- [x] Verify FINAL_SUBSIDY_PER_MINUTE remains 300000000000 (0.3 BON/minute = 0.3 BON/block)

- [x] Remove all Monero mainnet checkpoints

- [x] Remove all testnet/stagenet checkpoints

- [x] Return true from init_default_checkpoints()

- [x] Clear DNS checkpoint sources (moneropulse domains)

- [x] Replace Monero hardfork schedule with single v16 entry at height 1

- [x] Set mainnet_hard_fork_version_1_till to 0

- [x] Update testnet/stagenet similarly

**File:** `src/hardforks/hardforks.cpp` (lines 34-78)

**Target:**
```cpp
const hardfork_t mainnet_hard_forks[] = {
  { 16, 0, 0, 1735689600 },  // v16 from block 0 (genesis block)
};
const size_t num_mainnet_hard_forks = 1;
const uint64_t mainnet_hard_fork_version_1_till = 0;
```

**Required Tests:**
```cpp
// tests/unit_tests/rxmr_chain.cpp
TEST(chain_state, starts_at_version_16)
{
  ASSERT_EQ(num_mainnet_hard_forks, 1);
  ASSERT_EQ(mainnet_hard_forks[0].version, 16);
  ASSERT_EQ(mainnet_hard_forks[0].height, 0);
}
```

---

### 4.3 Remove Seed Nodes ✅ COMPLETED

- [x] Clear Monero IP seed nodes from net_node.inl

- [x] Clear Monero DNS seed nodes from net_node.h

- [x] Clear DNS checkpoint sources from checkpoints.cpp

- [x] Clear DNS blocklist sources from net_node.inl

- [x] Clear DNS update sources from updates.cpp

- [x] Clear DNS probe hostname from dns_utils.cpp

- [x] Update dns_checks debug utility

**Files:**
- `src/p2p/net_node.inl` (lines 731-763)
- `src/p2p/net_node.h` (lines 305-310)
- `src/checkpoints/checkpoints.cpp` (lines 304-307)

**Required Tests:**
```cpp
// tests/unit_tests/rxmr_network.cpp
TEST(network_identity, no_monero_seed_nodes)
{
  // Verify seed node list doesn't contain Monero domains
  for (const auto& seed : m_seed_nodes_list) {
    ASSERT_TRUE(seed.find("moneroseeds") == std::string::npos);
  }
}
```

---

### 4.4 Generate Genesis Block ✅ COMPLETED

- [x] Implement `--print-genesis-tx` option in daemon (src/daemon/main.cpp, command_line_args.h)

- [x] Create unit tests for genesis validation (tests/unit_tests/rxmr_chain.cpp)

