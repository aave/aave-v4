// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract SpokeTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function setUp() public override {
    super.setUp();

    // Add dai
    uint256 daiAssetId = 0;
    hub.addAsset(
      LiquidityHub.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      address(dai)
    );
    spoke1.addReserve(
      daiAssetId,
      Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false}),
      address(dai)
    );
    hub.addSpoke(
      daiAssetId,
      LiquidityHub.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max}),
      address(spoke1)
    );
    spoke2.addReserve(
      daiAssetId,
      Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false}),
      address(dai)
    );
    hub.addSpoke(
      daiAssetId,
      LiquidityHub.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max}),
      address(spoke2)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(daiAssetId, 1e8);

    // Add eth
    uint256 ethAssetId = 1;
    hub.addAsset(
      LiquidityHub.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      address(eth)
    );
    spoke1.addReserve(
      ethAssetId,
      Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false}),
      address(eth)
    );
    hub.addSpoke(
      ethAssetId,
      LiquidityHub.SpokeConfig({supplyCap: type(uint256).max, drawCap: 0}),
      USER1
    );
    spoke2.addReserve(
      ethAssetId,
      Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false}),
      address(eth)
    );
    hub.addSpoke(
      ethAssetId,
      LiquidityHub.SpokeConfig({supplyCap: type(uint256).max, drawCap: 0}),
      address(spoke2)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 2000e8);
  }

  function test_first_supply() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    deal(address(dai), USER1, amount);

    LiquidityHub.Asset memory reserveData = hub.getAsset(assetId);
    LiquidityHub.Spoke memory spokeData = hub.getSpoke(assetId, address(spoke1));

    assertEq(reserveData.totalShares, 0, 'wrong reserve shares pre-supply');
    assertEq(reserveData.totalAssets, 0, 'wrong reserve assets pre-supply');
    assertEq(dai.balanceOf(USER1), amount, 'wrong user token balance pre-supply');
    assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance pre-supply');

    vm.startPrank(USER1);
    IERC20(dai).approve(address(spoke1), amount);
    vm.expectEmit(true, true, true, false, address(spoke1));
    emit Supplied(assetId, USER1, amount);
    spoke1.supply(assetId, amount);
    vm.stopPrank();

    reserveData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));
    Spoke.UserConfig memory userData = spoke1.getUser(assetId, USER1);

    assertEq(
      reserveData.totalShares,
      hub.convertAssetsToShares(assetId, amount, true),
      'wrong reserve total shares post-supply'
    );
    assertEq(reserveData.totalAssets, amount, 'wrong reserve total assets post-supply');
    assertEq(
      spokeData.totalShares,
      hub.convertAssetsToShares(assetId, amount, true),
      'wrong spoke total shares post-supply'
    );
    assertEq(spokeData.drawnShares, 0, 'wrong spoke shares post-supply');
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);
    assertEq(
      userData.supplyShares,
      hub.convertAssetsToShares(assetId, amount, true),
      'wrong user supply shares'
    );
    assertEq(userData.debtShares, 0, 'wrong user debt shares');
  }

  function test_first_borrow() public {}

  function test_withdraw() public {}

  function test_borrow() public {}

  function test_repay() public {}
}
