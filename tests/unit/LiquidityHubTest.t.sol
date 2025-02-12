// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract LiquidityHubTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function setUp() public override {
    super.setUp();

    address[] memory spokes = new address[](2);
    spokes[0] = address(spoke1);
    spokes[1] = address(spoke2);
    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });
    spokeConfigs[1] = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });
    Spoke.ReserveConfig[] memory reserveConfigs = new Spoke.ReserveConfig[](2);
    reserveConfigs[0] = Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false});
    reserveConfigs[1] = Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false});

    // Add dai
    uint256 daiAssetId = 0;
    Utils.addAssetAndSpokes(
      hub,
      address(dai),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    MockPriceOracle(address(oracle)).setAssetPrice(daiAssetId, 1e8);

    // Add eth
    uint256 ethAssetId = 1;
    Utils.addAssetAndSpokes(
      hub,
      address(eth),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 2000e8);

    irStrategy.setInterestRateParams(
      daiAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 9000, // 90.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );
    irStrategy.setInterestRateParams(
      ethAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 9000, // 90.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );

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
      DataTypes.AssetConfig({
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

  function test_supply_revertsWith_asset_not_active() public {
    uint256 daiId = 0;
    uint256 amount = 100e18;

    _updateActive(daiId, false);

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    hub.supply(daiId, amount, 0);
  }

  function test_supply_revertsWith_supply_cap_exceeded() public {
    uint256 daiId = 0;
    uint256 amount = 100e18;
    _updateSupplyCap(daiId, address(spoke1), amount - 1);

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLY_CAP_EXCEEDED);
    hub.supply(daiId, amount, 0);
  }

  function test_first_supply() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    deal(address(dai), address(spoke1), amount);

    LiquidityHub.Asset memory reserveData = hub.getAsset(assetId);
    LiquidityHub.Spoke memory spokeData = hub.getSpoke(assetId, address(spoke1));

    assertEq(reserveData.totalShares, 0, 'wrong reserve shares pre-supply');
    assertEq(reserveData.totalAssets, 0, 'wrong reserve assets pre-supply');
    assertEq(dai.balanceOf(address(spoke1)), amount, 'wrong user token balance pre-supply');
    assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance pre-supply');

    vm.startPrank(address(spoke1));
    IERC20(dai).transfer(address(hub), amount);
    vm.expectEmit(address(hub));
    emit Supply(assetId, address(spoke1), amount);
    hub.supply(assetId, amount, 0);
    vm.stopPrank();

    reserveData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));

    assertEq(
      reserveData.totalShares,
      hub.convertAssetsToSharesUp(assetId, amount),
      'wrong reserve total shares post-supply'
    );
    assertEq(reserveData.totalAssets, amount, 'wrong reserve total assets post-supply');
    assertEq(
      spokeData.totalShares,
      hub.convertAssetsToSharesUp(assetId, amount),
      'wrong spoke total shares post-supply'
    );
    assertEq(spokeData.drawnShares, 0, 'wrong spoke shares post-supply');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-supply');
    assertEq(dai.balanceOf(address(hub)), amount, 'wrong hub token balance post-supply');
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
    Spoke.UserConfig memory userData = spoke1.getUser(assetId, user);

    // check reserve index and user interest
    assertEq(reserveData.totalShares, amount, 'wrong reserve shares');
    assertEq(reserveData.totalAssets, amount, 'wrong reserve assets');
    assertEq(userData.supplyShares, amount, 'wrong user shares');
    assertEq(spoke1.getUserDebt(assetId, user), amount, 'wrong user assets');
  }

  function test_fuzz_supply_events(
    uint256 assetId,
    address spoke,
    uint256 amount,
    address onBehalfOf
  ) public {
    if (spoke == address(hub) || spoke == address(0)) return;
    if (onBehalfOf == address(0)) return;

    assetId = bound(assetId, 0, hub.assetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    hub.addSpoke(
      assetId,
      DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max}),
      spoke
    );

    address asset = hub.assetsList(assetId);

    deal(asset, spoke, amount);

    vm.startPrank(spoke);

    /// @dev Transfer is done by Spoke to Hub prior to supply logic
    /// therefore token transfer event won't be part of this flow
    // IERC20(asset).approve(address(hub), amount);
    // vm.expectEmit(asset);
    // emit Transfer(spoke, address(hub), amount);

    vm.expectEmit(address(hub));
    emit Supply(assetId, spoke, amount);

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

    deal(address(dai), address(spoke1), amount);

    LiquidityHub.Asset memory assetData = hub.getAsset(assetId);
    LiquidityHub.Spoke memory spokeData = hub.getSpoke(assetId, address(spoke1));

    assertEq(assetData.totalShares, 0, 'wrong hub total shares pre-supply');
    assertEq(assetData.totalAssets, 0, 'wrong hub total assets pre-supply');
    assertEq(spokeData.totalShares, 0, 'wrong hub total shares pre-supply');
    assertEq(spokeData.drawnShares, 0, 'wrong hub drawn shares pre-supply');

    assertEq(dai.balanceOf(address(spoke1)), amount, 'wrong spoke token balance pre-supply');
    assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance pre-supply');

    Utils.supply(vm, hub, assetId, address(spoke1), amount, address(spoke1));

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));

    assertEq(
      assetData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(assetId, amount),
      'wrong total shares post-supply'
    );
    assertEq(assetData.totalAssets, amount, 'wrong total assets post-supply');
    assertEq(
      spokeData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesDown(assetId, amount),
      'wrong hub total shares post-supply'
    );
    assertEq(spokeData.drawnShares, 0, 'wrong hub drawn shares post-supply');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-supply');
    assertEq(dai.balanceOf(address(hub)), amount, 'wrong hub token balance post-supply');

    // Index grows but same block, no interest acc
    uint256 newBorrowRate = 0.1e27; // 10.00%
    vm.mockCall(
      address(hub),
      abi.encodeWithSelector(ILiquidityHub.getBaseInterestRate.selector),
      abi.encode(newBorrowRate)
    );

    // Time flies, no interest acc
    vm.warp(block.timestamp + 1e4);

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));

    assertEq(
      assetData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(assetId, amount),
      'wrong total shares post time warp'
    );
    assertEq(assetData.totalAssets, amount, 'wrong total assets post time warp');
    assertEq(
      spokeData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesDown(assetId, amount),
      'wrong spoke total shares post time warp'
    );
    assertEq(spokeData.drawnShares, 0, 'wrong spoke drawn shares post time warp');

    // state update due to reserve operation
    // TODO helper for reserve state update
    // total assets do not change because no interest acc yet
    uint256 prevTotalAssets = assetData.totalAssets;

    uint256 spoke2SupplyShares = 1; // minimum for 1 share
    uint256 spoke2SupplyAssets = ILiquidityHub(address(hub)).convertSharesToAssetsDown(
      assetId,
      spoke2SupplyShares
    );

    uint256 newSpoke1Assets = amount.toAssetsDown(
      assetData.totalAssets + spoke2SupplyAssets,
      assetData.totalShares + spoke2SupplyShares
    );

    deal(address(dai), address(spoke2), spoke2SupplyAssets);
    Utils.supply(vm, hub, assetId, address(spoke2), spoke2SupplyAssets, address(spoke2));

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));
    LiquidityHub.Spoke memory spoke2Data = hub.getSpoke(assetId, address(spoke2));

    assertEq(assetData.totalShares, amount + spoke2SupplyShares, 'wrong final total shares');
    assertEq(
      assetData.totalAssets,
      prevTotalAssets + spoke2SupplyAssets,
      'wrong final total assets'
    );
    assertEq(assetData.drawnShares, 0, 'wrong final total drawn');
    assertEq(
      spokeData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesDown(assetId, amount),
      'wrong final spoke total shares'
    );
    assertEq(spokeData.drawnShares, 0, 'wrong final spoke drawn shares');
    assertEq(spoke2Data.totalShares, spoke2SupplyShares, 'wrong final spoke2 total shares');
    assertEq(spoke2Data.drawnShares, 0, 'wrong final spoke2 drawn shares');
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
      userData = spoke1.getUser(assetId, user);

      // check reserve index and user interest
      assertEq(reserveData.totalShares, p.totalShares, 'wrong reserve shares');
      assertEq(reserveData.totalAssets, p.totalAssets, 'wrong reserve assets');
      assertEq(userData.supplyShares, amount, 'wrong user shares');
      assertEq(spoke1.getUserDebt(assetId, user), p.userAssets, 'wrong user assets');

      // rate increases
      uint256 newBorrowRate = (borrowRateChange * i) % 2e27; // randomize, 200.00% max
      vm.mockCall(
        address(spoke1),
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
    deal(address(dai), address(spoke1), amount);
    Utils.supply(vm, hub, assetId, address(spoke1), amount, address(spoke1));

    LiquidityHub.Asset memory assetData = hub.getAsset(assetId);
    LiquidityHub.Spoke memory spokeData = hub.getSpoke(assetId, address(spoke1));

    assertEq(
      assetData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(assetId, amount),
      'wrong total shares pre-withdraw'
    );
    assertEq(assetData.totalAssets, amount, 'wrong total assets pre-withdraw');
    assertEq(
      spokeData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesDown(assetId, amount),
      'wrong spoke total shares pre-withdraw'
    );
    assertEq(spokeData.drawnShares, 0, 'wrong spoke drawn shares pre-withdraw');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-withdraw');
    assertEq(dai.balanceOf(address(hub)), amount, 'wrong hub token balance pre-withdraw');

    vm.startPrank(address(spoke1));
    vm.expectEmit(address(hub));
    emit Withdraw(assetId, address(spoke1), address(spoke1), amount);
    hub.withdraw(assetId, address(spoke1), amount, 0);
    vm.stopPrank();

    assetData = hub.getAsset(assetId);

    assertEq(assetData.totalShares, 0);
    assertEq(assetData.totalAssets, 0);
    assertEq(dai.balanceOf(address(spoke1)), amount, 'wrong spoke token balance post-withdraw');
    assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance post-withdraw');
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

    vm.expectEmit(asset);
    emit Transfer(address(hub), to, amount);

    vm.expectEmit(address(hub));
    emit Withdraw(assetId, user, to, amount);

    Utils.withdraw(vm, hub, assetId, user, amount, to);
  }

  function test_withdraw_all_with_interest() public {
    // TODO User supplies X and withdraws more than X because there is some yield
  }

  function test_withdraw_revertsWith_zero_supplied() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 1;

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw(assetId, address(spoke1), amount, 0);
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(dai), address(spoke1), amount);
    Utils.supply(vm, hub, assetId, address(spoke1), amount, address(spoke1));

    LiquidityHub.Asset memory reserveData = hub.getAsset(assetId);

    assertEq(reserveData.totalShares, amount);
    assertEq(reserveData.totalAssets, amount);
    assertEq(dai.balanceOf(address(spoke1)), 0);
    assertEq(dai.balanceOf(address(hub)), amount);

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw(assetId, address(spoke1), amount + 1, 0);

    // advance time, but no accumulation
    vm.warp(block.timestamp + 1e18);
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw(assetId, address(spoke1), amount + 1, 0);

    reserveData = hub.getAsset(assetId);

    assertEq(
      reserveData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(assetId, amount)
    );
    assertEq(reserveData.totalAssets, amount);
    assertEq(dai.balanceOf(address(spoke1)), 0);
    assertEq(dai.balanceOf(address(hub)), amount);
  }

  function test_withdraw_revertsWith_not_available_liquidity() public {
    uint256 daiId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(dai), address(spoke1), amount);
    Utils.supply(vm, hub, daiId, address(spoke1), amount, address(spoke1));

    // spoke1 draw all of dai reserve liquidity
    Utils.draw(vm, hub, daiId, address(spoke1), amount, address(spoke1));

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw(daiId, address(spoke1), amount, 0);
  }

  function test_withdraw_revertsWith_asset_not_active() public {
    uint256 daiId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(dai), address(spoke1), amount);
    Utils.supply(vm, hub, daiId, address(spoke1), amount, address(spoke1));

    _updateActive(daiId, false);

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    hub.withdraw(daiId, address(spoke1), amount, 0);
  }

  // TODO after RP logic is implemented
  function skip_test_user_riskPremium() public {
    uint256 amount = 100e18;
    uint256 ethAssetId = 1;
    uint256 daiAssetId = 0;

    deal(address(eth), USER1, amount);
    Utils.supply(vm, hub, ethAssetId, USER1, amount, USER1);
    spoke1.getUserDebt(ethAssetId, USER1);
    spoke1.getUserDebt(ethAssetId, USER2);
    spoke1.getUserDebt(daiAssetId, USER1);
    spoke1.getUserDebt(daiAssetId, USER2);
    // assertEq(hub.getUserRiskPremium(USER1), 0);
    // assertEq(hub.getUserRiskPremium(USER2), 0);

    deal(address(dai), USER1, amount);
    Utils.supply(vm, hub, daiAssetId, USER1, amount, USER2);
    spoke1.getUserDebt(ethAssetId, USER1);
    spoke1.getUserDebt(ethAssetId, USER2);
    spoke1.getUserDebt(daiAssetId, USER1);
    spoke1.getUserDebt(daiAssetId, USER2);
    // assertEq(hub.getUserRiskPremium(USER1), 0);
    // assertEq(hub.getUserRiskPremium(USER2), 10_00);
  }

  // TODO after RP logic is implemented
  function skip_test_user_riskPremium_update_affects_positions() public {
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

  // TODO after RP logic is implemented
  function skip_test_user_riskPremium_weighted() public {
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

  function test_first_draw() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    // spoke1 supply eth
    deal(address(eth), address(spoke1), ethAmount);
    Utils.supply(vm, hub, ethId, address(spoke1), ethAmount, address(spoke1));

    // spoke2 supply dai
    deal(address(dai), address(spoke2), daiAmount);
    Utils.supply(vm, hub, daiId, address(spoke2), daiAmount, address(spoke2));

    LiquidityHub.Asset memory daiData = hub.getAsset(daiId);
    LiquidityHub.Asset memory ethData = hub.getAsset(ethId);
    LiquidityHub.Spoke memory spoke1Data = hub.getSpoke(ethId, address(spoke1));
    LiquidityHub.Spoke memory spoke2Data = hub.getSpoke(daiId, address(spoke2));

    assertEq(
      daiData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(daiId, daiAmount),
      'wrong hub dai total shares pre-draw'
    );
    assertEq(daiData.totalAssets, daiAmount, 'wrong hub dai total assets pre-draw');
    assertEq(daiData.drawnShares, 0, 'wrong hub dai total assets pre-draw');
    assertEq(
      ethData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(ethId, ethAmount),
      'wrong hub eth total shares pre-draw'
    );
    assertEq(ethData.totalAssets, ethAmount, 'wrong hub eth total assets pre-draw');
    assertEq(ethData.drawnShares, 0, 'wrong hub eth drawn assets pre-draw');
    assertEq(
      spoke1Data.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesDown(ethId, ethAmount),
      'wrong spoke1 total shares pre-draw'
    );
    assertEq(spoke1Data.drawnShares, 0, 'wrong spoke1 drawn shares pre-draw');
    assertEq(
      spoke2Data.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesDown(daiId, daiAmount),
      'wrong spoke2 total shares pre-draw'
    );
    assertEq(spoke2Data.drawnShares, 0, 'wrong spoke2 drawn shares pre-draw');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke1 dai balance pre-draw');
    assertEq(eth.balanceOf(address(spoke2)), 0, 'wrong spoke2 eth balance pre-draw');

    // spoke1 draw half of dai reserve liquidity
    vm.prank(address(spoke1));
    vm.expectEmit(address(hub));
    emit Draw(daiId, address(spoke1), address(spoke1), daiAmount / 2);
    ILiquidityHub(address(hub)).draw(daiId, address(spoke1), daiAmount / 2, 0);

    daiData = hub.getAsset(daiId);
    ethData = hub.getAsset(ethId);
    spoke1Data = hub.getSpoke(ethId, address(spoke1));
    spoke2Data = hub.getSpoke(daiId, address(spoke2));

    assertEq(
      daiData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(daiId, daiAmount),
      'wrong hub dai total shares post-draw'
    );
    assertEq(daiData.totalAssets, daiAmount, 'wrong hub dai total assets post-draw');
    assertEq(ethData.totalAssets, ethAmount, 'wrong hub eth total assets post-draw');
    assertEq(
      ethData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(ethId, ethAmount),
      'wrong hub eth total shares post-draw'
    );
    assertEq(ethData.drawnShares, 0, 'wrong hub eth drawn shares post-draw');

    assertEq(dai.balanceOf(address(spoke1)), daiAmount / 2, 'wrong spoke1 dai final balance');
    assertEq(eth.balanceOf(address(spoke2)), 0, 'wrong spoke2 eth final balance');
  }

  function test_draw_revertsWith_asset_not_active() public {
    uint256 daiId = 2;
    uint256 drawnAmount = 1;
    _updateActive(daiId, false);
    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    ILiquidityHub(address(hub)).draw(daiId, address(spoke1), drawnAmount, 0);
  }

  function test_draw_revertsWith_not_available_liquidity() public {
    uint256 daiId = 0;
    uint256 drawnAmount = 1;
    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.NOT_AVAILABLE_LIQUIDITY);
    ILiquidityHub(address(hub)).draw(daiId, address(spoke1), drawnAmount, 0);
  }

  function test_draw_revertsWith_cap_exceeded() public {
    uint256 daiId = 0;
    uint256 daiAmount = 100e18;
    uint256 drawCap = 1;
    uint256 drawnAmount = drawCap + 1;

    _updateDrawCap(daiId, address(spoke1), drawCap);

    // User2 supply dai
    deal(address(dai), address(spoke2), daiAmount);
    Utils.supply(vm, hub, daiId, address(spoke2), daiAmount, address(spoke2));

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.DRAW_CAP_EXCEEDED);
    ILiquidityHub(address(hub)).draw(daiId, address(spoke1), drawnAmount, 0);
  }

  function test_restore_revertsWith_asset_not_active() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;

    // spoke1 supply eth
    deal(address(eth), address(spoke1), ethAmount);
    Utils.supply(vm, hub, ethId, address(spoke1), ethAmount, address(spoke1));

    // spoke2 supply dai
    deal(address(dai), address(spoke2), daiAmount);
    Utils.supply(vm, hub, daiId, address(spoke2), daiAmount, address(spoke2));

    // spoke1 draw half of dai reserve liquidity
    Utils.draw(vm, hub, daiId, address(spoke1), drawAmount, address(spoke1));

    _updateActive(daiId, false);

    // spoke1 restore all of drawn dai liquidity
    vm.startPrank(address(spoke1));
    IERC20(address(dai)).transfer(address(hub), drawAmount);
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    ILiquidityHub(address(hub)).restore(daiId, drawAmount, 0);
    vm.stopPrank();
  }

  function test_restore_revertsWith_invalid_restore_amount() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;

    // spoke1 supply eth
    deal(address(eth), address(spoke1), ethAmount);
    Utils.supply(vm, hub, ethId, address(spoke1), ethAmount, address(spoke1));

    // spoke2 supply dai
    deal(address(dai), address(spoke2), daiAmount);
    Utils.supply(vm, hub, daiId, address(spoke2), daiAmount, address(spoke2));

    // spoke1 draw half of dai reserve liquidity
    Utils.draw(vm, hub, daiId, address(spoke1), drawAmount, address(spoke1));

    // spoke1 restore invalid amount > drawn amount
    vm.startPrank(address(spoke1));
    IERC20(address(dai)).transfer(address(hub), drawAmount);
    vm.expectRevert(TestErrors.INVALID_RESTORE_AMOUNT);
    ILiquidityHub(address(hub)).restore(daiId, drawAmount + 1, 0);
    vm.stopPrank();
  }

  function test_restore() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;
    uint256 restoreAmount = daiAmount / 4;

    // spoke1 supply eth
    deal(address(eth), address(spoke1), ethAmount);
    Utils.supply(vm, hub, ethId, address(spoke1), ethAmount, address(spoke1));

    // spoke2 supply dai
    deal(address(dai), address(spoke2), daiAmount);
    Utils.supply(vm, hub, daiId, address(spoke2), daiAmount, address(spoke2));

    // spoke1 draw half of dai reserve liquidity
    Utils.draw(vm, hub, daiId, address(spoke1), drawAmount, address(spoke1));

    // spoke1 restore half of drawn dai liquidity
    vm.startPrank(address(spoke1));
    IERC20(address(dai)).transfer(address(hub), restoreAmount);
    vm.expectEmit(address(hub));
    emit Restore(daiId, address(spoke1), restoreAmount);
    ILiquidityHub(address(hub)).restore(daiId, restoreAmount, 0);
    vm.stopPrank();

    LiquidityHub.Asset memory daiData = hub.getAsset(daiId);
    LiquidityHub.Asset memory ethData = hub.getAsset(ethId);
    LiquidityHub.Spoke memory spoke1EthData = hub.getSpoke(ethId, address(spoke1));
    LiquidityHub.Spoke memory spoke1DaiData = hub.getSpoke(daiId, address(spoke1));
    LiquidityHub.Spoke memory spoke2EthData = hub.getSpoke(ethId, address(spoke2));
    LiquidityHub.Spoke memory spoke2DaiData = hub.getSpoke(daiId, address(spoke2));

    assertEq(
      daiData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(daiId, daiAmount),
      'wrong hub dai total shares post-restore'
    );
    assertEq(daiData.totalAssets, daiAmount, 'wrong hub dai total assets post-restore');
    assertEq(ethData.totalAssets, ethAmount, 'wrong hub eth total assets post-restore');
    assertEq(
      ethData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(ethId, ethAmount),
      'wrong hub eth total shares post-restore'
    );
    assertEq(ethData.drawnShares, 0, 'wrong hub eth drawn shares post-restore');
    assertEq(
      spoke1EthData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(ethId, ethAmount),
      'wrong spoke1 total eth shares post-restore'
    );
    assertEq(spoke1EthData.drawnShares, 0, 'wrong spoke1 drawn eth shares post-restore');
    assertEq(spoke1DaiData.totalShares, 0, 'wrong spoke1 total dai shares post-restore');
    assertEq(
      spoke1DaiData.drawnShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesUp(daiId, drawAmount - restoreAmount),
      'wrong spoke1 drawn dai shares post-restore'
    );
    assertEq(spoke2EthData.totalShares, 0, 'wrong spoke2 total eth shares post-restore');
    assertEq(spoke2EthData.drawnShares, 0, 'wrong spoke2 drawn eth shares post-restore');
    assertEq(
      spoke2DaiData.totalShares,
      ILiquidityHub(address(hub)).convertAssetsToSharesDown(daiId, daiAmount),
      'wrong spoke2 total dai shares post-restore'
    );
    assertEq(spoke2DaiData.drawnShares, 0, 'wrong spoke2 drawn dai shares post-restore');

    assertEq(dai.balanceOf(address(hub)), daiAmount - restoreAmount, 'wrong hub dai final balance');
    assertEq(
      dai.balanceOf(address(spoke1)),
      drawAmount - restoreAmount,
      'wrong spoke1 dai final balance'
    );
    assertEq(dai.balanceOf(address(spoke2)), 0, 'wrong spoke2 dai final balance');

    assertEq(eth.balanceOf(address(hub)), ethAmount, 'wrong hub eth final balance');
    assertEq(eth.balanceOf(address(spoke1)), 0, 'wrong spoke1 eth final balance');
    assertEq(eth.balanceOf(address(spoke2)), 0, 'wrong spoke2 eth final balance');
  }

  function test_addSpoke() public {
    uint256 daiId = 0;

    vm.expectEmit(address(hub));
    emit SpokeAdded(daiId, address(spoke1));
    hub.addSpoke(daiId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(spoke1));

    DataTypes.SpokeConfig memory spokeData = hub.getSpokeConfig(daiId, address(spoke1));
    assertEq(spokeData.supplyCap, 1, 'wrong spoke supply cap');
    assertEq(spokeData.drawCap, 1, 'wrong spoke draw cap');
  }

  function test_addSpoke_revertsWith_invalid_spoke() public {
    uint256 daiId = 0;
    vm.expectRevert(TestErrors.INVALID_SPOKE);
    hub.addSpoke(daiId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(0));
  }

  function test_addSpokes() public {
    uint256 daiId = 0;
    uint256 ethId = 1;

    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = 0;
    assetIds[1] = 1;

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
    spokeConfigs[1] = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

    vm.expectEmit(address(hub));
    emit SpokeAdded(daiId, address(spoke1));
    emit SpokeAdded(ethId, address(spoke1));
    hub.addSpokes(assetIds, spokeConfigs, address(spoke1));

    DataTypes.SpokeConfig memory daiSpokeData = hub.getSpokeConfig(daiId, address(spoke1));
    DataTypes.SpokeConfig memory ethSpokeData = hub.getSpokeConfig(ethId, address(spoke1));

    assertEq(daiSpokeData.supplyCap, 1, 'wrong dai spoke supply cap');
    assertEq(daiSpokeData.drawCap, 2, 'wrong dai spoke draw cap');

    assertEq(ethSpokeData.supplyCap, 3, 'wrong eth spoke supply cap');
    assertEq(ethSpokeData.drawCap, 4, 'wrong eth spoke draw cap');
  }

  function test_addSpokes_revertsWith_invalid_spoke() public {
    uint256 daiId = 0;
    uint256 ethId = 1;

    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = 0;
    assetIds[1] = 1;

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
    spokeConfigs[1] = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

    vm.expectRevert(TestErrors.INVALID_SPOKE);
    hub.addSpokes(assetIds, spokeConfigs, address(0));
  }

  // function _updateLiquidityPremium(uint256 assetId, uint256 newLiquidityPremium) internal {
  //   DataTypes.AssetConfig memory reserveConfig = hub.getAsset(assetId).config;
  //   reserveConfig.liquidityPremium = newLiquidityPremium;
  //   hub.updateAsset(assetId, reserveConfig);
  // }

  function _updateActive(uint256 assetId, bool newActive) internal {
    DataTypes.AssetConfig memory reserveConfig = hub.getAsset(assetId).config;
    reserveConfig.active = newActive;
    hub.updateAssetConfig(assetId, reserveConfig);
  }

  function _updateDrawCap(uint256 assetId, address spoke, uint256 newDrawCap) internal {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.drawCap = newDrawCap;
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }

  function _updateSupplyCap(uint256 assetId, address spoke, uint256 newSupplyCap) internal {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.supplyCap = newSupplyCap;
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }
}
