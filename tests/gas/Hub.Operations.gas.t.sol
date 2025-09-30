// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

/// forge-config: default.isolate = true
contract HubOperations_Gas_Tests is Base {
  using SafeCast for uint256;

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
    int256 premiumShares = hub1.previewDrawByAssets(daiAssetId, 500e18).toInt256();
    int256 premiumOffset = hub1
      .previewRestoreByShares(daiAssetId, uint256(premiumShares))
      .toInt256();
    hub1.refreshPremium(daiAssetId, IHubBase.PremiumDelta(premiumShares, premiumOffset, 0));

    skip(1000);

    (drawnRemaining, premiumRemaining) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    hub1.restore(daiAssetId, drawnRemaining / 2, 0, IHubBase.PremiumDelta(0, 0, 0), alice);
    vm.snapshotGasLastCall('Hub.Operations', 'restore: partial');

    skip(100);

    (drawnRemaining, premiumRemaining) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta(
      -premiumShares,
      -premiumOffset,
      0
    );
    hub1.restore(daiAssetId, drawnRemaining, premiumRemaining, premiumDelta, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'restore: full');
    vm.stopPrank();
  }

  function test_refreshPremium() public {
    int256 premiumShares = hub1.previewDrawByAssets(daiAssetId, 500e18).toInt256();
    int256 premiumOffset = hub1
      .previewRestoreByShares(daiAssetId, uint256(premiumShares))
      .toInt256();

    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, IHubBase.PremiumDelta(premiumShares, premiumOffset, 0));
    vm.snapshotGasLastCall('Hub.Operations', 'refreshPremium');
  }
}
