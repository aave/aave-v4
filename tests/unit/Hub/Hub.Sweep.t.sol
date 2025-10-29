// // SPDX-License-Identifier: UNLICENSED
// // Copyright (c) 2025 Aave Labs
// pragma solidity ^0.8.0;

// import 'tests/unit/Hub/HubBase.t.sol';

// contract HubSweepTest is HubBase {
//   address public reinvestmentController = makeAddr('reinvestmentController');

//   function test_sweep_revertsWith_AssetNotListed() public {
//     address underlying = _randomInvalidUnderlying(hub1);
//     vm.expectRevert(IHub.AssetNotListed.selector);
//     hub1.sweep(underlying, vm.randomUint());
//   }

//   function test_sweep_revertsWith_OnlyReinvestmentController_init() public {
//     assertEq(hub1.getAsset(address(tokenList.dai)).reinvestmentController, address(0));
//     vm.expectRevert(IHub.OnlyReinvestmentController.selector);
//     hub1.sweep(address(tokenList.dai), vm.randomUint());
//   }

//   function test_sweep_revertsWith_OnlyReinvestmentController(address caller) public {
//     vm.assume(caller != reinvestmentController);
//     updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

//     vm.expectRevert(IHub.OnlyReinvestmentController.selector);
//     vm.prank(caller);
//     hub1.sweep(address(tokenList.dai), vm.randomUint());
//   }

//   function test_sweep_revertsWith_InvalidAmount() public {
//     assertEq(hub1.getAsset(address(tokenList.dai)).swept, 0);
//     updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

//     vm.prank(reinvestmentController);
//     vm.expectRevert(IHub.InvalidAmount.selector);
//     hub1.sweep(address(tokenList.dai), 0);
//   }

//   function test_sweep() public {
//     test_sweep_fuzz(1000e18, 1000e18);
//   }

//   function test_sweep_fuzz(uint256 supplyAmount, uint256 sweepAmount) public {
//     supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
//     sweepAmount = bound(sweepAmount, 1, supplyAmount);

//     updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

//     _addLiquidity(address(tokenList.dai), supplyAmount);

//     uint256 assetLiquidity = hub1.getAssetLiquidity(address(tokenList.dai));

//     vm.expectEmit(address(tokenList.dai));
//     emit IERC20.Transfer(address(hub1), reinvestmentController, sweepAmount);

//     vm.expectEmit(address(hub1));
//     emit IHub.Sweep(address(tokenList.dai), reinvestmentController, sweepAmount);

//     vm.prank(reinvestmentController);
//     hub1.sweep(address(tokenList.dai), sweepAmount);

//     assertEq(hub1.getAssetSwept(address(tokenList.dai)), sweepAmount);
//     assertEq(hub1.getAssetLiquidity(address(tokenList.dai)), assetLiquidity - sweepAmount);
//     assertBorrowRateSynced(hub1, address(tokenList.dai), 'sweep');
//     assertHubLiquidity(hub1, address(tokenList.dai), 'sweep');
//   }

//   ///@dev swept amount is not withdrawable
//   function test_sweep_revertsWith_InsufficientLiquidity() public {
//     updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

//     uint256 initialLiquidity = vm.randomUint(2, MAX_SUPPLY_AMOUNT);
//     uint256 swept = vm.randomUint(1, initialLiquidity);

//     vm.startPrank(address(spoke1));
//     tokenList.dai.transferFrom(bob, address(hub1), initialLiquidity);
//     hub1.add(address(tokenList.dai), initialLiquidity);
//     vm.stopPrank();

//     vm.prank(reinvestmentController);
//     hub1.sweep(address(tokenList.dai), swept);

//     vm.expectRevert(
//       abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, initialLiquidity - swept)
//     );
//     vm.prank(address(spoke1));
//     hub1.remove(address(tokenList.dai), swept + 1, alice);
//   }

//   function test_sweep_does_not_impact_utilization(uint256 supplyAmount, uint256 drawAmount) public {
//     supplyAmount = bound(supplyAmount, 2, MAX_SUPPLY_AMOUNT);
//     drawAmount = bound(drawAmount, 1, supplyAmount - 1);
//     updateAssetReinvestmentController(hub1, address(tokenList.dai), reinvestmentController);

//     _addLiquidity(address(tokenList.dai), supplyAmount);
//     _drawLiquidity(address(tokenList.dai), drawAmount, false, false);
//     uint256 swept = vm.randomUint(1, supplyAmount - drawAmount);

//     uint256 drawnRate = hub1.getAssetDrawnRate(address(tokenList.dai));

//     vm.prank(reinvestmentController);
//     hub1.sweep(address(tokenList.dai), swept);

//     assertEq(hub1.getAssetDrawnRate(address(tokenList.dai)), drawnRate, 'drawnRate');
//     assertBorrowRateSynced(hub1, address(tokenList.dai), 'swept');
//     assertHubLiquidity(hub1, address(tokenList.dai), 'sweep');
//     (uint256 drawn, ) = hub1.getAssetOwed(address(tokenList.dai));
//     assertEq(
//       IBasicInterestRateStrategy(hub1.getAsset(address(tokenList.dai)).irStrategy)
//         .calculateInterestRate({
//           underlying: address(tokenList.dai),
//           liquidity: supplyAmount - drawAmount - swept,
//           drawn: drawn,
//           deficit: vm.randomUint(), // ignored
//           swept: swept
//         }),
//       drawnRate
//     );
//     assertEq(hub1.getAssetLiquidity(address(tokenList.dai)), supplyAmount - drawAmount - swept);
//     assertEq(hub1.getAssetSwept(address(tokenList.dai)), swept);
//   }
// }
