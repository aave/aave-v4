// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

import {Utils} from 'tests/Utils.sol';

contract HubRoundingTest is HubBase {
  using Math for uint256;

  /// @dev Added share price is not significantly affected by multiple donations
  function test_sharePriceWithMultipleDonations() public {
    // add and draw 1 dai and wait 12 seconds to start accruing interest
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 1,
      skipTime: 12
    });

    uint256 initialSharePrice = getAddExRate(daiAssetId);
    assertGt(initialSharePrice, 1e30);
    assertLt(initialSharePrice, 1.000001e30);

    for (uint256 i = 0; i < 1e4; ++i) {
      Utils.supply({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        caller: alice,
        amount: hub1.previewAddByShares(daiAssetId, 1),
        onBehalfOf: alice
      });

      Utils.withdraw({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        caller: alice,
        amount: 1,
        onBehalfOf: alice
      });

      assertLt(getAddExRate(daiAssetId), initialSharePrice + initialSharePrice.mulDiv(i + 1, SharesMath.VIRTUAL_ASSETS, Math.Rounding.Ceil));
    }
  }
}
