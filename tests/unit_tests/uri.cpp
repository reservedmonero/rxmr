// Copyright (c) 2016-2022, The Monero Project
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

// rXMR URI tests
// Acceptance criteria: Verify that rXMR payment URIs (rxmr:) are correctly parsed
// with rXMR testnet addresses (prefix 136, starting with 'T').

#include "gtest/gtest.h"
#include "wallet/wallet2.h"
#include "cryptonote_basic/account.h"
#include "cryptonote_basic/cryptonote_basic_impl.h"

// Helper class to generate valid rXMR testnet addresses for testing
class UriTestFixture : public ::testing::Test {
protected:
  static std::string test_address;
  static std::string test_integrated_address;
  static crypto::hash8 test_payment_id;

  static void SetUpTestSuite() {
    // Generate a deterministic test account
    cryptonote::account_base account;
    account.generate();

    // Generate testnet standard address (prefix 136)
    test_address = cryptonote::get_account_address_as_str(
      cryptonote::TESTNET, false, account.get_keys().m_account_address);

    // Generate testnet integrated address (prefix 137)
    memset(&test_payment_id, 0xf6, sizeof(test_payment_id)); // Fixed payment ID for tests
    test_integrated_address = cryptonote::get_account_integrated_address_as_str(
      cryptonote::TESTNET, account.get_keys().m_account_address, test_payment_id);
  }
};

std::string UriTestFixture::test_address;
std::string UriTestFixture::test_integrated_address;
crypto::hash8 UriTestFixture::test_payment_id;

#define PARSE_URI(uri, expected) \
  std::string address, payment_id, recipient_name, description, error; \
  uint64_t amount; \
  std::vector<std::string> unknown_parameters; \
  tools::wallet2 w(cryptonote::TESTNET); \
  bool ret = w.parse_uri(uri, address, payment_id, amount, description, recipient_name, unknown_parameters, error); \
  ASSERT_EQ(ret, expected);

TEST(uri, empty_string)
{
  PARSE_URI("", false);
}

TEST(uri, no_scheme)
{
  PARSE_URI("rxmr", false);
}

TEST(uri, bad_scheme)
{
  PARSE_URI("http://foo", false);
}

TEST(uri, scheme_not_first)
{
  PARSE_URI(" rxmr:", false);
}

TEST(uri, no_body)
{
  PARSE_URI("rxmr:", false);
}

TEST(uri, no_address)
{
  PARSE_URI("rxmr:?", false);
}

TEST(uri, bad_address)
{
  PARSE_URI("rxmr:44444", false);
}

TEST_F(UriTestFixture, good_address)
{
  PARSE_URI("rxmr:" + test_address, true);
  ASSERT_EQ(address, test_address);
}

TEST_F(UriTestFixture, good_integrated_address)
{
  PARSE_URI("rxmr:" + test_integrated_address, true);
}

TEST_F(UriTestFixture, parameter_without_inter)
{
  PARSE_URI("rxmr:" + test_address + "&amount=1", false);
}

TEST_F(UriTestFixture, parameter_without_equals)
{
  PARSE_URI("rxmr:" + test_address + "?amount", false);
}

TEST_F(UriTestFixture, parameter_without_value)
{
  PARSE_URI("rxmr:" + test_address + "?tx_amount=", false);
}

TEST_F(UriTestFixture, negative_amount)
{
  PARSE_URI("rxmr:" + test_address + "?tx_amount=-1", false);
}

TEST_F(UriTestFixture, bad_amount)
{
  PARSE_URI("rxmr:" + test_address + "?tx_amount=alphanumeric", false);
}

TEST_F(UriTestFixture, duplicate_parameter)
{
  PARSE_URI("rxmr:" + test_address + "?tx_amount=1&tx_amount=1", false);
}

TEST_F(UriTestFixture, unknown_parameter)
{
  PARSE_URI("rxmr:" + test_address + "?unknown=1", true);
  ASSERT_EQ(unknown_parameters.size(), 1);
  ASSERT_EQ(unknown_parameters[0], "unknown=1");
}

TEST_F(UriTestFixture, unknown_parameters)
{
  PARSE_URI("rxmr:" + test_address + "?tx_amount=1&unknown=1&tx_description=desc&foo=bar", true);
  ASSERT_EQ(unknown_parameters.size(), 2);
  ASSERT_EQ(unknown_parameters[0], "unknown=1");
  ASSERT_EQ(unknown_parameters[1], "foo=bar");
}

TEST_F(UriTestFixture, empty_payment_id)
{
  PARSE_URI("rxmr:" + test_address + "?tx_payment_id=", false);
}

TEST_F(UriTestFixture, bad_payment_id)
{
  PARSE_URI("rxmr:" + test_address + "?tx_payment_id=1234567890", false);
}

TEST_F(UriTestFixture, short_payment_id)
{
  PARSE_URI("rxmr:" + test_address + "?tx_payment_id=1234567890123456", false);
}

TEST_F(UriTestFixture, long_payment_id)
{
  PARSE_URI("rxmr:" + test_address + "?tx_payment_id=1234567890123456789012345678901234567890123456789012345678901234", true);
  ASSERT_EQ(address, test_address);
  ASSERT_EQ(payment_id, "1234567890123456789012345678901234567890123456789012345678901234");
}

TEST_F(UriTestFixture, payment_id_with_integrated_address)
{
  PARSE_URI("rxmr:" + test_integrated_address + "?tx_payment_id=1234567890123456", false);
}

TEST_F(UriTestFixture, empty_description)
{
  PARSE_URI("rxmr:" + test_address + "?tx_description=", true);
  ASSERT_EQ(description, "");
}

TEST_F(UriTestFixture, empty_recipient_name)
{
  PARSE_URI("rxmr:" + test_address + "?recipient_name=", true);
  ASSERT_EQ(recipient_name, "");
}

TEST_F(UriTestFixture, non_empty_description)
{
  PARSE_URI("rxmr:" + test_address + "?tx_description=foo", true);
  ASSERT_EQ(description, "foo");
}

TEST_F(UriTestFixture, non_empty_recipient_name)
{
  PARSE_URI("rxmr:" + test_address + "?recipient_name=foo", true);
  ASSERT_EQ(recipient_name, "foo");
}

TEST_F(UriTestFixture, url_encoding)
{
  PARSE_URI("rxmr:" + test_address + "?tx_description=foo%20bar", true);
  ASSERT_EQ(description, "foo bar");
}

TEST_F(UriTestFixture, non_alphanumeric_url_encoding)
{
  PARSE_URI("rxmr:" + test_address + "?tx_description=foo%2x", true);
  ASSERT_EQ(description, "foo%2x");
}

TEST_F(UriTestFixture, truncated_url_encoding)
{
  PARSE_URI("rxmr:" + test_address + "?tx_description=foo%2", true);
  ASSERT_EQ(description, "foo%2");
}

TEST_F(UriTestFixture, percent_without_url_encoding)
{
  PARSE_URI("rxmr:" + test_address + "?tx_description=foo%", true);
  ASSERT_EQ(description, "foo%");
}

TEST_F(UriTestFixture, url_encoded_once)
{
  PARSE_URI("rxmr:" + test_address + "?tx_description=foo%2020", true);
  ASSERT_EQ(description, "foo 20");
}

// Acceptance: Verify that Monero URIs are rejected
TEST(uri, monero_scheme_rejected)
{
  cryptonote::account_base account;
  account.generate();
  std::string addr = cryptonote::get_account_address_as_str(
    cryptonote::TESTNET, false, account.get_keys().m_account_address);
  PARSE_URI("monero:" + addr, false);  // monero: scheme should fail
}

