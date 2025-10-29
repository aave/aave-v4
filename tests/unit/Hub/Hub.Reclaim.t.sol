// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubReclaimTest is HubBase {
  function test_reclaim_revertsWith_AssetNotListed() public {
    address asset = _randomInvalidAsset(hub1);
    vm.expectRevert(IHub.AssetNotListed.selector);
    hub1.reclaim(asset, vm.randomUint());
  }

  function test_reclaim_revertsWith_OnlyReinvestmentController_init() public {
    assertEq(hub1.getAsset(address(tokenList.dai)).reinvestmentController, address(0));
    vm.expectRevert(IHub.OnlyReinvestmentController.selector);
    hub1.reclaim(address(tokenList.dai), vm.randomUint());
  }

  function test_reclaim_revertsWith_OnlyReinvestmentController(address caller) public {
    address reinvestmentController = makeAddr('reinvestmentController');
    vm.assume(caller != reinvestmentController);
    updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

    vm.expectRevert(IHub.OnlyReinvestmentController.selector);
    vm.prank(caller);
    hub1.reclaim(address(tokenList.dai), vm.randomUint());
  }

  function test_reclaim_revertsWith_InvalidAmount_zero() public {
    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

    vm.prank(reinvestmentController);
    vm.expectRevert(IHub.InvalidAmount.selector);
    hub1.reclaim(address(tokenList.dai), 0);
  }

  function test_reclaim_revertsWith_underflow_exceedsSwept() public {
    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

    assertEq(hub1.getAssetSwept(address(tokenList.dai)), 0);

    vm.prank(reinvestmentController);
    vm.expectRevert(stdError.arithmeticError);
    hub1.reclaim(address(tokenList.dai), 1);
  }

  function test_reclaim_revertsWith_underflow_exceedsSwept_afterSweep() public {
    uint256 supplyAmount = 1000e18;
    uint256 sweepAmount = 500e18;

    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

    _addLiquidity(address(tokenList.dai), supplyAmount);

    vm.prank(reinvestmentController);
    hub1.sweep(address(tokenList.dai), sweepAmount);

    assertEq(hub1.getAssetSwept(address(tokenList.dai)), sweepAmount);

    vm.prank(reinvestmentController);
    vm.expectRevert(stdError.arithmeticError);
    hub1.reclaim(address(tokenList.dai), sweepAmount + 1);
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
    updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

    _addLiquidity(address(tokenList.dai), supplyAmount);

    uint256 liquidityBeforeSweep = hub1.getAssetLiquidity(address(tokenList.dai));

    vm.prank(reinvestmentController);
    hub1.sweep(address(tokenList.dai), sweepAmount);

    uint256 liquidityAfterSweep = hub1.getAssetLiquidity(address(tokenList.dai));
    uint256 sweptAfterSweep = hub1.getAssetSwept(address(tokenList.dai));

    assertEq(liquidityAfterSweep, liquidityBeforeSweep - sweepAmount);
    assertEq(sweptAfterSweep, sweepAmount);

    deal(address(tokenList.dai), reinvestmentController, reclaimAmount);
    vm.prank(reinvestmentController);
    tokenList.dai.approve(address(hub1), reclaimAmount);

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Transfer(reinvestmentController, address(hub1), reclaimAmount);

    vm.expectEmit(address(hub1));
    emit IHub.Reclaim(address(tokenList.dai), reinvestmentController, reclaimAmount);

    vm.prank(reinvestmentController);
    hub1.reclaim(address(tokenList.dai), reclaimAmount);

    assertEq(hub1.getAssetSwept(address(tokenList.dai)), sweptAfterSweep - reclaimAmount);
    assertEq(hub1.getAssetLiquidity(address(tokenList.dai)), liquidityAfterSweep + reclaimAmount);
    assertBorrowRateSynced(hub1, address(tokenList.dai), 'reclaim');
    assertHubLiquidity(hub1, address(tokenList.dai), 'reclaim');
  }

  function test_reclaim_fullAmount() public {
    uint256 supplyAmount = 1000e18;
    uint256 sweepAmount = 500e18;

    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

    _addLiquidity(address(tokenList.dai), supplyAmount);

    vm.prank(reinvestmentController);
    hub1.sweep(address(tokenList.dai), sweepAmount);

    uint256 liquidityAfterSweep = hub1.getAssetLiquidity(address(tokenList.dai));

    deal(address(tokenList.dai), reinvestmentController, sweepAmount);
    vm.prank(reinvestmentController);
    tokenList.dai.approve(address(hub1), sweepAmount);

    vm.prank(reinvestmentController);
    hub1.reclaim(address(tokenList.dai), sweepAmount);

    assertEq(hub1.getAssetSwept(address(tokenList.dai)), 0);
    assertEq(hub1.getAssetLiquidity(address(tokenList.dai)), liquidityAfterSweep + sweepAmount);
    assertHubLiquidity(hub1, address(tokenList.dai), 'reclaim');
  }

  function test_reclaim_multipleSweepsAndReclaims() public {
    uint256 supplyAmount = 1000e18;

    address reinvestmentController = makeAddr('reinvestmentController');
    updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

    _addLiquidity(address(tokenList.dai), supplyAmount);

    uint256 initialLiquidity = hub1.getAssetLiquidity(address(tokenList.dai));

    uint256 firstSweep = 200e18;
    vm.prank(reinvestmentController);
    hub1.sweep(address(tokenList.dai), firstSweep);

    uint256 secondSweep = 300e18;
    vm.prank(reinvestmentController);
    hub1.sweep(address(tokenList.dai), secondSweep);

    uint256 totalSwept = firstSweep + secondSweep;
    assertEq(hub1.getAssetSwept(address(tokenList.dai)), totalSwept);
    assertEq(hub1.getAssetLiquidity(address(tokenList.dai)), initialLiquidity - totalSwept);

    // First reclaim
    uint256 firstReclaim = 100e18;
    deal(address(tokenList.dai), reinvestmentController, firstReclaim);
    vm.prank(reinvestmentController);
    tokenList.dai.approve(address(hub1), firstReclaim);

    vm.prank(reinvestmentController);
    hub1.reclaim(address(tokenList.dai), firstReclaim);

    assertEq(hub1.getAssetSwept(address(tokenList.dai)), totalSwept - firstReclaim);
    assertEq(hub1.getAssetLiquidity(address(tokenList.dai)), initialLiquidity - totalSwept + firstReclaim);

    // Second reclaim
    uint256 secondReclaim = 150e18;
    deal(address(tokenList.dai), reinvestmentController, secondReclaim);
    vm.prank(reinvestmentController);
    tokenList.dai.approve(address(hub1), secondReclaim);

    vm.prank(reinvestmentController);
    hub1.reclaim(address(tokenList.dai), secondReclaim);

    assertEq(hub1.getAssetSwept(address(tokenList.dai)), totalSwept - firstReclaim - secondReclaim);
    assertEq(
      hub1.getAssetLiquidity(address(tokenList.dai)),
      initialLiquidity - totalSwept + firstReclaim + secondReclaim
    );

    assertHubLiquidity(hub1, address(tokenList.dai), 'reclaim');
  }
}
