// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubSweepTest is HubBase {
  address public reinvestmentController = makeAddr('reinvestmentController');

  function test_sweep_revertsWith_AssetNotListed() public {
    uint256 assetId = _randomInvalidAssetId(hub1);
    vm.expectRevert(IHub.AssetNotListed.selector);
    hub1.sweep(assetId, vm.randomUint());
  }

  function test_sweep_revertsWith_OnlyReinvestmentController_init() public {
    assertEq(hub1.getAsset(daiAssetId).reinvestmentController, address(0));
    vm.expectRevert(IHub.OnlyReinvestmentController.selector);
    hub1.sweep(daiAssetId, vm.randomUint());
  }

  function test_sweep_revertsWith_OnlyReinvestmentController(address caller) public {
    vm.assume(caller != reinvestmentController);
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    vm.expectRevert(IHub.OnlyReinvestmentController.selector);
    vm.prank(caller);
    hub1.sweep(daiAssetId, vm.randomUint());
  }

  function test_sweep_revertsWith_InvalidAmount() public {
    assertEq(hub1.getAsset(daiAssetId).swept, 0);
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    vm.prank(reinvestmentController);
    vm.expectRevert(IHub.InvalidAmount.selector);
    hub1.sweep(daiAssetId, 0);
  }

  function test_sweep() public {
    test_sweep_fuzz(1000e18, 1000e18);
  }

  function test_sweep_fuzz(uint256 supplyAmount, uint256 sweepAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    sweepAmount = bound(sweepAmount, 1, supplyAmount);

    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    _addLiquidity(daiAssetId, supplyAmount);

    uint256 assetLiquidity = hub1.getLiquidity(daiAssetId);

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Transfer(address(hub1), reinvestmentController, sweepAmount);

    vm.expectEmit(address(hub1));
    emit IHub.Sweep(daiAssetId, reinvestmentController, sweepAmount);

    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, sweepAmount);

    assertEq(hub1.getSwept(daiAssetId), sweepAmount);
    assertEq(hub1.getLiquidity(daiAssetId), assetLiquidity - sweepAmount);
    assertBorrowRateSynced(hub1, daiAssetId, 'sweep');
  }

  ///@dev swept amount is not withdrawable
  function test_sweep_revertsWith_InsufficientLiquidity() public {
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    uint256 initialLiquidity = vm.randomUint(2, MAX_SUPPLY_AMOUNT);
    uint256 swept = vm.randomUint(1, initialLiquidity);

    vm.prank(address(spoke1));
    hub1.add(daiAssetId, initialLiquidity, alice);

    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, swept);

    vm.expectRevert(
      abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, initialLiquidity - swept)
    );
    vm.prank(address(spoke1));
    hub1.remove(daiAssetId, swept + 1, alice);
  }

  function test_sweep_does_not_impact_utilization(uint256 supplyAmount, uint256 drawAmount) public {
    supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, supplyAmount - 1);
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    _addLiquidity(daiAssetId, supplyAmount);
    _drawLiquidity(daiAssetId, drawAmount, false, false);
    uint256 swept = vm.randomUint(1, supplyAmount - drawAmount);

    uint256 drawnRate = hub1.getAssetDrawnRate(daiAssetId);

    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, swept);

    assertEq(hub1.getAssetDrawnRate(daiAssetId), drawnRate, 'drawnRate');
    assertBorrowRateSynced(hub1, daiAssetId, 'swept');
    (uint256 drawn, ) = hub1.getAssetOwed(daiAssetId);
    assertEq(
      IBasicInterestRateStrategy(hub1.getAsset(daiAssetId).irStrategy).calculateInterestRate({
        assetId: daiAssetId,
        liquidity: supplyAmount - drawAmount - swept,
        drawn: drawn,
        deficit: vm.randomUint(), // ignored
        swept: swept
      }),
      drawnRate
    );
    assertEq(hub1.getLiquidity(daiAssetId), supplyAmount - drawAmount - swept);
    assertEq(hub1.getSwept(daiAssetId), swept);
  }
}
