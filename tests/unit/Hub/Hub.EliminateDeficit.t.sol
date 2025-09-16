// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubEliminateDeficitTest is HubBase {
  uint256 assetId;
  uint256 deficitAmount;
  address senderSpoke;
  address receiverSpoke;
  address otherSpoke;

  function setUp() public override {
    super.setUp();
    assetId = usdxAssetId;
    deficitAmount = 1000e6;
    senderSpoke = address(spoke2);
    receiverSpoke = address(spoke1);
    otherSpoke = address(spoke3);
  }

  function test_eliminateDeficit_revertsWith_InvalidAmount_ZeroAmountNoDeficit() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(senderSpoke);
    hub1.eliminateDeficit(assetId, 0, receiverSpoke);
  }

  function test_eliminateDeficit_revertsWith_InvalidAmount_ZeroAmountWithDeficit() public {
    _createDeficit(assetId, receiverSpoke, deficitAmount);
    assertEq(hub1.getSpokeDeficit(assetId, receiverSpoke), deficitAmount);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(senderSpoke);
    hub1.eliminateDeficit(assetId, 0, receiverSpoke);
  }

  function test_eliminateDeficit_fuzz_revertsWith_InvalidAmount_Excess(uint256) public {
    _createDeficit(assetId, receiverSpoke, deficitAmount);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(senderSpoke);
    hub1.eliminateDeficit(assetId, vm.randomUint(deficitAmount + 1, UINT256_MAX), receiverSpoke);
  }

  function test_eliminateDeficit_fuzz_revertsWith_SenderSpokeNotActive(address caller) public {
    vm.assume(!hub1.getSpoke(assetId, caller).active);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(caller);
    hub1.eliminateDeficit(assetId, vm.randomUint(), receiverSpoke);
  }

  function test_eliminateDeficit(uint256) public {
    _createDeficit(assetId, receiverSpoke, deficitAmount);
    _createDeficit(assetId, otherSpoke, deficitAmount / 2);

    uint256 clearedDeficit = vm.randomUint(1, deficitAmount);

    Utils.add(hub1, assetId, senderSpoke, clearedDeficit + 1, alice);
    assertGe(hub1.getSpokeAddedAssets(assetId, senderSpoke), clearedDeficit);

    uint256 expectedRemoveShares = hub1.previewRemoveByAssets(assetId, clearedDeficit);
    uint256 spokeAddedShares = hub1.getSpokeAddedShares(assetId, senderSpoke);
    uint256 assetSuppliedShares = hub1.getAddedShares(assetId);
    uint256 addExRate = getAddExRate(assetId);

    vm.expectEmit(address(hub1));
    emit IHub.EliminateDeficit(
      assetId,
      senderSpoke,
      receiverSpoke,
      expectedRemoveShares,
      clearedDeficit
    );
    vm.prank(senderSpoke);
    uint256 removedShares = hub1.eliminateDeficit(assetId, clearedDeficit, receiverSpoke);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(hub1.getAssetDeficit(assetId), deficitAmount / 2 + deficitAmount - clearedDeficit);
    assertEq(hub1.getAddedShares(assetId), assetSuppliedShares - expectedRemoveShares);
    assertEq(
      hub1.getSpokeAddedShares(assetId, senderSpoke),
      spokeAddedShares - expectedRemoveShares
    );
    assertEq(hub1.getSpokeDeficit(assetId, receiverSpoke), deficitAmount - clearedDeficit);
    assertGe(getAddExRate(assetId), addExRate);
    assertBorrowRateSynced(hub1, assetId, 'eliminateDeficit');
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
