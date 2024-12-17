// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';
import '../mocks/MockSpokeExposedMethods.sol';

contract LiquidationTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  MockSpokeExposedMethods mockSpoke1;
  MockSpokeExposedMethods mockSpoke2;

  function setUp() public override {
    super.setUp();

    mockSpoke1 = new MockSpokeExposedMethods(address(hub), address(oracle));
    mockSpoke2 = new MockSpokeExposedMethods(address(hub), address(oracle));

    address[] memory spokes = new address[](2);
    spokes[0] = address(mockSpoke1);
    spokes[1] = address(mockSpoke2);
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

    // Add dai
    uint256 daiAssetId = 0;
    reserveConfigs[0] = Spoke.ReserveConfig({
      lt: 0.75e4,
      lb: 1.05e4,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.8e4,
      lb: 1.03e4,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
    Utils.addAssetAndSpokes(
      hub,
      address(dai),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    MockPriceOracle(address(oracle)).setAssetPrice(daiAssetId, 1e8);
    irStrategy.setInterestRateParams(
      daiAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 9000, // 90.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );

    // Add eth
    uint256 ethAssetId = 1;
    reserveConfigs[0] = Spoke.ReserveConfig({
      lt: 0.8e4,
      lb: 1.02e4,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.76e4,
      lb: 1.01e4,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
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
      ethAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 9000, // 90.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );

    // Add USDC
    uint256 usdcAssetId = 2;
    reserveConfigs[0] = Spoke.ReserveConfig({
      lt: 0.78e4,
      lb: 1.06e4,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.72e4,
      lb: 1.08e4,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
    Utils.addAssetAndSpokes(
      hub,
      address(usdc),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    MockPriceOracle(address(oracle)).setAssetPrice(usdcAssetId, 1e8);
    irStrategy.setInterestRateParams(
      usdcAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 9000, // 90.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );

    // Add WBTC
    uint256 wbtcAssetId = 3;
    reserveConfigs[0] = Spoke.ReserveConfig({
      lt: 0.85e4,
      lb: 1.05e4,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.84e4,
      lb: 1.025e4,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
    Utils.addAssetAndSpokes(
      hub,
      address(wbtc),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    MockPriceOracle(address(oracle)).setAssetPrice(wbtcAssetId, 50_000e8);
    irStrategy.setInterestRateParams(
      wbtcAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 9000, // 90.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );
  }

  function test_liquidationCall_revertsWith_invalid_debt_to_cover() public {
    uint256 ethAssetId = 1; // collateral asset
    uint256 daiAssetId = 0; // debt asset
    uint256 debtToCover = 0;

    vm.prank(LIQUIDATOR);
    vm.expectRevert(TestErrors.INVALID_DEBT_TO_COVER);
    mockSpoke1.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  }

  function test_liquidationCall_no_supply_revertsWith_health_factor_not_below_threshold() public {
    uint256 ethAssetId = 1; // collateral asset
    uint256 daiAssetId = 0; // debt asset
    uint256 debtToCover = 1;

    vm.expectRevert(TestErrors.HEALTH_FACTOR_NOT_BELOW_THRESHOLD);
    vm.prank(LIQUIDATOR);
    mockSpoke1.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  }

  function test_liquidationCall_revertsWith_health_factor_not_below_threshold() public {
    uint256 debtToCover = 1;
    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    vm.prank(LIQUIDATOR);
    vm.expectRevert(TestErrors.HEALTH_FACTOR_NOT_BELOW_THRESHOLD);
    mockSpoke1.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  }

  function test_liquidationCall_revertsWith_collateral_cannot_be_liquidated() public {
    uint256 debtToCover = 1;

    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;
    uint256 wbtcAssetId = 3;

    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k
    uint256 wbtcAmount = 1e18; // 1 wbtc -> $50k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

    // USER1 supply wbtc into mockSpoke1, NOT as collateral
    deal(address(wbtc), USER1, wbtcAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER1, wbtcAmount, USER1);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // HF drops below threshold, eth -> 0
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0);

    // wbtc is not set usingAsCollateral
    vm.prank(LIQUIDATOR);
    vm.expectRevert(TestErrors.COLLATERAL_CANNOT_BE_LIQUIDATED);
    mockSpoke1.liquidationCall(wbtcAssetId, daiAssetId, USER1, debtToCover);
  }

  function test_liquidationCall_lt0_revertsWith_collateral_cannot_be_liquidated() public {
    uint256 debtToCover = 1;

    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;
    uint256 wbtcAssetId = 3;

    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k
    uint256 wbtcAmount = 1e18; // 1 wbtc -> $50k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

    // USER1 supply wbtc into mockSpoke1
    deal(address(wbtc), USER1, wbtcAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER1, wbtcAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, wbtcAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // HF drops below threshold, eth -> 0
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0);

    // set LT to 0 for wbtc
    Utils.updateLiquidationThreshold(mockSpoke1, wbtcAssetId, 0);

    // wbtc is not set usingAsCollateral
    vm.prank(LIQUIDATOR);
    vm.expectRevert(TestErrors.COLLATERAL_CANNOT_BE_LIQUIDATED);
    mockSpoke1.liquidationCall(usdcAssetId, daiAssetId, USER1, debtToCover);
  }

  function test_liquidationCall_revertsWith_specified_currency_not_borrowed_by_user() public {
    uint256 debtToCover = 1;

    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;
    uint256 wbtcAssetId = 3;

    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // HF drops below threshold, eth -> 0
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0);

    console2.log('hf %e', mockSpoke1.getHealthFactor(USER1));

    // wbtc is not set usingAsCollateral
    vm.prank(LIQUIDATOR);
    vm.expectRevert(TestErrors.SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER);
    mockSpoke1.liquidationCall(daiAssetId, wbtcAssetId, USER1, debtToCover);
  }

  struct TestLiquidationCallLocalParams {
    Spoke.UserConfig user1DaiData0;
    Spoke.UserConfig user1EthData0;
    Spoke.UserConfig user1UsdcData0;
    Spoke.UserConfig user2UsdcData0;
    Spoke.Reserve reserveDaiData0;
    LiquidityHub.Spoke mockSpoke1DaiData0;
    LiquidityHub.Spoke mockSpoke1EthData0;
    LiquidityHub.Spoke mockSpoke1UsdcData0;
    Spoke.UserConfig user1DaiData1;
    Spoke.UserConfig user1EthData1;
    Spoke.UserConfig user1UsdcData1;
    Spoke.UserConfig user2UsdcData1;
    LiquidityHub.Spoke mockSpoke1DaiData1;
    LiquidityHub.Spoke mockSpoke1EthData1;
    LiquidityHub.Spoke mockSpoke1UsdcData1;
    Spoke.Reserve collateralReserve;
    Spoke.Reserve debtReserve;
    uint256 expectedCollateralLiquidated;
    uint256 expectedDebtCovered;
    uint256 expectedProtocolFee;
    uint256 actualDebtCovered;
    uint256[] debtAssetIds;
    uint256[] collateralAssetIds;
    uint256 recoveryThresholdLiquidatableDebt;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 avgLiquidationThreshold;
    uint256 userCollateralBalance;
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationProtocolFeeAmount;
    uint256 expectedDaiTotalSharesRemaining;
    uint256 expectedUsdcDrawnSharesRemaining;
    uint256 hf1;
  }

  /// @dev Test liquidation call with liquidated amount >= user collateral balance, liquidation protocol fee = 0, liquidation bonus = 0
  function test_liquidationCall_gteUserCollateralBalance_zeroLiquidationProtocolFeeZeroLiqBonus()
    public
  {
    uint256 debtToCover = 15_000e18;
    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = debtToCover; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    console2.log('T0 hf %e', mockSpoke1.getHealthFactor(USER1));

    // HF drops below threshold, eth -> $800/eth
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 800e8);
    // if eth -> 0, total collateral: $10k. LT is 0.75
    // total borrowed is $15k, total collateral is $10k
    // current HF = collateral * LT / borrowed = 0.75 * $10k / $15k = 0.5

    Utils.updateLiquidationBonus(mockSpoke1, daiAssetId, 1e4); // set 0% liq bonus

    console2.log('T1 hf %e', mockSpoke1.getHealthFactor(USER1));

    TestLiquidationCallLocalParams memory vars;

    // pre-liquidation
    vars.user1DaiData0 = mockSpoke1.getUser(daiAssetId, USER1);
    vars.mockSpoke1DaiData0 = hub.getSpoke(daiAssetId, address(mockSpoke1));

    vars.user1EthData0 = mockSpoke1.getUser(ethAssetId, USER1);
    vars.mockSpoke1EthData0 = hub.getSpoke(ethAssetId, address(mockSpoke1));

    vars.user1UsdcData0 = mockSpoke1.getUser(usdcAssetId, USER1);
    vars.user2UsdcData0 = mockSpoke1.getUser(usdcAssetId, USER2);
    vars.mockSpoke1UsdcData0 = hub.getSpoke(usdcAssetId, address(mockSpoke1));

    // dai
    assertEq(
      vars.user1DaiData0.usingAsCollateral,
      true,
      'Unexpected T0 user1 dai usingAsCollateral'
    );
    assertEq(
      vars.user1DaiData0.supplyShares,
      vars.mockSpoke1DaiData0.totalShares,
      'Unexpected T0 user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData0.debtShares, 0, 'Unexpected T0 user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData0.totalShares,
      hub.convertAssetsToSharesDown(daiAssetId, daiAmount),
      'Unexpected T0 mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData0.drawnShares, 0, 'Unexpected T0 mockSpoke1 dai drawnShares');
    // eth
    assertEq(
      vars.user1EthData0.usingAsCollateral,
      true,
      'Unexpected T0 user1 eth usingAsCollateral'
    );
    assertEq(
      vars.user1EthData0.supplyShares,
      vars.mockSpoke1EthData0.totalShares,
      'Unexpected T0 user1 eth supplyShares'
    );
    assertEq(vars.user1EthData0.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData0.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected T0 mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData0.drawnShares, 0, 'Unexpected T0 mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData0.usingAsCollateral,
      false,
      'Unexpected T0 user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData0.supplyShares,
      vars.mockSpoke1UsdcData0.totalShares,
      'Unexpected T0 user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData0.debtShares,
      vars.user2UsdcData0.supplyShares,
      'Unexpected T0 user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData0.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected T0 mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData0.drawnShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected T0 mockSpoke1 usdc drawnShares'
    );

    // action: liquidation
    deal(address(usdc), LIQUIDATOR, debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), debtToCover);

    vars.collateralReserve = mockSpoke1.getReserve(daiAssetId);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      ,

    ) = mockSpoke1.calculateUserAccountData(USER1);

    vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      debtToCover,
      USER1,
      usdcAssetId,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.collateralReserve
    );

    vars.collateralReserve = mockSpoke1.getReserve(daiAssetId);
    vars.debtReserve = mockSpoke1.getReserve(usdcAssetId);
    vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(daiAssetId, USER1);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      vars.collateralReserve,
      vars.debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.collateralReserve.config.lb // TODO: fetch from a getter?
    );

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: daiAssetId,
      debtAssetId: usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.actualDebtToLiquidate,
      actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(daiAssetId, usdcAssetId, USER1, debtToCover);
    vm.stopPrank();

    console2.log('Tf hf %e', mockSpoke1.getHealthFactor(USER1));

    // post-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(daiAssetId, address(mockSpoke1));
    vars.user1EthData1 = mockSpoke1.getUser(ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(ethAssetId, address(mockSpoke1));
    vars.user1UsdcData1 = mockSpoke1.getUser(usdcAssetId, USER1);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(usdcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = debtToCover - usdc.balanceOf(LIQUIDATOR);
    vars.expectedDaiTotalSharesRemaining =
      vars.mockSpoke1DaiData0.totalShares -
      hub.convertAssetsToSharesDown(daiAssetId, vars.actualCollateralToLiquidate);
    vars.expectedUsdcDrawnSharesRemaining =
      vars.mockSpoke1UsdcData0.drawnShares -
      hub.convertAssetsToSharesDown(usdcAssetId, vars.actualDebtCovered);
    vars.hf1 = mockSpoke1.getHealthFactor(USER1);

    // dai
    assertEq(vars.user1DaiData1.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.mockSpoke1DaiData1.totalShares,
      vars.expectedDaiTotalSharesRemaining,
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData1.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData1.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      vars.mockSpoke1UsdcData1.totalShares -
        hub.convertAssetsToSharesDown(usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    assertEq(vars.hf1, 1e18, 'Unexpected user1 final health factor');

    // liquidator
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      vars.actualCollateralToLiquidate,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      0,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  /// @dev Test liquidation call with liquidated amount >= user collateral balance, liquidation protocol fee = 0
  function test_liquidationCall_gteUserCollateralBalance_zeroLiquidationProtocolFeeNonZeroLiqBonus()
    public
  {
    uint256 debtToCover = 15_000e18;
    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = debtToCover; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    console2.log('T0 hf %e', mockSpoke1.getHealthFactor(USER1));

    // HF drops below threshold, eth -> $800/eth
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 800e8);
    // if eth -> 0, total collateral: $10k. LT is 0.75
    // total borrowed is $15k, total collateral is $10k
    // current HF = collateral * LT / borrowed = 0.75 * $10k / $15k = 0.5

    console2.log('T1 hf %e', mockSpoke1.getHealthFactor(USER1));

    TestLiquidationCallLocalParams memory vars;

    // pre-liquidation
    vars.user1DaiData0 = mockSpoke1.getUser(daiAssetId, USER1);
    vars.mockSpoke1DaiData0 = hub.getSpoke(daiAssetId, address(mockSpoke1));

    vars.user1EthData0 = mockSpoke1.getUser(ethAssetId, USER1);
    vars.mockSpoke1EthData0 = hub.getSpoke(ethAssetId, address(mockSpoke1));

    vars.user1UsdcData0 = mockSpoke1.getUser(usdcAssetId, USER1);
    vars.user2UsdcData0 = mockSpoke1.getUser(usdcAssetId, USER2);
    vars.mockSpoke1UsdcData0 = hub.getSpoke(usdcAssetId, address(mockSpoke1));

    // dai
    assertEq(
      vars.user1DaiData0.usingAsCollateral,
      true,
      'Unexpected T0 user1 dai usingAsCollateral'
    );
    assertEq(
      vars.user1DaiData0.supplyShares,
      vars.mockSpoke1DaiData0.totalShares,
      'Unexpected T0 user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData0.debtShares, 0, 'Unexpected T0 user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData0.totalShares,
      hub.convertAssetsToSharesDown(daiAssetId, daiAmount),
      'Unexpected T0 mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData0.drawnShares, 0, 'Unexpected T0 mockSpoke1 dai drawnShares');
    // eth
    assertEq(
      vars.user1EthData0.usingAsCollateral,
      true,
      'Unexpected T0 user1 eth usingAsCollateral'
    );
    assertEq(
      vars.user1EthData0.supplyShares,
      vars.mockSpoke1EthData0.totalShares,
      'Unexpected T0 user1 eth supplyShares'
    );
    assertEq(vars.user1EthData0.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData0.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected T0 mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData0.drawnShares, 0, 'Unexpected T0 mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData0.usingAsCollateral,
      false,
      'Unexpected T0 user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData0.supplyShares,
      vars.mockSpoke1UsdcData0.totalShares,
      'Unexpected T0 user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData0.debtShares,
      vars.user2UsdcData0.supplyShares,
      'Unexpected T0 user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData0.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected T0 mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData0.drawnShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected T0 mockSpoke1 usdc drawnShares'
    );

    // action: liquidation
    deal(address(usdc), LIQUIDATOR, debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), debtToCover);

    vars.collateralReserve = mockSpoke1.getReserve(daiAssetId);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      ,

    ) = mockSpoke1.calculateUserAccountData(USER1);

    vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      debtToCover,
      USER1,
      usdcAssetId,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.collateralReserve
    );

    vars.collateralReserve = mockSpoke1.getReserve(daiAssetId);
    vars.debtReserve = mockSpoke1.getReserve(usdcAssetId);
    vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(daiAssetId, USER1);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      vars.collateralReserve,
      vars.debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.collateralReserve.config.lb // TODO: fetch from a getter?
    );

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: daiAssetId,
      debtAssetId: usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.actualDebtToLiquidate,
      actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(daiAssetId, usdcAssetId, USER1, debtToCover);
    vm.stopPrank();

    console2.log('Tf hf %e', mockSpoke1.getHealthFactor(USER1));

    // post-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(daiAssetId, address(mockSpoke1));
    vars.user1EthData1 = mockSpoke1.getUser(ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(ethAssetId, address(mockSpoke1));
    vars.user1UsdcData1 = mockSpoke1.getUser(usdcAssetId, USER1);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(usdcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = debtToCover - usdc.balanceOf(LIQUIDATOR);
    vars.expectedDaiTotalSharesRemaining =
      vars.mockSpoke1DaiData0.totalShares -
      hub.convertAssetsToSharesDown(daiAssetId, vars.actualCollateralToLiquidate);
    vars.expectedUsdcDrawnSharesRemaining =
      vars.mockSpoke1UsdcData0.drawnShares -
      hub.convertAssetsToSharesDown(usdcAssetId, vars.actualDebtCovered);

    // dai
    assertEq(vars.user1DaiData1.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.mockSpoke1DaiData1.totalShares,
      vars.expectedDaiTotalSharesRemaining,
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData1.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData1.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      vars.mockSpoke1UsdcData1.totalShares -
        hub.convertAssetsToSharesDown(usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    assertEq(
      mockSpoke1.getHealthFactor(USER1),
      mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
      'Unexpected user1 final health factor'
    );

    // liquidator
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      vars.actualCollateralToLiquidate,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      0,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  function test_liquidationCall_gteUserCollateralBalance_nonZeroLiquidationProtocolFee() public {
    uint256 debtToCover = 15_000e18;
    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;
    uint256 newLpfp = 200; // in BPS, ie 2%

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = debtToCover; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);
    Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, daiAssetId, newLpfp);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // HF drops below threshold, eth -> $0.10
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0e8);
    // if eth -> 0, total collateral: $10k. LT is 0.75
    // total borrowed is $15k, total collateral is $10k
    // HF = collateral * LT / borrowed = 0.75 * $10k / $15k = 0.5

    TestLiquidationCallLocalParams memory vars;

    // pre-liquidation
    vars.user1DaiData0 = mockSpoke1.getUser(daiAssetId, USER1);
    vars.mockSpoke1DaiData0 = hub.getSpoke(daiAssetId, address(mockSpoke1));
    vars.reserveDaiData0 = mockSpoke1.getReserve(daiAssetId);

    vars.user1EthData0 = mockSpoke1.getUser(ethAssetId, USER1);
    vars.mockSpoke1EthData0 = hub.getSpoke(ethAssetId, address(mockSpoke1));

    vars.user1UsdcData0 = mockSpoke1.getUser(usdcAssetId, USER1);
    vars.user2UsdcData0 = mockSpoke1.getUser(usdcAssetId, USER2);
    vars.mockSpoke1UsdcData0 = hub.getSpoke(usdcAssetId, address(mockSpoke1));

    vars.expectedCollateralLiquidated = hub.convertSharesToAssetsDown(
      daiAssetId,
      vars.mockSpoke1DaiData0.totalShares
    );
    vars.expectedDebtCovered = _getExpectedDebtCovered(
      daiAssetId,
      usdcAssetId,
      vars.expectedCollateralLiquidated
    );
    (, , vars.expectedProtocolFee) = _getExpectedCollateralLiquidated(
      daiAssetId,
      usdcAssetId,
      vars.expectedDebtCovered
    );

    assertEq(
      vars.reserveDaiData0.config.lpfp,
      newLpfp,
      'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
    );

    // dai
    assertEq(vars.user1DaiData0.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.user1DaiData0.supplyShares,
      vars.mockSpoke1DaiData0.totalShares,
      'Unexpected user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData0.debtShares, 0, 'Unexpected user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData0.totalShares,
      hub.convertAssetsToSharesDown(daiAssetId, daiAmount),
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData0.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData0.usingAsCollateral, true, 'Unexpected user1 eth usingAsCollateral');
    assertEq(
      vars.user1EthData0.supplyShares,
      vars.mockSpoke1EthData0.totalShares,
      'Unexpected user1 eth supplyShares'
    );
    assertEq(vars.user1EthData0.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData0.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData0.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData0.usingAsCollateral,
      false,
      'Unexpected user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData0.supplyShares,
      vars.mockSpoke1UsdcData0.totalShares,
      'Unexpected user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData0.debtShares,
      vars.user2UsdcData0.supplyShares,
      'Unexpected user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData0.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData0.drawnShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc drawnShares'
    );

    // action: liquidation
    deal(address(usdc), LIQUIDATOR, debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), debtToCover);

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: daiAssetId,
      debtAssetId: usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.expectedDebtCovered,
      actualCollateralToLiquidate: vars.expectedCollateralLiquidated - vars.expectedProtocolFee,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(daiAssetId, usdcAssetId, USER1, debtToCover);
    vm.stopPrank();

    // post-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(daiAssetId, address(mockSpoke1));
    vars.user1EthData1 = mockSpoke1.getUser(ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(ethAssetId, address(mockSpoke1));
    vars.user1UsdcData1 = mockSpoke1.getUser(usdcAssetId, USER1);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(usdcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = debtToCover - usdc.balanceOf(LIQUIDATOR);

    // dai
    assertEq(vars.user1DaiData1.usingAsCollateral, false, 'Unexpected user1 dai usingAsCollateral');
    assertEq(vars.mockSpoke1DaiData1.totalShares, 0, 'Unexpected mockSpoke1 dai totalShares');
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData1.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData1.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      vars.mockSpoke1UsdcData1.totalShares -
        hub.convertAssetsToSharesDown(usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    assertEq(mockSpoke1.getHealthFactor(USER1), 0, 'Unexpected user1 final health factor'); // only bad debt remains

    // liquidator
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      vars.expectedCollateralLiquidated - vars.expectedProtocolFee,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      vars.expectedProtocolFee,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  function skip_test_liquidationCall_gteUserCollateralBalance_ltCollateralBalance() public {
    uint256 debtToCover = 5_000e18;
    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;
    uint256 newLpfp = 200; // in BPS, ie 2%

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);
    Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, daiAssetId, newLpfp);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // HF drops below threshold, eth -> $0.10
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0e8);
    // if eth -> 0, total collateral: $10k. LT is 0.75
    // total borrowed is $15k, total collateral is $10k
    // HF = collateral * LT / borrowed = 0.75 * $10k / $15k = 0.5
    // if paying back $10k in debt, collateral to liquidate = $10k

    TestLiquidationCallLocalParams memory vars;

    // pre-liquidation
    vars.user1DaiData0 = mockSpoke1.getUser(daiAssetId, USER1);
    vars.mockSpoke1DaiData0 = hub.getSpoke(daiAssetId, address(mockSpoke1));
    vars.reserveDaiData0 = mockSpoke1.getReserve(daiAssetId);

    vars.user1EthData0 = mockSpoke1.getUser(ethAssetId, USER1);
    vars.mockSpoke1EthData0 = hub.getSpoke(ethAssetId, address(mockSpoke1));

    vars.user1UsdcData0 = mockSpoke1.getUser(usdcAssetId, USER1);
    vars.user2UsdcData0 = mockSpoke1.getUser(usdcAssetId, USER2);
    vars.mockSpoke1UsdcData0 = hub.getSpoke(usdcAssetId, address(mockSpoke1));

    vars.expectedCollateralLiquidated = debtToCover;
    vars.expectedDebtCovered = _getExpectedDebtCovered(
      daiAssetId,
      usdcAssetId,
      vars.expectedCollateralLiquidated
    );
    (, , vars.expectedProtocolFee) = _getExpectedCollateralLiquidated(
      daiAssetId,
      usdcAssetId,
      vars.expectedDebtCovered
    );

    assertEq(
      vars.reserveDaiData0.config.lpfp,
      newLpfp,
      'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
    );

    // dai
    assertEq(vars.user1DaiData0.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.user1DaiData0.supplyShares,
      vars.mockSpoke1DaiData0.totalShares,
      'Unexpected user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData0.debtShares, 0, 'Unexpected user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData0.totalShares,
      hub.convertAssetsToSharesDown(daiAssetId, daiAmount),
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData0.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData0.usingAsCollateral, true, 'Unexpected user1 eth usingAsCollateral');
    assertEq(
      vars.user1EthData0.supplyShares,
      vars.mockSpoke1EthData0.totalShares,
      'Unexpected user1 eth supplyShares'
    );
    assertEq(vars.user1EthData0.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData0.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData0.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData0.usingAsCollateral,
      false,
      'Unexpected user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData0.supplyShares,
      vars.mockSpoke1UsdcData0.totalShares,
      'Unexpected user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData0.debtShares,
      vars.user2UsdcData0.supplyShares,
      'Unexpected user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData0.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData0.drawnShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc drawnShares'
    );

    // action: liquidation
    deal(address(usdc), LIQUIDATOR, debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), debtToCover);

    // vm.expectEmit(address(mockSpoke1));
    // emit LiquidationCall({
    //   collateralAssetId: daiAssetId,
    //   debtAssetId: usdcAssetId,
    //   user: USER1,
    //   actualDebtToLiquidate: vars.expectedDebtCovered,
    //   actualCollateralToLiquidate: vars.expectedCollateralLiquidated - vars.expectedProtocolFee,
    //   liquidator: LIQUIDATOR
    // });
    mockSpoke1.liquidationCall(daiAssetId, usdcAssetId, USER1, debtToCover);
    vm.stopPrank();

    // post-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(daiAssetId, address(mockSpoke1));
    vars.user1EthData1 = mockSpoke1.getUser(ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(ethAssetId, address(mockSpoke1));
    vars.user1UsdcData1 = mockSpoke1.getUser(usdcAssetId, USER1);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(usdcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = debtToCover - usdc.balanceOf(LIQUIDATOR);

    // dai
    assertEq(vars.user1DaiData1.usingAsCollateral, false, 'Unexpected user1 dai usingAsCollateral');
    // assertEq(vars.mockSpoke1DaiData1.totalShares, 0, 'Unexpected mockSpoke1 dai totalShares');
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData1.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData1.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      vars.mockSpoke1UsdcData1.totalShares -
        hub.convertAssetsToSharesDown(usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    assertEq(mockSpoke1.getHealthFactor(USER1), 0, 'Unexpected user1 final health factor'); // only bad debt remains

    // liquidator
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      vars.expectedCollateralLiquidated - vars.expectedProtocolFee,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      vars.expectedProtocolFee,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  // TODO: basic test with multiple borrowed assets, just liquidating one of them

  // function testLiquidationCallA() public {
  //   uint256 ethAssetId = 1; // collateral asset
  //   uint256 daiAssetId = 0; // debt asset
  //   // borrowed value > supplied value to simulate liquidation scenario
  //   // maxCollateralToLiquidate > userCollateralBalance
  //   uint256 daiAmount = 40e4;
  //   uint256 ethAmount = 10e4;

  //   // User1 supply eth
  //   deal(address(eth), USER1, ethAmount);
  //   Utils.supply(vm, hub, ethAssetId, USER1, ethAmount, USER1);

  //   // User2 supply dai
  //   deal(address(dai), USER2, daiAmount);
  //   Utils.supply(vm, hub, daiAssetId, USER2, daiAmount, USER2);

  //   uint256 portionBorrowed = 2;

  //   // User1 borrow half of dai reserve, ie debt
  //   vm.prank(USER1);
  //   bm.borrow(daiAssetId, daiAmount / portionBorrowed);

  //   uint256 debtToCover = bm.getUserDebt(daiAssetId, USER1);

  //   uint256 expectedDebtCovered = debtToCover;
  //   uint256 expectedCollateralLiquidated = _getExpectedCollateralLiquidated(
  //     ethAssetId,
  //     daiAssetId,
  //     debtToCover
  //   );

  //   deal(address(dai), LIQUIDATOR, expectedDebtCovered);
  //   vm.startPrank(LIQUIDATOR);
  //   dai.approve(address(hub), expectedDebtCovered);

  //   vm.expectEmit(true, true, true, true, address(hub));
  //   emit LiquidationCall(
  //     ethAssetId,
  //     daiAssetId,
  //     USER1,
  //     expectedDebtCovered,
  //     expectedCollateralLiquidated,
  //     LIQUIDATOR
  //   );
  //   hub.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  //   vm.stopPrank();

  //   assertEq(dai.balanceOf(LIQUIDATOR), 0, 'Unexpected liquidator debt asset balance');
  //   assertEq(
  //     eth.balanceOf(LIQUIDATOR),
  //     expectedCollateralLiquidated,
  //     'Unexpected liquidator collateral asset balance'
  //   );
  // }

  /// @return recoveryThresholdLiquidatableDebt liquidatable debt to restore HF to HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD
  /// @return maxLiquidatableDebt max liquidatable debt based on user's total debt
  function _calculateActualDebtToLiquidate(
    address user,
    uint256 debtAssetId,
    uint256[] memory debtAssetIds,
    uint256[] memory collateralAssetIds
  ) internal returns (uint256, uint256) {
    console2.log('------- _calculateActualDebtToLiquidate -------');

    uint256 totalDebtInBaseCurrency = _getTotalDebtInBaseCurrency(debtAssetIds, user);
    (
      uint256 totalCollateralInBaseCurrency,
      uint256 avgLiquidationThreshold
    ) = _getTotalCollateralInBaseCurrencyAndAvgLT(collateralAssetIds, user);

    uint256 recoveryThresholdLiquidatableDebt = (totalDebtInBaseCurrency -
      totalCollateralInBaseCurrency.percentMul(avgLiquidationThreshold).wadDiv(
        mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD()
      )) / MockPriceOracle(address(oracle)).getAssetPrice(debtAssetId);

    uint256 maxLiquidatableDebt = mockSpoke1.getUserDebtInAssets(debtAssetId, user);

    return (recoveryThresholdLiquidatableDebt, maxLiquidatableDebt);
  }

  function _getTotalDebtInBaseCurrency(
    uint256[] memory debtAssetIds,
    address user
  ) internal returns (uint256) {
    uint256 totalDebtInBaseCurrency;
    for (uint256 i; i < debtAssetIds.length; i++) {
      totalDebtInBaseCurrency +=
        mockSpoke1.getUserDebtInAssets(debtAssetIds[i], user) *
        oracle.getAssetPrice(debtAssetIds[i]);
    }
    return totalDebtInBaseCurrency;
  }

  /// @return totalCollateralInBaseCurrency total collateral in base currency
  /// @return avgLiquidationThreshold average liquidation threshold
  function _getTotalCollateralInBaseCurrencyAndAvgLT(
    uint256[] memory collateralAssetIds,
    address user
  ) internal returns (uint256, uint256) {
    uint256 totalCollateralInBaseCurrency;
    uint256 avgLiquidationThreshold;
    for (uint256 i; i < collateralAssetIds.length; i++) {
      Spoke.Reserve memory r = mockSpoke1.getReserve(collateralAssetIds[i]);
      uint256 collateralInBaseCurrency = mockSpoke1.getUserSupplyInAssets(
        collateralAssetIds[i],
        user
      ) * oracle.getAssetPrice(collateralAssetIds[i]);
      totalCollateralInBaseCurrency += collateralInBaseCurrency;
      avgLiquidationThreshold += collateralInBaseCurrency * r.config.lt;
    }
    avgLiquidationThreshold = totalCollateralInBaseCurrency == 0
      ? 0
      : avgLiquidationThreshold / totalCollateralInBaseCurrency;
    return (totalCollateralInBaseCurrency, avgLiquidationThreshold);
  }

  function _getExpectedDebtCovered(
    uint256 collateralAssetId,
    uint256 debtAssetId,
    uint256 collateralAmount
  ) internal returns (uint256) {
    uint256 debtAssetPrice = oracle.getAssetPrice(debtAssetId);

    return
      debtAssetPrice == 0
        ? 0
        : ((oracle.getAssetPrice(collateralAssetId) * collateralAmount) / (debtAssetPrice))
          .percentDiv(mockSpoke1.getLiquidationBonus(collateralAssetId));
  }

  /// @return expectedCollateralLiquidated expected collateral to liquidate (includes lb and lpfp)
  /// @return expectedLiquidationBonus expected liquidation bonus
  /// @return expectedProtocolFee protocol fee
  function _getExpectedCollateralLiquidated(
    uint256 collateralAssetId,
    uint256 debtAssetId,
    uint256 debtAmount
  )
    internal
    returns (
      uint256 expectedCollateralLiquidated,
      uint256 expectedLiquidationBonus,
      uint256 expectedProtocolFee
    )
  {
    uint256 collateralAssetPrice = oracle.getAssetPrice(collateralAssetId);

    expectedCollateralLiquidated = collateralAssetPrice == 0
      ? 0
      : (oracle.getAssetPrice(debtAssetId) * debtAmount).percentMul(
        mockSpoke1.getLiquidationBonus(collateralAssetId)
      ) / collateralAssetPrice;
    expectedLiquidationBonus =
      expectedCollateralLiquidated -
      expectedCollateralLiquidated.percentDiv(mockSpoke1.getLiquidationBonus(collateralAssetId));
    expectedProtocolFee = expectedLiquidationBonus.percentMul(
      mockSpoke1.getLiquidationProtocolFeePercentage(collateralAssetId)
    );
    expectedLiquidationBonus -= expectedProtocolFee;

    // console2.log(
    //   '_getExpectedCollateralLiquidated %e %e %e',
    //   expectedCollateralLiquidated,
    //   expectedLiquidationBonus,
    //   expectedProtocolFee
    // );
  }
}
