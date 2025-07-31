// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Base} from 'tests/Base.t.sol';

/// forge-config: default.isolate = true
contract SpokeOperations_Gas_Tests is Base {
  function setUp() public override {
    deployFixtures();
    initEnvironment();

    vm.startPrank(address(spoke2));
    hub1.add(daiAssetId, 1000e18, bob);
    hub1.add(wethAssetId, 1000e18, bob);
    hub1.add(usdxAssetId, 1000e6, bob);
    hub1.add(wbtcAssetId, 1000e8, bob);
    vm.stopPrank();
  }

  function test_supply() public {
    vm.startPrank(alice);
    vm.startSnapshotGas('Spoke.Operations', 'supply + enable collateral');
    spoke1.supply(_daiReserveId(spoke1), 100e18, alice);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true, alice);
    vm.stopSnapshotGas();

    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: 0 borrows, collateral disabled');
    skip(100);

    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true, alice);
    spoke1.supply(_wethReserveId(spoke1), 1e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: 0 borrows, collateral enabled');
    skip(100);

    spoke1.supply(_wethReserveId(spoke1), 1e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: second action, same reserve');
    skip(100);

    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    spoke1.borrow(_daiReserveId(spoke1), 100e18, alice);
    skip(100);

    spoke1.supply(_wbtcReserveId(spoke1), 1e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'supply: 1 borrow');

    vm.stopPrank();
  }

  function test_usingAsCollateral() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, bob);

    vm.startPrank(alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'usingAsCollateral: 0 borrows, enable');

    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.borrow(_daiReserveId(spoke1), 100e18, alice);

    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'usingAsCollateral: 1 borrow, enable');

    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true, alice);

    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), false, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'usingAsCollateral: 1 borrow, disable');
    vm.stopPrank();
  }

  function test_withdraw() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, bob);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);

    spoke1.withdraw(_usdxReserveId(spoke1), 500e6, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'withdraw: 0 borrows, partial');

    skip(100);

    spoke1.withdraw(_usdxReserveId(spoke1), 500e6, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'withdraw: 0 borrows, full');

    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.borrow(_daiReserveId(spoke1), 10e18, alice);
    skip(100);

    spoke1.withdraw(_usdxReserveId(spoke1), 500e6, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'withdraw: 1 borrow, partial');
    vm.stopPrank();
  }

  function test_borrow() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, bob);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);

    spoke1.borrow(_daiReserveId(spoke1), 500e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'borrow');
    vm.stopPrank();
  }

  function test_restore() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, bob);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    spoke1.borrow(_daiReserveId(spoke1), 500e18, alice);

    skip(1000);

    spoke1.repay(_daiReserveId(spoke1), 200e18, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'repay: partial');

    skip(1000);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max, alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'repay: full');
    vm.stopPrank();
  }

  function test_liquidation() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, bob);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    vm.stopPrank();

    _borrowToBeBelowHf(spoke1, alice, _daiReserveId(spoke1), 0.9e18);

    skip(365 days);

    vm.startPrank(bob);
    spoke1.liquidationCall(_usdxReserveId(spoke1), _daiReserveId(spoke1), alice, 100e18);
    vm.snapshotGasLastCall('Spoke.Operations', 'liquidationCall: partial');

    spoke1.liquidationCall(_usdxReserveId(spoke1), _daiReserveId(spoke1), alice, type(uint256).max);
    vm.snapshotGasLastCall('Spoke.Operations', 'liquidationCall: full');
    vm.stopPrank();
  }

  function test_updateRiskPremium() public {
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), 1000e18, bob);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 2000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);

    spoke1.borrow(_daiReserveId(spoke1), 500e18, alice);

    spoke1.updateUserRiskPremium(alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'updateUserRiskPremium: 1 borrow');

    spoke1.borrow(_usdxReserveId(spoke1), 500e6, alice);

    spoke1.updateUserRiskPremium(alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'updateUserRiskPremium: 2 borrows');
    vm.stopPrank();
  }

  function test_updateUserDynamicConfig() public {
    vm.startPrank(alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    updateLiquidationFee(spoke1, _usdxReserveId(spoke1), 10_00);

    spoke1.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'updateUserDynamicConfig: 1 collateral');

    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true, alice);
    updateLiquidationFee(spoke1, _daiReserveId(spoke1), 15_00);

    spoke1.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall('Spoke.Operations', 'updateUserDynamicConfig: 2 collaterals');
    vm.stopPrank();
  }
}
