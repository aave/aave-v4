// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

/// forge-config: default.isolate = true
contract HubOperations_Gas_Tests is Base {
  using SafeCast for *;

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

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 1000e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 500e18, alice);

    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, IHubBase.PremiumDelta(premiumShares, premiumOffset, 1));
    vm.snapshotGasLastCall('Hub.Operations', 'refreshPremium');
  }

  function test_payFee_transferShares() public {
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 1000e18,
      user: alice
    });

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    spoke1.borrow(_daiReserveId(spoke1), 500e18, alice);
    vm.stopPrank();

    skip(100);

    vm.prank(address(spoke1));
    hub1.payFeeShares(daiAssetId, 100e18);
    vm.snapshotGasLastCall('Hub.Operations', 'payFee');

    skip(100);

    vm.prank(address(spoke1));
    hub1.transferShares(daiAssetId, 100e18, address(spoke2));
    vm.snapshotGasLastCall('Hub.Operations', 'transferShares');
  }

  function test_deficit() public {
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 1000e18,
      user: alice
    });

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 1000e6, alice);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true, alice);
    spoke1.borrow(_daiReserveId(spoke1), 500e18, alice);
    vm.stopPrank();

    skip(100);

    ISpoke.UserPosition memory userPosition = spoke1.getUserPosition(_daiReserveId(spoke1), alice);
    (uint256 drawnDebt, uint256 premiumDebt) = spoke1.getUserDebt(_daiReserveId(spoke1), alice);

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: -userPosition.premiumShares.toInt256(),
      offsetDelta: -userPosition.premiumOffset.toInt256(),
      realizedDelta: 0
    });

    vm.prank(address(spoke1));
    hub1.reportDeficit(daiAssetId, drawnDebt, premiumDebt, premiumDelta);
    vm.snapshotGasLastCall('Hub.Operations', 'reportDeficit');

    vm.prank(address(spoke1));
    hub1.eliminateDeficit(daiAssetId, 100e18, address(spoke1));
    vm.snapshotGasLastCall('Hub.Operations', 'eliminateDeficit: partial');

    uint256 deficit = hub1.getAssetDeficit(daiAssetId);

    vm.prank(address(spoke1));
    hub1.eliminateDeficit(daiAssetId, deficit, address(spoke1));
    vm.snapshotGasLastCall('Hub.Operations', 'eliminateDeficit: full');
  }
}
