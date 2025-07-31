// SPDX-License-Identifier: MIT
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
    hub.add(usdxAssetId, 1000e6, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'add');
  }

  function test_remove() public {
    vm.startPrank(address(spoke1));
    hub.add(usdxAssetId, 1000e6, alice);
    hub.remove(usdxAssetId, 500e6, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'remove: partial');
    skip(100);
    hub.remove(usdxAssetId, 500e6, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'remove: full');
    vm.stopPrank();
  }

  function test_draw() public {
    vm.prank(address(spoke2));
    hub.add(daiAssetId, 1000e18, alice);

    vm.startPrank(address(spoke1));
    hub.add(usdxAssetId, 1000e6, alice);

    skip(100);

    hub.draw(daiAssetId, 500e18, alice);
    // todo: do refresh call to fully encapsulate a `hub.restore` call
    vm.snapshotGasLastCall('Hub.Operations', 'draw');
    vm.stopPrank();
  }

  function test_restore() public {
    uint256 drawnRemaining;
    uint256 premiumRemaining;
    vm.prank(address(spoke2));
    hub.add(daiAssetId, 1000e18, bob);

    vm.startPrank(address(spoke1));
    hub.add(usdxAssetId, 1000e6, alice);
    hub.draw(daiAssetId, 500e18, alice);
    // todo: do refresh call to fully encapsulate a `hub.restore` call & add premium debt

    skip(1000);

    (drawnRemaining, premiumRemaining) = hub.getSpokeOwed(daiAssetId, address(spoke1));
    hub.restore(daiAssetId, drawnRemaining / 2, 0, DataTypes.PremiumDelta(0, 0, 0), alice);
    // todo: do refresh call to fully encapsulate a `hub.restore` call
    vm.snapshotGasLastCall('Hub.Operations', 'restore: partial');

    skip(100);

    (drawnRemaining, premiumRemaining) = hub.getSpokeOwed(daiAssetId, address(spoke1));
    hub.restore(daiAssetId, drawnRemaining, 0, DataTypes.PremiumDelta(0, 0, 0), alice);
    vm.snapshotGasLastCall('Hub.Operations', 'restore: full');
    vm.stopPrank();
  }

  // todo validate refresh since notify will now call `refreshRiskPremium`
  function test_accrueInterest() public {
    vm.skip(true, 'to be replaced with refreshRiskPremium');
    // vm.startPrank(address(spoke2));
    // hub.add(daiAssetId, 1000e18, bob);
    // hub.draw(daiAssetId, 500e18, bob);
    // vm.stopPrank();
    // vm.prank(address(spoke1));
    // hub.draw(daiAssetId, 500e18, alice);
    // skip(100);
    // vm.prank(address(spoke1));
    // hub.accrueInterest(daiAssetId);
    // vm.snapshotGasLastCall('Hub.Operations', 'accrueInterest');
  }
}
