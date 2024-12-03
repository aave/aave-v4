// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract LiquidationTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

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
    spoke1.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  }

  function test_liquidationCall_no_supply_revertsWith_health_factor_not_below_threshold() public {
    uint256 ethAssetId = 1; // collateral asset
    uint256 daiAssetId = 0; // debt asset
    uint256 debtToCover = 1;

    vm.expectRevert(TestErrors.HEALTH_FACTOR_NOT_BELOW_THRESHOLD);
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
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

    // USER1 supply dai into spoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, spoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, spoke1, USER1, daiAssetId, usingAsCollateral);

    // USER1 supply eth into spoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, spoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, spoke1, USER1, ethAssetId, usingAsCollateral);

    // USER2 supply usdc into spoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, spoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, spoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    vm.prank(LIQUIDATOR);
    vm.expectRevert(TestErrors.HEALTH_FACTOR_NOT_BELOW_THRESHOLD);
    spoke1.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
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

    // USER1 supply dai into spoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, spoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, spoke1, USER1, daiAssetId, usingAsCollateral);

    // USER1 supply eth into spoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, spoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, spoke1, USER1, ethAssetId, usingAsCollateral);

    // USER1 supply wbtc into spoke1, NOT as collateral
    deal(address(wbtc), USER1, wbtcAmount);
    Utils.spokeSupply(vm, hub, spoke1, wbtcAssetId, USER1, wbtcAmount, USER1);

    // USER2 supply usdc into spoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, spoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, spoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // HF drops below threshold, eth -> 0
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0);

    // wbtc is not set usingAsCollateral
    vm.prank(LIQUIDATOR);
    vm.expectRevert(TestErrors.COLLATERAL_CANNOT_BE_LIQUIDATED);
    spoke1.liquidationCall(wbtcAssetId, daiAssetId, USER1, debtToCover);
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

    // USER1 supply dai into spoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, spoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, spoke1, USER1, daiAssetId, usingAsCollateral);

    // USER1 supply eth into spoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, spoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, spoke1, USER1, ethAssetId, usingAsCollateral);

    // USER1 supply wbtc into spoke1
    deal(address(wbtc), USER1, wbtcAmount);
    Utils.spokeSupply(vm, hub, spoke1, wbtcAssetId, USER1, wbtcAmount, USER1);
    Utils.setUsingAsCollateral(vm, spoke1, USER1, wbtcAssetId, usingAsCollateral);

    // USER2 supply usdc into spoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, spoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, spoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // HF drops below threshold, eth -> 0
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0);

    // set LT to 0 for wbtc
    Utils.updateLiquidationThreshold(spoke1, wbtcAssetId, 0);

    // wbtc is not set usingAsCollateral
    vm.prank(LIQUIDATOR);
    vm.expectRevert(TestErrors.COLLATERAL_CANNOT_BE_LIQUIDATED);
    spoke1.liquidationCall(wbtcAssetId, daiAssetId, USER1, debtToCover);
  }

  struct TestLiquidationCallLocalParams {
    Spoke.UserConfig user1DaiData0;
    Spoke.UserConfig user1EthData0;
    Spoke.UserConfig user1UsdcData0;
    Spoke.UserConfig user2UsdcData0;
    Spoke.Reserve reserveDaiData0;
    LiquidityHub.Spoke spoke1DaiData0;
    LiquidityHub.Spoke spoke1EthData0;
    LiquidityHub.Spoke spoke1UsdcData0;
    Spoke.UserConfig user1DaiData1;
    Spoke.UserConfig user1EthData1;
    Spoke.UserConfig user1UsdcData1;
    Spoke.UserConfig user2UsdcData1;
    LiquidityHub.Spoke spoke1DaiData1;
    LiquidityHub.Spoke spoke1EthData1;
    LiquidityHub.Spoke spoke1UsdcData1;
    uint256 expectedCollateralLiquidated;
    uint256 expectedDebtCovered;
    uint256 expectedProtocolFee;
    uint256 actualDebtCovered;
  }

  /// @dev Test liquidation call with liquidated amount lt user collateral balance
  function test_liquidationCall_gteUserCollateralBalance_noLiquidationProtocolFee() public {
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

    // USER1 supply dai into spoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, spoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, spoke1, USER1, daiAssetId, usingAsCollateral);

    // USER1 supply eth into spoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, spoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, spoke1, USER1, ethAssetId, usingAsCollateral);

    // USER2 supply usdc into spoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, spoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, spoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // HF drops below threshold, eth -> $0.10
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0e8);
    // if eth -> 0, total collateral: $10k. LT is 0.75
    // total borrowed is $15k, total collateral is $10k
    // HF = collateral * LT / borrowed = 0.75 * $10k / $15k = 0.5
    // if paying back $10k in debt, collateral to liquidate = $10k

    TestLiquidationCallLocalParams memory testLiquidationCallLocalParams;

    // pre-liquidation
    testLiquidationCallLocalParams.user1DaiData0 = spoke1.getUser(daiAssetId, USER1);
    testLiquidationCallLocalParams.spoke1DaiData0 = hub.getSpoke(daiAssetId, address(spoke1));

    testLiquidationCallLocalParams.user1EthData0 = spoke1.getUser(ethAssetId, USER1);
    testLiquidationCallLocalParams.spoke1EthData0 = hub.getSpoke(ethAssetId, address(spoke1));

    testLiquidationCallLocalParams.user1UsdcData0 = spoke1.getUser(usdcAssetId, USER1);
    testLiquidationCallLocalParams.user2UsdcData0 = spoke1.getUser(usdcAssetId, USER2);
    testLiquidationCallLocalParams.spoke1UsdcData0 = hub.getSpoke(usdcAssetId, address(spoke1));

    testLiquidationCallLocalParams.expectedCollateralLiquidated = hub.convertSharesToAssetsDown(
      daiAssetId,
      testLiquidationCallLocalParams.spoke1DaiData0.totalShares
    );
    testLiquidationCallLocalParams.expectedDebtCovered = _getExpectedDebtCovered(
      daiAssetId,
      usdcAssetId,
      testLiquidationCallLocalParams.expectedCollateralLiquidated
    );

    // dai
    assertEq(
      testLiquidationCallLocalParams.user1DaiData0.usingAsCollateral,
      true,
      'Unexpected user1 dai usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.user1DaiData0.supplyShares,
      testLiquidationCallLocalParams.spoke1DaiData0.totalShares,
      'Unexpected user1 dai supplyShares'
    );
    assertEq(
      testLiquidationCallLocalParams.user1DaiData0.debtShares,
      0,
      'Unexpected user1 dai debtShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1DaiData0.totalShares,
      hub.convertAssetsToSharesDown(daiAssetId, daiAmount),
      'Unexpected spoke1 dai totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1DaiData0.drawnShares,
      0,
      'Unexpected spoke1 dai drawnShares'
    );
    // eth
    assertEq(
      testLiquidationCallLocalParams.user1EthData0.usingAsCollateral,
      true,
      'Unexpected user1 eth usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.user1EthData0.supplyShares,
      testLiquidationCallLocalParams.spoke1EthData0.totalShares,
      'Unexpected user1 eth supplyShares'
    );
    assertEq(
      testLiquidationCallLocalParams.user1EthData0.debtShares,
      0,
      'Unexpected user1 eth debtShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1EthData0.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected spoke1 eth totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1EthData0.drawnShares,
      0,
      'Unexpected spoke1 eth drawnShares'
    );
    // usdc
    assertEq(
      testLiquidationCallLocalParams.user1UsdcData0.usingAsCollateral,
      false,
      'Unexpected user1 usdc usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.user2UsdcData0.supplyShares,
      testLiquidationCallLocalParams.spoke1UsdcData0.totalShares,
      'Unexpected user2 usdc supplyShares'
    );
    assertEq(
      testLiquidationCallLocalParams.user1UsdcData0.debtShares,
      testLiquidationCallLocalParams.user2UsdcData0.supplyShares,
      'Unexpected user1 usdc debtShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1UsdcData0.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected spoke1 usdc totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1UsdcData0.drawnShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected spoke1 usdc drawnShares'
    );

    // action: liquidation
    deal(address(usdc), LIQUIDATOR, debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(spoke1), debtToCover);

    vm.expectEmit(address(spoke1));
    emit LiquidationCall({
      collateralAssetId: daiAssetId,
      debtAssetId: usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: testLiquidationCallLocalParams.expectedDebtCovered,
      actualCollateralToLiquidate: testLiquidationCallLocalParams.expectedCollateralLiquidated,
      liquidator: LIQUIDATOR
    });
    spoke1.liquidationCall(daiAssetId, usdcAssetId, USER1, debtToCover);
    vm.stopPrank();

    // post-liquidation
    testLiquidationCallLocalParams.user1DaiData1 = spoke1.getUser(daiAssetId, USER1);
    testLiquidationCallLocalParams.spoke1DaiData1 = hub.getSpoke(daiAssetId, address(spoke1));
    testLiquidationCallLocalParams.user1EthData1 = spoke1.getUser(ethAssetId, USER1);
    testLiquidationCallLocalParams.spoke1EthData1 = hub.getSpoke(ethAssetId, address(spoke1));
    testLiquidationCallLocalParams.user1UsdcData1 = spoke1.getUser(usdcAssetId, USER1);
    testLiquidationCallLocalParams.spoke1UsdcData1 = hub.getSpoke(usdcAssetId, address(spoke1));
    testLiquidationCallLocalParams.actualDebtCovered = debtToCover - usdc.balanceOf(LIQUIDATOR);

    // dai
    // TODO: update after enhanced liq, no longer zero collateral remaining
    assertEq(
      testLiquidationCallLocalParams.user1DaiData1.usingAsCollateral,
      false,
      'Unexpected user1 dai usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1DaiData1.totalShares,
      0,
      'Unexpected spoke1 dai totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1DaiData1.drawnShares,
      0,
      'Unexpected spoke1 dai drawnShares'
    );
    // eth
    assertEq(
      testLiquidationCallLocalParams.user1EthData1.usingAsCollateral,
      true,
      'Unexpected eth usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected spoke1 eth totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1EthData1.drawnShares,
      0,
      'Unexpected spoke1 eth drawnShares'
    );
    // usdc
    assertEq(
      testLiquidationCallLocalParams.user1UsdcData1.usingAsCollateral,
      false,
      'Unexpected usdc usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected spoke1 usdc totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1UsdcData1.drawnShares,
      testLiquidationCallLocalParams.spoke1UsdcData1.totalShares -
        hub.convertAssetsToSharesDown(
          usdcAssetId,
          testLiquidationCallLocalParams.actualDebtCovered
        ),
      'Unexpected spoke1 usdc drawnShares'
    );
    // TODO: assertion on health factor, should be 1e18 after enhanced liq

    // liquidator
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      testLiquidationCallLocalParams.expectedCollateralLiquidated,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(spoke1.RESERVE_TREASURY_ADDRESS()),
      0,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

  /// @dev Test liquidation call with liquidated amount lt user collateral balance
  function test_liquidationCall_gteUserCollateralBalance_withLiquidationProtocolFee() public {
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

    // USER1 supply dai into spoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(vm, hub, spoke1, daiAssetId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(vm, spoke1, USER1, daiAssetId, usingAsCollateral);
    Utils.updateLiquidationProtocolFeePercentage(spoke1, daiAssetId, newLpfp);

    // USER1 supply eth into spoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(vm, hub, spoke1, ethAssetId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(vm, spoke1, USER1, ethAssetId, usingAsCollateral);

    // USER2 supply usdc into spoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(vm, hub, spoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

    // USER1 borrow usdc
    Utils.borrow(vm, spoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

    // HF drops below threshold, eth -> $0.10
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0e8);
    // if eth -> 0, total collateral: $10k. LT is 0.75
    // total borrowed is $15k, total collateral is $10k
    // HF = collateral * LT / borrowed = 0.75 * $10k / $15k = 0.5
    // if paying back $10k in debt, collateral to liquidate = $10k

    TestLiquidationCallLocalParams memory testLiquidationCallLocalParams;

    // pre-liquidation
    testLiquidationCallLocalParams.user1DaiData0 = spoke1.getUser(daiAssetId, USER1);
    testLiquidationCallLocalParams.spoke1DaiData0 = hub.getSpoke(daiAssetId, address(spoke1));
    testLiquidationCallLocalParams.reserveDaiData0 = spoke1.getReserve(daiAssetId);

    testLiquidationCallLocalParams.user1EthData0 = spoke1.getUser(ethAssetId, USER1);
    testLiquidationCallLocalParams.spoke1EthData0 = hub.getSpoke(ethAssetId, address(spoke1));

    testLiquidationCallLocalParams.user1UsdcData0 = spoke1.getUser(usdcAssetId, USER1);
    testLiquidationCallLocalParams.user2UsdcData0 = spoke1.getUser(usdcAssetId, USER2);
    testLiquidationCallLocalParams.spoke1UsdcData0 = hub.getSpoke(usdcAssetId, address(spoke1));

    testLiquidationCallLocalParams.expectedCollateralLiquidated = hub.convertSharesToAssetsDown(
      daiAssetId,
      testLiquidationCallLocalParams.spoke1DaiData0.totalShares
    );
    testLiquidationCallLocalParams.expectedDebtCovered = _getExpectedDebtCovered(
      daiAssetId,
      usdcAssetId,
      testLiquidationCallLocalParams.expectedCollateralLiquidated
    );
    (, , testLiquidationCallLocalParams.expectedProtocolFee) = _getExpectedCollateralLiquidated(
      daiAssetId,
      usdcAssetId,
      testLiquidationCallLocalParams.expectedDebtCovered
    );

    assertEq(
      testLiquidationCallLocalParams.reserveDaiData0.config.lpfp,
      newLpfp,
      'Unexpected spoke1 dai liquidation protocol fee percentage'
    );

    // dai
    assertEq(
      testLiquidationCallLocalParams.user1DaiData0.usingAsCollateral,
      true,
      'Unexpected user1 dai usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.user1DaiData0.supplyShares,
      testLiquidationCallLocalParams.spoke1DaiData0.totalShares,
      'Unexpected user1 dai supplyShares'
    );
    assertEq(
      testLiquidationCallLocalParams.user1DaiData0.debtShares,
      0,
      'Unexpected user1 dai debtShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1DaiData0.totalShares,
      hub.convertAssetsToSharesDown(daiAssetId, daiAmount),
      'Unexpected spoke1 dai totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1DaiData0.drawnShares,
      0,
      'Unexpected spoke1 dai drawnShares'
    );
    // eth
    assertEq(
      testLiquidationCallLocalParams.user1EthData0.usingAsCollateral,
      true,
      'Unexpected user1 eth usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.user1EthData0.supplyShares,
      testLiquidationCallLocalParams.spoke1EthData0.totalShares,
      'Unexpected user1 eth supplyShares'
    );
    assertEq(
      testLiquidationCallLocalParams.user1EthData0.debtShares,
      0,
      'Unexpected user1 eth debtShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1EthData0.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected spoke1 eth totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1EthData0.drawnShares,
      0,
      'Unexpected spoke1 eth drawnShares'
    );
    // usdc
    assertEq(
      testLiquidationCallLocalParams.user1UsdcData0.usingAsCollateral,
      false,
      'Unexpected user1 usdc usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.user2UsdcData0.supplyShares,
      testLiquidationCallLocalParams.spoke1UsdcData0.totalShares,
      'Unexpected user2 usdc supplyShares'
    );
    assertEq(
      testLiquidationCallLocalParams.user1UsdcData0.debtShares,
      testLiquidationCallLocalParams.user2UsdcData0.supplyShares,
      'Unexpected user1 usdc debtShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1UsdcData0.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected spoke1 usdc totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1UsdcData0.drawnShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected spoke1 usdc drawnShares'
    );

    // action: liquidation
    deal(address(usdc), LIQUIDATOR, debtToCover);
    vm.startPrank(LIQUIDATOR);
    usdc.approve(address(spoke1), debtToCover);

    vm.expectEmit(address(spoke1));
    emit LiquidationCall({
      collateralAssetId: daiAssetId,
      debtAssetId: usdcAssetId,
      user: USER1,
      actualDebtToLiquidate: testLiquidationCallLocalParams.expectedDebtCovered,
      actualCollateralToLiquidate: testLiquidationCallLocalParams.expectedCollateralLiquidated -
        testLiquidationCallLocalParams.expectedProtocolFee,
      liquidator: LIQUIDATOR
    });
    spoke1.liquidationCall(daiAssetId, usdcAssetId, USER1, debtToCover);
    vm.stopPrank();

    // post-liquidation
    testLiquidationCallLocalParams.user1DaiData1 = spoke1.getUser(daiAssetId, USER1);
    testLiquidationCallLocalParams.spoke1DaiData1 = hub.getSpoke(daiAssetId, address(spoke1));
    testLiquidationCallLocalParams.user1EthData1 = spoke1.getUser(ethAssetId, USER1);
    testLiquidationCallLocalParams.spoke1EthData1 = hub.getSpoke(ethAssetId, address(spoke1));
    testLiquidationCallLocalParams.user1UsdcData1 = spoke1.getUser(usdcAssetId, USER1);
    testLiquidationCallLocalParams.spoke1UsdcData1 = hub.getSpoke(usdcAssetId, address(spoke1));
    testLiquidationCallLocalParams.actualDebtCovered = debtToCover - usdc.balanceOf(LIQUIDATOR);

    // dai
    // TODO: update after enhanced liq, no longer zero collateral remaining
    assertEq(
      testLiquidationCallLocalParams.user1DaiData1.usingAsCollateral,
      false,
      'Unexpected user1 dai usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1DaiData1.totalShares,
      0,
      'Unexpected spoke1 dai totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1DaiData1.drawnShares,
      0,
      'Unexpected spoke1 dai drawnShares'
    );
    // eth
    assertEq(
      testLiquidationCallLocalParams.user1EthData1.usingAsCollateral,
      true,
      'Unexpected eth usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1EthData1.totalShares,
      hub.convertAssetsToSharesDown(ethAssetId, ethAmount),
      'Unexpected spoke1 eth totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1EthData1.drawnShares,
      0,
      'Unexpected spoke1 eth drawnShares'
    );
    // usdc
    assertEq(
      testLiquidationCallLocalParams.user1UsdcData1.usingAsCollateral,
      false,
      'Unexpected usdc usingAsCollateral'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1UsdcData1.totalShares,
      hub.convertAssetsToSharesDown(usdcAssetId, usdcBorrowAmount),
      'Unexpected spoke1 usdc totalShares'
    );
    assertEq(
      testLiquidationCallLocalParams.spoke1UsdcData1.drawnShares,
      testLiquidationCallLocalParams.spoke1UsdcData1.totalShares -
        hub.convertAssetsToSharesDown(
          usdcAssetId,
          testLiquidationCallLocalParams.actualDebtCovered
        ),
      'Unexpected spoke1 usdc drawnShares'
    );
    // TODO: assertion on health factor, should be 1e18 after enhanced liq

    // liquidator
    assertEq(
      dai.balanceOf(LIQUIDATOR),
      testLiquidationCallLocalParams.expectedCollateralLiquidated -
        testLiquidationCallLocalParams.expectedProtocolFee,
      'Unexpected liquidator collateral asset balance'
    );
    assertEq(
      dai.balanceOf(spoke1.RESERVE_TREASURY_ADDRESS()),
      testLiquidationCallLocalParams.expectedProtocolFee,
      'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
    );
  }

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
          .percentDiv(spoke1.getLiquidationBonus(collateralAssetId));
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
        spoke1.getLiquidationBonus(collateralAssetId)
      ) / collateralAssetPrice;
    expectedLiquidationBonus =
      expectedCollateralLiquidated -
      expectedCollateralLiquidated.percentDiv(spoke1.getLiquidationBonus(collateralAssetId));
    expectedProtocolFee = expectedLiquidationBonus.percentMul(
      spoke1.getLiquidationProtocolFeePercentage(collateralAssetId)
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
