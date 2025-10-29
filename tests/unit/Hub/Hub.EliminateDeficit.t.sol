// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubEliminateDeficitTest is HubBase {
  address asset;
  uint256 deficitAmount;
  address callerSpoke;
  address coveredSpoke;
  address otherSpoke;

  function setUp() public override {
    super.setUp();
    asset = address(tokenList.usdx);
    deficitAmount = 1000e6;
    callerSpoke = address(spoke2);
    coveredSpoke = address(spoke1);
    otherSpoke = address(spoke3);
  }

  function test_eliminateDeficit_revertsWith_InvalidAmount_ZeroAmountNoDeficit() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(callerSpoke);
    hub1.eliminateDeficit(asset, 0, coveredSpoke);
  }

  function test_eliminateDeficit_revertsWith_InvalidAmount_ZeroAmountWithDeficit() public {
    _createDeficit(asset, coveredSpoke, deficitAmount);
    assertEq(hub1.getSpokeDeficit(asset, coveredSpoke), deficitAmount);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(callerSpoke);
    hub1.eliminateDeficit(asset, 0, coveredSpoke);
  }

  function test_eliminateDeficit_fuzz_revertsWith_InvalidAmount_Excess(uint256) public {
    _createDeficit(asset, coveredSpoke, deficitAmount);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(callerSpoke);
    hub1.eliminateDeficit(asset, vm.randomUint(deficitAmount + 1, UINT256_MAX), coveredSpoke);
  }

  function test_eliminateDeficit_fuzz_revertsWith_callerSpokeNotActive(address caller) public {
    vm.assume(!hub1.getSpoke(asset, caller).active);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(caller);
    hub1.eliminateDeficit(asset, vm.randomUint(), coveredSpoke);
  }

  /// @dev paused but active spokes are allowed to eliminate deficit
  function test_eliminateDeficit_allowSpokePaused() public {
    _createDeficit(asset, coveredSpoke, deficitAmount);
    Utils.add(hub1, asset, callerSpoke, deficitAmount + 1, alice);

    updateSpokeActive(hub1, asset, callerSpoke, true);
    _updateSpokePaused(hub1, asset, callerSpoke, true);

    vm.prank(callerSpoke);
    hub1.eliminateDeficit(asset, deficitAmount, coveredSpoke);
  }

  function test_eliminateDeficit(uint256) public {
    uint256 deficitAmount2 = deficitAmount / 2;
    _createDeficit(asset, coveredSpoke, deficitAmount);
    _createDeficit(asset, otherSpoke, deficitAmount2);

    uint256 clearedDeficit = vm.randomUint(1, deficitAmount);

    Utils.add(hub1, asset, callerSpoke, clearedDeficit + 1, alice);
    assertGe(hub1.getSpokeAddedAssets(asset, callerSpoke), clearedDeficit);

    uint256 expectedRemoveShares = hub1.previewRemoveByAssets(asset, clearedDeficit);
    uint256 spokeAddedShares = hub1.getSpokeAddedShares(asset, callerSpoke);
    uint256 assetSuppliedShares = hub1.getAddedShares(asset);
    uint256 addExRate = getAddExRate(asset);

    vm.expectEmit(address(hub1));
    emit IHub.EliminateDeficit(
      asset,
      callerSpoke,
      coveredSpoke,
      expectedRemoveShares,
      clearedDeficit
    );
    vm.prank(callerSpoke);
    uint256 removedShares = hub1.eliminateDeficit(asset, clearedDeficit, coveredSpoke);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(hub1.getAssetDeficit(asset), deficitAmount2 + deficitAmount - clearedDeficit);
    assertEq(hub1.getAddedShares(asset), assetSuppliedShares - expectedRemoveShares);
    assertEq(hub1.getSpokeAddedShares(asset, callerSpoke), spokeAddedShares - expectedRemoveShares);
    assertEq(hub1.getSpokeDeficit(asset, coveredSpoke), deficitAmount - clearedDeficit);
    assertGe(getAddExRate(asset), addExRate);
    assertBorrowRateSynced(hub1, asset, 'eliminateDeficit');
  }

  function _createDeficit(address asset, address spoke, uint256 amount) internal {
    _addAndDrawLiquidity({
      hub: hub1,
      asset: asset,
      addUser: alice,
      addSpoke: spoke,
      addAmount: amount,
      drawUser: alice,
      drawSpoke: spoke,
      drawAmount: amount,
      skipTime: 365 days
    });

    vm.prank(spoke);
    hub1.reportDeficit(asset, amount, 0, IHubBase.PremiumDelta(0, 0, 0));
  }
}
