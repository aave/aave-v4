// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract LiquidityHubTest is BaseTest {
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
    spoke.addReserve(
      daiAssetId,
      Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false}),
      address(dai)
    );
    hub.addSpoke(
      daiAssetId,
      LiquidityHub.SpokeConfig({supplyCap: type(uint256).max, drawCap: 0}),
      address(spoke)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(daiAssetId, 1e8);

    // Add eth
    uint256 ethAssetId = 1;
    hub.addAsset(
      LiquidityHub.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      address(eth)
    );
    spoke.addReserve(
      ethAssetId,
      Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false}),
      address(eth)
    );
    hub.addSpoke(
      ethAssetId,
      LiquidityHub.SpokeConfig({supplyCap: type(uint256).max, drawCap: 0}),
      address(spoke)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 2000e8);

    // Add dai again but with basic credit line borrow module
    uint256 daiCreditLineAssetId = 2;
    // flat 5% interest rate
    creditLineIRStrategy.setInterestRateParams(
      daiCreditLineAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 5000, // 50.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );
    spokeCreditLine = new MockSpokeCreditLine(address(hub), address(creditLineIRStrategy));
    hub.addAsset(
      LiquidityHub.AssetConfig({
        decimals: 18,
        active: true,
        irStrategy: address(creditLineIRStrategy)
      }),
      address(dai)
    );
    spokeCreditLine.addReserve(
      daiCreditLineAssetId,
      MockSpokeCreditLine.ReserveConfig({lt: 0, lb: 0, rf: 0, borrowable: true}),
      address(dai)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(daiCreditLineAssetId, 1e8);

    vm.warp(block.timestamp + 20);
  }

  function test_first_supply() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    deal(address(dai), address(spoke), amount);

    LiquidityHub.Asset memory reserveData = hub.getAsset(assetId);
    LiquidityHub.Spoke memory spokeData = hub.getSpoke(assetId, address(spoke));

    assertEq(reserveData.totalShares, 0, 'wrong reserve shares pre-supply');
    assertEq(reserveData.totalAssets, 0, 'wrong reserve assets pre-supply');
    assertEq(dai.balanceOf(address(spoke)), amount, 'wrong user token balance pre-supply');
    assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance pre-supply');

    vm.startPrank(address(spoke));
    IERC20(dai).approve(address(hub), amount);
    vm.expectEmit(true, true, true, false, address(hub));
    emit Supply(assetId, address(spoke), amount);
    hub.supply(assetId, amount, 0);
    vm.stopPrank();

    reserveData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke));

    assertEq(
      reserveData.totalShares,
      hub.convertAssetsToShares(assetId, amount, true),
      'wrong reserve total shares post-supply'
    );
    assertEq(reserveData.totalAssets, amount, 'wrong reserve total assets post-supply');
    assertEq(
      spokeData.totalShares,
      hub.convertAssetsToShares(assetId, amount, true),
      'wrong spoke stotal hares post-supply'
    );
    assertEq(spokeData.drawnShares, 0, 'wrong spoke shares post-supply');
    assertEq(dai.balanceOf(address(spoke)), 0);
    assertEq(dai.balanceOf(address(hub)), amount);
  }

  /// User makes a first supply, shares and assets amounts are correct, no precision loss
  function skip_test_fuzz_first_supply(uint256 assetId, address user, uint256 amount) public {
    if (user == address(hub) || user == address(0)) return;
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    deal(hub.assetsList(assetId), user, type(uint128).max);
    deal(hub.assetsList(assetId), USER1, type(uint128).max);

    // initial supply
    Utils.supply(vm, hub, assetId, user, amount, user);

    LiquidityHub.Asset memory reserveData = hub.getAsset(assetId);
    Spoke.UserConfig memory userData = spoke.getUser(assetId, user);

    // check reserve index and user interest
    assertEq(reserveData.totalShares, amount, 'wrong reserve shares');
    assertEq(reserveData.totalAssets, amount, 'wrong reserve assets');
    assertEq(userData.supplyShares, amount, 'wrong user shares');
    assertEq(spoke.getUserDebt(assetId, user), amount, 'wrong user assets');
  }

  function test_fuzz_supply_events(
    uint256 assetId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) public {
    if (user == address(hub) || user == address(0)) return;
    if (onBehalfOf == address(0)) return;
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    address asset = hub.assetsList(assetId);

    deal(asset, user, amount);

    vm.startPrank(user);
    IERC20(asset).approve(address(hub), amount);

    vm.expectEmit(true, true, true, true, asset);
    emit Transfer(user, address(hub), amount);

    vm.expectEmit(true, true, true, true, address(hub));
    emit Supply(assetId, user, amount);

    hub.supply(assetId, amount, 0);
    vm.stopPrank();
  }

  function test_supply_zero_reverts() public {
    // TODO User cannot supply 0 assets
  }

  function test_supply_with_increased_index() public {
    // TODO User supplies X and gets accounted X assets and less than X shares.
  }

  function test_supply_index_increase() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    deal(address(dai), USER1, amount);

    LiquidityHub.Asset memory reserveData = hub.getAsset(assetId);
    Spoke.UserConfig memory userData = spoke.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, 0);
    assertEq(reserveData.totalAssets, 0);
    assertEq(userData.supplyShares, 0);
    assertEq(spoke.getUserDebt(assetId, USER1), 0);
    assertEq(dai.balanceOf(USER1), amount);
    assertEq(dai.balanceOf(address(hub)), 0);

    Utils.supply(vm, hub, assetId, USER1, amount, USER1);

    reserveData = hub.getAsset(assetId);
    userData = spoke.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(userData.supplyShares, amount);
    assertEq(spoke.getUserDebt(assetId, USER1), amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    // Index grows but same block, no interest acc
    uint256 newBorrowRate = 0.1e27; // 10.00%
    vm.mockCall(
      address(spoke),
      abi.encodeWithSelector(ISpoke.getInterestRate.selector),
      abi.encode(newBorrowRate)
    );

    userData = spoke.getUser(assetId, USER1);
    assertEq(spoke.getUserDebt(assetId, USER1), amount);

    // Time flies, no interest acc
    vm.warp(block.timestamp + 1e4);

    userData = spoke.getUser(assetId, USER1);
    reserveData = hub.getAsset(assetId);
    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(spoke.getUserDebt(assetId, USER1), amount);

    // state update due to reserve operation
    // TODO helper for reserve state update
    // total assets do not change because no interest acc yet
    uint256 newTotalAssets = reserveData.totalAssets;

    uint256 user2SupplyShares = 1; // minimum for 1 share
    uint256 user2SupplyAssets = user2SupplyShares.toAssetsUp(
      newTotalAssets,
      reserveData.totalShares
    );

    uint256 newUserAssets = amount.toAssetsDown(
      newTotalAssets + user2SupplyAssets,
      reserveData.totalShares + user2SupplyShares
    );

    deal(address(dai), USER2, user2SupplyAssets);
    Utils.supply(vm, hub, assetId, USER2, user2SupplyAssets, USER2);

    // reserve update
    userData = spoke.getUser(assetId, USER1);
    reserveData = hub.getAsset(assetId);

    assertEq(reserveData.totalShares, amount + user2SupplyShares, 'wrong total shares');
    assertEq(reserveData.totalAssets, newTotalAssets + user2SupplyAssets, 'wrong total assets');
    assertEq(reserveData.drawnShares, 0, 'wrong total drawn');
    assertEq(userData.supplyShares, amount);
    assertEq(spoke.getUserDebt(assetId, USER1), newUserAssets, 'wrong user assets');
  }

  struct TestSupplyUserParams {
    uint256 totalAssets;
    uint256 totalShares;
    uint256 userAssets;
    uint256 userShares;
  }

  /// forge-config: default.fuzz.max-test-rejects = 1
  /// User makes a first supply, which increases overtime as yield accrues
  // TODO: to be fixed, there is precision loss
  function skip_test_fuzz_supply_index_increase(
    uint256 assetId,
    address user,
    uint256 amount
  ) public {
    if (user == address(hub) || user == address(0)) return;
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    deal(hub.assetsList(assetId), user, type(uint128).max);
    deal(hub.assetsList(assetId), USER1, type(uint128).max);

    // initial supply
    Utils.supply(vm, hub, assetId, user, amount, user);

    uint256 elapsedTimeChange = bound(uint160(user), 0, 30 days); // [0, 30 days] range
    uint256 borrowRateChange = bound(uint160(user), 0, 1e27); // [0.00%, 100.00%] range;

    TestSupplyUserParams memory p = TestSupplyUserParams({
      totalAssets: amount,
      totalShares: amount,
      userAssets: amount,
      userShares: amount
    });
    LiquidityHub.Asset memory reserveData;
    Spoke.UserConfig memory userData;

    for (uint256 i = 0; i < 2; i += 1) {
      reserveData = hub.getAsset(assetId);
      userData = spoke.getUser(assetId, user);

      // check reserve index and user interest
      assertEq(reserveData.totalShares, p.totalShares, 'wrong reserve shares');
      assertEq(reserveData.totalAssets, p.totalAssets, 'wrong reserve assets');
      assertEq(userData.supplyShares, amount, 'wrong user shares');
      assertEq(spoke.getUserDebt(assetId, user), p.userAssets, 'wrong user assets');

      // rate increases
      uint256 newBorrowRate = (borrowRateChange * i) % 2e27; // randomize, 200.00% max
      vm.mockCall(
        address(spoke),
        abi.encodeWithSelector(ISpoke.getInterestRate.selector),
        abi.encode(newBorrowRate)
      );

      // time flies
      uint256 elapsedTime = (i % 2 == 0 ? elapsedTimeChange : elapsedTimeChange * 2) % 30 days; // randomize, 30 days max
      vm.warp(block.timestamp + elapsedTime);

      // calculate new index
      p.totalAssets += MathUtils
        .calculateLinearInterest(newBorrowRate, uint40(reserveData.lastUpdateTimestamp))
        .rayMul(reserveData.totalAssets);

      uint256 user2SupplyShares = 1; // minimum for 1 share
      uint256 user2SupplyAssets = user2SupplyShares.toAssetsUp(
        p.totalAssets,
        reserveData.totalShares
      );

      p.totalAssets += user2SupplyAssets;
      p.totalShares += user2SupplyShares;

      p.userAssets = p.userShares.toAssetsDown(p.totalAssets, p.totalShares);

      // update reserve state
      Utils.supply(vm, hub, assetId, USER1, user2SupplyAssets, USER1);
    }
  }

  function test_withdraw() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(dai), USER1, amount);
    Utils.supply(vm, hub, assetId, USER1, amount, USER1);

    LiquidityHub.Asset memory reserveData = hub.getAsset(assetId);
    Spoke.UserConfig memory userData = spoke.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(userData.supplyShares, amount);
    assertEq(spoke.getUserDebt(assetId, USER1), amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    Utils.withdraw(vm, hub, assetId, USER1, amount, USER1);

    reserveData = hub.getAsset(assetId);
    userData = spoke.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, 0);
    assertEq(reserveData.totalAssets, 0);
    assertEq(userData.supplyShares, 0);
    assertEq(spoke.getUserDebt(assetId, USER1), 0);
    assertEq(dai.balanceOf(USER1), amount);
    assertEq(dai.balanceOf(address(hub)), 0);
  }

  function skip_test_fuzz_withdraw_events(
    uint256 assetId,
    address user,
    uint256 amount,
    address to
  ) public {
    if (user == address(hub) || user == address(0)) return;
    if (to == address(0)) return;
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    address asset = hub.assetsList(assetId);

    // User supply
    deal(asset, user, amount);
    Utils.supply(vm, hub, assetId, user, amount, user);

    vm.expectEmit(true, true, true, true, asset);
    emit Transfer(address(hub), to, amount);

    vm.expectEmit(true, true, true, true, address(hub));
    emit Withdraw(assetId, user, to, amount);

    Utils.withdraw(vm, hub, assetId, user, amount, to);
  }

  function test_withdraw_all_with_interest() public {
    // TODO User supplies X and withdraws more than X because there is some yield
  }

  function test_withdraw_zero_reverts() public {
    // TODO User cannot withdraw 0 assets
  }

  function test_withdraw_more_than_supplied_reverts() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(dai), USER1, amount);
    Utils.supply(vm, hub, assetId, USER1, amount, USER1);

    LiquidityHub.Asset memory reserveData = hub.getAsset(assetId);
    Spoke.UserConfig memory userData = spoke.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(userData.supplyShares, amount);
    assertEq(spoke.getUserDebt(assetId, USER1), amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    vm.prank(USER1);

    vm.expectRevert(TestErrors.NOT_AVAILABLE_LIQUIDITY);
    hub.withdraw(assetId, USER1, amount + 1, 0);

    // advance time, but no accumulation
    vm.warp(block.timestamp + 1e18);
    vm.expectRevert(TestErrors.NOT_AVAILABLE_LIQUIDITY);
    hub.withdraw(assetId, USER1, amount + 1, 0);

    reserveData = hub.getAsset(assetId);
    userData = spoke.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(userData.supplyShares, amount);
    assertEq(spoke.getUserDebt(assetId, USER1), amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);
  }

  function test_user_riskPremium() public {
    uint256 amount = 100e18;
    uint256 ethAssetId = 1;
    uint256 daiAssetId = 0;

    deal(address(eth), USER1, amount);
    Utils.supply(vm, hub, ethAssetId, USER1, amount, USER1);
    spoke.getUserDebt(ethAssetId, USER1);
    spoke.getUserDebt(ethAssetId, USER2);
    spoke.getUserDebt(daiAssetId, USER1);
    spoke.getUserDebt(daiAssetId, USER2);
    // assertEq(hub.getUserRiskPremium(USER1), 0);
    // assertEq(hub.getUserRiskPremium(USER2), 0);

    deal(address(dai), USER1, amount);
    Utils.supply(vm, hub, daiAssetId, USER1, amount, USER2);
    spoke.getUserDebt(ethAssetId, USER1);
    spoke.getUserDebt(ethAssetId, USER2);
    spoke.getUserDebt(daiAssetId, USER1);
    spoke.getUserDebt(daiAssetId, USER2);
    // assertEq(hub.getUserRiskPremium(USER1), 0);
    // assertEq(hub.getUserRiskPremium(USER2), 10_00);
  }

  function test_user_riskPremium_update_affects_positions() public {
    uint256 assetId = 1;
    uint256 amount = 100e18;

    uint256 calcRiskPremium;

    // 100 collateral of ETH - 0 liquidityPremium
    // _updateLiquidityPremium(assetId, 0);
    // assertEq(hub.getUserRiskPremium(USER1), 0);
    deal(address(eth), USER1, amount);
    Utils.supply(vm, hub, assetId, USER1, amount, USER1);
    calcRiskPremium = 0;
    // assertEq(hub.getUserRiskPremium(USER1), calcRiskPremium);

    // ETH liquidityPremium changes to 100_00
    // _updateLiquidityPremium(assetId, 100_00);
    // assertEq(hub.getUserRiskPremium(USER1), 0);
    // hub.refreshUserRiskPremium(USER1);
    calcRiskPremium = 100_00;
    // assertEq(hub.getUserRiskPremium(USER1), calcRiskPremium);
  }

  function test_user_riskPremium_weighted() public {
    uint256 ethAssetId = 1;
    uint256 daiAssetId = 0;
    uint256 ethAmount = 1e18;
    uint256 daiAmount = 2000e18;
    // ETH liquidityPremium to 0, DAI liquidityPremium to 50% liquidityPremium
    // _updateLiquidityPremium(daiAssetId, 50_00);
    // _updateLiquidityPremium(ethAssetId, 0);

    deal(address(dai), USER1, daiAmount);
    Utils.supply(vm, hub, daiAssetId, USER1, daiAmount, USER1);
    deal(address(eth), USER1, ethAmount);
    Utils.supply(vm, hub, ethAssetId, USER1, ethAmount, USER1);

    uint256 calcRiskPremium = 25_00;
    // assertEq(hub.getUserRiskPremium(USER1), calcRiskPremium);
  }

  function test_first_borrow() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    // User1 supply eth
    deal(address(eth), USER1, ethAmount);
    Utils.supply(vm, hub, ethId, USER1, ethAmount, USER1);

    // User2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.supply(vm, hub, daiId, USER2, daiAmount, USER2);

    LiquidityHub.Asset memory daiData = hub.getAsset(daiId);
    LiquidityHub.Asset memory ethData = hub.getAsset(ethId);
    Spoke.UserConfig memory userDaiData1 = spoke.getUser(daiId, USER1);
    Spoke.UserConfig memory userEthData1 = spoke.getUser(ethId, USER1);
    Spoke.UserConfig memory userDaiData2 = spoke.getUser(daiId, USER2);
    Spoke.UserConfig memory userEthData2 = spoke.getUser(ethId, USER2);

    assertEq(daiData.totalShares, daiAmount);
    assertEq(daiData.totalAssets, daiAmount);
    assertEq(daiData.drawnShares, 0);
    assertEq(ethData.totalShares, ethAmount);
    assertEq(ethData.totalAssets, ethAmount);
    assertEq(ethData.drawnShares, 0);

    assertEq(userDaiData1.supplyShares, 0);
    assertEq(spoke.getUserDebt(daiId, USER1), 0);
    assertEq(userEthData1.supplyShares, ethAmount);
    assertEq(spoke.getUserDebt(ethId, USER1), ethAmount);

    assertEq(userDaiData2.supplyShares, daiAmount);
    assertEq(spoke.getUserDebt(daiId, USER2), daiAmount);
    assertEq(userEthData2.supplyShares, 0);
    assertEq(spoke.getUserDebt(ethId, USER2), 0);

    assertEq(dai.balanceOf(USER1), 0);

    // User1 draw half of dai reserve liquidity
    vm.prank(USER1);
    ISpoke(address(spoke)).borrow(daiId, USER1, daiAmount / 2);

    daiData = hub.getAsset(daiId);
    ethData = hub.getAsset(ethId);
    userDaiData1 = spoke.getUser(daiId, USER1);
    userEthData1 = spoke.getUser(ethId, USER1);
    userDaiData2 = spoke.getUser(daiId, USER2);
    userEthData2 = spoke.getUser(ethId, USER2);

    assertEq(daiData.totalShares, daiAmount);
    assertEq(daiData.totalAssets, daiAmount);
    assertEq(daiData.drawnShares, daiAmount / 2);
    assertEq(ethData.totalShares, ethAmount);
    assertEq(ethData.totalAssets, ethAmount);
    assertEq(ethData.drawnShares, 0);

    assertEq(userDaiData1.supplyShares, 0);
    assertEq(spoke.getUserDebt(daiId, USER1), 0);
    assertEq(userEthData1.supplyShares, ethAmount);
    assertEq(spoke.getUserDebt(ethId, USER1), ethAmount);

    assertEq(userDaiData2.supplyShares, daiAmount);
    assertEq(spoke.getUserDebt(daiId, USER2), daiAmount);
    assertEq(userEthData2.supplyShares, 0);
    assertEq(spoke.getUserDebt(ethId, USER2), 0);

    assertEq(dai.balanceOf(USER1), daiAmount / 2);
  }

  function test_revert_draw_reserve_not_active() public {
    uint256 daiId = 2;
    uint256 drawnAmount = 1;
    _updateActive(daiId, false);
    vm.prank(USER1);
    vm.expectRevert(TestErrors.RESERVE_NOT_ACTIVE);
    ISpoke(address(spokeCreditLine)).borrow(daiId, USER1, drawnAmount);
  }

  function test_revert_draw_invalid_amount() public {
    uint256 daiId = 2;
    uint256 drawnAmount = 1;
    vm.prank(USER1);
    vm.expectRevert(TestErrors.INVALID_AMOUNT);
    ISpoke(address(spokeCreditLine)).borrow(daiId, USER1, drawnAmount);
  }

  function test_revert_draw_cap_exceeded() public {
    uint256 daiId = 2;
    uint256 daiAmount = 100e18;
    uint256 drawCap = 1;
    uint256 drawnAmount = drawCap + 1;

    // _updateDrawCap(daiId, drawCap);

    // User2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.supply(vm, hub, daiId, USER2, daiAmount, USER2);

    vm.prank(USER1);
    vm.expectRevert(TestErrors.CAP_EXCEEDED);
    ISpoke(address(spokeCreditLine)).borrow(daiId, USER1, drawnAmount);
  }

  // function _updateLiquidityPremium(uint256 assetId, uint256 newLiquidityPremium) internal {
  //   LiquidityHub.AssetConfig memory reserveConfig = hub.getAsset(assetId).config;
  //   reserveConfig.liquidityPremium = newLiquidityPremium;
  //   hub.updateAsset(assetId, reserveConfig);
  // }

  function _updateActive(uint256 assetId, bool newActive) internal {
    LiquidityHub.AssetConfig memory reserveConfig = hub.getAsset(assetId).config;
    reserveConfig.active = newActive;
    hub.updateAsset(assetId, reserveConfig);
  }

  // function _updateDrawCap(uint256 assetId, uint256 newDrawCap) internal {
  //   LiquidityHub.AssetConfig memory reserveConfig = hub.getAsset(assetId).config;
  //   reserveConfig.drawCap = newDrawCap;
  //   hub.updateAsset(assetId, reserveConfig);
  // }
}
