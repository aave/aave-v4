// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';
import '../mocks/MockSpokeExposedMethods.sol';

contract LiquidationInternalCalculationTest is BaseTest {
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

  /// forge-config: default.fuzz.runs = 1000
  function test_fuzz_calculateUserAccountData_noCollateral(
    uint256 daiAmount,
    uint256 ethAmount
  ) public {
    vm.assume(daiAmount > 1e2 && ethAmount > 1e2); // ensure some amount leading to shares > 0

    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);

    (
      uint256 totalCollateralInBaseCurrency,
      uint256 totalDebtInBaseCurrency,
      uint256 avgLiquidationThreshold,
      uint256 userRiskPremium,
      uint256 healthFactor
    ) = mockSpoke1.calculateUserAccountData(USER1);

    assertEq(totalCollateralInBaseCurrency, 0, 'Unexpected totalCollateralInBaseCurrency');
    assertEq(totalDebtInBaseCurrency, 0, 'Unexpected totalDebtInBaseCurrency');
    assertEq(avgLiquidationThreshold, 0, 'Unexpected avgLiquidationThreshold');
    assertEq(userRiskPremium, 0, 'Unexpected userRiskPremium');
    assertEq(healthFactor, type(uint256).max, 'Unexpected healthFactor');
  }

  /// forge-config: default.fuzz.runs = 1000
  function test_fuzz_calculateUserAccountData_noBorrow(
    uint256 daiAmount,
    uint256 ethAmount
  ) public {
    daiAmount = bound(daiAmount, 1e2, 1e28);
    ethAmount = bound(ethAmount, 1e2, 1e28);

    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    bool usingAsCollateral = true;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

    uint256[] memory collateralAssetIds = new uint256[](2);
    collateralAssetIds[0] = daiAssetId;
    collateralAssetIds[1] = ethAssetId;

    (
      uint256 expectedTotalCollateralInBaseCurrency,
      uint256 expectedAvgLiquidationThreshold
    ) = _calculateTotalCollateralInBaseCurrencyAndAvgLT(collateralAssetIds, USER1);

    (
      uint256 totalCollateralInBaseCurrency,
      uint256 totalDebtInBaseCurrency,
      uint256 avgLiquidationThreshold,
      uint256 userRiskPremium,
      uint256 healthFactor
    ) = mockSpoke1.calculateUserAccountData(USER1);

    assertEq(
      totalCollateralInBaseCurrency,
      expectedTotalCollateralInBaseCurrency,
      'Unexpected totalCollateralInBaseCurrency'
    );
    assertEq(totalDebtInBaseCurrency, 0, 'Unexpected totalDebtInBaseCurrency');
    assertEq(
      avgLiquidationThreshold,
      expectedAvgLiquidationThreshold,
      'Unexpected avgLiquidationThreshold'
    );
    assertEq(userRiskPremium, 0, 'Unexpected userRiskPremium');
    assertEq(healthFactor, type(uint256).max, 'Unexpected healthFactor');
  }

  /// forge-config: default.fuzz.runs = 1000
  function test_fuzz_calculateUserAccountData(
    uint256 daiAmount,
    uint256 ethAmount,
    uint256 usdcBorrowAmount
  ) public {
    daiAmount = bound(daiAmount, 1e2, 1e28);
    ethAmount = bound(ethAmount, 1e2, 1e28);
    usdcBorrowAmount = bound(usdcBorrowAmount, 1e2, 1e27);

    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;
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

    uint256[] memory collateralAssetIds = new uint256[](2);
    collateralAssetIds[0] = daiAssetId;
    collateralAssetIds[1] = ethAssetId;

    (
      uint256 expectedTotalCollateralInBaseCurrency,
      uint256 expectedAvgLiquidationThreshold
    ) = _calculateTotalCollateralInBaseCurrencyAndAvgLT(collateralAssetIds, USER1);

    uint256[] memory debtAssetIds = new uint256[](1);
    debtAssetIds[0] = usdcAssetId;
    uint256 expectedTotalDebtInBaseCurrency = _calculateTotalDebtInBaseCurrency(
      debtAssetIds,
      USER1
    );

    uint256 expectedHF = expectedTotalDebtInBaseCurrency == 0
      ? type(uint256).max
      : (expectedTotalCollateralInBaseCurrency.percentMul(expectedAvgLiquidationThreshold)).wadDiv(
        expectedTotalDebtInBaseCurrency
      );

    (
      uint256 totalCollateralInBaseCurrency,
      uint256 totalDebtInBaseCurrency,
      uint256 avgLiquidationThreshold,
      uint256 userRiskPremium,
      uint256 healthFactor
    ) = mockSpoke1.calculateUserAccountData(USER1);

    assertEq(
      totalCollateralInBaseCurrency,
      expectedTotalCollateralInBaseCurrency,
      'Unexpected totalCollateralInBaseCurrency'
    );
    assertEq(
      totalDebtInBaseCurrency,
      expectedTotalDebtInBaseCurrency,
      'Unexpected totalDebtInBaseCurrency'
    );
    assertEq(
      avgLiquidationThreshold,
      expectedAvgLiquidationThreshold,
      'Unexpected avgLiquidationThreshold'
    );
    assertEq(userRiskPremium, 0, 'Unexpected userRiskPremium');
    assertEq(healthFactor, expectedHF, 'Unexpected healthFactor');
  }

  /// forge-config: default.fuzz.runs = 1000
  function test_fuzz_calculateUserAccountData_multiple_borrows(
    uint256 daiAmount,
    uint256 ethAmount,
    uint256 usdcBorrowAmount,
    uint256 wbtcBorrowAmount
  ) public {
    daiAmount = bound(daiAmount, 1e2, 1e28);
    ethAmount = bound(ethAmount, 1e2, 1e28);
    usdcBorrowAmount = bound(usdcBorrowAmount, 1e2, 1e27);
    wbtcBorrowAmount = bound(wbtcBorrowAmount, 1e2, 1e25);

    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;
    uint256 wbtcAssetId = 3;
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

    // USER2 supply wbtc into mockSpoke1
    deal(address(wbtc), USER2, wbtcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // USER1 borrow wbtc
    Utils.borrow(vm, mockSpoke1, wbtcAssetId, USER1, wbtcBorrowAmount, USER1);

    uint256[] memory collateralAssetIds = new uint256[](2);
    collateralAssetIds[0] = daiAssetId;
    collateralAssetIds[1] = ethAssetId;
    (
      uint256 expectedTotalCollateralInBaseCurrency,
      uint256 expectedAvgLiquidationThreshold
    ) = _calculateTotalCollateralInBaseCurrencyAndAvgLT(collateralAssetIds, USER1);

    uint256[] memory debtAssetIds = new uint256[](2);
    debtAssetIds[0] = usdcAssetId;
    debtAssetIds[1] = wbtcAssetId;
    uint256 expectedTotalDebtInBaseCurrency = _calculateTotalDebtInBaseCurrency(
      debtAssetIds,
      USER1
    );

    uint256 expectedHF = expectedTotalDebtInBaseCurrency == 0
      ? type(uint256).max
      : (expectedTotalCollateralInBaseCurrency.percentMul(expectedAvgLiquidationThreshold)).wadDiv(
        expectedTotalDebtInBaseCurrency
      );

    (
      uint256 totalCollateralInBaseCurrency,
      uint256 totalDebtInBaseCurrency,
      uint256 avgLiquidationThreshold,
      uint256 userRiskPremium,
      uint256 healthFactor
    ) = mockSpoke1.calculateUserAccountData(USER1);

    assertEq(
      totalCollateralInBaseCurrency,
      expectedTotalCollateralInBaseCurrency,
      'Unexpected totalCollateralInBaseCurrency'
    );
    assertEq(
      totalDebtInBaseCurrency,
      expectedTotalDebtInBaseCurrency,
      'Unexpected totalDebtInBaseCurrency'
    );
    assertEq(
      avgLiquidationThreshold,
      expectedAvgLiquidationThreshold,
      'Unexpected avgLiquidationThreshold'
    );
    assertEq(userRiskPremium, 0, 'Unexpected userRiskPremium');
    assertEq(healthFactor, expectedHF, 'Unexpected healthFactor');
  }

  struct TestCalculateActualDebtToLiquidateLocalParams {
    uint256[] collateralAssetIds;
    uint256[] debtAssetIds;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 avgLiquidationThreshold;
    uint256 healthFactor;
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationProtocolFeeAmount;
    uint256 expectedActualCollateralToLiquidate;
    uint256 expectedActualDebtToLiquidate;
    uint256 expectedLiquidationProtocolFeeAmount;
  }

  /// forge-config: default.fuzz.runs = 1000
  function test_fuzz_calculateActualDebtToLiquidate(
    uint256 daiAmount,
    uint256 ethAmount,
    uint256 usdcBorrowAmount,
    uint256 wbtcBorrowAmount,
    uint256 debtToCover
  ) public {
    daiAmount = bound(daiAmount, 1e2, 1e28);
    ethAmount = bound(ethAmount, 1e2, 1e28);
    usdcBorrowAmount = bound(usdcBorrowAmount, 1e2, 1e27);
    wbtcBorrowAmount = bound(wbtcBorrowAmount, 1e2, 1e25);
    debtToCover = bound(debtToCover, 1e2, 1e30);

    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;
    uint256 wbtcAssetId = 3;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, true);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, true);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER2 supply wbtc into mockSpoke1
    deal(address(wbtc), USER2, wbtcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // USER1 borrow wbtc
    Utils.borrow(vm, mockSpoke1, wbtcAssetId, USER1, wbtcBorrowAmount, USER1);

    TestCalculateActualDebtToLiquidateLocalParams memory localParams;

    (
      localParams.totalCollateralInBaseCurrency,
      localParams.totalDebtInBaseCurrency,
      localParams.avgLiquidationThreshold,
      ,
      localParams.healthFactor
    ) = mockSpoke1.calculateUserAccountData(USER1);

    localParams.collateralAssetIds = new uint256[](2);
    localParams.collateralAssetIds[0] = daiAssetId;
    localParams.collateralAssetIds[1] = ethAssetId;

    localParams.debtAssetIds = new uint256[](2);
    localParams.debtAssetIds[0] = usdcAssetId;
    localParams.debtAssetIds[1] = wbtcAssetId;

    (, , localParams.expectedActualDebtToLiquidate) = _calculateActualDebtToLiquidate(
      debtToCover,
      USER1,
      usdcAssetId,
      localParams.debtAssetIds,
      localParams.collateralAssetIds
    );

    uint256 actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      debtToCover,
      USER1,
      usdcAssetId,
      localParams.totalCollateralInBaseCurrency,
      localParams.totalDebtInBaseCurrency,
      localParams.avgLiquidationThreshold
    );

    assertEq(
      actualDebtToLiquidate,
      localParams.expectedActualDebtToLiquidate,
      'Unexpected actualDebtToLiquidate'
    );
  }

  /// forge-config: default.fuzz.runs = 1000
  function test_fuzz_calculateActualDebtToLiquidate_noDebt(
    uint256 daiAmount,
    uint256 ethAmount,
    uint256 usdcBorrowAmount,
    uint256 wbtcBorrowAmount,
    uint256 debtToCover
  ) public {
    daiAmount = bound(daiAmount, 1e2, 1e28);
    ethAmount = bound(ethAmount, 1e2, 1e28);
    usdcBorrowAmount = bound(usdcBorrowAmount, 1e2, 1e27);
    wbtcBorrowAmount = bound(wbtcBorrowAmount, 1e2, 1e25);
    debtToCover = bound(debtToCover, 1e2, 1e30);

    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;
    uint256 wbtcAssetId = 3;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, true);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, true);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER2 supply wbtc into mockSpoke1
    deal(address(wbtc), USER2, wbtcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

    TestCalculateActualDebtToLiquidateLocalParams memory localParams;

    (
      localParams.totalCollateralInBaseCurrency,
      localParams.totalDebtInBaseCurrency,
      localParams.avgLiquidationThreshold,
      ,
      localParams.healthFactor
    ) = mockSpoke1.calculateUserAccountData(USER1);

    uint256 actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      debtToCover,
      USER1,
      usdcAssetId,
      localParams.totalCollateralInBaseCurrency,
      localParams.totalDebtInBaseCurrency,
      localParams.avgLiquidationThreshold
    );

    assertEq(actualDebtToLiquidate, 0, 'Unexpected actualDebtToLiquidate');
  }

  /// forge-config: default.fuzz.runs = 1000
  function test_fuzz_calculateActualDebtToLiquidate_noCollateral(
    uint256 debtToCover,
    uint256 debtAssetId
  ) public {
    vm.assume(debtAssetId <= 3); // only 4 assets defined

    TestCalculateActualDebtToLiquidateLocalParams memory localParams;

    (
      localParams.totalCollateralInBaseCurrency,
      localParams.totalDebtInBaseCurrency,
      localParams.avgLiquidationThreshold,
      ,
      localParams.healthFactor
    ) = mockSpoke1.calculateUserAccountData(USER1);

    uint256 actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      debtToCover,
      USER1,
      debtAssetId,
      localParams.totalCollateralInBaseCurrency,
      localParams.totalDebtInBaseCurrency,
      localParams.avgLiquidationThreshold
    );

    assertEq(actualDebtToLiquidate, 0, 'Unexpected actualDebtToLiquidate');
  }

  /// forge-config: default.fuzz.runs = 1000
  function test_fuzz_calculateAvailableCollateralToLiquidate_noLpfp(
    uint256 daiAmount,
    uint256 ethAmount,
    uint256 usdcBorrowAmount,
    uint256 wbtcBorrowAmount,
    uint256 debtToCover
  ) public {
    daiAmount = bound(daiAmount, 1e2, 1e28);
    ethAmount = bound(ethAmount, 1e2, 1e28);
    usdcBorrowAmount = bound(usdcBorrowAmount, 1e2, 1e27);
    wbtcBorrowAmount = bound(wbtcBorrowAmount, 1e2, 1e25);
    debtToCover = bound(debtToCover, 1e2, 1e30);

    uint256 daiAssetId = 0;
    uint256 ethAssetId = 1;
    uint256 usdcAssetId = 2;
    uint256 wbtcAssetId = 3;

    // USER1 supply dai into mockSpoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, true);

    // USER1 supply eth into mockSpoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, true);

    // USER2 supply usdc into mockSpoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER2 supply wbtc into mockSpoke1
    deal(address(wbtc), USER2, wbtcBorrowAmount);
    Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // USER1 borrow wbtc
    Utils.borrow(vm, mockSpoke1, wbtcAssetId, USER1, wbtcBorrowAmount, USER1);

    TestCalculateActualDebtToLiquidateLocalParams memory localParams;

    (
      localParams.totalCollateralInBaseCurrency,
      localParams.totalDebtInBaseCurrency,
      localParams.avgLiquidationThreshold,
      ,
      localParams.healthFactor
    ) = mockSpoke1.calculateUserAccountData(USER1);

    localParams.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
      debtToCover,
      USER1,
      usdcAssetId,
      localParams.totalCollateralInBaseCurrency,
      localParams.totalDebtInBaseCurrency,
      localParams.avgLiquidationThreshold
    );

    (
      localParams.expectedActualCollateralToLiquidate,
      localParams.expectedActualDebtToLiquidate,
      localParams.expectedLiquidationProtocolFeeAmount
    ) = _calculateAvailableCollateralToLiquidate(
      mockSpoke1.getReserve(daiAssetId),
      mockSpoke1.getReserve(usdcAssetId),
      localParams.actualDebtToLiquidate,
      mockSpoke1.getUserSupplyInAssets(daiAssetId, USER1),
      mockSpoke1.getLiquidationBonus(daiAssetId)
    );

    (
      localParams.actualCollateralToLiquidate,
      localParams.actualDebtToLiquidate,
      localParams.liquidationProtocolFeeAmount
    ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
      mockSpoke1.getReserve(daiAssetId),
      mockSpoke1.getReserve(usdcAssetId),
      localParams.actualDebtToLiquidate,
      mockSpoke1.getUserSupplyInAssets(daiAssetId, USER1),
      mockSpoke1.getLiquidationBonus(daiAssetId)
    );

    assertEq(
      localParams.actualCollateralToLiquidate,
      localParams.expectedActualCollateralToLiquidate,
      'Unexpected actualCollateralToLiquidate'
    );
    assertEq(
      localParams.actualDebtToLiquidate,
      localParams.expectedActualDebtToLiquidate,
      'Unexpected actualDebtToLiquidate'
    );
    assertEq(
      localParams.liquidationProtocolFeeAmount,
      localParams.expectedLiquidationProtocolFeeAmount,
      'Unexpected liquidationProtocolFeeAmount'
    );
    assertEq(
      localParams.liquidationProtocolFeeAmount,
      0,
      'Unexpected liquidationProtocolFeeAmount > 0'
    );
  }

  /// @return totalCollateralInBaseCurrency total collateral in base currency
  /// @return avgLiquidationThreshold average liquidation threshold
  function _calculateTotalCollateralInBaseCurrencyAndAvgLT(
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

  function _calculateTotalDebtInBaseCurrency(
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

  /// @return recoveryThresholdLiquidatableDebt liquidatable debt to restore HF to HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD
  /// @return maxLiquidatableDebt max liquidatable debt based on user's total debt
  function _calculateActualDebtToLiquidate(
    uint256 debtToCover,
    address user,
    uint256 debtAssetId,
    uint256[] memory debtAssetIds,
    uint256[] memory collateralAssetIds
  )
    internal
    returns (
      uint256 recoveryThresholdLiquidatableDebt,
      uint256 maxLiquidatableDebt,
      uint256 actualDebtToLiquidate
    )
  {
    console2.log('------- test calculateActualDebtToLiquidate -------');

    uint256 totalDebtInBaseCurrency = _calculateTotalDebtInBaseCurrency(debtAssetIds, user);
    (
      uint256 totalCollateralInBaseCurrency,
      uint256 avgLiquidationThreshold
    ) = _calculateTotalCollateralInBaseCurrencyAndAvgLT(collateralAssetIds, user);

    uint256 liquidationRecoveryDebt = totalCollateralInBaseCurrency
      .percentMul(avgLiquidationThreshold)
      .wadDiv(mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD());

    recoveryThresholdLiquidatableDebt = totalDebtInBaseCurrency > liquidationRecoveryDebt
      ? (totalDebtInBaseCurrency - liquidationRecoveryDebt) /
        MockPriceOracle(address(oracle)).getAssetPrice(debtAssetId)
      : 0;

    maxLiquidatableDebt = mockSpoke1.getUserDebtInAssets(debtAssetId, user);

    maxLiquidatableDebt = maxLiquidatableDebt > recoveryThresholdLiquidatableDebt
      ? recoveryThresholdLiquidatableDebt
      : maxLiquidatableDebt;
    actualDebtToLiquidate = debtToCover > maxLiquidatableDebt ? maxLiquidatableDebt : debtToCover;
  }

  function _calculateAvailableCollateralToLiquidate(
    Spoke.Reserve memory collateralReserve,
    Spoke.Reserve memory debtReserve,
    uint256 actualDebtToLiquidate,
    uint256 userCollateralBalance,
    uint256 liquidationBonus
  ) internal returns (uint256, uint256, uint256) {
    Spoke.AvailableCollateralToLiquidateLocalVars memory vars;

    vars.collateralAssetPrice = MockPriceOracle(address(oracle)).getAssetPrice(
      collateralReserve.id
    );
    vars.debtAssetPrice = MockPriceOracle(address(oracle)).getAssetPrice(debtReserve.id);

    vars.collateralAssetUnit = 10 ** collateralReserve.decimals;
    vars.debtAssetUnit = 10 ** debtReserve.decimals;

    vars.liquidationProtocolFeePercentage = mockSpoke1.getLiquidationProtocolFeePercentage(
      collateralReserve.id
    );

    // find collateral amount that corresponds to the debt to cover
    vars.baseCollateral =
      (vars.debtAssetPrice * actualDebtToLiquidate * vars.collateralAssetUnit) /
      (vars.collateralAssetPrice * vars.debtAssetUnit);

    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(liquidationBonus);

    if (vars.maxCollateralToLiquidate > userCollateralBalance) {
      vars.collateralAmount = userCollateralBalance;
      vars.debtAmountNeeded = ((vars.collateralAssetPrice *
        vars.collateralAmount *
        vars.debtAssetUnit) / (vars.debtAssetPrice * vars.collateralAssetUnit)).percentDiv(
          liquidationBonus
        );
    } else {
      vars.collateralAmount = vars.maxCollateralToLiquidate;
      vars.debtAmountNeeded = actualDebtToLiquidate;
    }

    if (vars.liquidationProtocolFeePercentage != 0) {
      vars.bonusCollateral =
        vars.collateralAmount -
        vars.collateralAmount.percentDiv(liquidationBonus);

      vars.liquidationProtocolFeeAmount = vars.bonusCollateral.percentMul(
        vars.liquidationProtocolFeePercentage
      );

      return (
        vars.collateralAmount - vars.liquidationProtocolFeeAmount,
        vars.debtAmountNeeded,
        vars.liquidationProtocolFeeAmount
      );
    } else {
      return (vars.collateralAmount, vars.debtAmountNeeded, 0);
    }
  }
}
