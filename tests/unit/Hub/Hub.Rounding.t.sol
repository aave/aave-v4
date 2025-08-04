// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

import {Utils} from 'tests/Utils.sol';

contract HubRoundingTest is HubBase {
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

      assertApproxEqAbs(_sharePrice(daiAssetId), 1e18, 0.011e18);
    }
  }

  function _sharePrice(uint256 assetId) public view returns (uint256) {
    return hub1.convertToAddedAssets(assetId, 1e18);
  }
}
