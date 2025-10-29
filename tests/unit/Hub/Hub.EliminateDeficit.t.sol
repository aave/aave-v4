// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubEliminateDeficitTest is HubBase {
  address underlying;
  uint256 deficitAmount;
  address callerSpoke;
  address coveredSpoke;
  address otherSpoke;

  function setUp() public override {
    super.setUp();
    underlying = address(tokenList.usdx);
    deficitAmount = 1000e6;
    callerSpoke = address(spoke2);
    coveredSpoke = address(spoke1);
    otherSpoke = address(spoke3);
  }

  function test_eliminateDeficit_revertsWith_InvalidAmount_ZeroAmountNoDeficit() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(callerSpoke);
    hub1.eliminateDeficit(underlying, 0, coveredSpoke);
  }

  function test_eliminateDeficit_revertsWith_InvalidAmount_ZeroAmountWithDeficit() public {
    _createDeficit(underlying, coveredSpoke, deficitAmount);
    assertEq(hub1.getSpokeDeficit(underlying, coveredSpoke), deficitAmount);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(callerSpoke);
    hub1.eliminateDeficit(underlying, 0, coveredSpoke);
  }

  function test_eliminateDeficit_fuzz_revertsWith_InvalidAmount_Excess(uint256) public {
    _createDeficit(underlying, coveredSpoke, deficitAmount);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(callerSpoke);
    hub1.eliminateDeficit(underlying, vm.randomUint(deficitAmount + 1, UINT256_MAX), coveredSpoke);
  }

  function test_eliminateDeficit_fuzz_revertsWith_callerSpokeNotActive(address caller) public {
    vm.assume(!hub1.getSpoke(underlying, caller).active);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(caller);
    hub1.eliminateDeficit(underlying, vm.randomUint(), coveredSpoke);
  }

  /// @dev paused but active spokes are allowed to eliminate deficit
  function test_eliminateDeficit_allowSpokePaused() public {
    _createDeficit(underlying, coveredSpoke, deficitAmount);
    Utils.add(hub1, underlying, callerSpoke, deficitAmount + 1, alice);

    updateSpokeActive(hub1, underlying, callerSpoke, true);
    _updateSpokePaused(hub1, underlying, callerSpoke, true);

    vm.prank(callerSpoke);
    hub1.eliminateDeficit(underlying, deficitAmount, coveredSpoke);
  }

  function test_eliminateDeficit(uint256) public {
    uint256 deficitAmount2 = deficitAmount / 2;
    _createDeficit(underlying, coveredSpoke, deficitAmount);
    _createDeficit(underlying, otherSpoke, deficitAmount2);

    uint256 clearedDeficit = vm.randomUint(1, deficitAmount);

    Utils.add(hub1, underlying, callerSpoke, clearedDeficit + 1, alice);
    assertGe(hub1.getSpokeAddedAssets(underlying, callerSpoke), clearedDeficit);

    uint256 expectedRemoveShares = hub1.previewRemoveByAssets(underlying, clearedDeficit);
    uint256 spokeAddedShares = hub1.getSpokeAddedShares(underlying, callerSpoke);
    uint256 assetSuppliedShares = hub1.getAddedShares(underlying);
    uint256 addExRate = getAddExRate(underlying);

    vm.expectEmit(address(hub1));
    emit IHub.EliminateDeficit(
      underlying,
      callerSpoke,
      coveredSpoke,
      expectedRemoveShares,
      clearedDeficit
    );
    vm.prank(callerSpoke);
    uint256 removedShares = hub1.eliminateDeficit(underlying, clearedDeficit, coveredSpoke);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(hub1.getAssetDeficit(underlying), deficitAmount2 + deficitAmount - clearedDeficit);
    assertEq(hub1.getAddedShares(underlying), assetSuppliedShares - expectedRemoveShares);
    assertEq(
      hub1.getSpokeAddedShares(underlying, callerSpoke),
      spokeAddedShares - expectedRemoveShares
    );
    assertEq(hub1.getSpokeDeficit(underlying, coveredSpoke), deficitAmount - clearedDeficit);
    assertGe(getAddExRate(underlying), addExRate);
    assertBorrowRateSynced(hub1, underlying, 'eliminateDeficit');
  }

  function _createDeficit(address underlying, address spoke, uint256 amount) internal {
    _addAndDrawLiquidity({
      hub: hub1,
      underlying: underlying,
      addUser: alice,
      addSpoke: spoke,
      addAmount: amount,
      drawUser: alice,
      drawSpoke: spoke,
      drawAmount: amount,
      skipTime: 365 days
    });

    vm.prank(spoke);
    hub1.reportDeficit(underlying, amount, 0, IHubBase.PremiumDelta(0, 0, 0));
  }
}
