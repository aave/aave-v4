// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Base} from 'tests/Base.t.sol';

contract SpokeGetters_Gas_Tests is Base {
  function setUp() public override {
    deployFixtures();
    initEnvironment();
  }

  function test_getUserAccountData() external {
    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 0, borrows: 0');
  }

  function test_getUserAccountData_oneSupplies() external {
    vm.prank(alice);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, 1000e18);

    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 1, borrows: 0');
  }

  function test_getUserAccountData_twoSupplies() external {
    vm.startPrank(alice);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, 1000e18);
    spoke1.supply(spokeInfo[spoke1].weth.reserveId, 1000e18);

    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 2, borrows: 0');
  }

  function test_getUserAccountData_twoSupplies_onBorrows() external {
    vm.startPrank(alice);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, 1000e18);
    spoke1.supply(spokeInfo[spoke1].weth.reserveId, 1000e18);
    spoke1.borrow(spokeInfo[spoke1].dai.reserveId, 800e18, alice);

    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 2, borrows: 1');
  }
}
