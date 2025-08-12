// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubSweepTest is HubBase {
  function test_sweep_revertsWith_InvalidReinvestmentStrategy_init() public {
    assertEq(hub1.getAsset(daiAssetId).reinvestmentStrategy, address(0));
    vm.expectRevert(IHub.InvalidReinvestmentStrategy.selector);
    hub1.sweep(daiAssetId, vm.randomUint());
  }

  function test_sweep_revertsWith_InvalidReinvestmentStrategy(address caller) public {
    address reinvestmentStrategy = makeAddr('reinvestmentStrategy');
    vm.assume(caller != reinvestmentStrategy);
    updateAssetReinvestmentStrategy(hub1, daiAssetId, reinvestmentStrategy);

    vm.expectRevert(IHub.InvalidReinvestmentStrategy.selector);
    vm.prank(caller);
    hub1.sweep(daiAssetId, vm.randomUint());
  }

  function test_sweep_revertsWith_InvalidSweepAmount() public {
    assertEq(hub1.getAsset(daiAssetId).swept, 0);
    address reinvestmentStrategy = makeAddr('reinvestmentStrategy');
    updateAssetReinvestmentStrategy(hub1, daiAssetId, reinvestmentStrategy);

    vm.prank(reinvestmentStrategy);
    vm.expectRevert(IHub.InvalidSweepAmount.selector);
    hub1.sweep(daiAssetId, 0);
  }

  function test_sweep() public {
    test_sweep_fuzz(1000e18, 1000e18);
  }

  function test_sweep_fuzz(uint256 supplyAmount, uint256 sweepAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    sweepAmount = bound(sweepAmount, 1, supplyAmount);

    address reinvestmentStrategy = makeAddr('reinvestmentStrategy');
    updateAssetReinvestmentStrategy(hub1, daiAssetId, reinvestmentStrategy);

    _addLiquidity(daiAssetId, supplyAmount);

    uint256 assetLiquidity = hub1.getLiquidity(daiAssetId);

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Transfer(address(hub1), reinvestmentStrategy, sweepAmount);

    vm.expectEmit(address(hub1));
    emit IHub.Sweep(daiAssetId, sweepAmount);

    vm.prank(reinvestmentStrategy);
    hub1.sweep(daiAssetId, sweepAmount);

    assertEq(hub1.getSwept(daiAssetId), sweepAmount);
    assertEq(hub1.getLiquidity(daiAssetId), assetLiquidity - sweepAmount);
    assertBorrowRateSynced(hub1, daiAssetId, 'sweep');
  }
}
