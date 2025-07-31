// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubMoveSuppliedSharesTest is LiquidityHubBase {
  // TODO: Test moving supplied shares from one spoke to another
  function test_moveSuppliedShares() public {
    test_moveSuppliedShares_fuzz(1000e18, 1000e18);
  }

  function test_moveSuppliedShares_fuzz(uint256 supplyAmount, uint256 moveAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    moveAmount = bound(moveAmount, 1, supplyAmount);

    // supply from spoke 1
    deal(address(tokenList.dai), address(spoke1), supplyAmount);
    Utils.add(hub, daiAssetId, address(spoke1), supplyAmount, address(spoke1));

    uint256 suppliedShares = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));
    uint256 assetSuppliedShares = hub.getAssetSuppliedShares(daiAssetId);
    assertEq(suppliedShares, hub.convertToSuppliedAssets(daiAssetId, supplyAmount));
    assertEq(suppliedShares, assetSuppliedShares);

    // move supplied shares from spoke 1 to spoke 2
    vm.prank(address(spoke1));
    hub.moveSuppliedShares(daiAssetId, moveAmount, address(spoke2));

    assertEq(hub.getSpokeSuppliedShares(daiAssetId, address(spoke1)), suppliedShares - moveAmount);
    assertEq(hub.getSpokeSuppliedShares(daiAssetId, address(spoke2)), moveAmount);
    assertEq(hub.getAssetSuppliedShares(daiAssetId), assetSuppliedShares);
  }

  // TODO: Test moving too many supplied shares from one spoke to another (more than the spoke has) (Revert)
  // TODO: Test moving 0 supplied shares from one spoke to another (Revert)
  // TODO: Test moving supplied shares from inactive spoke (Revert)
  // TODO: Test moving too many supplied shares to other spoke (exceeding cap) (Revert)
}
