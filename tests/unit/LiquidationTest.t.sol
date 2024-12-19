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

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

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

    // wbtc is not set usingAsCollateral
    vm.prank(LIQUIDATOR);
    vm.expectRevert(TestErrors.SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER);
    mockSpoke1.liquidationCall(daiAssetId, wbtcAssetId, USER1, debtToCover);
  }

  struct TestLiquidationCallLocalParams {
    Spoke.UserConfig user1DaiData1;
    Spoke.UserConfig user1EthData1;
    Spoke.UserConfig user1UsdcData1;
    Spoke.UserConfig user2UsdcData1;
    Spoke.UserConfig user1WbtcData1;
    Spoke.UserConfig user2WbtcData1;
    Spoke.UserConfig user1WbtcData2;
    Spoke.Reserve reserveDaiData1;
    Spoke.Reserve reserveEthData1;
    LiquidityHub.Spoke mockSpoke1DaiData1;
    LiquidityHub.Spoke mockSpoke1EthData1;
    LiquidityHub.Spoke mockSpoke1UsdcData1;
    LiquidityHub.Spoke mockSpoke1WbtcData1;
    Spoke.UserConfig user1DaiData2;
    Spoke.UserConfig user1EthData2;
    Spoke.UserConfig user1UsdcData2;
    LiquidityHub.Spoke mockSpoke1DaiData2;
    LiquidityHub.Spoke mockSpoke1EthData2;
    LiquidityHub.Spoke mockSpoke1UsdcData2;
    LiquidityHub.Spoke mockSpoke1WbtcData2;
    Spoke.Reserve collateralReserve;
    Spoke.Reserve debtReserve;
    uint256 actualDebtCovered;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 avgLiquidationThreshold;
    uint256 userCollateralBalance;
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationProtocolFeeAmount;
    uint256 expectedDaiTotalSharesRemaining;
    uint256 expectedEthTotalSharesRemaining;
    uint256 expectedUsdcDrawnSharesRemaining;
    uint256 newLpfp;
    uint256 debtToCover;
    uint256 debtAssetPrice;
    uint256 daiAssetId;
    uint256 ethAssetId;
    uint256 usdcAssetId;
    uint256 wbtcAssetId;
    uint256 hf0;
    uint256 hf1;
    uint256 hf2;
  }

  /// @dev Test liquidation call with liquidated amount >= user collateral balance; liquidation protocol fee = 0; liquidation bonus = 0
  function test_liquidationCall_gteUserCollateralBalance_zeroLiquidationProtocolFeeZeroLiqBonus()
    public
  {
    TestLiquidationCallLocalParams memory vars;

    vars.debtToCover = 15_000e18;
    vars.daiAssetId = 0;
    vars.ethAssetId = 1;
    vars.usdcAssetId = 2;

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = vars.debtToCover; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // T0: supply/borrow
    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

    vars.hf0 = mockSpoke1.getHealthFactor(USER1);
    assertTrue(
      vars.hf0 > mockSpoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
      'Unexpected T1 health factor'
    );

    // T1: eth price drops from $2000 -> $800/eth
    MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);
    vars.hf1 = mockSpoke1.getHealthFactor(USER1);
    assertTrue(vars.hf1 < vars.hf0, 'Unexpected change in user1 hf at T1');

    Utils.updateLiquidationBonus(mockSpoke1, vars.daiAssetId, 1e4); // set 0% liq bonus

    // pre-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));

    vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

    vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

    // dai
    assertEq(
      vars.user1DaiData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 dai usingAsCollateral'
    );
    assertEq(
      vars.user1DaiData1.supplyShares,
      vars.mockSpoke1DaiData1.totalShares,
      'Unexpected T1 user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData1.totalShares,
      hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
      'Unexpected T1 mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
    // eth
    assertEq(
      vars.user1EthData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 eth usingAsCollateral'
    );
    assertEq(
      vars.user1EthData1.supplyShares,
      vars.mockSpoke1EthData1.totalShares,
      'Unexpected T1 user1 eth supplyShares'
    );
    assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected T1 mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData1.usingAsCollateral,
      false,
      'Unexpected T1 user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData1.supplyShares,
      vars.mockSpoke1UsdcData1.totalShares,
      'Unexpected T1 user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData1.debtShares,
      vars.user2UsdcData1.supplyShares,
      'Unexpected T1 user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc drawnShares'
    );

    // T2 / T_final
    // action: liquidation
    deal(address(usdc), LIQUIDATOR, vars.debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), vars.debtToCover);

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      ,

    ) = mockSpoke1.calculateUserAccountData(USER1);

    vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      vars.collateralReserve,
      vars.debtToCover,
      USER1,
      vars.usdcAssetId,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.debtAssetPrice
    );

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
    vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      vars.collateralReserve,
      vars.debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.debtAssetPrice
    );

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: vars.daiAssetId,
      debtAssetId: vars.usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.actualDebtToLiquidate,
      actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
    vm.stopPrank();

    // post-liquidation
    vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
    vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
    vars.expectedDaiTotalSharesRemaining =
      vars.mockSpoke1DaiData1.totalShares -
      hub.convertAssetsToSharesDown(vars.daiAssetId, vars.actualCollateralToLiquidate);
    vars.expectedUsdcDrawnSharesRemaining =
      vars.mockSpoke1UsdcData1.drawnShares -
      hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
    vars.hf2 = mockSpoke1.getHealthFactor(USER1);

    // dai
    assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.mockSpoke1DaiData2.totalShares,
      vars.expectedDaiTotalSharesRemaining,
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData2.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData2.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData2.drawnShares,
      vars.mockSpoke1UsdcData2.totalShares -
        hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    // hf assertions
    assertEq(
      vars.hf2,
      mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
      'Unexpected user1 Tf health factor'
    );
    assertTrue(vars.hf2 > vars.hf1, 'Unexpected final decrease in user1 health factor');

    // liquidator
    assertEq(
      usdc.balanceOf(LIQUIDATOR),
      vars.debtToCover - vars.actualDebtToLiquidate,
      'Unexpected liquidator debt asset balance'
    );
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

  function test_liquidationCall_gteUserCollateralBalance_zeroLiquidationProtocolFee() public {
    TestLiquidationCallLocalParams memory vars;

    vars.debtToCover = 15_000e18;
    vars.daiAssetId = 0;
    vars.ethAssetId = 1;
    vars.usdcAssetId = 2;

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = vars.debtToCover; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // T0
    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

    vars.hf0 = mockSpoke1.getHealthFactor(USER1);
    assertTrue(
      vars.hf0 > mockSpoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
      'Unexpected T1 health factor'
    );

    // T1: eth price drops from $2000 -> $800/eth
    MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);

    vars.hf1 = mockSpoke1.getHealthFactor(USER1);
    assertTrue(vars.hf1 < vars.hf0, 'Unexpected change in user1 hf at T1');

    // pre-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));

    vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

    vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

    // dai
    assertEq(
      vars.user1DaiData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 dai usingAsCollateral'
    );
    assertEq(
      vars.user1DaiData1.supplyShares,
      vars.mockSpoke1DaiData1.totalShares,
      'Unexpected T1 user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData1.totalShares,
      hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
      'Unexpected T1 mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
    // eth
    assertEq(
      vars.user1EthData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 eth usingAsCollateral'
    );
    assertEq(
      vars.user1EthData1.supplyShares,
      vars.mockSpoke1EthData1.totalShares,
      'Unexpected T1 user1 eth supplyShares'
    );
    assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected T1 mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData1.usingAsCollateral,
      false,
      'Unexpected T1 user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData1.supplyShares,
      vars.mockSpoke1UsdcData1.totalShares,
      'Unexpected T1 user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData1.debtShares,
      vars.user2UsdcData1.supplyShares,
      'Unexpected T1 user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc drawnShares'
    );

    // T2 / T_final
    // action: liquidation
    deal(address(usdc), LIQUIDATOR, vars.debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), vars.debtToCover);

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      ,

    ) = mockSpoke1.calculateUserAccountData(USER1);

    vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      vars.collateralReserve,
      vars.debtToCover,
      USER1,
      vars.usdcAssetId,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.debtAssetPrice
    );

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
    vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      vars.collateralReserve,
      vars.debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.debtAssetPrice
    );

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: vars.daiAssetId,
      debtAssetId: vars.usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.actualDebtToLiquidate,
      actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
    vm.stopPrank();

    // post-liquidation
    vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
    vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
    vars.expectedDaiTotalSharesRemaining =
      vars.mockSpoke1DaiData1.totalShares -
      hub.convertAssetsToSharesDown(vars.daiAssetId, vars.actualCollateralToLiquidate);
    vars.expectedUsdcDrawnSharesRemaining =
      vars.mockSpoke1UsdcData1.drawnShares -
      hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
    vars.hf2 = mockSpoke1.getHealthFactor(USER1);

    // dai
    assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.mockSpoke1DaiData2.totalShares,
      vars.expectedDaiTotalSharesRemaining,
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData2.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData2.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData2.drawnShares,
      vars.mockSpoke1UsdcData2.totalShares -
        hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    assertEq(
      mockSpoke1.getHealthFactor(USER1),
      mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
      'Unexpected user1 final health factor'
    );
    // health factor
    assertEq(
      vars.hf2,
      mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
      'Unexpected user1 final health factor'
    );
    assertTrue(vars.hf2 > vars.hf1, 'Unexpected final decrease in user1 health factor');

    // liquidator
    assertEq(
      usdc.balanceOf(LIQUIDATOR),
      vars.debtToCover - vars.actualDebtToLiquidate,
      'Unexpected liquidator debt asset balance'
    );
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      vars.actualCollateralToLiquidate,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      vars.liquidationProtocolFeeAmount,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  function test_liquidationCall_gteUserCollateralBalance() public {
    TestLiquidationCallLocalParams memory vars;

    vars.debtToCover = 15_000e18;
    vars.daiAssetId = 0;
    vars.ethAssetId = 1;
    vars.usdcAssetId = 2;
    vars.newLpfp = 200;

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = vars.debtToCover; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // T0
    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);
    Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.daiAssetId, vars.newLpfp);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

    vars.hf0 = mockSpoke1.getHealthFactor(USER1);

    assertTrue(
      vars.hf0 > mockSpoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
      'Unexpected T1 health factor'
    );

    // T1: eth price drops from $2000 -> $800/eth
    MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);
    vars.hf1 = mockSpoke1.getHealthFactor(USER1);
    assertTrue(vars.hf1 < vars.hf0, 'Unexpected change in user1 hf at T1');

    // pre-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.reserveDaiData1 = mockSpoke1.getReserve(vars.daiAssetId);

    vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

    vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

    assertEq(
      vars.reserveDaiData1.config.lpfp,
      vars.newLpfp,
      'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
    );

    // dai
    assertEq(
      vars.user1DaiData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 dai usingAsCollateral'
    );
    assertEq(
      vars.user1DaiData1.supplyShares,
      vars.mockSpoke1DaiData1.totalShares,
      'Unexpected T1 user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData1.totalShares,
      hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
      'Unexpected T1 mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
    // eth
    assertEq(
      vars.user1EthData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 eth usingAsCollateral'
    );
    assertEq(
      vars.user1EthData1.supplyShares,
      vars.mockSpoke1EthData1.totalShares,
      'Unexpected T1 user1 eth supplyShares'
    );
    assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected T1 mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData1.usingAsCollateral,
      false,
      'Unexpected T1 user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData1.supplyShares,
      vars.mockSpoke1UsdcData1.totalShares,
      'Unexpected T1 user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData1.debtShares,
      vars.user2UsdcData1.supplyShares,
      'Unexpected T1 user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc drawnShares'
    );

    // action: liquidation
    deal(address(usdc), LIQUIDATOR, vars.debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), vars.debtToCover);

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      ,

    ) = mockSpoke1.calculateUserAccountData(USER1);

    vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      vars.collateralReserve,
      vars.debtToCover,
      USER1,
      vars.usdcAssetId,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.debtAssetPrice
    );

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
    vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      vars.collateralReserve,
      vars.debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.debtAssetPrice
    );

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: vars.daiAssetId,
      debtAssetId: vars.usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.actualDebtToLiquidate,
      actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
    vm.stopPrank();

    // post-liquidation
    vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));

    vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

    vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

    vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
    vars.expectedDaiTotalSharesRemaining =
      vars.mockSpoke1DaiData1.totalShares -
      hub.convertAssetsToSharesDown(
        vars.daiAssetId,
        vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
      );
    vars.expectedUsdcDrawnSharesRemaining =
      vars.mockSpoke1UsdcData1.drawnShares -
      hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
    vars.hf2 = mockSpoke1.getHealthFactor(USER1);

    // dai
    assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.mockSpoke1DaiData2.totalShares,
      vars.expectedDaiTotalSharesRemaining,
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData2.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData2.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData2.drawnShares,
      vars.mockSpoke1UsdcData2.totalShares -
        hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    // health factor
    assertEq(
      vars.hf2,
      mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
      'Unexpected user1 final health factor'
    );
    assertTrue(vars.hf2 > vars.hf1, 'Unexpected final decrease in user1 health factor');

    // liquidator
    assertEq(
      usdc.balanceOf(LIQUIDATOR),
      vars.debtToCover - vars.actualDebtToLiquidate,
      'Unexpected liquidator debt asset balance'
    );
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      vars.actualCollateralToLiquidate,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      vars.liquidationProtocolFeeAmount,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  /// @dev Test liquidation call with maxLiquidatableDebt <= liquidationRecoveryDebt
  function test_liquidationCall_maxLiquidatableDebt_lte_liquidationRecoveryDebt() public {
    TestLiquidationCallLocalParams memory vars;

    vars.debtToCover = 15_000e18;
    vars.daiAssetId = 0;
    vars.ethAssetId = 1;
    vars.usdcAssetId = 2;
    vars.newLpfp = 200;

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = vars.debtToCover; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // T0
    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);
    Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.daiAssetId, vars.newLpfp);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

    vars.hf0 = mockSpoke1.getHealthFactor(USER1);

    assertTrue(
      vars.hf0 > mockSpoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
      'Unexpected T1 health factor'
    );

    // eth price drops
    MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 0.1e8);

    vars.hf1 = mockSpoke1.getHealthFactor(USER1);
    assertTrue(vars.hf1 < vars.hf0, 'Unexpected change in user1 hf at T1');

    // pre-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.reserveDaiData1 = mockSpoke1.getReserve(vars.daiAssetId);

    vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

    vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

    assertEq(
      vars.reserveDaiData1.config.lpfp,
      vars.newLpfp,
      'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
    );

    // dai
    assertEq(
      vars.user1DaiData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 dai usingAsCollateral'
    );
    assertEq(
      vars.user1DaiData1.supplyShares,
      vars.mockSpoke1DaiData1.totalShares,
      'Unexpected T1 user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData1.totalShares,
      hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
      'Unexpected T1 mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
    // eth
    assertEq(
      vars.user1EthData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 eth usingAsCollateral'
    );
    assertEq(
      vars.user1EthData1.supplyShares,
      vars.mockSpoke1EthData1.totalShares,
      'Unexpected T1 user1 eth supplyShares'
    );
    assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected T1 mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData1.usingAsCollateral,
      false,
      'Unexpected T1 user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData1.supplyShares,
      vars.mockSpoke1UsdcData1.totalShares,
      'Unexpected T1 user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData1.debtShares,
      vars.user2UsdcData1.supplyShares,
      'Unexpected T1 user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc drawnShares'
    );

    // T2 / T_final
    // action: liquidation
    deal(address(usdc), LIQUIDATOR, vars.debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), vars.debtToCover);

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      ,

    ) = mockSpoke1.calculateUserAccountData(USER1);

    vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      vars.collateralReserve,
      vars.debtToCover,
      USER1,
      vars.usdcAssetId,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.debtAssetPrice
    );

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
    vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      vars.collateralReserve,
      vars.debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.debtAssetPrice
    );

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: vars.daiAssetId,
      debtAssetId: vars.usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.actualDebtToLiquidate,
      actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
    vm.stopPrank();

    // post-liquidation
    vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
    vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
    vars.expectedDaiTotalSharesRemaining =
      vars.mockSpoke1DaiData1.totalShares -
      hub.convertAssetsToSharesDown(
        vars.daiAssetId,
        vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
      );
    vars.expectedUsdcDrawnSharesRemaining =
      vars.mockSpoke1UsdcData1.drawnShares -
      hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
    vars.hf2 = mockSpoke1.getHealthFactor(USER1);

    // dai
    assertEq(vars.user1DaiData2.usingAsCollateral, false, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.mockSpoke1DaiData2.totalShares,
      vars.expectedDaiTotalSharesRemaining,
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData2.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData2.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData2.drawnShares,
      vars.mockSpoke1UsdcData2.totalShares -
        hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    // health factor
    assertTrue(
      vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
      'Unexpected user1 final health factor'
    );
    assertTrue(vars.hf2 < vars.hf1, 'Unexpected final change in user1 health factor'); // in this case HF decreases as remaining collateral has dropped in value drastically

    // liquidator
    assertEq(
      usdc.balanceOf(LIQUIDATOR),
      vars.debtToCover - vars.actualDebtToLiquidate,
      'Unexpected liquidator debt asset balance'
    );
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      vars.actualCollateralToLiquidate,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      vars.liquidationProtocolFeeAmount,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  /// @dev Test liquidation call liquidating the non stablecoin collateral
  function test_liquidationCall_gteUserCollateralBalance_liquidateEth() public {
    TestLiquidationCallLocalParams memory vars;

    vars.debtToCover = 15_000e18;
    vars.daiAssetId = 0;
    vars.ethAssetId = 1;
    vars.usdcAssetId = 2;
    vars.newLpfp = 200;

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // T0
    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);
    Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.ethAssetId, vars.newLpfp);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

    vars.hf0 = mockSpoke1.getHealthFactor(USER1);

    assertTrue(
      vars.hf0 > mockSpoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
      'Unexpected T1 health factor'
    );

    // eth price drops from $2000 -> $600/eth
    MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 600e8);

    vars.hf1 = mockSpoke1.getHealthFactor(USER1);
    assertTrue(
      vars.hf1 < mockSpoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
      'Unexpected T1 health factor'
    );
    assertTrue(vars.hf1 < vars.hf0, 'Unexpected T1 increase in health factor');

    // pre-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));

    vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
    vars.reserveEthData1 = mockSpoke1.getReserve(vars.ethAssetId);

    vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

    assertEq(
      vars.reserveEthData1.config.lpfp,
      vars.newLpfp,
      'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
    );

    // dai
    assertEq(
      vars.user1DaiData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 dai usingAsCollateral'
    );
    assertEq(
      vars.user1DaiData1.supplyShares,
      vars.mockSpoke1DaiData1.totalShares,
      'Unexpected T1 user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData1.totalShares,
      hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
      'Unexpected T1 mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
    // eth
    assertEq(
      vars.user1EthData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 eth usingAsCollateral'
    );
    assertEq(
      vars.user1EthData1.supplyShares,
      vars.mockSpoke1EthData1.totalShares,
      'Unexpected T1 user1 eth supplyShares'
    );
    assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected T1 mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData1.usingAsCollateral,
      false,
      'Unexpected T1 user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData1.supplyShares,
      vars.mockSpoke1UsdcData1.totalShares,
      'Unexpected T1 user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData1.debtShares,
      vars.user2UsdcData1.supplyShares,
      'Unexpected T1 user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc drawnShares'
    );

    // T2 / T_final
    // action: liquidation
    deal(address(usdc), LIQUIDATOR, vars.debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), vars.debtToCover);

    vars.collateralReserve = mockSpoke1.getReserve(vars.ethAssetId);
    vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      ,

    ) = mockSpoke1.calculateUserAccountData(USER1);

    vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      vars.collateralReserve,
      vars.debtToCover,
      USER1,
      vars.usdcAssetId,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.debtAssetPrice
    );

    vars.collateralReserve = mockSpoke1.getReserve(vars.ethAssetId);
    vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
    vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.ethAssetId, USER1);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      vars.collateralReserve,
      vars.debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.debtAssetPrice
    );

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: vars.ethAssetId,
      debtAssetId: vars.usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.actualDebtToLiquidate,
      actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(vars.ethAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
    vm.stopPrank();

    // post-liquidation
    vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
    vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
    vars.expectedEthTotalSharesRemaining =
      vars.mockSpoke1EthData1.totalShares -
      hub.convertAssetsToSharesDown(
        vars.ethAssetId,
        vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
      );
    vars.expectedUsdcDrawnSharesRemaining =
      vars.mockSpoke1UsdcData1.drawnShares -
      hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
    vars.hf2 = mockSpoke1.getHealthFactor(USER1);

    // dai
    assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.mockSpoke1DaiData2.totalShares,
      vars.mockSpoke1DaiData1.totalShares,
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData2.usingAsCollateral, false, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData2.totalShares,
      vars.expectedEthTotalSharesRemaining,
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData2.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData2.drawnShares,
      vars.mockSpoke1UsdcData2.totalShares -
        hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    // health factor
    assertTrue(
      vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
      'Unexpected user1 final health factor'
    );
    assertTrue(vars.hf2 > vars.hf1, 'Unexpected decrease in user1 health factor');

    // liquidator
    assertEq(
      usdc.balanceOf(LIQUIDATOR),
      vars.debtToCover - vars.actualDebtToLiquidate,
      'Unexpected liquidator debt asset balance'
    );
    assertEq(
      eth.balanceOf(LIQUIDATOR),
      vars.actualCollateralToLiquidate,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      eth.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      vars.liquidationProtocolFeeAmount,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  /// @dev Test liquidation call with liquidated amount < user collateral balance, liquidation protocol fee = 0
  function test_liquidationCall_ltCollateralBalance_zeroLiquidationProtocolFee() public {
    TestLiquidationCallLocalParams memory vars;

    vars.debtToCover = 1000e18;
    vars.daiAssetId = 0;
    vars.ethAssetId = 1;
    vars.usdcAssetId = 2;

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // T0
    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);
    vars.hf0 = mockSpoke1.getHealthFactor(USER1);
    assertTrue(
      vars.hf0 > mockSpoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
      'Unexpected T0 health factor'
    );

    // T1: eth drops fomr $2000 -> $800/eth
    MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);

    vars.hf1 = mockSpoke1.getHealthFactor(USER1);

    // pre-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));

    vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

    vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

    // dai
    assertEq(
      vars.user1DaiData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 dai usingAsCollateral'
    );
    assertEq(
      vars.user1DaiData1.supplyShares,
      vars.mockSpoke1DaiData1.totalShares,
      'Unexpected T1 user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData1.totalShares,
      hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
      'Unexpected T1 mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
    // eth
    assertEq(
      vars.user1EthData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 eth usingAsCollateral'
    );
    assertEq(
      vars.user1EthData1.supplyShares,
      vars.mockSpoke1EthData1.totalShares,
      'Unexpected T1 user1 eth supplyShares'
    );
    assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected T1 mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData1.usingAsCollateral,
      false,
      'Unexpected T1 user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData1.supplyShares,
      vars.mockSpoke1UsdcData1.totalShares,
      'Unexpected T1 user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData1.debtShares,
      vars.user2UsdcData1.supplyShares,
      'Unexpected T1 user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc drawnShares'
    );

    // T2 / T_final
    // action: liquidation
    deal(address(usdc), LIQUIDATOR, vars.debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), vars.debtToCover);

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      ,

    ) = mockSpoke1.calculateUserAccountData(USER1);

    vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      vars.collateralReserve,
      vars.debtToCover,
      USER1,
      vars.usdcAssetId,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.debtAssetPrice
    );

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
    vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      vars.collateralReserve,
      vars.debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.debtAssetPrice
    );

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: vars.daiAssetId,
      debtAssetId: vars.usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.actualDebtToLiquidate,
      actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
    vm.stopPrank();

    // post-liquidation
    vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
    vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
    vars.expectedDaiTotalSharesRemaining =
      vars.mockSpoke1DaiData1.totalShares -
      hub.convertAssetsToSharesDown(vars.daiAssetId, vars.actualCollateralToLiquidate);
    vars.expectedUsdcDrawnSharesRemaining =
      vars.mockSpoke1UsdcData1.drawnShares -
      hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
    vars.hf2 = mockSpoke1.getHealthFactor(USER1);

    // dai
    assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.mockSpoke1DaiData2.totalShares,
      vars.expectedDaiTotalSharesRemaining,
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData2.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData2.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData2.drawnShares,
      vars.mockSpoke1UsdcData2.totalShares -
        hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    // health factor
    assertTrue(
      vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
      'Unexpected user1 final health factor'
    );
    assertTrue(vars.hf2 > vars.hf1, 'Unexpected decrease in user1 health factor');

    // liquidator
    assertEq(
      usdc.balanceOf(LIQUIDATOR),
      vars.debtToCover - vars.actualDebtToLiquidate,
      'Unexpected liquidator debt asset balance'
    );
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      vars.actualCollateralToLiquidate,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      vars.liquidationProtocolFeeAmount,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  function test_liquidationCall_ltCollateralBalance() public {
    TestLiquidationCallLocalParams memory vars;

    vars.debtToCover = 5_000e18;
    vars.daiAssetId = 0;
    vars.ethAssetId = 1;
    vars.usdcAssetId = 2;
    vars.newLpfp = 200;

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    bool usingAsCollateral = true;

    // T0
    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);
    Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.daiAssetId, vars.newLpfp);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);
    vars.hf0 = mockSpoke1.getHealthFactor(USER1);

    assertTrue(
      vars.hf0 > mockSpoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
      'Unexpected T1 health factor'
    );

    // T1: eth price drops from $2000 -> $800/eth
    MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);
    vars.hf1 = mockSpoke1.getHealthFactor(USER1);

    // pre-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.reserveDaiData1 = mockSpoke1.getReserve(vars.daiAssetId);

    vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

    vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

    assertEq(
      vars.reserveDaiData1.config.lpfp,
      vars.newLpfp,
      'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
    );

    // dai
    assertEq(
      vars.user1DaiData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 dai usingAsCollateral'
    );
    assertEq(
      vars.user1DaiData1.supplyShares,
      vars.mockSpoke1DaiData1.totalShares,
      'Unexpected T1 user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData1.totalShares,
      hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
      'Unexpected T1 mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
    // eth
    assertEq(
      vars.user1EthData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 eth usingAsCollateral'
    );
    assertEq(
      vars.user1EthData1.supplyShares,
      vars.mockSpoke1EthData1.totalShares,
      'Unexpected T1 user1 eth supplyShares'
    );
    assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected T1 mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData1.usingAsCollateral,
      false,
      'Unexpected T1 user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData1.supplyShares,
      vars.mockSpoke1UsdcData1.totalShares,
      'Unexpected T1 user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData1.debtShares,
      vars.user2UsdcData1.supplyShares,
      'Unexpected T1 user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc drawnShares'
    );

    // T2 / T_final
    // action: liquidation
    deal(address(usdc), LIQUIDATOR, vars.debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), vars.debtToCover);

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      ,

    ) = mockSpoke1.calculateUserAccountData(USER1);

    vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      vars.collateralReserve,
      vars.debtToCover,
      USER1,
      vars.usdcAssetId,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.debtAssetPrice
    );

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
    vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      vars.collateralReserve,
      vars.debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.debtAssetPrice
    );

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: vars.daiAssetId,
      debtAssetId: vars.usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.actualDebtToLiquidate,
      actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
    vm.stopPrank();

    // post-liquidation
    vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
    vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
    vars.expectedDaiTotalSharesRemaining =
      vars.mockSpoke1DaiData1.totalShares -
      hub.convertAssetsToSharesDown(
        vars.daiAssetId,
        vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
      );
    vars.expectedUsdcDrawnSharesRemaining =
      vars.mockSpoke1UsdcData1.drawnShares -
      hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
    vars.hf2 = mockSpoke1.getHealthFactor(USER1);

    // dai
    assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.mockSpoke1DaiData2.totalShares,
      vars.expectedDaiTotalSharesRemaining,
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData2.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData2.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData2.drawnShares,
      vars.mockSpoke1UsdcData2.totalShares -
        hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    // health factor
    assertTrue(
      vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
      'Unexpected user1 final health factor'
    );
    assertTrue(vars.hf2 > vars.hf1, 'Unexpected decrease in user1 health factor');

    // liquidator
    assertEq(
      usdc.balanceOf(LIQUIDATOR),
      vars.debtToCover - vars.actualDebtToLiquidate,
      'Unexpected liquidator debt asset balance'
    );
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      vars.actualCollateralToLiquidate,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      vars.liquidationProtocolFeeAmount,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  function test_liquidationCall_ltCollateralBalance_multiBorrow() public {
    TestLiquidationCallLocalParams memory vars;

    vars.debtToCover = 5_000e18;
    vars.daiAssetId = 0;
    vars.ethAssetId = 1;
    vars.usdcAssetId = 2;
    vars.wbtcAssetId = 3;
    vars.newLpfp = 200;

    // total collateral: $30k
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    uint256 wbtcBorrowAmount = 0.1e18; // 0.1 wBTC -> $5k
    bool usingAsCollateral = true;

    // T0
    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);
    Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.daiAssetId, vars.newLpfp);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER2 supply wbtc into mockSpoke1
    deal(address(wbtc), USER2, wbtcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // USER1 borrow wbtc
    Utils.borrow(vm, mockSpoke1, vars.wbtcAssetId, USER1, wbtcBorrowAmount, USER1);

    vars.hf0 = mockSpoke1.getHealthFactor(USER1);

    assertTrue(
      vars.hf0 > mockSpoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
      'Unexpected T1 health factor'
    );

    // T1: eth price drops from $2000 -> $800/eth
    MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);
    vars.hf1 = mockSpoke1.getHealthFactor(USER1);

    // pre-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.reserveDaiData1 = mockSpoke1.getReserve(vars.daiAssetId);

    vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

    vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

    vars.user1WbtcData1 = mockSpoke1.getUser(vars.wbtcAssetId, USER1);
    vars.user2WbtcData1 = mockSpoke1.getUser(vars.wbtcAssetId, USER2);
    vars.mockSpoke1WbtcData1 = hub.getSpoke(vars.wbtcAssetId, address(mockSpoke1));

    assertEq(
      vars.reserveDaiData1.config.lpfp,
      vars.newLpfp,
      'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
    );

    // dai
    assertEq(
      vars.user1DaiData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 dai usingAsCollateral'
    );
    assertEq(
      vars.user1DaiData1.supplyShares,
      vars.mockSpoke1DaiData1.totalShares,
      'Unexpected T1 user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData1.totalShares,
      hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
      'Unexpected T1 mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
    // eth
    assertEq(
      vars.user1EthData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 eth usingAsCollateral'
    );
    assertEq(
      vars.user1EthData1.supplyShares,
      vars.mockSpoke1EthData1.totalShares,
      'Unexpected T1 user1 eth supplyShares'
    );
    assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected T1 mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData1.usingAsCollateral,
      false,
      'Unexpected T1 user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData1.supplyShares,
      vars.mockSpoke1UsdcData1.totalShares,
      'Unexpected T1 user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData1.debtShares,
      vars.user2UsdcData1.supplyShares,
      'Unexpected T1 user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc drawnShares'
    );
    // wbtc
    assertEq(
      vars.user1WbtcData1.usingAsCollateral,
      false,
      'Unexpected T1 user1 wbtc usingAsCollateral'
    );
    assertEq(
      vars.user2WbtcData1.supplyShares,
      vars.mockSpoke1WbtcData1.totalShares,
      'Unexpected T1 user2 wbtc supplyShares'
    );
    assertEq(
      vars.user1WbtcData1.debtShares,
      vars.user2WbtcData1.supplyShares,
      'Unexpected T1 user1 wbtc debtShares'
    );
    assertEq(
      vars.mockSpoke1WbtcData1.totalShares,
      hub.convertAssetsToSharesDown(vars.wbtcAssetId, wbtcBorrowAmount),
      'Unexpected T1 mockSpoke1 wbtc totalShares'
    );
    assertEq(
      vars.mockSpoke1WbtcData1.drawnShares,
      hub.convertAssetsToSharesDown(vars.wbtcAssetId, wbtcBorrowAmount),
      'Unexpected T1 mockSpoke1 wbtc drawnShares'
    );

    // T2 / T_final
    // action: liquidation
    deal(address(usdc), LIQUIDATOR, vars.debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), vars.debtToCover);

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      ,

    ) = mockSpoke1.calculateUserAccountData(USER1);

    vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      vars.collateralReserve,
      vars.debtToCover,
      USER1,
      vars.usdcAssetId,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.debtAssetPrice
    );

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
    vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      vars.collateralReserve,
      vars.debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.debtAssetPrice
    );

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: vars.daiAssetId,
      debtAssetId: vars.usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.actualDebtToLiquidate,
      actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
    vm.stopPrank();

    // post-liquidation
    vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
    vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
    vars.mockSpoke1WbtcData2 = hub.getSpoke(vars.wbtcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
    vars.expectedDaiTotalSharesRemaining =
      vars.mockSpoke1DaiData1.totalShares -
      hub.convertAssetsToSharesDown(
        vars.daiAssetId,
        vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
      );
    vars.expectedUsdcDrawnSharesRemaining =
      vars.mockSpoke1UsdcData1.drawnShares -
      hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
    vars.hf2 = mockSpoke1.getHealthFactor(USER1);

    // dai
    assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
    assertEq(
      vars.mockSpoke1DaiData2.totalShares,
      vars.expectedDaiTotalSharesRemaining,
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData2.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData2.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData2.drawnShares,
      vars.mockSpoke1UsdcData2.totalShares -
        hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    // wbtc
    assertEq(vars.user1WbtcData2.usingAsCollateral, false, 'Unexpected wbtc usingAsCollateral');
    assertEq(
      vars.mockSpoke1WbtcData2.totalShares,
      vars.mockSpoke1WbtcData1.totalShares,
      'Unexpected mockSpoke1 wbtc totalShares'
    );
    assertEq(
      vars.mockSpoke1WbtcData2.drawnShares,
      vars.mockSpoke1WbtcData1.drawnShares,
      'Unexpected mockSpoke1 wbtc drawnShares'
    );
    // health factor
    assertTrue(
      vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
      'Unexpected user1 final health factor'
    );
    assertTrue(vars.hf2 < vars.hf1, 'Unexpected increase in user1 health factor'); // remaining debt from wbtc, hf decreases

    // liquidator
    assertEq(
      usdc.balanceOf(LIQUIDATOR),
      vars.debtToCover - vars.actualDebtToLiquidate,
      'Unexpected liquidator debt asset balance'
    );
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      vars.actualCollateralToLiquidate,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      vars.liquidationProtocolFeeAmount,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  function test_liquidationCall_gteCollateralBalance_multiBorrow() public {
    TestLiquidationCallLocalParams memory vars;

    vars.debtToCover = 10_000e18;
    vars.daiAssetId = 0;
    vars.ethAssetId = 1;
    vars.usdcAssetId = 2;
    vars.wbtcAssetId = 3;
    vars.newLpfp = 200;

    // total collateral: $30k
    uint256 daiAmount = vars.debtToCover; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k

    // total borrowed: $15k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    uint256 wbtcBorrowAmount = 0.1e18; // 0.1 wBTC -> $5k
    bool usingAsCollateral = true;

    // T0
    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);
    Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.daiAssetId, vars.newLpfp);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER2 supply wbtc into mockSpoke1
    deal(address(wbtc), USER2, wbtcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, vars.wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // USER1 borrow wbtc
    Utils.borrow(vm, mockSpoke1, vars.wbtcAssetId, USER1, wbtcBorrowAmount, USER1);

    vars.hf0 = mockSpoke1.getHealthFactor(USER1);

    assertTrue(
      vars.hf0 > mockSpoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD(),
      'Unexpected T1 health factor'
    );

    // T1: eth price drops from $2000 -> $800/eth
    MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);
    vars.hf1 = mockSpoke1.getHealthFactor(USER1);

    // pre-liquidation
    vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.reserveDaiData1 = mockSpoke1.getReserve(vars.daiAssetId);

    vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

    vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
    vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

    vars.user1WbtcData1 = mockSpoke1.getUser(vars.wbtcAssetId, USER1);
    vars.user2WbtcData1 = mockSpoke1.getUser(vars.wbtcAssetId, USER2);
    vars.mockSpoke1WbtcData1 = hub.getSpoke(vars.wbtcAssetId, address(mockSpoke1));

    assertEq(
      vars.reserveDaiData1.config.lpfp,
      vars.newLpfp,
      'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
    );

    // dai
    assertEq(
      vars.user1DaiData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 dai usingAsCollateral'
    );
    assertEq(
      vars.user1DaiData1.supplyShares,
      vars.mockSpoke1DaiData1.totalShares,
      'Unexpected T1 user1 dai supplyShares'
    );
    assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
    assertEq(
      vars.mockSpoke1DaiData1.totalShares,
      hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
      'Unexpected T1 mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
    // eth
    assertEq(
      vars.user1EthData1.usingAsCollateral,
      true,
      'Unexpected T1 user1 eth usingAsCollateral'
    );
    assertEq(
      vars.user1EthData1.supplyShares,
      vars.mockSpoke1EthData1.totalShares,
      'Unexpected T1 user1 eth supplyShares'
    );
    assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
    assertEq(
      vars.mockSpoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected T1 mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
    // usdc
    assertEq(
      vars.user1UsdcData1.usingAsCollateral,
      false,
      'Unexpected T1 user1 usdc usingAsCollateral'
    );
    assertEq(
      vars.user2UsdcData1.supplyShares,
      vars.mockSpoke1UsdcData1.totalShares,
      'Unexpected T1 user2 usdc supplyShares'
    );
    assertEq(
      vars.user1UsdcData1.debtShares,
      vars.user2UsdcData1.supplyShares,
      'Unexpected T1 user1 usdc debtShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData1.drawnShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected T1 mockSpoke1 usdc drawnShares'
    );
    // wbtc
    assertEq(
      vars.user1WbtcData1.usingAsCollateral,
      false,
      'Unexpected T1 user1 wbtc usingAsCollateral'
    );
    assertEq(
      vars.user2WbtcData1.supplyShares,
      vars.mockSpoke1WbtcData1.totalShares,
      'Unexpected T1 user2 wbtc supplyShares'
    );
    assertEq(
      vars.user1WbtcData1.debtShares,
      vars.user2WbtcData1.supplyShares,
      'Unexpected T1 user1 wbtc debtShares'
    );
    assertEq(
      vars.mockSpoke1WbtcData1.totalShares,
      hub.convertAssetsToSharesDown(vars.wbtcAssetId, wbtcBorrowAmount),
      'Unexpected T1 mockSpoke1 wbtc totalShares'
    );
    assertEq(
      vars.mockSpoke1WbtcData1.drawnShares,
      hub.convertAssetsToSharesDown(vars.wbtcAssetId, wbtcBorrowAmount),
      'Unexpected T1 mockSpoke1 wbtc drawnShares'
    );

    // T2 / T_final
    // action: liquidation
    deal(address(usdc), LIQUIDATOR, vars.debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(mockSpoke1), vars.debtToCover);

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

    (
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      ,

    ) = mockSpoke1.calculateUserAccountData(USER1);

    vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      vars.collateralReserve,
      vars.debtToCover,
      USER1,
      vars.usdcAssetId,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency,
      vars.avgLiquidationThreshold,
      vars.debtAssetPrice
    );

    vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
    vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
    vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      vars.collateralReserve,
      vars.debtReserve,
      vars.actualDebtToLiquidate,
      vars.userCollateralBalance,
      vars.debtAssetPrice
    );

    vm.expectEmit(address(mockSpoke1));
    emit LiquidationCall({
      collateralAssetId: vars.daiAssetId,
      debtAssetId: vars.usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: vars.actualDebtToLiquidate,
      actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
      liquidator: LIQUIDATOR
    });
    mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
    vm.stopPrank();

    // post-liquidation
    vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
    vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
    vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
    vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
    vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
    vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
    vars.mockSpoke1WbtcData2 = hub.getSpoke(vars.wbtcAssetId, address(mockSpoke1));
    vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
    vars.expectedDaiTotalSharesRemaining =
      vars.mockSpoke1DaiData1.totalShares -
      hub.convertAssetsToSharesDown(
        vars.daiAssetId,
        vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
      );
    vars.expectedUsdcDrawnSharesRemaining =
      vars.mockSpoke1UsdcData1.drawnShares -
      hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
    vars.hf2 = mockSpoke1.getHealthFactor(USER1);

    // dai
    assertEq(vars.user1DaiData2.usingAsCollateral, false, 'Unexpected user1 dai usingAsCollateral'); // all Dai liquidated
    assertEq(
      vars.mockSpoke1DaiData2.totalShares,
      vars.expectedDaiTotalSharesRemaining,
      'Unexpected mockSpoke1 dai totalShares'
    );
    assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
    // eth
    assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
    assertEq(
      vars.mockSpoke1EthData2.totalShares,
      hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
      'Unexpected mockSpoke1 eth totalShares'
    );
    assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
    // usdc
    assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
    assertEq(
      vars.mockSpoke1UsdcData2.totalShares,
      hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
      'Unexpected mockSpoke1 usdc totalShares'
    );
    assertEq(
      vars.mockSpoke1UsdcData2.drawnShares,
      vars.mockSpoke1UsdcData2.totalShares -
        hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
      'Unexpected mockSpoke1 usdc drawnShares'
    );
    // wbtc
    assertEq(vars.user1WbtcData2.usingAsCollateral, false, 'Unexpected wbtc usingAsCollateral');
    assertEq(
      vars.mockSpoke1WbtcData2.totalShares,
      vars.mockSpoke1WbtcData1.totalShares,
      'Unexpected mockSpoke1 wbtc totalShares'
    );
    assertEq(
      vars.mockSpoke1WbtcData2.drawnShares,
      vars.mockSpoke1WbtcData1.drawnShares,
      'Unexpected mockSpoke1 wbtc drawnShares'
    );
    // health factor
    assertTrue(
      vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
      'Unexpected user1 final health factor'
    );
    assertTrue(vars.hf2 < vars.hf1, 'Unexpected increase in user1 health factor'); // remaining debt from wbtc, hf decreases

    // liquidator
    assertEq(
      usdc.balanceOf(LIQUIDATOR),
      vars.debtToCover - vars.actualDebtToLiquidate,
      'Unexpected liquidator debt asset balance'
    );
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      vars.actualCollateralToLiquidate,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
      vars.liquidationProtocolFeeAmount,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }
}
