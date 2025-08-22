// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

/// forge-config: default.isolate = true
contract HubOperations_Gas_Tests is Base {
  function setUp() public override {
    deployFixtures();
    initEnvironment();
  }

  function test_add() public {
    vm.prank(address(spoke1));
    hub1.add(usdxAssetId, 1000e6, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'add');
  }

  function test_remove() public {
    vm.startPrank(address(spoke1));
    hub1.add(usdxAssetId, 1000e6, alice);
    hub1.remove(usdxAssetId, 500e6, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'remove: partial');
    skip(100);
    hub1.remove(usdxAssetId, 500e6, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'remove: full');
    vm.stopPrank();
  }

  function test_draw() public {
    vm.prank(address(spoke2));
    hub1.add(daiAssetId, 1000e18, alice);

    vm.startPrank(address(spoke1));
    hub1.add(usdxAssetId, 1000e6, alice);

    skip(100);

    hub1.draw(daiAssetId, 500e18, alice);
    // todo: do refresh call to fully encapsulate a `hub1.restore` call
    vm.snapshotGasLastCall('Hub.Operations', 'draw');
    vm.stopPrank();
  }

  function test_restore() public {
    uint256 drawnRemaining;
    uint256 premiumRemaining;
    vm.prank(address(spoke2));
    hub1.add(daiAssetId, 1000e18, bob);

    vm.startPrank(address(spoke1));
    hub1.add(usdxAssetId, 1000e6, alice);
    hub1.draw(daiAssetId, 500e18, alice);
    // todo: do refresh call to fully encapsulate a `hub1.restore` call & add premium debt

    skip(1000);

    (drawnRemaining, premiumRemaining) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    hub1.restore(daiAssetId, drawnRemaining / 2, 0, DataTypes.PremiumDelta(0, 0, 0), alice);
    // todo: do refresh call to fully encapsulate a `hub1.restore` call
    vm.snapshotGasLastCall('Hub.Operations', 'restore: partial');

    skip(100);

    (drawnRemaining, premiumRemaining) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    hub1.restore(daiAssetId, drawnRemaining, 0, DataTypes.PremiumDelta(0, 0, 0), alice);
    vm.snapshotGasLastCall('Hub.Operations', 'restore: full');
    vm.stopPrank();
  }

  function test_refreshPremium() public {
    vm.startPrank(bob);
    spoke2.supply(_daiReserveId(spoke2), 10000e18, bob);
    spoke2.setUsingAsCollateral(_daiReserveId(spoke2), true, bob);
    spoke2.borrow(_daiReserveId(spoke2), 500e18, bob);
    vm.stopPrank();

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    spoke1.borrow(_daiReserveId(spoke1), 500e18, alice);
    vm.stopPrank();

    skip(100);

    vm.prank(alice);
    spoke1.borrow(_daiReserveId(spoke1), 1e18, alice);

    skip(100);

    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, DataTypes.PremiumDelta(2, 1, -1));
    vm.snapshotGasLastCall('Hub.Operations', 'refreshPremium');
  }
}
