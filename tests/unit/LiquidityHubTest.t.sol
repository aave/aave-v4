// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'src/contracts/types/DataTypes.sol';
import '../BaseTest.t.sol';

contract LiquidityHubTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using SupplyReserveConfiguration for DataTypes.SupplyReserveConfig;
  using BorrowReserveConfiguration for DataTypes.BorrowReserveConfig;

  function setUp() public override {
    super.setUp();

    // Add dai
    hub.addReserve(
      DataTypes.SupplyReserveConfigurationParams({
        borrowModule: address(bm),
        supplyModule: address(0),
        lt: 0,
        lb: 0,
        rf: 0,
        active: true,
        borrowable: false,
        frozen: false,
        paused: false,
        supplyCap: 0,
        borrowCap: 0,
        liquidityPremium: 10_00
      }),
      DataTypes.BorrowReserveConfigurationParams({
        borrowModule: address(bm),
        supplyModule: address(0),
        lt: 0,
        lb: 0,
        rf: 0,
        active: true,
        borrowable: false,
        frozen: false,
        paused: false,
        supplyCap: 0,
        borrowCap: 0,
        liquidityPremium: 10_00
      }),
      address(dai)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(0, 1e8);

    // Add eth
    hub.addReserve(
      DataTypes.SupplyReserveConfigurationParams({
        borrowModule: address(bm),
        supplyModule: address(0),
        lt: 0,
        lb: 0,
        rf: 0,
        active: true,
        borrowable: false,
        frozen: false,
        paused: false,
        supplyCap: 0,
        borrowCap: 0,
        liquidityPremium: 0
      }),
      DataTypes.BorrowReserveConfigurationParams({
        borrowModule: address(bm),
        supplyModule: address(0),
        lt: 0,
        lb: 0,
        rf: 0,
        active: true,
        borrowable: false,
        frozen: false,
        paused: false,
        supplyCap: 0,
        borrowCap: 0,
        liquidityPremium: 0
      }),
      address(eth)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(1, 2000e8);

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
      abi.encodeWithSelector(IBorrowModule.calculateInterestRates.selector),
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
    uint256 cumulated = MathUtils
      .calculateLinearInterest(newBorrowRate, uint40(reserveData.lastUpdateTimestamp))
      .rayMul(reserveData.totalAssets);
    uint256 newTotalAssets = reserveData.totalAssets + cumulated;

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
        abi.encodeWithSelector(IBorrowModule.calculateInterestRates.selector),
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

    vm.expectRevert(Errors.NOT_AVAILABLE_LIQUIDITY);
    hub.withdraw(assetId, amount + 1, USER1);

    // advance time, but no accumulation
    vm.warp(block.timestamp + 1e18);
    vm.expectRevert(Errors.NOT_AVAILABLE_LIQUIDITY);
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

  function testReserveConfiguration() public {
    LiquidityHub.Reserve memory reserveData = hub.getReserve(0);
    DataTypes.BorrowReserveConfig memory borrowConfig = reserveData.borrowConfig;
    DataTypes.SupplyReserveConfig memory supplyConfig = reserveData.supplyConfig;

    // Test Getters
    assertEq(borrowConfig.getLiquidationThreshold(), 0);
    assertEq(supplyConfig.getLiquidationThreshold(), 0);
    assertEq(borrowConfig.getLiquidationBonus(), 0);
    assertEq(supplyConfig.getLiquidationBonus(), 0);
    assertEq(borrowConfig.getActive(), true);
    assertEq(supplyConfig.getActive(), true);
    assertEq(borrowConfig.getFrozen(), false);
    assertEq(supplyConfig.getFrozen(), false);
    assertEq(borrowConfig.getPaused(), false);
    assertEq(supplyConfig.getPaused(), false);
    assertEq(borrowConfig.getBorrowingEnabled(), false);
    assertEq(supplyConfig.getBorrowingEnabled(), false);
    assertEq(borrowConfig.getReserveFactor(), 0);
    assertEq(supplyConfig.getReserveFactor(), 0);
    assertEq(borrowConfig.getBorrowCap(), 0);
    assertEq(supplyConfig.getBorrowCap(), 0);
    assertEq(borrowConfig.getSupplyCap(), 0);
    assertEq(supplyConfig.getSupplyCap(), 0);
    assertEq(borrowConfig.getLiquidityPremium(), 10_00);
    assertEq(supplyConfig.getLiquidityPremium(), 10_00);

    (bool active, bool borrowable, bool frozen, bool paused) = borrowConfig.getFlags();
    bool[4] memory expected = [true, false, false, false];
    bool[4] memory actual = [active, borrowable, frozen, paused];
    for (uint8 i = 0; i < 4; i += 1) {
      assertEq(expected[i], actual[i]);
    }

    (active, borrowable, frozen, paused) = supplyConfig.getFlags();
    for (uint8 i = 0; i < 4; i += 1) {
      assertEq(expected[i], actual[i]);
    }

    (uint256 lt, uint256 lb, uint256 rf) = borrowConfig.getParams();
    assertEq(lt, 0);
    assertEq(lb, 0);
    assertEq(rf, 0);
    (lt, lb, rf) = supplyConfig.getParams();
    assertEq(lt, 0);
    assertEq(lb, 0);
    assertEq(rf, 0);

    (uint256 borrowCap, uint256 supplyCap) = borrowConfig.getCaps();
    assertEq(borrowCap, 0);
    assertEq(supplyCap, 0);
    (borrowCap, supplyCap) = supplyConfig.getCaps();
    assertEq(borrowCap, 0);
    assertEq(supplyCap, 0);

    // Test Setters
    borrowConfig.setLiquidationThreshold(1);
    assertEq(borrowConfig.getLiquidationThreshold(), 1);
    supplyConfig.setLiquidationThreshold(1);
    assertEq(supplyConfig.getLiquidationThreshold(), 1);
    borrowConfig.setLiquidationBonus(1);
    assertEq(borrowConfig.getLiquidationBonus(), 1);
    supplyConfig.setLiquidationBonus(1);
    assertEq(supplyConfig.getLiquidationBonus(), 1);
    borrowConfig.setActive(false);
    assertEq(borrowConfig.getActive(), false);
    supplyConfig.setActive(false);
    assertEq(supplyConfig.getActive(), false);
    borrowConfig.setFrozen(true);
    assertEq(borrowConfig.getFrozen(), true);
    supplyConfig.setFrozen(true);
    assertEq(supplyConfig.getFrozen(), true);
    borrowConfig.setPaused(true);
    assertEq(borrowConfig.getPaused(), true);
    supplyConfig.setPaused(true);
    assertEq(supplyConfig.getPaused(), true);
    borrowConfig.setBorrowingEnabled(true);
    assertEq(borrowConfig.getBorrowingEnabled(), true);
    supplyConfig.setBorrowingEnabled(true);
    assertEq(supplyConfig.getBorrowingEnabled(), true);
    borrowConfig.setReserveFactor(1);
    assertEq(borrowConfig.getReserveFactor(), 1);
    supplyConfig.setReserveFactor(1);
    assertEq(supplyConfig.getReserveFactor(), 1);
    borrowConfig.setBorrowCap(1);
    assertEq(borrowConfig.getBorrowCap(), 1);
    supplyConfig.setBorrowCap(1);
    assertEq(supplyConfig.getBorrowCap(), 1);
    borrowConfig.setSupplyCap(1);
    assertEq(borrowConfig.getSupplyCap(), 1);
    supplyConfig.setSupplyCap(1);
    assertEq(supplyConfig.getSupplyCap(), 1);
    borrowConfig.setLiquidityPremium(1);
    assertEq(borrowConfig.getLiquidityPremium(), 1);
    supplyConfig.setLiquidityPremium(1);
    assertEq(supplyConfig.getLiquidityPremium(), 1);

    // Test setConfigFromParams
    DataTypes.BorrowReserveConfigurationParams memory newBorrowParams = DataTypes
      .BorrowReserveConfigurationParams({
        borrowModule: address(bm),
        supplyModule: address(0),
        lt: 3,
        lb: 3,
        rf: 3,
        active: true,
        borrowable: false,
        frozen: false,
        paused: false,
        supplyCap: 3,
        borrowCap: 3,
        liquidityPremium: 20_00
      });
    borrowConfig.setConfigFromParams(newBorrowParams);
    assertEq(borrowConfig.getLiquidationThreshold(), newBorrowParams.lt);
    assertEq(borrowConfig.getLiquidationBonus(), newBorrowParams.lb);
    assertEq(borrowConfig.getReserveFactor(), newBorrowParams.rf);
    assertEq(borrowConfig.getActive(), newBorrowParams.active);
    assertEq(borrowConfig.getBorrowingEnabled(), newBorrowParams.borrowable);
    assertEq(borrowConfig.getFrozen(), newBorrowParams.frozen);
    assertEq(borrowConfig.getPaused(), newBorrowParams.paused);
    assertEq(borrowConfig.getBorrowCap(), newBorrowParams.borrowCap);
    assertEq(borrowConfig.getSupplyCap(), newBorrowParams.supplyCap);
    assertEq(borrowConfig.getLiquidityPremium(), newBorrowParams.liquidityPremium);

    DataTypes.SupplyReserveConfigurationParams memory newSupplyParams = DataTypes
      .SupplyReserveConfigurationParams({
        borrowModule: address(bm),
        supplyModule: address(0),
        lt: 3,
        lb: 3,
        rf: 3,
        active: true,
        borrowable: false,
        frozen: false,
        paused: false,
        supplyCap: 3,
        borrowCap: 3,
        liquidityPremium: 20_00
      });
    supplyConfig.setConfigFromParams(newSupplyParams);
    assertEq(supplyConfig.getLiquidationThreshold(), newSupplyParams.lt);
    assertEq(supplyConfig.getLiquidationBonus(), newSupplyParams.lb);
    assertEq(supplyConfig.getReserveFactor(), newSupplyParams.rf);
    assertEq(supplyConfig.getActive(), newSupplyParams.active);
    assertEq(supplyConfig.getBorrowingEnabled(), newSupplyParams.borrowable);
    assertEq(supplyConfig.getFrozen(), newSupplyParams.frozen);
    assertEq(supplyConfig.getPaused(), newSupplyParams.paused);
    assertEq(supplyConfig.getBorrowCap(), newSupplyParams.borrowCap);
    assertEq(supplyConfig.getSupplyCap(), newSupplyParams.supplyCap);
    assertEq(supplyConfig.getLiquidityPremium(), newSupplyParams.liquidityPremium);
  }

  function _updateLiquidityPremium(uint256 assetId, uint256 newLiquidityPremium) internal {
    DataTypes.SupplyReserveConfig memory reserveConfig = hub.getReserve(assetId).supplyConfig;
    reserveConfig.setLiquidityPremium(newLiquidityPremium);
    hub.updateSupplyReserve(assetId, reserveConfig);
  }
}
