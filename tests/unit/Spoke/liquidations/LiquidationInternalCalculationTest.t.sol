// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import 'tests/mocks/MockSpokeExposedMethods.sol';

contract LiquidationInternalCalculationTest is Base {
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
    initEnvironment();

    mockSpoke1 = new MockSpokeExposedMethods(
      address(hub),
      address(oracle),
      TREASURY,
      WadRayMath.WAD
    );
    mockSpoke2 = new MockSpokeExposedMethods(
      address(hub),
      address(oracle),
      TREASURY,
      WadRayMath.WAD
    );

    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });

    hub.addSpoke(wethAssetId, spokeConfig, address(mockSpoke1));
    hub.addSpoke(wbtcAssetId, spokeConfig, address(mockSpoke1));
    hub.addSpoke(daiAssetId, spokeConfig, address(mockSpoke1));
    hub.addSpoke(usdxAssetId, spokeConfig, address(mockSpoke1));
    hub.addSpoke(usdyAssetId, spokeConfig, address(mockSpoke1));

    hub.addSpoke(wethAssetId, spokeConfig, address(mockSpoke2));
    hub.addSpoke(wbtcAssetId, spokeConfig, address(mockSpoke2));
    hub.addSpoke(daiAssetId, spokeConfig, address(mockSpoke2));
    hub.addSpoke(usdxAssetId, spokeConfig, address(mockSpoke2));
    hub.addSpoke(usdyAssetId, spokeConfig, address(mockSpoke2));

    // Spoke reserve configs
    DataTypes.ReserveConfig memory wethConfig = DataTypes.ReserveConfig({
      decimals: tokenList.weth.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 80_00,
      liquidationBonus: 100_00,
      liquidityPremium: 15_00,
      liquidationProtocolFeePercentage: 0,
      borrowable: true,
      collateral: true
    });
    DataTypes.ReserveConfig memory wbtcConfig = DataTypes.ReserveConfig({
      decimals: tokenList.wbtc.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 75_00,
      liquidationBonus: 100_00,
      liquidityPremium: 5_00,
      liquidationProtocolFeePercentage: 0,
      borrowable: true,
      collateral: true
    });
    DataTypes.ReserveConfig memory daiConfig = DataTypes.ReserveConfig({
      decimals: tokenList.dai.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 78_00,
      liquidationBonus: 100_00,
      liquidityPremium: 20_00,
      liquidationProtocolFeePercentage: 0,
      borrowable: true,
      collateral: true
    });
    DataTypes.ReserveConfig memory usdxConfig = DataTypes.ReserveConfig({
      decimals: tokenList.usdx.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 78_00,
      liquidationBonus: 100_00,
      liquidityPremium: 50_00,
      liquidationProtocolFeePercentage: 0,
      borrowable: true,
      collateral: true
    });
    DataTypes.ReserveConfig memory usdyConfig = DataTypes.ReserveConfig({
      decimals: tokenList.usdy.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 78_00,
      liquidationBonus: 100_00,
      liquidityPremium: 50_00,
      liquidationProtocolFeePercentage: 0,
      borrowable: true,
      collateral: true
    });

    mockSpoke1.addReserve(wethAssetId, wethConfig);
    mockSpoke1.addReserve(wbtcAssetId, wbtcConfig);
    mockSpoke1.addReserve(daiAssetId, daiConfig);
    mockSpoke1.addReserve(usdxAssetId, usdxConfig);
    mockSpoke1.addReserve(usdyAssetId, usdyConfig);

    mockSpoke2.addReserve(wethAssetId, wethConfig);
    mockSpoke2.addReserve(wbtcAssetId, wbtcConfig);
    mockSpoke2.addReserve(daiAssetId, daiConfig);
    mockSpoke2.addReserve(usdxAssetId, usdxConfig);
    mockSpoke2.addReserve(usdyAssetId, usdyConfig);
  }

  // function test_fuzz_calculateUserAccountData_noCollateral(
  //   uint256 daiAmount,
  //   uint256 ethAmount
  // ) public {
  //   vm.assume(daiAmount > 1e2 && ethAmount > 1e2); // ensure some amount leading to shares > 0

  //   uint256 daiAssetId = 0;
  //   uint256 ethAssetId = 1;

  //   // USER1 supply dai into mockSpoke1
  //   deal(address(dai), USER1, daiAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);

  //   // USER1 supply eth into mockSpoke1
  //   deal(address(eth), USER1, ethAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);

  //   (
  //     uint256 totalCollateralInBaseCurrency,
  //     uint256 totalDebtInBaseCurrency,
  //     uint256 avgLiquidationThreshold,
  //     uint256 userRiskPremium,
  //     uint256 healthFactor
  //   ) = mockSpoke1.calculateUserAccountData(USER1);

  //   assertEq(totalCollateralInBaseCurrency, 0, 'Unexpected totalCollateralInBaseCurrency');
  //   assertEq(totalDebtInBaseCurrency, 0, 'Unexpected totalDebtInBaseCurrency');
  //   assertEq(avgLiquidationThreshold, 0, 'Unexpected avgLiquidationThreshold');
  //   assertEq(userRiskPremium, 0, 'Unexpected userRiskPremium');
  //   assertEq(healthFactor, type(uint256).max, 'Unexpected healthFactor');
  // }

  // /// forge-config: default.fuzz.runs = 1000
  // function test_fuzz_calculateUserAccountData_noBorrow(
  //   uint256 daiAmount,
  //   uint256 ethAmount
  // ) public {
  //   daiAmount = bound(daiAmount, 1e2, 1e28);
  //   ethAmount = bound(ethAmount, 1e2, 1e28);

  //   uint256 daiAssetId = 0;
  //   uint256 ethAssetId = 1;
  //   bool usingAsCollateral = true;

  //   // USER1 supply dai into mockSpoke1
  //   deal(address(dai), USER1, daiAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

  //   // USER1 supply eth into mockSpoke1
  //   deal(address(eth), USER1, ethAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

  //   uint256[] memory collateralAssetIds = new uint256[](2);
  //   collateralAssetIds[0] = daiAssetId;
  //   collateralAssetIds[1] = ethAssetId;

  //   (
  //     uint256 expectedTotalCollateralInBaseCurrency,
  //     uint256 expectedAvgLiquidationThreshold
  //   ) = _calculateTotalCollateralInBaseCurrencyAndAvgLT(collateralAssetIds, USER1);

  //   (
  //     uint256 totalCollateralInBaseCurrency,
  //     uint256 totalDebtInBaseCurrency,
  //     uint256 avgLiquidationThreshold,
  //     uint256 userRiskPremium,
  //     uint256 healthFactor
  //   ) = mockSpoke1.calculateUserAccountData(USER1);

  //   assertEq(
  //     totalCollateralInBaseCurrency,
  //     expectedTotalCollateralInBaseCurrency,
  //     'Unexpected totalCollateralInBaseCurrency'
  //   );
  //   assertEq(totalDebtInBaseCurrency, 0, 'Unexpected totalDebtInBaseCurrency');
  //   assertEq(
  //     avgLiquidationThreshold,
  //     expectedAvgLiquidationThreshold,
  //     'Unexpected avgLiquidationThreshold'
  //   );
  //   assertEq(userRiskPremium, 0, 'Unexpected userRiskPremium');
  //   assertEq(healthFactor, type(uint256).max, 'Unexpected healthFactor');
  // }

  // /// forge-config: ci.fuzz.runs = 1000
  // function test_fuzz_calculateUserAccountData(
  //   uint256 daiAmount,
  //   uint256 ethAmount,
  //   uint256 usdcBorrowAmount
  // ) public {
  //   daiAmount = bound(daiAmount, 1e2, 1e28);
  //   ethAmount = bound(ethAmount, 1e2, 1e28);
  //   usdcBorrowAmount = bound(usdcBorrowAmount, 1e2, 1e27);

  //   uint256 daiAssetId = 0;
  //   uint256 ethAssetId = 1;
  //   uint256 usdcAssetId = 2;
  //   bool usingAsCollateral = true;

  //   // USER1 supply dai into mockSpoke1
  //   deal(address(dai), USER1, daiAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

  //   // USER1 supply eth into mockSpoke1
  //   deal(address(eth), USER1, ethAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

  //   // USER2 supply usdc into mockSpoke1
  //   deal(address(usdc), USER2, usdcBorrowAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //   // USER1 borrow usdc
  //   Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //   uint256[] memory collateralAssetIds = new uint256[](2);
  //   collateralAssetIds[0] = daiAssetId;
  //   collateralAssetIds[1] = ethAssetId;

  //   (
  //     uint256 expectedTotalCollateralInBaseCurrency,
  //     uint256 expectedAvgLiquidationThreshold
  //   ) = _calculateTotalCollateralInBaseCurrencyAndAvgLT(collateralAssetIds, USER1);

  //   uint256[] memory debtAssetIds = new uint256[](1);
  //   debtAssetIds[0] = usdcAssetId;
  //   uint256 expectedTotalDebtInBaseCurrency = _calculateTotalDebtInBaseCurrency(
  //     debtAssetIds,
  //     USER1
  //   );

  //   uint256 expectedHF = expectedTotalDebtInBaseCurrency == 0
  //     ? type(uint256).max
  //     : (expectedTotalCollateralInBaseCurrency.wadMul(expectedAvgLiquidationThreshold)).wadDiv(
  //       expectedTotalDebtInBaseCurrency
  //     ) / 1e4;

  //   (
  //     uint256 totalCollateralInBaseCurrency,
  //     uint256 totalDebtInBaseCurrency,
  //     uint256 avgLiquidationThreshold,
  //     uint256 userRiskPremium,
  //     uint256 healthFactor
  //   ) = mockSpoke1.calculateUserAccountData(USER1);

  //   assertEq(
  //     totalCollateralInBaseCurrency,
  //     expectedTotalCollateralInBaseCurrency,
  //     'Unexpected totalCollateralInBaseCurrency'
  //   );
  //   assertEq(
  //     totalDebtInBaseCurrency,
  //     expectedTotalDebtInBaseCurrency,
  //     'Unexpected totalDebtInBaseCurrency'
  //   );
  //   assertEq(
  //     avgLiquidationThreshold,
  //     expectedAvgLiquidationThreshold,
  //     'Unexpected avgLiquidationThreshold'
  //   );
  //   assertEq(userRiskPremium, 0, 'Unexpected userRiskPremium');
  //   assertEq(healthFactor, expectedHF, 'Unexpected healthFactor');
  // }

  // /// forge-config: ci.fuzz.runs = 1000
  // function test_fuzz_calculateUserAccountData_multiple_borrows(
  //   uint256 daiAmount,
  //   uint256 ethAmount,
  //   uint256 usdcBorrowAmount,
  //   uint256 wbtcBorrowAmount
  // ) public {
  //   daiAmount = bound(daiAmount, 1e2, 1e28);
  //   ethAmount = bound(ethAmount, 1e2, 1e28);
  //   usdcBorrowAmount = bound(usdcBorrowAmount, 1e2, 1e27);
  //   wbtcBorrowAmount = bound(wbtcBorrowAmount, 1e2, 1e25);

  //   uint256 daiAssetId = 0;
  //   uint256 ethAssetId = 1;
  //   uint256 usdcAssetId = 2;
  //   uint256 wbtcAssetId = 3;
  //   bool usingAsCollateral = true;

  //   // USER1 supply dai into mockSpoke1
  //   deal(address(dai), USER1, daiAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

  //   // USER1 supply eth into mockSpoke1
  //   deal(address(eth), USER1, ethAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

  //   // USER2 supply usdc into mockSpoke1
  //   deal(address(usdc), USER2, usdcBorrowAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //   // USER2 supply wbtc into mockSpoke1
  //   deal(address(wbtc), USER2, wbtcBorrowAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

  //   // USER1 borrow usdc
  //   Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //   // USER1 borrow wbtc
  //   Utils.borrow(vm, mockSpoke1, wbtcAssetId, USER1, wbtcBorrowAmount, USER1);

  //   uint256[] memory collateralAssetIds = new uint256[](2);
  //   collateralAssetIds[0] = daiAssetId;
  //   collateralAssetIds[1] = ethAssetId;
  //   (
  //     uint256 expectedTotalCollateralInBaseCurrency,
  //     uint256 expectedAvgLiquidationThreshold
  //   ) = _calculateTotalCollateralInBaseCurrencyAndAvgLT(collateralAssetIds, USER1);

  //   uint256[] memory debtAssetIds = new uint256[](2);
  //   debtAssetIds[0] = usdcAssetId;
  //   debtAssetIds[1] = wbtcAssetId;
  //   uint256 expectedTotalDebtInBaseCurrency = _calculateTotalDebtInBaseCurrency(
  //     debtAssetIds,
  //     USER1
  //   );

  //   uint256 expectedHF = expectedTotalDebtInBaseCurrency == 0
  //     ? type(uint256).max
  //     : (expectedTotalCollateralInBaseCurrency.wadMul(expectedAvgLiquidationThreshold)).wadDiv(
  //       expectedTotalDebtInBaseCurrency
  //     ) / 1e4;

  //   (
  //     uint256 totalCollateralInBaseCurrency,
  //     uint256 totalDebtInBaseCurrency,
  //     uint256 avgLiquidationThreshold,
  //     uint256 userRiskPremium,
  //     uint256 healthFactor
  //   ) = mockSpoke1.calculateUserAccountData(USER1);

  //   assertEq(
  //     totalCollateralInBaseCurrency,
  //     expectedTotalCollateralInBaseCurrency,
  //     'Unexpected totalCollateralInBaseCurrency'
  //   );
  //   assertEq(
  //     totalDebtInBaseCurrency,
  //     expectedTotalDebtInBaseCurrency,
  //     'Unexpected totalDebtInBaseCurrency'
  //   );
  //   assertEq(
  //     avgLiquidationThreshold,
  //     expectedAvgLiquidationThreshold,
  //     'Unexpected avgLiquidationThreshold'
  //   );
  //   assertEq(userRiskPremium, 0, 'Unexpected userRiskPremium');
  //   assertEq(healthFactor, expectedHF, 'Unexpected healthFactor');
  // }

  DataTypes.Reserve internal collateralReserve;

  function test_calculateActualDebtToLiquidate() public {
    // uint256 debtToCover = 100e18;
    // address user = alice;
    // uint256 debtReserveId = _wethReserveId(ISpoke(mockSpoke1));
    // mockSpoke1.calculateActualDebtToLiquidate(collateralReserve,
    // );
    // uint256 debtToCover,
    // address user,
    // uint256 debtReserveId,
    // DataTypes.LiquidationCallLocalVars memory params
  }

  // /// forge-config: ci.fuzz.runs = 1000
  // function test_fuzz_calculateActualDebtToLiquidate(
  //   uint256 daiAmount,
  //   uint256 ethAmount,
  //   uint256 usdcBorrowAmount,
  //   uint256 wbtcBorrowAmount,
  //   uint256 debtToCover
  // ) public {
  //   // uint256 daiAmount = 1e18;
  //   // uint256 ethAmount = 1e18;
  //   // uint256 usdcBorrowAmount = 15e18;
  //   // uint256 wbtcBorrowAmount = 1e15;
  //   // uint256 debtToCover = usdcBorrowAmount;

  //   daiAmount = bound(daiAmount, 1e2, 1e28);
  //   ethAmount = bound(ethAmount, 1e2, 1e28);
  //   usdcBorrowAmount = bound(usdcBorrowAmount, 1e2, 1e27);
  //   wbtcBorrowAmount = bound(wbtcBorrowAmount, 1e2, 1e25);
  //   debtToCover = bound(debtToCover, 1e2, 1e30);

  //   uint256 daiAssetId = 0;
  //   uint256 ethAssetId = 1;
  //   uint256 usdcAssetId = 2;
  //   uint256 wbtcAssetId = 3;

  //   // USER1 supply dai into mockSpoke1
  //   deal(address(dai), USER1, daiAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, true);

  //   // USER1 supply eth into mockSpoke1
  //   deal(address(eth), USER1, ethAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, true);

  //   // USER2 supply usdc into mockSpoke1
  //   deal(address(usdc), USER2, usdcBorrowAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //   // USER2 supply wbtc into mockSpoke1
  //   deal(address(wbtc), USER2, wbtcBorrowAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

  //   // USER1 borrow usdc
  //   Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //   // USER1 borrow wbtc
  //   Utils.borrow(vm, mockSpoke1, wbtcAssetId, USER1, wbtcBorrowAmount, USER1);

  //   TestCalculateActualDebtToLiquidateLocalParams memory vars;

  //   vars.collateralReserve = mockSpoke1.getReserve(daiAssetId);

  //   (
  //     vars.totalCollateralInBaseCurrency,
  //     vars.totalDebtInBaseCurrency,
  //     vars.avgLiquidationThreshold,
  //     ,
  //     vars.healthFactor
  //   ) = mockSpoke1.calculateUserAccountData(USER1);

  //   vars.collateralAssetIds = new uint256[](2);
  //   vars.collateralAssetIds[0] = daiAssetId;
  //   vars.collateralAssetIds[1] = ethAssetId;

  //   vars.debtAssetIds = new uint256[](2);
  //   vars.debtAssetIds[0] = usdcAssetId;
  //   vars.debtAssetIds[1] = wbtcAssetId;

  //   (, , vars.expectedActualDebtToLiquidate) = _calculateActualDebtToLiquidate(
  //     debtToCover,
  //     USER1,
  //     usdcAssetId,
  //     daiAssetId,
  //     vars.debtAssetIds,
  //     vars.collateralAssetIds
  //   );

  //   // uint256 actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //   //   debtToCover,
  //   //   USER1,
  //   //   usdcAssetId,
  //   //   vars.totalCollateralInBaseCurrency,
  //   //   vars.totalDebtInBaseCurrency,
  //   //   vars.avgLiquidationThreshold,
  //   //   vars.collateralReserve
  //   // );

  //   // assertEq(
  //   //   actualDebtToLiquidate,
  //   //   vars.expectedActualDebtToLiquidate,
  //   //   'Unexpected actualDebtToLiquidate'
  //   // );
  // }

  // /// forge-config: ci.fuzz.runs = 1000
  // function test_fuzz_calculateActualDebtToLiquidate_noDebt(
  //   uint256 daiAmount,
  //   uint256 ethAmount,
  //   uint256 usdcBorrowAmount,
  //   uint256 wbtcBorrowAmount,
  //   uint256 debtToCover
  // ) public {
  //   daiAmount = bound(daiAmount, 1e2, 1e28);
  //   ethAmount = bound(ethAmount, 1e2, 1e28);
  //   usdcBorrowAmount = bound(usdcBorrowAmount, 1e2, 1e27);
  //   wbtcBorrowAmount = bound(wbtcBorrowAmount, 1e2, 1e25);
  //   debtToCover = bound(debtToCover, 1e2, 1e30);

  //   uint256 daiAssetId = 0;
  //   uint256 ethAssetId = 1;
  //   uint256 usdcAssetId = 2;
  //   uint256 wbtcAssetId = 3;

  //   // USER1 supply dai into mockSpoke1
  //   deal(address(dai), USER1, daiAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, true);

  //   // USER1 supply eth into mockSpoke1
  //   deal(address(eth), USER1, ethAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, true);

  //   // USER2 supply usdc into mockSpoke1
  //   deal(address(usdc), USER2, usdcBorrowAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //   // USER2 supply wbtc into mockSpoke1
  //   deal(address(wbtc), USER2, wbtcBorrowAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

  //   TestCalculateActualDebtToLiquidateLocalParams memory vars;

  //   vars.collateralReserve = mockSpoke1.getReserve(daiAssetId);
  //   vars.debtAssetPrice = oracle.getAssetPrice(usdcAssetId);

  //   (
  //     vars.totalCollateralInBaseCurrency,
  //     vars.totalDebtInBaseCurrency,
  //     vars.avgLiquidationThreshold,
  //     ,
  //     vars.healthFactor
  //   ) = mockSpoke1.calculateUserAccountData(USER1);

  //   uint256 actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //     vars.collateralReserve,
  //     debtToCover,
  //     USER1,
  //     usdcAssetId,
  //     vars.totalCollateralInBaseCurrency,
  //     vars.totalDebtInBaseCurrency,
  //     vars.avgLiquidationThreshold,
  //     vars.debtAssetPrice
  //   );

  //   assertEq(actualDebtToLiquidate, 0, 'Unexpected actualDebtToLiquidate');
  // }

  // /// forge-config: default.fuzz.runs = 1000
  // function test_fuzz_calculateActualDebtToLiquidate_noCollateral(
  //   uint256 debtToCover,
  //   uint256 debtAssetId
  // ) public {
  //   debtAssetId = bound(debtAssetId, 0, 3); // only 4 assets defined

  //   TestCalculateActualDebtToLiquidateLocalParams memory vars;

  //   vars.collateralReserve = mockSpoke1.getReserve(debtAssetId);
  //   vars.debtAssetPrice = oracle.getAssetPrice(debtAssetId);

  //   (
  //     vars.totalCollateralInBaseCurrency,
  //     vars.totalDebtInBaseCurrency,
  //     vars.avgLiquidationThreshold,
  //     ,
  //     vars.healthFactor
  //   ) = mockSpoke1.calculateUserAccountData(USER1);

  //   uint256 actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //     vars.collateralReserve,
  //     debtToCover,
  //     USER1,
  //     debtAssetId,
  //     vars.totalCollateralInBaseCurrency,
  //     vars.totalDebtInBaseCurrency,
  //     vars.avgLiquidationThreshold,
  //     vars.debtAssetPrice
  //   );

  //   assertEq(actualDebtToLiquidate, 0, 'Unexpected actualDebtToLiquidate');
  // }

  // /// forge-config: default.fuzz.runs = 1000
  // function test_fuzz_calculateAvailableCollateralToLiquidate_noLpfp(
  //   uint256 daiAmount,
  //   uint256 ethAmount,
  //   uint256 usdcBorrowAmount,
  //   uint256 wbtcBorrowAmount,
  //   uint256 debtToCover
  // ) public {
  //   daiAmount = bound(daiAmount, 1e2, 1e28);
  //   ethAmount = bound(ethAmount, 1e2, 1e28);
  //   usdcBorrowAmount = bound(usdcBorrowAmount, 1e2, 1e27);
  //   wbtcBorrowAmount = bound(wbtcBorrowAmount, 1e2, 1e25);
  //   debtToCover = bound(debtToCover, 1e2, 1e30);

  //   uint256 daiAssetId = 0;
  //   uint256 ethAssetId = 1;
  //   uint256 usdcAssetId = 2;
  //   uint256 wbtcAssetId = 3;

  //   // USER1 supply dai into mockSpoke1
  //   deal(address(dai), USER1, daiAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, true);

  //   // USER1 supply eth into mockSpoke1
  //   deal(address(eth), USER1, ethAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, true);

  //   // USER2 supply usdc into mockSpoke1
  //   deal(address(usdc), USER2, usdcBorrowAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //   // USER2 supply wbtc into mockSpoke1
  //   deal(address(wbtc), USER2, wbtcBorrowAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

  //   // USER1 borrow usdc
  //   Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //   // USER1 borrow wbtc
  //   Utils.borrow(vm, mockSpoke1, wbtcAssetId, USER1, wbtcBorrowAmount, USER1);

  //   TestCalculateActualDebtToLiquidateLocalParams memory vars;
  //   vars.debtAssetPrice = oracle.getAssetPrice(usdcAssetId);

  //   (
  //     vars.totalCollateralInBaseCurrency,
  //     vars.totalDebtInBaseCurrency,
  //     vars.avgLiquidationThreshold,
  //     ,
  //     vars.healthFactor
  //   ) = mockSpoke1.calculateUserAccountData(USER1);

  //   vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //     vars.collateralReserve,
  //     debtToCover,
  //     USER1,
  //     usdcAssetId,
  //     vars.totalCollateralInBaseCurrency,
  //     vars.totalDebtInBaseCurrency,
  //     vars.avgLiquidationThreshold,
  //     vars.debtAssetPrice
  //   );

  //   (
  //     vars.expectedActualCollateralToLiquidate,
  //     vars.expectedActualDebtToLiquidate,
  //     vars.expectedLiquidationProtocolFeeAmount
  //   ) = _calculateAvailableCollateralToLiquidate(
  //     mockSpoke1.getReserve(daiAssetId),
  //     mockSpoke1.getReserve(usdcAssetId),
  //     vars.actualDebtToLiquidate,
  //     mockSpoke1.getUserSupplyInAssets(daiAssetId, USER1)
  //   );

  //   (
  //     vars.actualCollateralToLiquidate,
  //     vars.actualDebtToLiquidate,
  //     vars.liquidationProtocolFeeAmount
  //   ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
  //     mockSpoke1.getReserve(daiAssetId),
  //     mockSpoke1.getReserve(usdcAssetId),
  //     vars.actualDebtToLiquidate,
  //     mockSpoke1.getUserSupplyInAssets(daiAssetId, USER1),
  //     vars.debtAssetPrice
  //   );

  //   assertEq(
  //     vars.actualCollateralToLiquidate,
  //     vars.expectedActualCollateralToLiquidate,
  //     'Unexpected actualCollateralToLiquidate'
  //   );
  //   assertEq(
  //     vars.actualDebtToLiquidate,
  //     vars.expectedActualDebtToLiquidate,
  //     'Unexpected actualDebtToLiquidate'
  //   );
  //   assertEq(
  //     vars.liquidationProtocolFeeAmount,
  //     vars.expectedLiquidationProtocolFeeAmount,
  //     'Unexpected liquidationProtocolFeeAmount'
  //   );
  //   assertEq(vars.liquidationProtocolFeeAmount, 0, 'Unexpected liquidationProtocolFeeAmount');
  //   assertEq(
  //     (vars.actualCollateralToLiquidate + vars.expectedLiquidationProtocolFeeAmount).percentDiv(
  //       mockSpoke1.getLiquidationBonus(daiAssetId)
  //     ),
  //     vars.actualDebtToLiquidate,
  //     'Unexpected ratio of collateral to debt'
  //   );
  // }

  // /// forge-config: default.fuzz.runs = 1000
  // function test_fuzz_calculateAvailableCollateralToLiquidate_withLpfp(
  //   uint256 daiAmount,
  //   uint256 ethAmount,
  //   uint256 usdcBorrowAmount,
  //   uint256 wbtcBorrowAmount,
  //   uint256 debtToCover
  // ) public {
  //   daiAmount = bound(daiAmount, 1e2, 1e28);
  //   ethAmount = bound(ethAmount, 1e2, 1e28);
  //   usdcBorrowAmount = bound(usdcBorrowAmount, 1e2, 1e27);
  //   wbtcBorrowAmount = bound(wbtcBorrowAmount, 1e2, 1e25);
  //   debtToCover = bound(debtToCover, 1e2, 1e30);

  //   // uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //   // uint256 ethAmount = 10e18; // 10 eth -> $20k
  //   // uint256 wbtcBorrowAmount = 1e18; // 1 wbtc -> $50k
  //   // uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
  //   // uint256 debtToCover = 10_000e18;

  //   uint256 daiAssetId = 0;
  //   uint256 ethAssetId = 1;
  //   uint256 usdcAssetId = 2;
  //   uint256 wbtcAssetId = 3;

  //   // USER1 supply dai into mockSpoke1
  //   deal(address(dai), USER1, daiAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, true);

  //   // USER1 supply eth into mockSpoke1
  //   deal(address(eth), USER1, ethAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
  //   Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, true);

  //   // USER2 supply usdc into mockSpoke1
  //   deal(address(usdc), USER2, usdcBorrowAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //   // USER2 supply wbtc into mockSpoke1
  //   deal(address(wbtc), USER2, wbtcBorrowAmount);
  //   Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

  //   // USER1 borrow usdc
  //   Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //   // USER1 borrow wbtc
  //   Utils.borrow(vm, mockSpoke1, wbtcAssetId, USER1, wbtcBorrowAmount, USER1);

  //   // set lpfp to 200 BPS, 2%
  //   Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, daiAssetId, 200);

  //   console2.log(
  //     'mockSpoke1.getLiquidationProtocolFeePercentage(daiAssetId) %e',
  //     mockSpoke1.getLiquidationProtocolFeePercentage(daiAssetId)
  //   );

  //   TestCalculateActualDebtToLiquidateLocalParams memory vars;

  //   vars.collateralReserve = mockSpoke1.getReserve(daiAssetId);
  //   vars.debtAssetPrice = oracle.getAssetPrice(usdcAssetId);

  //   (
  //     vars.totalCollateralInBaseCurrency,
  //     vars.totalDebtInBaseCurrency,
  //     vars.avgLiquidationThreshold,
  //     ,
  //     vars.healthFactor
  //   ) = mockSpoke1.calculateUserAccountData(USER1);

  //   vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //     vars.collateralReserve,
  //     debtToCover,
  //     USER1,
  //     usdcAssetId,
  //     vars.totalCollateralInBaseCurrency,
  //     vars.totalDebtInBaseCurrency,
  //     vars.avgLiquidationThreshold,
  //     vars.debtAssetPrice
  //   );

  //   (
  //     vars.expectedActualCollateralToLiquidate,
  //     vars.expectedActualDebtToLiquidate,
  //     vars.expectedLiquidationProtocolFeeAmount
  //   ) = _calculateAvailableCollateralToLiquidate(
  //     mockSpoke1.getReserve(daiAssetId),
  //     mockSpoke1.getReserve(usdcAssetId),
  //     vars.actualDebtToLiquidate,
  //     mockSpoke1.getUserSupplyInAssets(daiAssetId, USER1)
  //   );

  //   (
  //     vars.actualCollateralToLiquidate,
  //     vars.actualDebtToLiquidate,
  //     vars.liquidationProtocolFeeAmount
  //   ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
  //     mockSpoke1.getReserve(daiAssetId),
  //     mockSpoke1.getReserve(usdcAssetId),
  //     vars.actualDebtToLiquidate,
  //     mockSpoke1.getUserSupplyInAssets(daiAssetId, USER1),
  //     vars.debtAssetPrice
  //   );

  //   console2.log('vars.healthFactor %e', vars.healthFactor);
  //   console2.log('vars.liquidationProtocolFeeAmount %e', vars.liquidationProtocolFeeAmount);

  //   assertEq(
  //     vars.actualCollateralToLiquidate,
  //     vars.expectedActualCollateralToLiquidate,
  //     'Unexpected actualCollateralToLiquidate'
  //   );
  //   assertEq(
  //     vars.actualDebtToLiquidate,
  //     vars.expectedActualDebtToLiquidate,
  //     'Unexpected actualDebtToLiquidate'
  //   );
  //   assertEq(
  //     vars.liquidationProtocolFeeAmount,
  //     vars.expectedLiquidationProtocolFeeAmount,
  //     'Unexpected liquidationProtocolFeeAmount'
  //   );

  //   console2.log('test vars.actualCollateralToLiquidate %e', vars.actualCollateralToLiquidate);
  //   console2.log('test vars.actualDebtToLiquidate %e', vars.actualDebtToLiquidate);
  //   console2.log(
  //     'test vars.expectedLiquidationProtocolFeeAmount %e',
  //     vars.expectedLiquidationProtocolFeeAmount
  //   );
  //   assertEq(
  //     (vars.actualCollateralToLiquidate + vars.expectedLiquidationProtocolFeeAmount).percentDiv(
  //       mockSpoke1.getLiquidationBonus(daiAssetId)
  //     ),
  //     vars.actualDebtToLiquidate,
  //     'Unexpected ratio of collateral to debt'
  //   );
  //   vars.collateralAmount = (vars.actualCollateralToLiquidate +
  //     vars.expectedLiquidationProtocolFeeAmount);
  //   vars.bonusCollateral =
  //     vars.collateralAmount -
  //     vars.collateralAmount.percentDiv(mockSpoke1.getLiquidationBonus(daiAssetId));

  //   // console2.log('vars.bonusCollateral %e', vars.bonusCollateral);
  //   assertEq(
  //     vars.expectedLiquidationProtocolFeeAmount,
  //     vars.bonusCollateral.percentMul(mockSpoke1.getLiquidationProtocolFeePercentage(daiAssetId))
  //   );
  // }

  // /// @return totalCollateralInBaseCurrency total collateral in base currency
  // /// @return avgLiquidationThreshold average liquidation threshold
  // function _calculateTotalCollateralInBaseCurrencyAndAvgLT(
  //   uint256[] memory collateralAssetIds,
  //   address user
  // ) internal returns (uint256, uint256) {
  //   uint256 totalCollateralInBaseCurrency;
  //   uint256 avgLiquidationThreshold;
  //   for (uint256 i; i < collateralAssetIds.length; i++) {
  //     DataTypes.Reserve memory r = mockSpoke1.getReserve(collateralAssetIds[i]);
  //     uint256 collateralInBaseCurrency = mockSpoke1.getUserSupplyInAssets(
  //       collateralAssetIds[i],
  //       user
  //     ) * oracle.getAssetPrice(collateralAssetIds[i]);
  //     totalCollateralInBaseCurrency += collateralInBaseCurrency;
  //     avgLiquidationThreshold += collateralInBaseCurrency * r.config.lt;
  //   }
  //   avgLiquidationThreshold = totalCollateralInBaseCurrency == 0
  //     ? 0
  //     : avgLiquidationThreshold.wadDiv(totalCollateralInBaseCurrency);
  //   return (totalCollateralInBaseCurrency, avgLiquidationThreshold);
  // }

  // function _calculateTotalDebtInBaseCurrency(
  //   uint256[] memory debtAssetIds,
  //   address user
  // ) internal returns (uint256) {
  //   uint256 totalDebtInBaseCurrency;
  //   for (uint256 i; i < debtAssetIds.length; i++) {
  //     totalDebtInBaseCurrency +=
  //       mockSpoke1.getUserDebtInAssets(debtAssetIds[i], user) *
  //       oracle.getAssetPrice(debtAssetIds[i]);
  //   }
  //   return totalDebtInBaseCurrency;
  // }

  // struct CalculateActualDebtToLiquidateLocalParams {
  //   uint256 totalDebtInBaseCurrency;
  //   uint256 totalCollateralInBaseCurrency;
  //   uint256 avgLiquidationThreshold;
  //   uint256 liquidationRecoveryDebt;
  //   uint256 debtAssetPrice;
  //   uint256 hfScaledDebt;
  //   uint256 weightedCollateral;
  // }

  // /// @return recoveryThresholdLiquidatableDebt liquidatable debt to restore HF to HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD
  // /// @return maxLiquidatableDebt max liquidatable debt based on user's total debt
  // function _calculateActualDebtToLiquidate(
  //   uint256 debtToCover,
  //   address user,
  //   uint256 debtAssetId,
  //   uint256 collateralAssetId,
  //   uint256[] memory debtAssetIds,
  //   uint256[] memory collateralAssetIds
  // )
  //   internal
  //   returns (
  //     uint256 recoveryThresholdLiquidatableDebt,
  //     uint256 maxLiquidatableDebt,
  //     uint256 actualDebtToLiquidate
  //   )
  // {
  //   console2.log('------- test calculateActualDebtToLiquidate -------');

  //   CalculateActualDebtToLiquidateLocalParams memory vars;

  //   vars.totalDebtInBaseCurrency = _calculateTotalDebtInBaseCurrency(debtAssetIds, user);
  //   (
  //     vars.totalCollateralInBaseCurrency,
  //     vars.avgLiquidationThreshold
  //   ) = _calculateTotalCollateralInBaseCurrencyAndAvgLT(collateralAssetIds, user);

  //   DataTypes.Reserve memory collateralReserve = mockSpoke1.getReserve(collateralAssetId);

  //   vars.debtAssetPrice = IPriceOracle(oracle).getAssetPrice(debtAssetId);

  //   console2.log(
  //     'calc %e',
  //     mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD().wadMul(vars.totalDebtInBaseCurrency)
  //   );
  //   console2.log(
  //     'calc2 %e',
  //     vars.totalCollateralInBaseCurrency.wadMul(vars.avgLiquidationThreshold)
  //   );

  //   vars.hfScaledDebt = mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD().wadMul(
  //     vars.totalDebtInBaseCurrency
  //   );
  //   vars.weightedCollateral =
  //     vars.totalCollateralInBaseCurrency.wadMul(vars.avgLiquidationThreshold) /
  //     1e4;
  //   vars.debtAssetPrice = MockPriceOracle(address(oracle)).getAssetPrice(debtAssetId);

  //   // amount of user debt that corresponds to HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD
  //   uint256 liquidationRecoveryDebt = vars.hfScaledDebt > vars.weightedCollateral
  //     ? (vars.hfScaledDebt - vars.weightedCollateral).wadDiv(
  //       mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD() -
  //         (collateralReserve.config.lb * 1e14).percentMul(collateralReserve.config.lt) // convert BPS to WAD
  //     )
  //     : 0;

  //   liquidationRecoveryDebt = vars.debtAssetPrice == 0
  //     ? 0
  //     : vars.liquidationRecoveryDebt / vars.debtAssetPrice;

  //   vars.liquidationRecoveryDebt = vars.totalDebtInBaseCurrency > vars.liquidationRecoveryDebt
  //     ? vars.liquidationRecoveryDebt
  //     : 0;

  //   maxLiquidatableDebt = mockSpoke1.getUserDebtInAssets(debtAssetId, user);

  //   maxLiquidatableDebt = maxLiquidatableDebt > vars.liquidationRecoveryDebt
  //     ? vars.liquidationRecoveryDebt
  //     : maxLiquidatableDebt;
  //   actualDebtToLiquidate = debtToCover > maxLiquidatableDebt ? maxLiquidatableDebt : debtToCover;
  // }

  // function _calculateAvailableCollateralToLiquidate(
  //   DataTypes.Reserve memory collateralReserve,
  //   DataTypes.Reserve memory debtReserve,
  //   uint256 actualDebtToLiquidate,
  //   uint256 userCollateralBalance
  // ) internal returns (uint256, uint256, uint256) {
  //   Spoke.AvailableCollateralToLiquidateLocalVars memory vars;

  //   vars.collateralAssetPrice = MockPriceOracle(address(oracle)).getAssetPrice(
  //     collateralReserve.id
  //   );
  //   vars.debtAssetPrice = MockPriceOracle(address(oracle)).getAssetPrice(debtReserve.id);

  //   vars.collateralAssetUnit = 10 ** collateralReserve.decimals;
  //   vars.debtAssetUnit = 10 ** debtReserve.decimals;

  //   vars.liquidationProtocolFeePercentage = mockSpoke1.getLiquidationProtocolFeePercentage(
  //     collateralReserve.id
  //   );

  //   // find collateral amount that corresponds to the debt to cover
  //   vars.baseCollateral =
  //     (vars.debtAssetPrice * actualDebtToLiquidate * vars.collateralAssetUnit) /
  //     (vars.collateralAssetPrice * vars.debtAssetUnit);

  //   vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(collateralReserve.config.lb);

  //   if (vars.maxCollateralToLiquidate > userCollateralBalance) {
  //     vars.collateralAmount = userCollateralBalance;
  //     vars.debtAmountNeeded = ((vars.collateralAssetPrice *
  //       vars.collateralAmount *
  //       vars.debtAssetUnit) / (vars.debtAssetPrice * vars.collateralAssetUnit)).percentDiv(
  //         collateralReserve.config.lb
  //       );
  //   } else {
  //     vars.collateralAmount = vars.maxCollateralToLiquidate;
  //     vars.debtAmountNeeded = actualDebtToLiquidate;
  //   }

  //   if (vars.liquidationProtocolFeePercentage != 0) {
  //     vars.bonusCollateral =
  //       vars.collateralAmount -
  //       vars.collateralAmount.percentDiv(collateralReserve.config.lb);

  //     vars.liquidationProtocolFeeAmount = vars.bonusCollateral.percentMul(
  //       vars.liquidationProtocolFeePercentage
  //     );

  //     return (
  //       vars.collateralAmount - vars.liquidationProtocolFeeAmount,
  //       vars.debtAmountNeeded,
  //       vars.liquidationProtocolFeeAmount
  //     );
  //   } else {
  //     return (vars.collateralAmount, vars.debtAmountNeeded, 0);
  //   }
  // }
}
