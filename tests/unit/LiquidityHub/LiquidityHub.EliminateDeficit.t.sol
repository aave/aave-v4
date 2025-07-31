// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubEliminateDeficitTest is LiquidityHubBase {
  function test_eliminateDeficit_revertsWith_InvalidDeficitAmount_zero() public {
    uint256 assetId = _randomAssetId(hub);
    vm.expectRevert(ILiquidityHub.InvalidDeficitAmount.selector);
    vm.prank(address(spoke1));
    hub.eliminateDeficit(assetId, 0);

    _createDeficit(assetId, spoke1, 1000e6);
    assertEq(hub.getDeficit(assetId), 1000e6);
    vm.expectRevert(ILiquidityHub.InvalidDeficitAmount.selector);
    vm.prank(address(spoke1));
    hub.eliminateDeficit(assetId, 0);
  }

  function test_eliminateDeficit_revertsWith_InvalidDeficitAmount_excess() public {
    uint256 assetId = _randomAssetId(hub);
    _createDeficit(assetId, spoke1, 1000e6);
    vm.expectRevert(ILiquidityHub.InvalidDeficitAmount.selector);
    vm.prank(address(spoke1));
    hub.eliminateDeficit(assetId, vm.randomUint(1000e6 + 1, UINT256_MAX));
  }

  function test_eliminateDeficit_revertsWith_SpokeNotActive(address caller) public {
    uint256 assetId = _randomAssetId(hub);
    vm.assume(!hub.getSpoke(assetId, caller).config.active);

    vm.expectRevert(ILiquidityHub.SpokeNotActive.selector);
    vm.prank(caller);
    hub.eliminateDeficit(assetId, vm.randomUint());
  }

  function test_eliminateDeficit() public {
    uint256 assetId = _randomAssetId(hub);
    uint256 deficit = 1000e6;

    _createDeficit(assetId, spoke1, deficit);
    _inflateIndex(hub, assetId);

    uint256 clearedDeficit = vm.randomUint(1, deficit);
    _supply(hub, spoke1, assetId, clearedDeficit);
    assertGe(hub.getSpokeSuppliedAmount(assetId, address(spoke1)), clearedDeficit);

    uint256 expectedRemoveShares = hub.previewRemoveByAssets(assetId, clearedDeficit);
    uint256 spokeSuppliedShares = hub.getSpokeSuppliedShares(assetId, address(spoke1));
    uint256 assetSuppliedShares = hub.getAssetSuppliedShares(assetId);
    uint256 supplyExRate = getSupplyExRate(assetId);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitEliminated(
      assetId,
      address(spoke1),
      expectedRemoveShares,
      clearedDeficit
    );
    vm.prank(address(spoke1));
    uint256 removedShares = hub.eliminateDeficit(assetId, clearedDeficit);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(hub.getDeficit(assetId), deficit - clearedDeficit);
    assertEq(hub.getAssetSuppliedShares(assetId), assetSuppliedShares - expectedRemoveShares);
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(spoke1)),
      spokeSuppliedShares - expectedRemoveShares
    );
    assertGe(getSupplyExRate(assetId), supplyExRate);
    assertBorrowRateSynced(hub, assetId, 'eliminateDeficit');
  }

  function test_eliminateDeficit_partial() public {
    uint256 assetId = _randomAssetId(hub);
    uint256 deficit = 1000e6;

    _createDeficit(assetId, spoke1, deficit);
    _inflateIndex(hub, assetId);

    uint256 clearedDeficit = vm.randomUint(1, deficit - 1);
    _supply(hub, spoke1, assetId, clearedDeficit);
    assertGe(hub.getSpokeSuppliedAmount(assetId, address(spoke1)), clearedDeficit);

    uint256 expectedRemoveShares = hub.previewRemoveByAssets(assetId, clearedDeficit);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitEliminated(
      assetId,
      address(spoke1),
      expectedRemoveShares,
      clearedDeficit
    );
    vm.prank(address(spoke1));
    uint256 removedShares = hub.eliminateDeficit(assetId, clearedDeficit);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(hub.getDeficit(assetId), deficit - clearedDeficit);
    assertBorrowRateSynced(hub, assetId, 'eliminateDeficit');
  }

  function _createDeficit(uint256 assetId, ISpoke spoke, uint256 amount) internal {
    _addLiquidity(assetId, amount);
    _drawLiquidityFromSpoke(address(spoke), assetId, amount, 322 days, true);
    vm.prank(address(spoke));
    hub.reportDeficit(assetId, amount, 0, DataTypes.PremiumDelta(0, 0, 0));

    assertEq(hub.getDeficit(assetId), amount);
  }

  function _supply(
    ILiquidityHub liquidityHub,
    ISpoke spoke,
    uint256 assetId,
    uint256 assetAmount
  ) internal {
    uint256 shares = liquidityHub.previewRemoveByAssets(assetId, assetAmount) + 1;
    uint256 exactAssetAmount = liquidityHub.previewRemoveByShares(assetId, shares);
    Utils.add(liquidityHub, assetId, address(spoke), exactAssetAmount, alice);
  }

  function _inflateIndex(ILiquidityHub liquidityHub, uint256 assetId) internal {
    _supplyAndDrawLiquidity({
      liquidityHub: liquidityHub,
      assetId: assetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: 1000e6,
      drawUser: alice,
      drawSpoke: address(spoke3),
      drawAmount: 1000e6,
      skipTime: 312 days
    });
  }
}
