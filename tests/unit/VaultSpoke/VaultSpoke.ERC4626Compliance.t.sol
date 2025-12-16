// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/VaultSpoke/VaultSpoke.Base.t.sol';
import {ERC4626Test} from 'lib/erc4626-tests/ERC4626.test.sol';

contract VaultSpokeERC4626ComplianceTest is VaultSpokeBaseTest, ERC4626Test {
  function setUp() public override(VaultSpokeBaseTest, ERC4626Test) {
    VaultSpokeBaseTest.setUp();
    updateLiquidityFee(IHub(daiVault.hub()), daiVault.assetId(), 0);

    _underlying_ = daiVault.asset();
    _vault_ = address(daiVault);

    _delta_ = 0;
    _vaultMayBeEmpty = true; // inflation protection through virtual shares on hub
    _unlimitedAmount = false;
  }

  function setUpYield(Init memory init) public override {
    if (init.yield > 0) {
      init.yield = bound(init.yield, 1, int(MAX_SUPPLY_AMOUNT));
      IHub hub = IHub(IVaultSpoke(_vault_).hub());
      uint256 assetId = IVaultSpoke(_vault_).assetId();
      uint256 gain = uint(init.yield);

      TestnetERC20(IVaultSpoke(_vault_).asset()).mint(address(hub), gain);
      vm.startPrank(address(spoke2));
      hub.add(assetId, gain);
      _mockInterestRateBps(100_00); // 100% interest rate
      hub.draw(assetId, gain, address(spoke2));
      skip(365 days);
      tokenList.dai.transfer(address(hub), gain);
      hub.restore(assetId, gain, IHubBase.PremiumDelta(0, 0, 0));
      vm.stopPrank();
    }
  }
}
