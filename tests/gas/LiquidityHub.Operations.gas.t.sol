// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Base} from 'tests/Base.t.sol';

contract LiquidityHubOperations_Gas_Tests is Base {
  function setUp() public override {
    deployFixtures();
    initEnvironment();
  }

  function test_supply() public {
    vm.prank(address(spoke1));
    hub.supply(usdxAssetId, 1000e6, 15_00, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'supply');
  }

  function test_withdraw() public {
    vm.startPrank(address(spoke1));
    hub.supply(usdxAssetId, 1000e6, 15_00, alice);

    hub.withdraw(usdxAssetId, 500e6, 18_12, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'withdraw: partial');

    skip(100);

    hub.withdraw(usdxAssetId, 500e6, 20_74, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'withdraw: full');
    vm.stopPrank();
  }

  function test_draw() public {
    vm.prank(address(spoke2));
    hub.supply(daiAssetId, 1000e18, 15_00, alice);

    vm.startPrank(address(spoke1));
    hub.supply(usdxAssetId, 1000e6, 18_80, alice);

    skip(100);

    hub.draw(daiAssetId, 500e18, 19_00, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'draw');
    vm.stopPrank();
  }

  function test_restore() public {
    vm.prank(address(spoke2));
    hub.supply(daiAssetId, 1000e18, 20_00, bob);

    vm.startPrank(address(spoke1));
    hub.supply(usdxAssetId, 1000e6, 15_00, alice);
    hub.draw(daiAssetId, 500e18, 15_00, alice);

    skip(1000);

    hub.restore(daiAssetId, 200e18, 21_09, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'restore: partial');

    skip(100);

    uint256 cumulativeDebtRemaining = hub.getSpokeCumulativeDebt(daiAssetId, address(spoke1));
    hub.restore(daiAssetId, cumulativeDebtRemaining, 21_90, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'restore: full');
    vm.stopPrank();
  }

  function test_accrueInterest() public {
    vm.startPrank(address(spoke2));
    hub.supply(daiAssetId, 1000e18, 20_09, bob);
    hub.draw(daiAssetId, 500e18, 20_09, bob);
    vm.stopPrank();

    vm.prank(address(spoke1));
    hub.draw(daiAssetId, 500e18, 15_00, alice);

    skip(100);

    vm.prank(address(spoke1));
    hub.accrueInterest(daiAssetId, 21_09);
    vm.snapshotGasLastCall('Hub.Operations', 'accrueInterest');
  }
}
