// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubEliminateDeficitTest is HubBase {
  uint256 internal _assetId;
  uint256 internal _deficitAmount;
  address internal _callerSpoke;
  address internal _coveredSpoke;
  address internal _otherSpoke;

  function setUp() public override {
    super.setUp();
    _assetId = usdxAssetId;
    _deficitAmount = 1000e6;
    _callerSpoke = address(spoke2);
    _coveredSpoke = address(spoke1);
    _otherSpoke = address(spoke3);
  }

  function test_eliminateDeficit_revertsWith_InvalidAmount_ZeroAmountNoDeficit() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(_callerSpoke);
    hub1.eliminateDeficit(_assetId, 0, _coveredSpoke);
  }

  function test_eliminateDeficit_revertsWith_InvalidAmount_ZeroAmountWithDeficit() public {
    _createDeficit(_assetId, _coveredSpoke, _deficitAmount);
    assertEq(hub1.getSpokeDeficit(_assetId, _coveredSpoke), _deficitAmount);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(_callerSpoke);
    hub1.eliminateDeficit(_assetId, 0, _coveredSpoke);
  }

  function test_eliminateDeficit_fuzz_revertsWith_InvalidAmount_Excess(uint256) public {
    _createDeficit(_assetId, _coveredSpoke, _deficitAmount);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(_callerSpoke);
    hub1.eliminateDeficit(_assetId, vm.randomUint(_deficitAmount + 1, UINT256_MAX), _coveredSpoke);
  }

  function test_eliminateDeficit_fuzz_revertsWith_callerSpokeNotActive(address caller) public {
    vm.assume(!hub1.getSpoke(_assetId, caller).active);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(caller);
    hub1.eliminateDeficit(_assetId, vm.randomUint(), _coveredSpoke);
  }

  /// @dev paused but active spokes are allowed to eliminate deficit
  function test_eliminateDeficit_allowSpokePaused() public {
    _createDeficit(_assetId, _coveredSpoke, _deficitAmount);
    Utils.add(hub1, _assetId, _callerSpoke, _deficitAmount + 1, alice);

    updateSpokeActive(hub1, _assetId, _callerSpoke, true);
    _updateSpokePaused(hub1, _assetId, _callerSpoke, true);

    vm.prank(_callerSpoke);
    hub1.eliminateDeficit(_assetId, _deficitAmount, _coveredSpoke);
  }

  function test_eliminateDeficit(uint256) public {
    uint256 deficitAmount2 = _deficitAmount / 2;
    _createDeficit(_assetId, _coveredSpoke, _deficitAmount);
    _createDeficit(_assetId, _otherSpoke, deficitAmount2);

    uint256 clearedDeficit = vm.randomUint(1, _deficitAmount);

    Utils.add(hub1, _assetId, _callerSpoke, clearedDeficit + 1, alice);
    assertGe(hub1.getSpokeAddedAssets(_assetId, _callerSpoke), clearedDeficit);

    uint256 expectedRemoveShares = hub1.previewRemoveByAssets(_assetId, clearedDeficit);
    uint256 spokeAddedShares = hub1.getSpokeAddedShares(_assetId, _callerSpoke);
    uint256 assetSuppliedShares = hub1.getAddedShares(_assetId);
    uint256 addExRate = getAddExRate(_assetId);

    vm.expectEmit(address(hub1));
    emit IHub.EliminateDeficit(
      _assetId,
      _callerSpoke,
      _coveredSpoke,
      expectedRemoveShares,
      clearedDeficit
    );
    vm.prank(_callerSpoke);
    uint256 removedShares = hub1.eliminateDeficit(_assetId, clearedDeficit, _coveredSpoke);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(hub1.getAssetDeficit(_assetId), deficitAmount2 + _deficitAmount - clearedDeficit);
    assertEq(hub1.getAddedShares(_assetId), assetSuppliedShares - expectedRemoveShares);
    assertEq(
      hub1.getSpokeAddedShares(_assetId, _callerSpoke),
      spokeAddedShares - expectedRemoveShares
    );
    assertEq(hub1.getSpokeDeficit(_assetId, _coveredSpoke), _deficitAmount - clearedDeficit);
    assertGe(getAddExRate(_assetId), addExRate);
    _assertBorrowRateSynced(hub1, _assetId, 'eliminateDeficit');
  }

  function _createDeficit(uint256 assetId, address spoke, uint256 amount) internal {
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: assetId,
      addUser: alice,
      addSpoke: spoke,
      addAmount: amount,
      drawUser: alice,
      drawSpoke: spoke,
      drawAmount: amount,
      skipTime: 365 days
    });

    vm.prank(spoke);
    hub1.reportDeficit(assetId, amount, 0, IHubBase.PremiumDelta(0, 0, 0));
  }
}
