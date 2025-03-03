// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Base} from 'tests/Base.t.sol';

contract SpokeOperations_Gas_Tests is Base {
  function setUp() public override {
    deployFixtures();
    initEnvironment();
  }

  function test_supply() public {
    vm.prank(alice);
    spoke1.supply(spokeInfo[spoke1].usdx.reserveId, 1000e6);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply');

    vm.prank(alice);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].usdx.reserveId, true);
    vm.snapshotGasLastCall('Spoke.Operations', 'usingAsCollateral');
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
  }

  function test_borrow() public {
    vm.prank(bob);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, 1000e18);

    vm.startPrank(alice);
    spoke1.supply(spokeInfo[spoke1].usdx.reserveId, 1000e6);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].usdx.reserveId, true);

    spoke1.borrow(spokeInfo[spoke1].dai.reserveId, 500e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'borrow');
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
  }
}
