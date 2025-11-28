// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

/// forge-config: default.isolate = true
contract HubOperations_Gas_Tests is Base {
  using SafeCast for *;
  using WadRayMath for uint256;

  function setUp() public override {
    deployFixtures();
    initEnvironment();
  }

  function test_add() public {
    vm.startPrank(address(spoke1));
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(usdxAssetId, 1000e6);
    vm.snapshotGasLastCall('Hub.Operations', 'add');

    vm.startSnapshotGas('Hub.Operations', 'add: with transfer');
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(usdxAssetId, 1000e6);
    vm.stopSnapshotGas();
    vm.stopPrank();
  }

  function test_remove() public {
    vm.startPrank(address(spoke1));
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(usdxAssetId, 1000e6);
    hub1.remove(usdxAssetId, 500e6, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'remove: partial');
    skip(100);
    hub1.remove(usdxAssetId, 500e6, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'remove: full');
    vm.stopPrank();
  }

  function test_draw() public {
    vm.startPrank(address(spoke2));
    tokenList.dai.transferFrom(alice, address(hub1), 1000e18);
    hub1.add(daiAssetId, 1000e18);
    vm.stopPrank();

    vm.startPrank(address(spoke1));
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(usdxAssetId, 1000e6);

    skip(100);

    hub1.draw(daiAssetId, 500e18, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'draw');
    vm.stopPrank();
  }

  function test_restore() public {
    uint256 drawnRemaining;
    uint256 premiumRemaining;
    vm.startPrank(address(spoke2));
    tokenList.dai.transferFrom(alice, address(hub1), 1000e18);
    hub1.add(daiAssetId, 1000e18);
    vm.stopPrank();

    vm.startPrank(address(spoke1));
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(usdxAssetId, 1000e6);
    hub1.draw(daiAssetId, 500e18, alice);
    uint256 premiumShares = hub1.previewDrawByAssets(daiAssetId, 500e18);
    int256 premiumOffsetRay = _calculatePremiumAssetsRay(hub1, daiAssetId, premiumShares)
      .toInt256();
    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      hub: hub1,
      assetId: daiAssetId,
      oldPremiumShares: 0,
      oldPremiumOffsetRay: 0,
      drawnShares: premiumShares, // risk premium is 100%
      riskPremium: 100_00,
      restoredPremiumRay: _calculatePremiumDebtRay(
        hub1,
        daiAssetId,
        premiumShares,
        premiumOffsetRay
      )
    });
    hub1.refreshPremium(daiAssetId, premiumDelta);

    skip(1000);

    (drawnRemaining, premiumRemaining) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), drawnRemaining / 2);
    hub1.restore(daiAssetId, drawnRemaining / 2, ZERO_PREMIUM_DELTA);
    vm.snapshotGasLastCall('Hub.Operations', 'restore: partial');

    skip(100);

    (drawnRemaining, premiumRemaining) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), drawnRemaining + premiumRemaining);
    premiumDelta = _getExpectedPremiumDelta({
      hub: hub1,
      assetId: daiAssetId,
      oldPremiumShares: premiumShares,
      oldPremiumOffsetRay: premiumOffsetRay,
      drawnShares: 0,
      riskPremium: 0,
      restoredPremiumRay: _calculatePremiumDebtRay(
        hub1,
        daiAssetId,
        premiumShares,
        premiumOffsetRay
      )
    });
    hub1.restore(daiAssetId, drawnRemaining, premiumDelta);
    vm.snapshotGasLastCall('Hub.Operations', 'restore: full');
    vm.stopPrank();
  }

  function test_restore_with_transfer() public {
    uint256 drawnRemaining;
    uint256 premiumRemaining;
    vm.startPrank(address(spoke2));
    tokenList.dai.transferFrom(alice, address(hub1), 1000e18);
    hub1.add(daiAssetId, 1000e18);
    vm.stopPrank();

    vm.startPrank(address(spoke1));
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(usdxAssetId, 1000e6);
    hub1.draw(daiAssetId, 500e18, alice);
    uint256 premiumShares = hub1.previewDrawByAssets(daiAssetId, 500e18);
    int256 premiumOffsetRay = _calculatePremiumAssetsRay(hub1, daiAssetId, uint256(premiumShares))
      .toInt256();
    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      hub: hub1,
      assetId: daiAssetId,
      oldPremiumShares: 0,
      oldPremiumOffsetRay: 0,
      drawnShares: premiumShares,
      riskPremium: 100_00,
      restoredPremiumRay: _calculatePremiumDebtRay(
        hub1,
        daiAssetId,
        premiumShares,
        premiumOffsetRay
      )
    });
    hub1.refreshPremium(daiAssetId, premiumDelta);

    skip(1000);

    (drawnRemaining, premiumRemaining) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    vm.startSnapshotGas('Hub.Operations', 'restore: partial - with transfer');
    tokenList.dai.transferFrom(alice, address(hub1), drawnRemaining / 2);
    hub1.restore(daiAssetId, drawnRemaining / 2, ZERO_PREMIUM_DELTA);
    vm.stopSnapshotGas();

    skip(100);

    (drawnRemaining, premiumRemaining) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    premiumDelta = _getExpectedPremiumDelta({
      hub: hub1,
      assetId: daiAssetId,
      oldPremiumShares: premiumShares,
      oldPremiumOffsetRay: premiumOffsetRay,
      drawnShares: 0,
      riskPremium: 0,
      restoredPremiumRay: _calculatePremiumDebtRay(
        hub1,
        daiAssetId,
        premiumShares,
        premiumOffsetRay
      )
    });
    vm.startSnapshotGas('Hub.Operations', 'restore: full - with transfer');
    tokenList.dai.transferFrom(alice, address(hub1), drawnRemaining + premiumRemaining);
    hub1.restore(daiAssetId, drawnRemaining, premiumDelta);
    vm.stopSnapshotGas();
    vm.stopPrank();
  }

  function test_refreshPremium() public {
    uint256 premiumShares = hub1.previewDrawByAssets(daiAssetId, 500e18);
    int256 premiumOffsetRay = _calculatePremiumAssetsRay(hub1, daiAssetId, premiumShares)
      .toInt256();
    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      hub: hub1,
      assetId: daiAssetId,
      oldPremiumShares: 0,
      oldPremiumOffsetRay: 0,
      drawnShares: premiumShares,
      riskPremium: 100_00,
      restoredPremiumRay: _calculatePremiumDebtRay(
        hub1,
        daiAssetId,
        premiumShares,
        premiumOffsetRay
      )
    });

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 1000e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 500e18, alice);

    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);
    vm.snapshotGasLastCall('Hub.Operations', 'refreshPremium');
  }

  function test_mintFeeShares() public {
    vm.startPrank(address(spoke2));
    tokenList.dai.transferFrom(alice, address(hub1), 1000e18);
    hub1.add(daiAssetId, 1000e18);
    vm.stopPrank();

    vm.startPrank(address(spoke1));
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(usdxAssetId, 1000e6);
    hub1.draw(daiAssetId, 500e18, alice);
    vm.stopPrank();

    skip(100);

    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);
    vm.snapshotGasLastCall('Hub.Operations', 'mintFeeShares');
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

    (uint256 drawnDebt, ) = spoke1.getUserDebt(_daiReserveId(spoke1), alice);

    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta(
      spoke1,
      alice,
      _daiReserveId(spoke1),
      type(uint256).max
    );

    vm.prank(address(spoke1));
    hub1.reportDeficit(daiAssetId, drawnDebt, premiumDelta);
    vm.snapshotGasLastCall('Hub.Operations', 'reportDeficit');

    vm.prank(address(spoke1));
    hub1.eliminateDeficit(daiAssetId, 100e18, address(spoke1));
    vm.snapshotGasLastCall('Hub.Operations', 'eliminateDeficit: partial');

    uint256 deficitRay = hub1.getAssetDeficitRay(daiAssetId);

    vm.prank(address(spoke1));
    hub1.eliminateDeficit(daiAssetId, deficitRay.fromRayUp(), address(spoke1));
    vm.snapshotGasLastCall('Hub.Operations', 'eliminateDeficit: full');
  }
}
