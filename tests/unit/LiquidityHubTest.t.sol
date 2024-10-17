// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract LiquidityHubTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function setUp() public override {
    super.setUp();

    // Add dai
    hub.addReserve(
      LiquidityHub.ReserveConfig({
        borrowModule: address(bm),
        decimals: 18,
        active: true,
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        liquidityPremium: 10_00
      }),
      address(dai)
    );
    bm.addReserve(
      0,
      BorrowModule.ReserveConfig({lt: 0, lb: 0, rf: 0, borrowable: true}),
      address(dai)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(0, 1e8);

    // Add eth
    hub.addReserve(
      LiquidityHub.ReserveConfig({
        borrowModule: address(bm),
        decimals: 18,
        active: true,
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        liquidityPremium: 0
      }),
      address(eth)
    );
    bm.addReserve(
      1,
      BorrowModule.ReserveConfig({lt: 0, lb: 0, rf: 0, borrowable: true}),
      address(eth)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(1, 2000e8);

    // Add dai again but with basic credit line borrow module
    uint256 daiCreditLineAssetId = 2;
    hub.addReserve(
      LiquidityHub.ReserveConfig({
        borrowModule: address(bmcl),
        decimals: 18,
        active: true,
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        liquidityPremium: 10_00
      }),
      address(dai)
    );
    bmcl.addReserve(
      daiCreditLineAssetId,
      MockBorrowModuleCreditLine.ReserveConfig({lt: 0, lb: 0, rf: 0, borrowable: true}),
      address(dai)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(daiCreditLineAssetId, 1e8);

    // set IR for basic credit line borrow module
    bmcl.setInterestRate(0.05e27); // 5.00%
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

    vm.warp(block.timestamp + 20);
  }

  function test_first_supply() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    deal(address(dai), USER1, amount);

    LiquidityHub.Reserve memory reserveData = hub.getReserve(assetId);
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, 0);
    assertEq(reserveData.totalAssets, 0);
    assertEq(userData.shares, 0);
    assertEq(hub.getUserBalance(assetId, USER1), 0);
    assertEq(dai.balanceOf(USER1), amount);
    assertEq(dai.balanceOf(address(hub)), 0);

    Utils.supply(vm, hub, assetId, USER1, amount, USER1);

    reserveData = hub.getReserve(assetId);
    userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(userData.shares, amount);
    assertEq(hub.getUserBalance(assetId, USER1), amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);
  }

  /// User makes a first supply, shares and assets amounts are correct, no precision loss
  function skip_test_fuzz_first_supply(uint256 assetId, address user, uint256 amount) public {
    if (user == address(hub) || user == address(0)) return;
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    deal(hub.reservesList(assetId), user, type(uint128).max);
    deal(hub.reservesList(assetId), USER1, type(uint128).max);

    // initial supply
    Utils.supply(vm, hub, assetId, user, amount, user);

    LiquidityHub.Reserve memory reserveData = hub.getReserve(assetId);
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, user);

    // check reserve index and user interest
    assertEq(reserveData.totalShares, amount, 'wrong reserve shares');
    assertEq(reserveData.totalAssets, amount, 'wrong reserve assets');
    assertEq(userData.shares, amount, 'wrong user shares');
    assertEq(hub.getUserBalance(assetId, user), amount, 'wrong user assets');
  }

  function test_fuzz_supply_events(
    uint256 assetId,
    address user,
    uint256 amount,
    address onBehalfOf
  ) public {
    if (user == address(hub) || user == address(0)) return;
    if (onBehalfOf == address(0)) return;
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    address asset = hub.reservesList(assetId);

    deal(asset, user, amount);

    vm.startPrank(user);
    IERC20(asset).approve(address(hub), amount);

    vm.expectEmit(true, true, true, true, asset);
    emit Transfer(user, address(hub), amount);

    vm.expectEmit(true, true, true, true, address(hub));
    emit Supply(assetId, user, onBehalfOf, amount, 0);

    hub.supply(assetId, amount, onBehalfOf, 0);
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

    LiquidityHub.Reserve memory reserveData = hub.getReserve(assetId);
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, 0);
    assertEq(reserveData.totalAssets, 0);
    assertEq(userData.shares, 0);
    assertEq(hub.getUserBalance(assetId, USER1), 0);
    assertEq(dai.balanceOf(USER1), amount);
    assertEq(dai.balanceOf(address(hub)), 0);

    Utils.supply(vm, hub, assetId, USER1, amount, USER1);

    reserveData = hub.getReserve(assetId);
    userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(userData.shares, amount);
    assertEq(hub.getUserBalance(assetId, USER1), amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    // Index grows but same block, no interest acc
    uint256 newBorrowRate = 0.1e27; // 10.00%
    vm.mockCall(
      address(bm),
      abi.encodeWithSelector(IBorrowModule.getInterestRate.selector),
      abi.encode(newBorrowRate)
    );

    userData = hub.getUser(assetId, USER1);
    assertEq(hub.getUserBalance(assetId, USER1), amount);

    // Time flies, no interest acc
    vm.warp(block.timestamp + 1e4);

    userData = hub.getUser(assetId, USER1);
    reserveData = hub.getReserve(assetId);
    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(hub.getUserBalance(assetId, USER1), amount);

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
    userData = hub.getUser(assetId, USER1);
    reserveData = hub.getReserve(assetId);

    assertEq(reserveData.totalShares, amount + user2SupplyShares, 'wrong total shares');
    assertEq(reserveData.totalAssets, newTotalAssets + user2SupplyAssets, 'wrong total assets');
    assertEq(reserveData.totalDrawn, 0, 'wrong total drawn');
    assertEq(userData.shares, amount);
    assertEq(hub.getUserBalance(assetId, USER1), newUserAssets, 'wrong user assets');
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
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    deal(hub.reservesList(assetId), user, type(uint128).max);
    deal(hub.reservesList(assetId), USER1, type(uint128).max);

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
    LiquidityHub.Reserve memory reserveData;
    LiquidityHub.UserConfig memory userData;

    for (uint256 i = 0; i < 2; i += 1) {
      reserveData = hub.getReserve(assetId);
      userData = hub.getUser(assetId, user);

      // check reserve index and user interest
      assertEq(reserveData.totalShares, p.totalShares, 'wrong reserve shares');
      assertEq(reserveData.totalAssets, p.totalAssets, 'wrong reserve assets');
      assertEq(userData.shares, amount, 'wrong user shares');
      assertEq(hub.getUserBalance(assetId, user), p.userAssets, 'wrong user assets');

      // rate increases
      uint256 newBorrowRate = (borrowRateChange * i) % 2e27; // randomize, 200.00% max
      vm.mockCall(
        address(bm),
        abi.encodeWithSelector(IBorrowModule.getInterestRate.selector),
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

    LiquidityHub.Reserve memory reserveData = hub.getReserve(assetId);
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(userData.shares, amount);
    assertEq(hub.getUserBalance(assetId, USER1), amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    Utils.withdraw(vm, hub, assetId, USER1, amount, USER1);

    reserveData = hub.getReserve(assetId);
    userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, 0);
    assertEq(reserveData.totalAssets, 0);
    assertEq(userData.shares, 0);
    assertEq(hub.getUserBalance(assetId, USER1), 0);
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
    assetId = bound(assetId, 0, hub.reserveCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    address asset = hub.reservesList(assetId);

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

    LiquidityHub.Reserve memory reserveData = hub.getReserve(assetId);
    LiquidityHub.UserConfig memory userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(userData.shares, amount);
    assertEq(hub.getUserBalance(assetId, USER1), amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    vm.prank(USER1);

    vm.expectRevert(TestErrors.NOT_AVAILABLE_LIQUIDITY);
    hub.withdraw(assetId, amount + 1, USER1);

    // advance time, but no accumulation
    vm.warp(block.timestamp + 1e18);
    vm.expectRevert(TestErrors.NOT_AVAILABLE_LIQUIDITY);
    hub.withdraw(assetId, amount + 1, USER1);

    reserveData = hub.getReserve(assetId);
    userData = hub.getUser(assetId, USER1);

    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(userData.shares, amount);
    assertEq(hub.getUserBalance(assetId, USER1), amount);
    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(hub)), amount);
  }

  function test_user_riskPremium() public {
    uint256 amount = 100e18;
    uint256 ethAssetId = 1;
    uint256 daiAssetId = 0;

    deal(address(eth), USER1, amount);
    Utils.supply(vm, hub, ethAssetId, USER1, amount, USER1);
    hub.getUserBalance(ethAssetId, USER1);
    hub.getUserBalance(ethAssetId, USER2);
    hub.getUserBalance(daiAssetId, USER1);
    hub.getUserBalance(daiAssetId, USER2);
    assertEq(hub.getUserRiskPremium(USER1), 0);
    assertEq(hub.getUserRiskPremium(USER2), 0);

    deal(address(dai), USER1, amount);
    Utils.supply(vm, hub, daiAssetId, USER1, amount, USER2);
    hub.getUserBalance(ethAssetId, USER1);
    hub.getUserBalance(ethAssetId, USER2);
    hub.getUserBalance(daiAssetId, USER1);
    hub.getUserBalance(daiAssetId, USER2);
    assertEq(hub.getUserRiskPremium(USER1), 0);
    assertEq(hub.getUserRiskPremium(USER2), 10_00);
  }

  function test_user_riskPremium_update_affects_positions() public {
    uint256 assetId = 1;
    uint256 amount = 100e18;

    uint256 calcRiskPremium;

    // 100 collateral of ETH - 0 liquidityPremium
    _updateLiquidityPremium(assetId, 0);
    assertEq(hub.getUserRiskPremium(USER1), 0);
    deal(address(eth), USER1, amount);
    Utils.supply(vm, hub, assetId, USER1, amount, USER1);
    calcRiskPremium = 0;
    assertEq(hub.getUserRiskPremium(USER1), calcRiskPremium);

    // ETH liquidityPremium changes to 100_00
    _updateLiquidityPremium(assetId, 100_00);
    assertEq(hub.getUserRiskPremium(USER1), 0);
    hub.refreshUserRiskPremium(USER1);
    calcRiskPremium = 100_00;
    assertEq(hub.getUserRiskPremium(USER1), calcRiskPremium);
  }

  function test_user_riskPremium_weighted() public {
    uint256 ethAssetId = 1;
    uint256 daiAssetId = 0;
    uint256 ethAmount = 1e18;
    uint256 daiAmount = 2000e18;
    // ETH liquidityPremium to 0, DAI liquidityPremium to 50% liquidityPremium
    _updateLiquidityPremium(daiAssetId, 50_00);
    _updateLiquidityPremium(ethAssetId, 0);

    deal(address(dai), USER1, daiAmount);
    Utils.supply(vm, hub, daiAssetId, USER1, daiAmount, USER1);
    deal(address(eth), USER1, ethAmount);
    Utils.supply(vm, hub, ethAssetId, USER1, ethAmount, USER1);

    uint256 calcRiskPremium = 25_00;
    assertEq(hub.getUserRiskPremium(USER1), calcRiskPremium);
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

    LiquidityHub.Reserve memory daiData = hub.getReserve(daiId);
    LiquidityHub.Reserve memory ethData = hub.getReserve(ethId);
    LiquidityHub.UserConfig memory userDaiData1 = hub.getUser(daiId, USER1);
    LiquidityHub.UserConfig memory userEthData1 = hub.getUser(ethId, USER1);
    LiquidityHub.UserConfig memory userDaiData2 = hub.getUser(daiId, USER2);
    LiquidityHub.UserConfig memory userEthData2 = hub.getUser(ethId, USER2);

    assertEq(daiData.totalShares, daiAmount);
    assertEq(daiData.totalAssets, daiAmount);
    assertEq(daiData.totalDrawn, 0);
    assertEq(ethData.totalShares, ethAmount);
    assertEq(ethData.totalAssets, ethAmount);
    assertEq(ethData.totalDrawn, 0);

    assertEq(userDaiData1.shares, 0);
    assertEq(hub.getUserBalance(daiId, USER1), 0);
    assertEq(userEthData1.shares, ethAmount);
    assertEq(hub.getUserBalance(ethId, USER1), ethAmount);

    assertEq(userDaiData2.shares, daiAmount);
    assertEq(hub.getUserBalance(daiId, USER2), daiAmount);
    assertEq(userEthData2.shares, 0);
    assertEq(hub.getUserBalance(ethId, USER2), 0);

    assertEq(dai.balanceOf(USER1), 0);

    // User1 draw half of dai reserve liquidity
    vm.prank(USER1);
    IBorrowModule(daiData.config.borrowModule).borrow(daiId, daiAmount / 2);

    daiData = hub.getReserve(daiId);
    ethData = hub.getReserve(ethId);
    userDaiData1 = hub.getUser(daiId, USER1);
    userEthData1 = hub.getUser(ethId, USER1);
    userDaiData2 = hub.getUser(daiId, USER2);
    userEthData2 = hub.getUser(ethId, USER2);

    assertEq(daiData.totalShares, daiAmount);
    assertEq(daiData.totalAssets, daiAmount);
    assertEq(daiData.totalDrawn, daiAmount / 2);
    assertEq(ethData.totalShares, ethAmount);
    assertEq(ethData.totalAssets, ethAmount);
    assertEq(ethData.totalDrawn, 0);

    assertEq(userDaiData1.shares, 0);
    assertEq(hub.getUserBalance(daiId, USER1), 0);
    assertEq(userEthData1.shares, ethAmount);
    assertEq(hub.getUserBalance(ethId, USER1), ethAmount);

    assertEq(userDaiData2.shares, daiAmount);
    assertEq(hub.getUserBalance(daiId, USER2), daiAmount);
    assertEq(userEthData2.shares, 0);
    assertEq(hub.getUserBalance(ethId, USER2), 0);

    assertEq(dai.balanceOf(USER1), daiAmount / 2);
  }

  // test with basic borrow module
  // credit line with fixed interest rate
  function test_first_borrow_credit_line() public {
    // DAI with basic credit line borrow module
    uint256 daiId = 2;
    uint256 daiAmount = 100e18;

    uint256[] memory drawnAmounts = new uint256[](2);

    // User2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.supply(vm, hub, daiId, USER2, daiAmount, USER2);

    LiquidityHub.Reserve memory daiData0 = hub.getReserve(daiId);

    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(daiData0.config.borrowModule), 0);

    drawnAmounts[0] = daiAmount / 2;
    drawnAmounts[1] = daiAmount / 4;

    // User1 draw half of dai reserve liquidity for borrow module
    vm.prank(USER1);
    IBorrowModule(daiData0.config.borrowModule).borrow(daiId, drawnAmounts[0]);

    LiquidityHub.Reserve memory daiData1 = hub.getReserve(daiId);

    assertEq(daiData1.totalShares, daiAmount, 'wrong total shares after first drawing');
    assertEq(daiData1.totalAssets, daiData0.totalAssets, 'wrong total assets after first drawing');
    assertEq(daiData1.totalDrawn, drawnAmounts[0], 'wrong total drawn after first drawing');
    assertEq(dai.balanceOf(USER1), drawnAmounts[0], 'wrong dai balance after first drawing');

    // accumulate interest over the year
    skip(365 days);
    uint256 cumulated = MathUtils
      .calculateLinearInterest(
        IBorrowModule(daiData1.config.borrowModule).getInterestRate(),
        uint40(daiData1.lastUpdateTimestamp)
      )
      .rayMul(daiData1.totalDrawn);

    // User1 draw quarter of dai reserve liquidity for borrow module
    // to trigger interest accrual
    vm.prank(USER1);
    IBorrowModule(daiData1.config.borrowModule).borrow(daiId, drawnAmounts[1]);

    LiquidityHub.Reserve memory daiData2 = hub.getReserve(daiId);

    assertEq(daiData2.totalShares, daiAmount, 'wrong total shares');
    assertEq(
      daiData2.totalAssets,
      daiData0.totalAssets + (cumulated - daiData1.totalDrawn),
      'wrong total assets'
    );
    assertEq(daiData2.totalDrawn, cumulated + drawnAmounts[1], 'wrong total drawn');
    assertEq(dai.balanceOf(USER1), drawnAmounts[0] + drawnAmounts[1], 'wrong final dai balance');
  }

  function test_fuzz_multiple_draws_credit_line(uint256 numDrawings, uint256 entropy) public {
    numDrawings = bound(numDrawings, 1, 10);

    // DAI with basic credit line borrow module
    uint256 daiId = 2;
    uint256 daiAmount = 100e18;

    uint256[] memory drawnAmounts = new uint256[](numDrawings);
    LiquidityHub.Reserve[] memory daiData = new LiquidityHub.Reserve[](numDrawings);

    // User2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.supply(vm, hub, daiId, USER2, daiAmount, USER2);

    vm.startPrank(USER1);
    uint256 totalDrawn;
    for (uint256 i = 0; i < numDrawings; i++) {
      drawnAmounts[i] = daiAmount / _pseudoRandomNumber(entropy, numDrawings, numDrawings + 5); // divide by some amount > number of drawings, ensuring total drawn < total supplied assets
      totalDrawn += drawnAmounts[i];

      vm.mockCall(
        address(bmcl),
        abi.encodeWithSelector(IBorrowModule.getInterestRate.selector),
        abi.encode(_pseudoRandomNumber(entropy, 0, 100) * .01e27) // random interest rate 0-100%
      );

      // User1 draws some of dai reserve liquidity for borrow module
      IBorrowModule(address(bmcl)).borrow(daiId, drawnAmounts[i]);

      daiData[i] = hub.getReserve(daiId);
      (uint256 totalCumulated, uint256 cumulatedInterest) = _calculateLinearInterest(
        i == 0 ? daiData[0] : daiData[i - 1]
      );

      assertEq(
        daiData[i].totalShares,
        daiAmount,
        string(abi.encodePacked('wrong total shares: i=', vm.toString(i)))
      );
      assertEq(
        daiData[i].totalAssets,
        i == 0
          ? daiData[0].totalAssets + cumulatedInterest
          : daiData[i - 1].totalAssets + cumulatedInterest,
        string(abi.encodePacked('wrong total assets: i=', vm.toString(i)))
      );
      assertEq(
        daiData[i].totalDrawn,
        i == 0 ? totalCumulated : totalCumulated + drawnAmounts[i],
        string(abi.encodePacked('wrong total drawn: i=', vm.toString(i)))
      );
      assertEq(
        dai.balanceOf(USER1),
        totalDrawn,
        string(abi.encodePacked('wrong final dai balance: i=', vm.toString(i)))
      );

      skip(_pseudoRandomNumber(entropy, numDrawings, 500) * 1 days); // skip forward randomly some amount of days to let interest accrue
    }
    vm.stopPrank();
  }

  function test_first_borrow_credit_line_interest_accruals() public {
    // DAI with basic credit line borrow module
    uint256 daiId = 2;
    uint256 daiAmount = 100e18;

    uint256[] memory drawnAmounts = new uint256[](2);

    // User2 supply dai
    deal(address(dai), USER2, daiAmount);
    Utils.supply(vm, hub, daiId, USER2, daiAmount, USER2);

    LiquidityHub.Reserve memory daiData0 = hub.getReserve(daiId);

    assertEq(dai.balanceOf(USER1), 0);
    assertEq(dai.balanceOf(address(bmcl)), 0);

    drawnAmounts[0] = daiAmount / 2;
    drawnAmounts[1] = daiAmount / 4;

    // User1 draw half of dai reserve liquidity for borrow module
    vm.prank(USER1);
    IBorrowModule(address(bmcl)).borrow(daiId, drawnAmounts[0]);

    LiquidityHub.Reserve memory daiData1 = hub.getReserve(daiId);

    assertEq(daiData1.totalShares, daiAmount, 'wrong total shares after first drawing');
    assertEq(daiData1.totalAssets, daiData0.totalAssets, 'wrong total assets after first drawing');
    assertEq(daiData1.totalDrawn, drawnAmounts[0], 'wrong total drawn after first drawing');
    assertEq(dai.balanceOf(USER1), drawnAmounts[0], 'wrong dai balance after first drawing');

    // accumulate interest over the year
    skip(365 days);
    uint256 cumulated = MathUtils
      .calculateLinearInterest(
        IBorrowModule(address(bmcl)).getInterestRate(),
        uint40(daiData1.lastUpdateTimestamp)
      )
      .rayMul(daiData1.totalDrawn);

    // User1 draw quarter of dai reserve liquidity for borrow module
    // to trigger interest accrual
    vm.prank(USER1);
    IBorrowModule(address(bmcl)).borrow(daiId, drawnAmounts[1]);

    LiquidityHub.Reserve memory daiData2 = hub.getReserve(daiId);

    assertEq(daiData2.totalShares, daiAmount, 'wrong total shares');
    assertEq(
      daiData2.totalAssets,
      daiData0.totalAssets + (cumulated - daiData1.totalDrawn),
      'wrong total assets'
    );
    assertEq(daiData2.totalDrawn, cumulated + drawnAmounts[1], 'wrong total drawn');
    assertEq(dai.balanceOf(USER1), drawnAmounts[0] + drawnAmounts[1], 'wrong final dai balance');
  }

  // TODO: move to a helper
  function _calculateLinearInterest(
    LiquidityHub.Reserve memory reserveData
  ) internal view returns (uint256 totalCumulated, uint256 cumulatedInterest) {
    // accumulate interest over the year
    totalCumulated = MathUtils
      .calculateLinearInterest(
        IBorrowModule(reserveData.config.borrowModule).getInterestRate(),
        uint40(reserveData.lastUpdateTimestamp)
      )
      .rayMul(reserveData.totalDrawn);

    cumulatedInterest = totalCumulated - reserveData.totalDrawn;

    return (totalCumulated, cumulatedInterest);
  }

  // TODO: move to a general helper
  function _pseudoRandomNumber(
    uint256 entropy,
    uint256 min,
    uint256 max
  ) internal view returns (uint256) {
    return
      bound(
        uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, entropy))),
        min,
        max
      );
  }

  function _updateLiquidityPremium(uint256 assetId, uint256 newLiquidityPremium) internal {
    LiquidityHub.ReserveConfig memory reserveConfig = hub.getReserve(assetId).config;
    reserveConfig.liquidityPremium = newLiquidityPremium;
    hub.updateReserve(assetId, reserveConfig);
  }
}
