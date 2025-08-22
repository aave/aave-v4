// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

/// forge-config: default.isolate = true
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
    spoke1.supply(_daiReserveId(spoke1), 1000e18, alice);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true, alice);

    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 1, borrows: 0');
    vm.stopPrank();
  }

  function test_getUserAccountData_twoSupplies() external {
    vm.startPrank(alice);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, alice);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true, alice);

    spoke1.supply(_wethReserveId(spoke1), 1000e18, alice);
    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true, alice);

    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 2, borrows: 0');
    vm.stopPrank();
  }

  function test_getUserAccountData_twoSupplies_oneBorrows() external {
    vm.prank(bob);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, bob);

    vm.startPrank(alice);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, alice);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true, alice);

    spoke1.supply(_wethReserveId(spoke1), 1000e18, alice);
    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true, alice);

    spoke1.borrow(_usdxReserveId(spoke1), 800e6, alice);

    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 2, borrows: 1');
    vm.stopPrank();
  }

  function test_getUserAccountData_twoSupplies_twoBorrows() external {
    vm.startPrank(bob);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, bob);
    spoke1.supply(_wbtcReserveId(spoke1), 1000e8, bob);
    vm.stopPrank();

    vm.startPrank(alice);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, alice);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true, alice);

    spoke1.supply(_wethReserveId(spoke1), 1000e18, alice);
    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true, alice);

    spoke1.borrow(_wbtcReserveId(spoke1), 3e8, alice);
    spoke1.borrow(_usdxReserveId(spoke1), 800e6, alice);

    spoke1.getUserAccountData(alice);
    vm.snapshotGasLastCall('Spoke.Getters', 'getUserAccountData: supplies: 2, borrows: 2');
    vm.stopPrank();
  }
}
