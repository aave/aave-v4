// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';
import {ERC4626Test} from 'lib/erc4626-tests/ERC4626.test.sol';

contract TokenizationSpokeERC4626ComplianceTest is TokenizationSpokeBaseTest, ERC4626Test {
  function setUp() public override(TokenizationSpokeBaseTest, ERC4626Test) {
    TokenizationSpokeBaseTest.setUp();
    updateLiquidityFee(IHub(daiVault.hub()), daiVault.assetId(), 0);

    _underlying_ = daiVault.asset();
    _vault_ = address(daiVault);

    _delta_ = 0; // maximum approximation error size to be passed to assertApproxEqAbs, 0 implies the vault follows the preferred rounding directions as per spec security considerations
    _vaultMayBeEmpty = true; // fuzz inputs that empties the vault are considered; inflation protection is through virtual shares on hub
    _unlimitedAmount = false; // fuzz inputs are restricted to the currently available amount from the caller
  }

  function setUpYield(Init memory init) public override {
    if (init.yield > 0) {
      init.yield = bound(init.yield, 1, int(MAX_SUPPLY_AMOUNT));
      IHub hub = IHub(ITokenizationSpoke(_vault_).hub());
      uint256 assetId = ITokenizationSpoke(_vault_).assetId();
      uint256 gain = uint(init.yield);

      TestnetERC20(ITokenizationSpoke(_vault_).asset()).mint(address(hub), gain);
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
