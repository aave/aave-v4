// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubEliminateDeficitTest is HubBase {
  function test_eliminateDeficit_revertsWith_InvalidAmount_zero() public {
    uint256 assetId = _randomAssetId(hub1);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(address(spoke1));
    hub1.eliminateDeficit(assetId, 0);

    _createDeficit(assetId, spoke1, 1000e6);
    assertEq(hub1.getDeficit(assetId), 1000e6);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(address(spoke1));
    hub1.eliminateDeficit(assetId, 0);
  }

  function test_eliminateDeficit_revertsWith_InvalidAmount_excess() public {
    uint256 assetId = _randomAssetId(hub1);
    _createDeficit(assetId, spoke1, 1000e6);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(address(spoke1));
    hub1.eliminateDeficit(assetId, vm.randomUint(1000e6 + 1, UINT256_MAX));
  }

  function test_eliminateDeficit_revertsWith_SpokeNotActive(address caller) public {
    uint256 assetId = _randomAssetId(hub1);
    vm.assume(!hub1.getSpoke(assetId, caller).active);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(caller);
    hub1.eliminateDeficit(assetId, vm.randomUint());
  }

  function test_eliminateDeficit() public {
    uint256 assetId = _randomAssetId(hub1);
    uint256 deficit = 1000e6;

    _createDeficit(assetId, spoke1, deficit);
    _inflateIndex(hub1, assetId);

    uint256 clearedDeficit = vm.randomUint(1, deficit);
    _supply(hub1, spoke1, assetId, clearedDeficit);
    assertGe(hub1.getSpokeAddedAmount(assetId, address(spoke1)), clearedDeficit);

    uint256 expectedRemoveShares = hub1.previewRemoveByAssets(assetId, clearedDeficit);
    uint256 spokeAddedShares = hub1.getSpokeAddedShares(assetId, address(spoke1));
    uint256 assetSuppliedShares = hub1.getTotalAddedShares(assetId);
    uint256 addExRate = getAddExRate(assetId);

    vm.expectEmit(address(hub1));
    emit IHub.EliminateDeficit(assetId, address(spoke1), expectedRemoveShares, clearedDeficit);
    vm.prank(address(spoke1));
    uint256 removedShares = hub1.eliminateDeficit(assetId, clearedDeficit);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(hub1.getDeficit(assetId), deficit - clearedDeficit);
    assertEq(hub1.getTotalAddedShares(assetId), assetSuppliedShares - expectedRemoveShares);
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(spoke1)),
      spokeAddedShares - expectedRemoveShares
    );
    assertGe(getAddExRate(assetId), addExRate);
    assertBorrowRateSynced(hub1, assetId, 'eliminateDeficit');
  }

  function test_eliminateDeficit_partial() public {
    uint256 assetId = _randomAssetId(hub1);
    uint256 deficit = 1000e6;

    _createDeficit(assetId, spoke1, deficit);
    _inflateIndex(hub1, assetId);

    uint256 clearedDeficit = vm.randomUint(1, deficit - 1);
    _supply(hub1, spoke1, assetId, clearedDeficit);
    assertGe(hub1.getSpokeAddedAmount(assetId, address(spoke1)), clearedDeficit);

    uint256 expectedRemoveShares = hub1.previewRemoveByAssets(assetId, clearedDeficit);

    vm.expectEmit(address(hub1));
    emit IHub.EliminateDeficit(assetId, address(spoke1), expectedRemoveShares, clearedDeficit);
    vm.prank(address(spoke1));
    uint256 removedShares = hub1.eliminateDeficit(assetId, clearedDeficit);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(hub1.getDeficit(assetId), deficit - clearedDeficit);
    assertBorrowRateSynced(hub1, assetId, 'eliminateDeficit');
  }

  function _createDeficit(uint256 assetId, ISpoke spoke, uint256 amount) internal {
    _addLiquidity(assetId, amount);
    _drawLiquidityFromSpoke(address(spoke), assetId, amount, 322 days, true);
    vm.prank(address(spoke));
    hub1.reportDeficit(assetId, amount, 0, DataTypes.PremiumDelta(0, 0, 0));

    assertEq(hub1.getDeficit(assetId), amount);
  }

  function _supply(IHub hub, ISpoke spoke, uint256 assetId, uint256 assetAmount) internal {
    uint256 shares = hub.previewRemoveByAssets(assetId, assetAmount) + 1;
    uint256 exactAssetAmount = hub.previewRemoveByShares(assetId, shares);
    Utils.add(hub, assetId, address(spoke), exactAssetAmount, alice);
  }

  function _inflateIndex(IHub hub, uint256 assetId) internal {
    _addAndDrawLiquidity({
      hub: hub,
      assetId: assetId,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: 1000e6,
      drawUser: alice,
      drawSpoke: address(spoke3),
      drawAmount: 1000e6,
      skipTime: 312 days
    });
  }
}
