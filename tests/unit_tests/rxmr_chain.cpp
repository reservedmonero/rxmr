// Copyright (c) 2014-2022, The Monero Project
// Copyright (c) 2026, The rXMR Project
//
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are
// permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of
//    conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice, this list
//    of conditions and the following disclaimer in the documentation and/or other
//    materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors may be
//    used to endorse or promote products derived from this software without specific
//    prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
// THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// rXMR chain state tests
// Acceptance criteria: Verify that rXMR starts fresh without Monero history
// and that genesis block is properly configured for the new chain.

#include "gtest/gtest.h"
#include "cryptonote_config.h"
#include "cryptonote_basic/cryptonote_basic.h"
#include "cryptonote_basic/cryptonote_format_utils.h"
#include "hardforks/hardforks.h"
#include "checkpoints/checkpoints.h"
#include "string_tools.h"

// Test suite: Verify hardfork schedule activates all compatibility entries at
// genesis and reaches version 16 immediately.
// Acceptance: rXMR can keep versions 1-16 in the table for wallet compatibility
// as long as every entry activates at height 0 and the terminal version is 16.
TEST(chain_state, starts_at_version_16)
{
  ASSERT_GE(num_mainnet_hard_forks, 1);
  for (size_t i = 0; i < num_mainnet_hard_forks; ++i)
    ASSERT_EQ(mainnet_hard_forks[i].height, 0);
  ASSERT_EQ(mainnet_hard_forks[num_mainnet_hard_forks - 1].version, 16);
}

// Test suite: Verify no legacy v1 period exists
// Acceptance: mainnet_hard_fork_version_1_till must be 0
// This prevents any blocks being mined with legacy v1 rules
TEST(chain_state, no_v1_period)
{
  ASSERT_EQ(mainnet_hard_fork_version_1_till, 0);
}

// Test suite: Verify testnet hardfork configuration
// Acceptance: Testnet should also activate its entire compatibility schedule
// at genesis and terminate at version 16.
TEST(chain_state, testnet_starts_at_version_16)
{
  ASSERT_GE(num_testnet_hard_forks, 1);
  for (size_t i = 0; i < num_testnet_hard_forks; ++i)
    ASSERT_EQ(testnet_hard_forks[i].height, 0);
  ASSERT_EQ(testnet_hard_forks[num_testnet_hard_forks - 1].version, 16);
}

// Test suite: Verify stagenet hardfork configuration
// Acceptance: Stagenet should also activate its entire compatibility schedule
// at genesis and terminate at version 16.
TEST(chain_state, stagenet_starts_at_version_16)
{
  ASSERT_GE(num_stagenet_hard_forks, 1);
  for (size_t i = 0; i < num_stagenet_hard_forks; ++i)
    ASSERT_EQ(stagenet_hard_forks[i].height, 0);
  ASSERT_EQ(stagenet_hard_forks[num_stagenet_hard_forks - 1].version, 16);
}

// Test suite: Verify genesis transaction is valid and parseable
// Acceptance: GENESIS_TX hex must parse as a valid coinbase transaction
// This verifies the genesis block will initialize correctly
TEST(chain_state, genesis_tx_is_valid)
{
  cryptonote::transaction tx;
  std::string genesis_hex = config::GENESIS_TX;
  cryptonote::blobdata genesis_blob;

  // Parse hex to binary
  ASSERT_TRUE(epee::string_tools::parse_hexstr_to_binbuff(genesis_hex, genesis_blob));

  // Parse binary to transaction
  ASSERT_TRUE(cryptonote::parse_and_validate_tx_from_blob(genesis_blob, tx));

  // Verify it's a coinbase (miner) transaction
  ASSERT_TRUE(cryptonote::is_coinbase(tx));
}

// Test suite: Verify testnet genesis transaction is valid
// Acceptance: Testnet GENESIS_TX must also be a valid coinbase transaction
TEST(chain_state, testnet_genesis_tx_is_valid)
{
  cryptonote::transaction tx;
  std::string genesis_hex = config::testnet::GENESIS_TX;
  cryptonote::blobdata genesis_blob;

  ASSERT_TRUE(epee::string_tools::parse_hexstr_to_binbuff(genesis_hex, genesis_blob));
  ASSERT_TRUE(cryptonote::parse_and_validate_tx_from_blob(genesis_blob, tx));
  ASSERT_TRUE(cryptonote::is_coinbase(tx));
}

// Test suite: Verify stagenet genesis transaction is valid
// Acceptance: Stagenet GENESIS_TX must also be a valid coinbase transaction
TEST(chain_state, stagenet_genesis_tx_is_valid)
{
  cryptonote::transaction tx;
  std::string genesis_hex = config::stagenet::GENESIS_TX;
  cryptonote::blobdata genesis_blob;

  ASSERT_TRUE(epee::string_tools::parse_hexstr_to_binbuff(genesis_hex, genesis_blob));
  ASSERT_TRUE(cryptonote::parse_and_validate_tx_from_blob(genesis_blob, tx));
  ASSERT_TRUE(cryptonote::is_coinbase(tx));
}

// Test suite: Verify each network has a unique genesis nonce
// Acceptance: Different nonces ensure unique genesis block hashes per network
// This prevents any confusion between mainnet, testnet, and stagenet chains
TEST(chain_state, unique_genesis_nonces)
{
  ASSERT_NE(config::GENESIS_NONCE, config::testnet::GENESIS_NONCE);
  ASSERT_NE(config::GENESIS_NONCE, config::stagenet::GENESIS_NONCE);
  ASSERT_NE(config::testnet::GENESIS_NONCE, config::stagenet::GENESIS_NONCE);
}

// Test suite: Verify no initial checkpoints exist
// Acceptance: rXMR starts fresh with no Monero checkpoint history
// Empty checkpoints allow the new chain to grow from its own genesis
TEST(chain_state, no_initial_checkpoints)
{
  cryptonote::checkpoints cp;
  cp.init_default_checkpoints(cryptonote::MAINNET);
  // For a fresh chain, max height should be 0 (no checkpoints)
  ASSERT_EQ(cp.get_max_height(), 0);
}

// Test suite: Verify testnet has no initial checkpoints
// Acceptance: Testnet should also start without inherited checkpoints
TEST(chain_state, testnet_no_initial_checkpoints)
{
  cryptonote::checkpoints cp;
  cp.init_default_checkpoints(cryptonote::TESTNET);
  ASSERT_EQ(cp.get_max_height(), 0);
}

// Test suite: Verify stagenet has no initial checkpoints
// Acceptance: Stagenet should also start without inherited checkpoints
TEST(chain_state, stagenet_no_initial_checkpoints)
{
  cryptonote::checkpoints cp;
  cp.init_default_checkpoints(cryptonote::STAGENET);
  ASSERT_EQ(cp.get_max_height(), 0);
}
