#!/usr/bin/env python3

# Copyright (c) 2019-2022, The Monero Project
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this list of
#    conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice, this list
#    of conditions and the following disclaimer in the documentation and/or other
#    materials provided with the distribution.
# 
# 3. Neither the name of the copyright holder nor the names of its contributors may be
#    used to endorse or promote products derived from this software without specific
#    prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
# THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

"""Test address validation RPC calls
"""

from __future__ import print_function
from framework.wallet import Wallet
from rxmr_fixtures import (
    MAIN_ADDRESS,
    MAIN_ADDRESS_BAD_CHECKSUM,
    MAIN_INTEGRATED_ADDRESS,
    SECOND_MAIN_ADDRESS,
    STAGENET_ADDRESS,
    TESTNET_ADDRESS,
    SEED,
)

class AddressValidationTest():
    def run_test(self):
      self.create()
      self.check_bad_addresses()
      self.check_good_addresses()
      self.check_openalias_addresses()

    def create(self):
        print('Creating wallet')
        seed = SEED
        address = MAIN_ADDRESS
        self.wallet = Wallet()
        # close the wallet if any, will throw if none is loaded
        try: self.wallet.close_wallet()
        except: pass
        res = self.wallet.restore_deterministic_wallet(seed = seed)
        assert res.address == address
        assert res.seed == seed

    def check_bad_addresses(self):
        print('Validating bad addresses')
        bad_addresses = ['', 'a', MAIN_ADDRESS_BAD_CHECKSUM, ' ', '@', 'C4KF']
        for address in bad_addresses:
            res = self.wallet.validate_address(address, any_net_type = False)
            assert not res.valid
            res = self.wallet.validate_address(address, any_net_type = True)
            assert not res.valid

    def check_good_addresses(self):
        print('Validating good addresses')
        addresses = [
            [ 'mainnet',  '', MAIN_ADDRESS ],
            [ 'mainnet',  '', SECOND_MAIN_ADDRESS ],
            [ 'testnet',  '', TESTNET_ADDRESS ],
            [ 'stagenet', '', STAGENET_ADDRESS ],
            [ 'mainnet', 'i', MAIN_INTEGRATED_ADDRESS ],
            [ 'mainnet', 's', 'HY92vDicqeiBGTY8psSNkJBg9SZgxxGGRUhGwRptBhgr5XSQ1XzmA9m8QAnoxydecSh5aLJXdrgXwTDMMZ1AuXsN1JXPVXJ' ],
            [ 'mainnet', 's', 'HU1zZPAstyALxtK1Jmx2BkNBDBSMDEVaRYMMyVbeURYDWs8uNGDZURKCA5yRcyMxHzPcmCf1q2fSdhQVcaKsFrtGRw1ttfz' ],
            [ 'testnet', 'i', 'Pv99qc974iP4eGcoeeC6mdUPh7BfEv9i99gRJUZq72YS86gPpsZDStvK14Pb19zGD7fyPD8QkG9HBj3PHd5Ppw2XVYxogqQEJc117K9kmRZ1' ],
            [ 'testnet', 's', 'RRSa6Yd4Y4kPHn23GNbH6SiW5sbW4umxeNSoe4SooCrSTA7HMTXHEUiHeiUmyZpXjZetnUN6cN4g3MTzPtoj2tbX1p8YVySqr' ],
            [ 'testnet', 's', 'RRSL73zuTCZ8e6nB3BH3Fd7DRH3xsHLybjQEMwFijun9GkNWhmYJM3LGNwSpvPGBiM5EGkKbPNEUgeNZuef3EGon18qTzk8hd' ],
            [ 'stagenet', 'i', 'FgcUoiWVU5weCcQEjNbf59Um6R9NfVUNkHTLhhPCmNvgDLVS88YW5tScnm83rw9mfgYtchtDDTW5jEfMhygi27j1QYphX38hg6m4VCAioq' ],
            [ 'stagenet', 's', 'K5q8UqgTqUjFMcKhsPRG51QmCsv8dYYbL6GcQoLwEEFvPvkVvc7BhebfA4pnEFF9Lq66hwvLqBvpHjTcqvpJMHmmNmXtgDp' ],
            [ 'stagenet', 's', 'KCVirCzsSwia8pkWxueD5xBqhQczkusYiCMYMnJGcGmuQxa7aDBxN1G7iCuLCNB3VPeb2TW7U9FdxB27xKkWKfJ8VgNTKJd' ],
        ]
        for any_net_type in [True, False]:
            for address in addresses:
                res = self.wallet.validate_address(address[2], any_net_type = any_net_type)
                if any_net_type or address[0] == 'mainnet':
                    assert res.valid
                    assert res.integrated == (address[1] == 'i')
                    assert res.subaddress == (address[1] == 's')
                    assert res.nettype == address[0]
                    assert res.openalias_address == ''
                else:
                    assert not res.valid

    def check_openalias_addresses(self):
        print('Validating openalias addresses')
        # rXMR uses different address prefixes; Monero OpenAlias records must be rejected.
        addresses = [
            'donate@getmonero.org'
        ]
        for address in addresses:
            res = self.wallet.validate_address(address)
            assert not res.valid
            res = self.wallet.validate_address(address, allow_openalias = True)
            assert not res.valid

if __name__ == '__main__':
    AddressValidationTest().run_test()
