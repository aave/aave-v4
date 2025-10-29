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
    vm.startPrank(address(spoke1));
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(address(tokenList.usdx), 1000e6);
    vm.snapshotGasLastCall('Hub.Operations', 'add');
    vm.stopPrank();
  }

  function test_remove() public {
    vm.startPrank(address(spoke1));
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(address(tokenList.usdx), 1000e6);
    hub1.remove(address(tokenList.usdx), 500e6, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'remove: partial');
    skip(100);
    hub1.remove(address(tokenList.usdx), 500e6, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'remove: full');
    vm.stopPrank();
  }

  function test_draw() public {
    vm.startPrank(address(spoke2));
    tokenList.dai.transferFrom(alice, address(hub1), 1000e18);
    hub1.add(address(tokenList.dai), 1000e18);
    vm.stopPrank();

    vm.startPrank(address(spoke1));
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(address(tokenList.usdx), 1000e6);

    skip(100);

    hub1.draw(address(tokenList.dai), 500e18, alice);
    vm.snapshotGasLastCall('Hub.Operations', 'draw');
    vm.stopPrank();
  }

  function test_restore() public {
    uint256 drawnRemaining;
    uint256 premiumRemaining;
    vm.startPrank(address(spoke2));
    tokenList.dai.transferFrom(alice, address(hub1), 1000e18);
    hub1.add(address(tokenList.dai), 1000e18);
    vm.stopPrank();

    vm.startPrank(address(spoke1));
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(address(tokenList.usdx), 1000e6);
    hub1.draw(address(tokenList.dai), 500e18, alice);
    int256 premiumShares = hub1.previewDrawByAssets(address(tokenList.dai), 500e18).toInt256();
    int256 premiumOffset = hub1
      .previewRestoreByShares(address(tokenList.dai), uint256(premiumShares))
      .toInt256();
    hub1.refreshPremium(
      address(tokenList.dai),
      IHubBase.PremiumDelta(premiumShares, premiumOffset, 0)
    );

    skip(1000);

    (drawnRemaining, premiumRemaining) = hub1.getSpokeOwed(address(tokenList.dai), address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), drawnRemaining / 2);
    hub1.restore(address(tokenList.dai), drawnRemaining / 2, 0, IHubBase.PremiumDelta(0, 0, 0));
    vm.snapshotGasLastCall('Hub.Operations', 'restore: partial');

    skip(100);

    (drawnRemaining, premiumRemaining) = hub1.getSpokeOwed(address(tokenList.dai), address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), drawnRemaining + premiumRemaining);
    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta(
      -premiumShares,
      -premiumOffset,
      0
    );
    hub1.restore(address(tokenList.dai), drawnRemaining, premiumRemaining, premiumDelta);
    vm.snapshotGasLastCall('Hub.Operations', 'restore: full');
    vm.stopPrank();
  }

  function test_refreshPremium() public {
    int256 premiumShares = hub1.previewDrawByAssets(address(tokenList.dai), 500e18).toInt256();
    int256 premiumOffset = hub1
      .previewRestoreByShares(address(tokenList.dai), uint256(premiumShares))
      .toInt256();

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 1000e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 500e18, alice);

    vm.prank(address(spoke1));
    hub1.refreshPremium(
      address(tokenList.dai),
      IHubBase.PremiumDelta(premiumShares, premiumOffset, 1)
    );
    vm.snapshotGasLastCall('Hub.Operations', 'refreshPremium');
  }

  function test_mintFeeShares() public {
    vm.startPrank(address(spoke2));
    tokenList.dai.transferFrom(alice, address(hub1), 1000e18);
    hub1.add(address(tokenList.dai), 1000e18);
    vm.stopPrank();

    vm.startPrank(address(spoke1));
    tokenList.usdx.transferFrom(alice, address(hub1), 1000e6);
    hub1.add(address(tokenList.usdx), 1000e6);
    hub1.draw(address(tokenList.dai), 500e18, alice);
    vm.stopPrank();

    skip(100);

    Utils.mintFeeShares(hub1, address(tokenList.dai), ADMIN);
    vm.snapshotGasLastCall('Hub.Operations', 'mintFeeShares');
  }

  function test_payFee_transferShares() public {
    Utils.add({
      hub: hub1,
      underlying: address(tokenList.dai),
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
    hub1.payFeeShares(address(tokenList.dai), 100e18);
    vm.snapshotGasLastCall('Hub.Operations', 'payFee');

    skip(100);

    vm.prank(address(spoke1));
    hub1.transferShares(address(tokenList.dai), 100e18, address(spoke2));
    vm.snapshotGasLastCall('Hub.Operations', 'transferShares');
  }

  function test_deficit() public {
    Utils.add({
      hub: hub1,
      underlying: address(tokenList.dai),
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
    hub1.reportDeficit(address(tokenList.dai), drawnDebt, premiumDebt, premiumDelta);
    vm.snapshotGasLastCall('Hub.Operations', 'reportDeficit');

    vm.prank(address(spoke1));
    hub1.eliminateDeficit(address(tokenList.dai), 100e18, address(spoke1));
    vm.snapshotGasLastCall('Hub.Operations', 'eliminateDeficit: partial');

    uint256 deficit = hub1.getAssetDeficit(address(tokenList.dai));

    vm.prank(address(spoke1));
    hub1.eliminateDeficit(address(tokenList.dai), deficit, address(spoke1));
    vm.snapshotGasLastCall('Hub.Operations', 'eliminateDeficit: full');
  }
}
