// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBase.t.sol';

contract LiquidityHubClearDeficitTest is LiquidityHubBase {
  function test_clearDeficit_revertsWith_InvalidClearDeficitAmount() public {
    uint256 assetId = _randomAssetId(hub);
    vm.expectRevert(ILiquidityHub.InvalidClearDeficitAmount.selector);
    vm.prank(address(spoke1));
    hub.clearDeficit(assetId, 0);
  }

  function test_clearDeficit_revertsWith_SpokeNotActive(address caller) public {
    uint256 assetId = _randomAssetId(hub);
    vm.assume(!hub.getSpoke(assetId, caller).config.active);

    vm.expectRevert(ILiquidityHub.SpokeNotActive.selector);
    vm.prank(caller);
    hub.clearDeficit(assetId, vm.randomUint());
  }

  function test_clearDeficit() public {
    uint256 assetId = _randomAssetId(hub);
    uint256 deficit = 1000e6;

    _createDeficit(assetId, spoke1, deficit);
    // arbitrarily inflate index
    Utils.add(hub, assetId, address(spoke2), vm.randomUint(1, MAX_SUPPLY_AMOUNT), bob);
    Utils.add(hub, assetId, address(spoke3), vm.randomUint(1, MAX_SUPPLY_AMOUNT), derl);

    uint256 clearedDeficit = vm.randomUint(1, deficit);
    _supply(hub, spoke1, assetId, clearedDeficit);
    assertGe(hub.getSpokeSuppliedAmount(assetId, address(spoke1)), clearedDeficit);

    uint256 expectedRemoveShares = hub.previewRemoveByAssets(assetId, clearedDeficit);
    uint256 spokeSuppliedShares = hub.getSpokeSuppliedShares(assetId, address(spoke1));
    uint256 assetSuppliedShares = hub.getAssetSuppliedShares(assetId);
    uint256 supplyExRate = getSupplyExRate(assetId);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitCleared(
      assetId,
      address(spoke1),
      expectedRemoveShares,
      clearedDeficit
    );
    vm.prank(address(spoke1));
    uint256 removedShares = hub.clearDeficit(assetId, clearedDeficit);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(hub.getDeficit(assetId), deficit - clearedDeficit);
    assertEq(hub.getAssetSuppliedShares(assetId), assetSuppliedShares - expectedRemoveShares);
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(spoke1)),
      spokeSuppliedShares - expectedRemoveShares
    );
    assertGe(getSupplyExRate(assetId), supplyExRate);
    assertBorrowRateSynced(hub, assetId, 'clearDeficit');
  }

  function test_clearDeficit_partial() public {
    uint256 assetId = _randomAssetId(hub);
    uint256 deficit = 1000e6;

    _createDeficit(assetId, spoke1, deficit);
    // arbitrarily inflate index
    Utils.add(hub, assetId, address(spoke2), vm.randomUint(1, MAX_SUPPLY_AMOUNT), bob);
    Utils.add(hub, assetId, address(spoke3), vm.randomUint(1, MAX_SUPPLY_AMOUNT), derl);

    uint256 clearedDeficit = vm.randomUint(1, deficit - 1);
    _supply(hub, spoke1, assetId, clearedDeficit);
    assertGe(hub.getSpokeSuppliedAmount(assetId, address(spoke1)), clearedDeficit);

    uint256 expectedRemoveShares = hub.previewRemoveByAssets(assetId, clearedDeficit);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitCleared(
      assetId,
      address(spoke1),
      expectedRemoveShares,
      clearedDeficit
    );
    vm.prank(address(spoke1));
    uint256 removedShares = hub.clearDeficit(assetId, clearedDeficit);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(hub.getDeficit(assetId), deficit - clearedDeficit);
    assertBorrowRateSynced(hub, assetId, 'clearDeficit');
  }

  function test_clearDeficit_excess() public {
    uint256 assetId = _randomAssetId(hub);
    uint256 deficit = 1000e6;

    _createDeficit(assetId, spoke1, deficit);
    // arbitrarily inflate index
    Utils.add(hub, assetId, address(spoke2), vm.randomUint(1, MAX_SUPPLY_AMOUNT), bob);
    Utils.add(hub, assetId, address(spoke3), vm.randomUint(1, MAX_SUPPLY_AMOUNT), derl);

    _supply(hub, spoke1, assetId, deficit);
    assertGe(hub.getSpokeSuppliedAmount(assetId, address(spoke1)), deficit);

    uint256 expectedRemoveShares = hub.previewRemoveByAssets(assetId, deficit);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitCleared(assetId, address(spoke1), expectedRemoveShares, deficit);
    vm.prank(address(spoke1));
    uint256 removedShares = hub.clearDeficit(assetId, vm.randomUint(deficit, type(uint256).max));

    assertEq(removedShares, expectedRemoveShares);
    assertEq(hub.getDeficit(assetId), 0);
    assertBorrowRateSynced(hub, assetId, 'clearDeficit');
  }

  function _createDeficit(uint256 assetId, ISpoke spoke, uint256 amount) internal {
    _addLiquidity(assetId, amount);
    _drawLiquidityFromSpoke(address(spoke), assetId, amount, 322 days, true);
    vm.prank(address(spoke));
    hub.reportDeficit(assetId, amount, 0);

    assertEq(hub.getDeficit(assetId), amount);
  }

  function _supply(
    ILiquidityHub liqHub,
    ISpoke spoke,
    uint256 assetId,
    uint256 assetAmount
  ) internal {
    uint256 shares = liqHub.previewRemoveByAssets(assetId, assetAmount) + 1;
    uint256 exactAssetAmount = liqHub.previewRemoveByShares(assetId, shares);
    Utils.add(liqHub, assetId, address(spoke), exactAssetAmount, alice);
  }
}
