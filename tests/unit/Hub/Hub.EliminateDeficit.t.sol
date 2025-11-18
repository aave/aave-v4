// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubEliminateDeficitTest is HubBase {
  using WadRayMath for uint256;
  using MathUtils for uint256;

  uint256 assetId;
  uint256 deficitAmountRay;
  address callerSpoke;
  address coveredSpoke;
  address otherSpoke;

  function setUp() public override {
    super.setUp();
    assetId = usdxAssetId;
    deficitAmountRay = uint256(1000e6 * WadRayMath.RAY) / 3;
    callerSpoke = address(spoke2);
    coveredSpoke = address(spoke1);
    otherSpoke = address(spoke3);
  }

  function test_eliminateDeficit_revertsWith_InvalidAmount_ZeroAmountNoDeficit() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(callerSpoke);
    hub1.eliminateDeficit(assetId, 0, coveredSpoke);
  }

  function test_eliminateDeficit_revertsWith_InvalidAmount_ZeroAmountWithDeficit() public {
    _createDeficit(assetId, coveredSpoke, deficitAmountRay);
    assertEq(hub1.getSpokeDeficitRay(assetId, coveredSpoke), deficitAmountRay);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(callerSpoke);
    hub1.eliminateDeficit(assetId, 0, coveredSpoke);
  }

  // Caller spoke does not have funds
  function test_eliminateDeficit_fuzz_revertsWith_ArithmeticUnderflow_CallerSpokeNoFunds(
    uint256
  ) public {
    _createDeficit(assetId, coveredSpoke, deficitAmountRay);
    vm.expectRevert(stdError.arithmeticError);
    vm.prank(callerSpoke);
    hub1.eliminateDeficit(assetId, vm.randomUint(deficitAmountRay, UINT256_MAX), coveredSpoke);
  }

  function test_eliminateDeficit_fuzz_revertsWith_callerSpokeNotActive(address caller) public {
    vm.assume(!hub1.getSpoke(assetId, caller).active);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(caller);
    hub1.eliminateDeficit(assetId, vm.randomUint(), coveredSpoke);
  }

  /// @dev paused but active spokes are allowed to eliminate deficit
  function test_eliminateDeficit_allowSpokePaused() public {
    _createDeficit(assetId, coveredSpoke, deficitAmountRay);
    Utils.add(hub1, assetId, callerSpoke, deficitAmountRay.fromRayUp() + 1, alice);

    updateSpokeActive(hub1, assetId, callerSpoke, true);
    _updateSpokePaused(hub1, assetId, callerSpoke, true);

    vm.prank(callerSpoke);
    hub1.eliminateDeficit(assetId, deficitAmountRay.fromRayUp(), coveredSpoke);
  }

  function test_eliminateDeficit(uint256) public {
    uint256 deficitAmountRay2 = deficitAmountRay / 2;
    _createDeficit(assetId, coveredSpoke, deficitAmountRay);
    _createDeficit(assetId, otherSpoke, deficitAmountRay2);

    uint256 eliminateDeficitRay = vm.randomUint(1, type(uint256).max);
    uint256 clearedDeficitRay = eliminateDeficitRay.min(deficitAmountRay);
    uint256 clearedDeficit = clearedDeficitRay.fromRayUp();

    Utils.add(
      hub1,
      assetId,
      callerSpoke,
      hub1.previewAddByShares(assetId, hub1.previewRemoveByAssets(assetId, clearedDeficit)),
      alice
    );
    assertGe(hub1.getSpokeAddedAssets(assetId, callerSpoke), clearedDeficit);

    uint256 expectedRemoveShares = hub1.previewRemoveByAssets(assetId, clearedDeficit);
    uint256 spokeAddedShares = hub1.getSpokeAddedShares(assetId, callerSpoke);
    uint256 assetSuppliedShares = hub1.getAddedShares(assetId);
    uint256 addExRate = getAddExRate(assetId);

    vm.expectEmit(address(hub1));
    emit IHub.EliminateDeficit(
      assetId,
      callerSpoke,
      coveredSpoke,
      expectedRemoveShares,
      clearedDeficitRay
    );
    vm.prank(callerSpoke);
    uint256 removedShares = hub1.eliminateDeficit(assetId, eliminateDeficitRay, coveredSpoke);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(
      hub1.getAssetDeficitRay(assetId),
      deficitAmountRay2 + deficitAmountRay - clearedDeficitRay
    );
    assertEq(hub1.getAddedShares(assetId), assetSuppliedShares - expectedRemoveShares);
    assertEq(
      hub1.getSpokeAddedShares(assetId, callerSpoke),
      spokeAddedShares - expectedRemoveShares
    );
    assertEq(hub1.getSpokeDeficitRay(assetId, coveredSpoke), deficitAmountRay - clearedDeficitRay);
    assertGe(getAddExRate(assetId), addExRate);
    _assertBorrowRateSynced(hub1, assetId, 'eliminateDeficit');
  }

  function _createDeficit(uint256 assetId, address spoke, uint256 amountRay) internal {
    _mockInterestRateBps(100_00);
    uint256 amount = amountRay.fromRayUp();
    Utils.add(hub1, assetId, spoke, amount, alice);
    _drawLiquidity(assetId, amount, true, true, spoke);

    vm.prank(spoke);
    hub1.reportDeficit(assetId, 0, IHubBase.PremiumDelta(0, 0, 0, amountRay));
  }
}
