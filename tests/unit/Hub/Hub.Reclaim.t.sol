// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubReclaimTest is HubBase {
  function test_reclaim_revertsWith_AssetNotListed() public {
    uint256 assetId = _randomInvalidAssetId(hub1);
    vm.expectRevert(IHub.AssetNotListed.selector);
    hub1.reclaim(assetId, vm.randomUint());
  }

  function test_reclaim_revertsWith_OnlyReinvestmentController_init() public {
    assertEq(hub1.getAsset(daiAssetId).reinvestmentController, address(0));
    vm.expectRevert(IHub.OnlyReinvestmentController.selector);
    hub1.reclaim(daiAssetId, vm.randomUint());
  }

  function test_reclaim_revertsWith_OnlyReinvestmentController(address caller) public {
    address reinvestmentController = makeAddr('reinvestmentController');
    vm.assume(caller != reinvestmentController);
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    vm.expectRevert(IHub.OnlyReinvestmentController.selector);
    vm.prank(caller);
    hub1.reclaim(daiAssetId, vm.randomUint());
  }

  function test_reclaim_revertsWith_InvalidAmount_zero() public {
    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    vm.prank(reinvestmentController);
    vm.expectRevert(IHub.InvalidAmount.selector);
    hub1.reclaim(daiAssetId, 0);
  }

  function test_reclaim_revertsWith_InvalidAmount_exceedsSwept() public {
    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    assertEq(hub1.getSwept(daiAssetId), 0);

    vm.prank(reinvestmentController);
    vm.expectRevert(IHub.InvalidAmount.selector);
    hub1.reclaim(daiAssetId, 1);
  }

  function test_reclaim_revertsWith_InvalidAmount_exceedsSwept_afterSweep() public {
    uint256 supplyAmount = 1000e18;
    uint256 sweepAmount = 500e18;

    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    _addLiquidity(daiAssetId, supplyAmount);

    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, sweepAmount);

    assertEq(hub1.getSwept(daiAssetId), sweepAmount);

    vm.prank(reinvestmentController);
    vm.expectRevert(IHub.InvalidAmount.selector);
    hub1.reclaim(daiAssetId, sweepAmount + 1);
  }

  function test_reclaim() public {
    test_reclaim_fuzz(1000e18, 500e18, 200e18);
  }

  function test_reclaim_fuzz(
    uint256 supplyAmount,
    uint256 sweepAmount,
    uint256 reclaimAmount
  ) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    sweepAmount = bound(sweepAmount, 1, supplyAmount);
    reclaimAmount = bound(reclaimAmount, 1, sweepAmount);

    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    _addLiquidity(daiAssetId, supplyAmount);

    uint256 liquidityBeforeSweep = hub1.getLiquidity(daiAssetId);

    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, sweepAmount);

    uint256 liquidityAfterSweep = hub1.getLiquidity(daiAssetId);
    uint256 sweptAfterSweep = hub1.getSwept(daiAssetId);

    assertEq(liquidityAfterSweep, liquidityBeforeSweep - sweepAmount);
    assertEq(sweptAfterSweep, sweepAmount);

    deal(address(tokenList.dai), reinvestmentController, reclaimAmount);
    vm.prank(reinvestmentController);
    tokenList.dai.approve(address(hub1), reclaimAmount);

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Transfer(reinvestmentController, address(hub1), reclaimAmount);

    vm.expectEmit(address(hub1));
    emit IHub.Reclaim(daiAssetId, reinvestmentController, reclaimAmount);

    vm.prank(reinvestmentController);
    hub1.reclaim(daiAssetId, reclaimAmount);

    assertEq(hub1.getSwept(daiAssetId), sweptAfterSweep - reclaimAmount);
    assertEq(hub1.getLiquidity(daiAssetId), liquidityAfterSweep + reclaimAmount);
    assertBorrowRateSynced(hub1, daiAssetId, 'reclaim');
  }

  function test_reclaim_fullAmount() public {
    uint256 supplyAmount = 1000e18;
    uint256 sweepAmount = 500e18;

    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    _addLiquidity(daiAssetId, supplyAmount);

    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, sweepAmount);

    uint256 liquidityAfterSweep = hub1.getLiquidity(daiAssetId);

    deal(address(tokenList.dai), reinvestmentController, sweepAmount);
    vm.prank(reinvestmentController);
    tokenList.dai.approve(address(hub1), sweepAmount);

    vm.prank(reinvestmentController);
    hub1.reclaim(daiAssetId, sweepAmount);

    assertEq(hub1.getSwept(daiAssetId), 0);
    assertEq(hub1.getLiquidity(daiAssetId), liquidityAfterSweep + sweepAmount);
  }

  function test_reclaim_multipleSweepsAndReclaims() public {
    uint256 supplyAmount = 1000e18;

    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    _addLiquidity(daiAssetId, supplyAmount);

    uint256 initialLiquidity = hub1.getLiquidity(daiAssetId);

    uint256 firstSweep = 200e18;
    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, firstSweep);

    uint256 secondSweep = 300e18;
    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, secondSweep);

    uint256 totalSwept = firstSweep + secondSweep;
    assertEq(hub1.getSwept(daiAssetId), totalSwept);
    assertEq(hub1.getLiquidity(daiAssetId), initialLiquidity - totalSwept);

    // First reclaim
    uint256 firstReclaim = 100e18;
    deal(address(tokenList.dai), reinvestmentController, firstReclaim);
    vm.prank(reinvestmentController);
    tokenList.dai.approve(address(hub1), firstReclaim);

    vm.prank(reinvestmentController);
    hub1.reclaim(daiAssetId, firstReclaim);

    assertEq(hub1.getSwept(daiAssetId), totalSwept - firstReclaim);
    assertEq(hub1.getLiquidity(daiAssetId), initialLiquidity - totalSwept + firstReclaim);

    // Second reclaim
    uint256 secondReclaim = 150e18;
    deal(address(tokenList.dai), reinvestmentController, secondReclaim);
    vm.prank(reinvestmentController);
    tokenList.dai.approve(address(hub1), secondReclaim);

    vm.prank(reinvestmentController);
    hub1.reclaim(daiAssetId, secondReclaim);

    assertEq(hub1.getSwept(daiAssetId), totalSwept - firstReclaim - secondReclaim);
    assertEq(
      hub1.getLiquidity(daiAssetId),
      initialLiquidity - totalSwept + firstReclaim + secondReclaim
    );
  }
}
