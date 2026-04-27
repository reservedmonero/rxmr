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

// rXMR network identity tests
// Acceptance criteria: Verify that rXMR network parameters differ from Monero
// to ensure network isolation and proper branding.

#include "gtest/gtest.h"
#include "cryptonote_config.h"

// Test suite: Verify rXMR mainnet ports are correctly configured
// Acceptance: Mainnet ports must be 18880/18881/18882 (not Monero's 18080/18081/18082)
TEST(network_identity, mainnet_ports)
{
  ASSERT_EQ(config::P2P_DEFAULT_PORT, 18880);
  ASSERT_EQ(config::RPC_DEFAULT_PORT, 18881);
  ASSERT_EQ(config::ZMQ_RPC_DEFAULT_PORT, 18882);
}

// Test suite: Verify rXMR testnet ports are correctly configured
// Acceptance: Testnet ports must be 28880/28881 (not Monero's 28080/28081)
TEST(network_identity, testnet_ports)
{
  ASSERT_EQ(config::testnet::P2P_DEFAULT_PORT, 28880);
  ASSERT_EQ(config::testnet::RPC_DEFAULT_PORT, 28881);
  ASSERT_EQ(config::testnet::ZMQ_RPC_DEFAULT_PORT, 28882);
}

// Test suite: Verify rXMR stagenet ports are correctly configured
// Acceptance: Stagenet ports must be 38880/38881 (not Monero's 38080/38081)
TEST(network_identity, stagenet_ports)
{
  ASSERT_EQ(config::stagenet::P2P_DEFAULT_PORT, 38880);
  ASSERT_EQ(config::stagenet::RPC_DEFAULT_PORT, 38881);
  ASSERT_EQ(config::stagenet::ZMQ_RPC_DEFAULT_PORT, 38882);
}

// Test suite: Verify rXMR network ID differs from Monero
// Acceptance: First 3 bytes must be 0xB0, 0x9E, 0x80 (not Monero's 0x12, 0x30, 0xF1)
// This ensures rXMR nodes cannot accidentally connect to Monero network
TEST(network_identity, network_id_differs_from_monero)
{
  // rXMR mainnet NETWORK_ID starts with 0xB0, 0x9E, 0x80
  // Monero mainnet NETWORK_ID starts with 0x12, 0x30, 0xF1
  ASSERT_EQ(config::NETWORK_ID.data[0], 0xB0);
  ASSERT_EQ(config::NETWORK_ID.data[1], 0x9E);
  ASSERT_EQ(config::NETWORK_ID.data[2], 0x80);

  // Verify it's NOT Monero's ID
  ASSERT_NE(config::NETWORK_ID.data[0], 0x12);
}

// Test suite: Verify testnet network ID differs from mainnet
// Acceptance: Testnet must have different last byte (0x11) to isolate from mainnet
TEST(network_identity, testnet_network_id)
{
  ASSERT_EQ(config::testnet::NETWORK_ID.data[0], 0xB0);
  ASSERT_EQ(config::testnet::NETWORK_ID.data[1], 0x9E);
  ASSERT_EQ(config::testnet::NETWORK_ID.data[2], 0x80);
  // Last byte differs between networks
  ASSERT_EQ(config::testnet::NETWORK_ID.data[15], 0x11);
}

// Test suite: Verify stagenet network ID differs from mainnet
// Acceptance: Stagenet must have different last byte (0x12) to isolate from mainnet
TEST(network_identity, stagenet_network_id)
{
  ASSERT_EQ(config::stagenet::NETWORK_ID.data[0], 0xB0);
  ASSERT_EQ(config::stagenet::NETWORK_ID.data[1], 0x9E);
  ASSERT_EQ(config::stagenet::NETWORK_ID.data[2], 0x80);
  // Last byte differs between networks
  ASSERT_EQ(config::stagenet::NETWORK_ID.data[15], 0x12);
}

// Test suite: Verify rXMR consensus parameters for 60-second blocks
// Acceptance: Block time must be 60s (not Monero's 120s) for faster AI agent transactions
TEST(consensus, block_time_60_seconds)
{
  ASSERT_EQ(DIFFICULTY_TARGET_V2, 60);
}

// Test suite: Verify difficulty window maintains 24-hour adjustment period
// Acceptance: 1440 blocks * 60 seconds = 86400 seconds = 24 hours
TEST(consensus, difficulty_window_24h)
{
  // 1440 blocks * 60 seconds = 86400 seconds = 24 hours
  ASSERT_EQ(DIFFICULTY_WINDOW * DIFFICULTY_TARGET_V2, 86400);
}

// Test suite: Verify difficulty window is correctly set
// Acceptance: DIFFICULTY_WINDOW must be 1440 (not Monero's 720) to maintain 24h window with 60s blocks
TEST(consensus, difficulty_window_blocks)
{
  ASSERT_EQ(DIFFICULTY_WINDOW, 1440);
}

// Test suite: Verify emission speed factor is adjusted for 60-second blocks
// Acceptance: EMISSION_SPEED_FACTOR_PER_MINUTE must be 21 (not Monero's 20)
// This halves the 60s block reward, reducing main emission rate vs Monero
TEST(consensus, emission_factor_adjusted_for_60s_blocks)
{
  ASSERT_EQ(EMISSION_SPEED_FACTOR_PER_MINUTE, 21);
}
