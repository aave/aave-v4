// SPDX-License-Identifier: MIT
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
    vm.startPrank(alice);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, 1000e18);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].dai.reserveId, true);

    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 1, borrows: 0');
    vm.stopPrank();
  }

  function test_getUserAccountData_twoSupplies() external {
    vm.startPrank(alice);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, 1000e18);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].dai.reserveId, true);

    spoke1.supply(spokeInfo[spoke1].weth.reserveId, 1000e18);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].weth.reserveId, true);

    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 2, borrows: 0');
    vm.stopPrank();
  }

  function test_getUserAccountData_twoSupplies_oneBorrows() external {
    vm.prank(bob);
    spoke1.supply(spokeInfo[spoke1].usdx.reserveId, 1000e6);

    vm.startPrank(alice);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, 1000e18);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].dai.reserveId, true);

    spoke1.supply(spokeInfo[spoke1].weth.reserveId, 1000e18);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].weth.reserveId, true);

    spoke1.borrow(spokeInfo[spoke1].usdx.reserveId, 800e6, alice);

    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 2, borrows: 1');
    vm.stopPrank();
  }

  function test_getUserAccountData_twoSupplies_twoBorrows() external {
    vm.startPrank(bob);
    spoke1.supply(spokeInfo[spoke1].usdx.reserveId, 1000e6);
    spoke1.supply(spokeInfo[spoke1].wbtc.reserveId, 1000e8);
    vm.stopPrank();

    vm.startPrank(alice);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, 1000e18);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].dai.reserveId, true);

    spoke1.supply(spokeInfo[spoke1].weth.reserveId, 1000e18);
    spoke1.setUsingAsCollateral(spokeInfo[spoke1].weth.reserveId, true);

    spoke1.borrow(spokeInfo[spoke1].wbtc.reserveId, 300e8, alice);
    spoke1.borrow(spokeInfo[spoke1].usdx.reserveId, 800e6, alice);

    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 2, borrows: 2');
    vm.stopPrank();
  }
}
