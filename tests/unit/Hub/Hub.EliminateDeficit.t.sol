// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubEliminateDeficitTest is HubBase {
  using WadRayMath for uint256;
  using MathUtils for uint256;

  uint256 internal _assetId;
  uint256 internal _deficitAmountRay;
  address internal _callerSpoke;
  address internal _coveredSpoke;
  address internal _otherSpoke;

  function setUp() public override {
    super.setUp();
    _assetId = usdxAssetId;
    _deficitAmountRay = uint256(1000e6 * WadRayMath.RAY) / 3;
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
    _createDeficit(_assetId, _coveredSpoke, _deficitAmountRay);
    assertEq(hub1.getSpokeDeficitRay(_assetId, _coveredSpoke), _deficitAmountRay);
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(_callerSpoke);
    hub1.eliminateDeficit(_assetId, 0, _coveredSpoke);
  }

  // Caller spoke does not have funds
  function test_eliminateDeficit_fuzz_revertsWith_ArithmeticUnderflow_CallerSpokeNoFunds(
    uint256
  ) public {
    _createDeficit(_assetId, _coveredSpoke, _deficitAmountRay);
    vm.expectRevert(stdError.arithmeticError);
    vm.prank(_callerSpoke);
    hub1.eliminateDeficit(_assetId, vm.randomUint(_deficitAmountRay, UINT256_MAX), _coveredSpoke);
  }

  function test_eliminateDeficit_fuzz_revertsWith_callerSpokeNotActive(address caller) public {
    vm.assume(!hub1.getSpoke(_assetId, caller).active);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(caller);
    hub1.eliminateDeficit(_assetId, vm.randomUint(), _coveredSpoke);
  }

  /// @dev paused but active spokes are allowed to eliminate deficit
  function test_eliminateDeficit_allowSpokePaused() public {
    _createDeficit(_assetId, _coveredSpoke, _deficitAmountRay);
    Utils.add(hub1, _assetId, _callerSpoke, _deficitAmountRay.fromRayUp() + 1, alice);

    updateSpokeActive(hub1, _assetId, _callerSpoke, true);
    _updateSpokePaused(hub1, _assetId, _callerSpoke, true);

    vm.prank(_callerSpoke);
    hub1.eliminateDeficit(_assetId, _deficitAmountRay.fromRayUp(), _coveredSpoke);
  }

  function test_eliminateDeficit(uint256) public {
    uint256 deficitAmountRay2 = _deficitAmountRay / 2;
    _createDeficit(_assetId, _coveredSpoke, _deficitAmountRay);
    _createDeficit(_assetId, _otherSpoke, deficitAmountRay2);

    uint256 eliminateDeficitRay = vm.randomUint(1, type(uint256).max);
    uint256 clearedDeficitRay = eliminateDeficitRay.min(_deficitAmountRay);
    uint256 clearedDeficit = clearedDeficitRay.fromRayUp();

    Utils.add(
      hub1,
      _assetId,
      _callerSpoke,
      hub1.previewAddByShares(_assetId, hub1.previewRemoveByAssets(_assetId, clearedDeficit)),
      alice
    );
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
      clearedDeficitRay
    );
    vm.prank(_callerSpoke);
    uint256 removedShares = hub1.eliminateDeficit(_assetId, eliminateDeficitRay, _coveredSpoke);

    assertEq(removedShares, expectedRemoveShares);
    assertEq(
      hub1.getAssetDeficitRay(_assetId),
      deficitAmountRay2 + _deficitAmountRay - clearedDeficitRay
    );
    assertEq(hub1.getAddedShares(_assetId), assetSuppliedShares - expectedRemoveShares);
    assertEq(
      hub1.getSpokeAddedShares(_assetId, _callerSpoke),
      spokeAddedShares - expectedRemoveShares
    );
    assertEq(
      hub1.getSpokeDeficitRay(_assetId, _coveredSpoke),
      _deficitAmountRay - clearedDeficitRay
    );
    assertGe(getAddExRate(_assetId), addExRate);
    _assertBorrowRateSynced(hub1, _assetId, 'eliminateDeficit');
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
