// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Base} from 'tests/Base.t.sol';

contract SpokeOperations_Gas_Tests is Base {
  function setUp() public override {
    deployFixtures();
    initEnvironment();

    vm.startPrank(address(spoke2));
    hub.supply(daiAssetId, 1000e18, 20_09, bob);
    hub.supply(wethAssetId, 1000e18, 0, bob);
    hub.supply(usdxAssetId, 1000e6, 8_50, bob);
    hub.supply(wbtcAssetId, 1000e8, 37_05, bob);
    vm.stopPrank();
  }

  function test_supply() public {
    vm.startPrank(alice);

    spoke1.supply(spokeInfo[spoke1].usdx.reserveId, 500e6);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: 0 debt, collateralDisabled');
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].usdx.reserveId, true);

    spoke1.borrow(spokeInfo[spoke1].usdx.reserveId, 400e6, alice);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, 500e18);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: 1 debt');
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].dai.reserveId, true);

    spoke1.borrow(spokeInfo[spoke1].dai.reserveId, 400e18, alice);
    spoke1.supply(spokeInfo[spoke1].weth.reserveId, 500e18);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: 2 debt');
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].weth.reserveId, true);

    spoke1.borrow(spokeInfo[spoke1].weth.reserveId, 400e18, alice);
    spoke1.supply(spokeInfo[spoke1].wbtc.reserveId, 500e8);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: 3 debt');
    vm.stopPrank();
  }

  function test_usingAsCollateral() public {
    vm.startPrank(alice);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].usdx.reserveId, true);
    vm.snapshotGasLastCall('Spoke.Operations', 'usingAsCollateral');

    spoke1.supply(spokeInfo[spoke1].usdx.reserveId, 500e6);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: 0 debt, collateralEnabled');
    vm.stopPrank();
  }

  function test_withdraw() public {
    vm.startPrank(alice);
    spoke1.supply(spokeInfo[spoke1].usdx.reserveId, 1000e6);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].usdx.reserveId, true);

    spoke1.withdraw(spokeInfo[spoke1].usdx.reserveId, 500e6, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'withdraw: partial');

    skip(100);

    spoke1.withdraw(spokeInfo[spoke1].usdx.reserveId, 500e6, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'withdraw: full');
    vm.stopPrank();
  }

  function test_borrow() public {
    vm.prank(bob);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, 1000e18);

    vm.startPrank(alice);
    spoke1.supply(spokeInfo[spoke1].usdx.reserveId, 1000e6);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].usdx.reserveId, true);

    spoke1.borrow(spokeInfo[spoke1].dai.reserveId, 500e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'borrow');
    vm.stopPrank();
  }

  function test_restore() public {
    vm.prank(bob);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, 1000e18);

    vm.startPrank(alice);
    spoke1.supply(spokeInfo[spoke1].usdx.reserveId, 1000e6);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].usdx.reserveId, true);
    spoke1.borrow(spokeInfo[spoke1].dai.reserveId, 500e18, alice);

    skip(1000);

    spoke1.repay(spokeInfo[spoke1].dai.reserveId, 200e18);
    vm.snapshotGasLastCall('Spoke.Operations', 'repay: partial');

    skip(1000);
    uint256 cumulativeDebtRemaining = spoke1.getUserCumulativeDebt(
      spokeInfo[spoke1].dai.reserveId,
      alice
    );
    spoke1.repay(spokeInfo[spoke1].dai.reserveId, cumulativeDebtRemaining);
    vm.snapshotGasLastCall('Spoke.Operations', 'repay: full');
    vm.stopPrank();
  }
}
