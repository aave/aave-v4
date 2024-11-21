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
      address(spoke1)
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

  function test_supply() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    deal(address(dai), USER1, amount);

    Spoke.UserConfig memory userData = spoke1.getUser(assetId, USER1);

    assertEq(dai.balanceOf(USER1), amount, 'wrong user token balance pre-supply');
    assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance pre-supply');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-supply');
    assertEq(userData.supplyShares, 0, 'wrong user shares pre-supply');
    assertEq(userData.debtShares, 0, 'wrong user shares pre-supply');

    vm.startPrank(USER1);
    IERC20(dai).approve(address(spoke1), amount);
    vm.expectEmit(true, true, true, false, address(spoke1));
    emit Supplied(assetId, USER1, amount);
    spoke1.supply(assetId, amount);
    vm.stopPrank();

    userData = spoke1.getUser(assetId, USER1);

    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-supply');
    assertEq(
      userData.supplyShares,
      hub.convertAssetsToShares(assetId, amount, true),
      'wrong user supply shares'
    );
    assertEq(userData.debtShares, 0, 'wrong user debt shares');
  }

  function test_borrow() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    // USER1 supply eth
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, spoke1, ethId, USER1, ethAmount, USER1);

    // USER2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.spokeSupply(vm, hub, spoke1, daiId, USER2, daiAmount, USER2);

    Spoke.UserConfig memory user1Data = spoke1.getUser(ethId, USER1);
    Spoke.UserConfig memory user2Data = spoke1.getUser(daiId, USER2);

    assertEq(
      user1Data.supplyShares,
      ILiquidityHub(address(hub)).convertAssetsToShares(ethId, ethAmount, true),
      'wrong user1 supply shares pre-draw'
    );
    assertEq(user1Data.debtShares, 0, 'wrong user1 debt shares pre-draw');
    assertEq(
      user2Data.supplyShares,
      ILiquidityHub(address(hub)).convertAssetsToShares(daiId, daiAmount, true),
      'wrong user2 supply shares pre-draw'
    );
    assertEq(user2Data.debtShares, 0, 'wrong user2 debt shares pre-draw');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke1 dai balance pre-draw');
    assertEq(eth.balanceOf(address(spoke2)), 0, 'wrong spoke2 eth balance pre-draw');
    assertEq(dai.balanceOf(USER1), 0, 'wrong spoke1 dai balance pre-draw');
    assertEq(eth.balanceOf(USER2), 0, 'wrong spoke2 eth balance pre-draw');

    // USER1 draw half of dai reserve liquidity
    vm.prank(USER1);
    vm.expectEmit(true, true, true, true, address(spoke1));
    emit Borrowed(daiId, USER1, daiAmount / 2);
    ISpoke(spoke1).borrow(daiId, USER1, daiAmount / 2);

    user1Data = spoke1.getUser(ethId, USER1);
    user2Data = spoke1.getUser(daiId, USER2);

    assertEq(
      user1Data.supplyShares,
      ILiquidityHub(address(hub)).convertAssetsToShares(ethId, ethAmount, true),
      'wrong user1 supply shares final balance'
    );
    assertEq(user1Data.debtShares, 0, 'wrong user1 debt shares final balance');
    assertEq(
      user2Data.supplyShares,
      ILiquidityHub(address(hub)).convertAssetsToShares(daiId, daiAmount, true),
      'wrong user2 supply shares final balance'
    );
    assertEq(user2Data.debtShares, 0, 'wrong user2 debt shares final');
    assertEq(dai.balanceOf(USER1), daiAmount / 2, 'wrong USER1 dai final balance');
    assertEq(eth.balanceOf(USER2), 0, 'wrong USER2 eth final balance');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke1 dai final balance');
    assertEq(eth.balanceOf(address(spoke2)), 0, 'wrong spoke2 eth final balance');
  }

  function test_withdraw() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // USER1 supply
    deal(address(dai), USER1, amount);
    Utils.spokeSupply(vm, hub, spoke1, assetId, USER1, amount, USER1);

    Spoke.UserConfig memory user1Data = spoke1.getUser(assetId, USER1);

    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-withdraw');
    assertEq(dai.balanceOf(address(hub)), amount, 'wrong hub token balance pre-withdraw');
    assertEq(dai.balanceOf(USER1), 0, 'wrong user token balance pre-withdraw');
    assertEq(
      user1Data.supplyShares,
      ILiquidityHub(hub).convertAssetsToShares(assetId, amount, false),
      'wrong user supply shares post-withdraw'
    );
    assertEq(user1Data.debtShares, 0, 'wrong user debt shares post-withdraw');

    vm.startPrank(USER1);
    vm.expectEmit(true, true, true, true, address(spoke1));
    emit Withdrawn(assetId, USER1, amount);
    spoke1.withdraw(assetId, USER1, amount);
    vm.stopPrank();

    user1Data = spoke1.getUser(assetId, USER1);

    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-withdraw');
    assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance post-withdraw');
    assertEq(dai.balanceOf(USER1), amount, 'wrong user token balance post-withdraw');
    assertEq(user1Data.supplyShares, 0, 'wrong user supply shares post-withdraw');
    assertEq(user1Data.debtShares, 0, 'wrong user debt shares post-withdraw');
  }
  function test_repay() public {}
}
