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
      lb: 0,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.8e4,
      lb: 0,
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
      lb: 0,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.76e4,
      lb: 0,
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
      lb: 0,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.72e4,
      lb: 0,
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
      lb: 0,
      lpfp: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.84e4,
      lb: 0,
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

  function test_liquidationCall_revertsWith_specified_currency_not_borrowed_by_user() public {
    uint256 ethAssetId = 1; // collateral asset
    uint256 daiAssetId = 0; // debt asset
    uint256 debtToCover = 1;

    vm.expectRevert(TestErrors.SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER);
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

  // function testFuzzRevertPausedCollateralReserveLiquidationCall(uint256 debtToCover) public {
  //   vm.assume(debtToCover > 0);
  //   uint256 ethAssetId = 1; // collateral asset
  //   uint256 daiAssetId = 0; // debt asset

  //   // ETH reserve is inactive
  //   _updatePaused(ethAssetId, false);
  //   vm.expectRevert(TestErrors.RESERVE_NOT_ACTIVE);
  //   vm.prank(LIQUIDATOR);
  //   hub.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  // }

  // function testFuzzRevertInactiveCollateralReserveLiquidationCall(uint256 debtToCover) public {
  //   vm.assume(debtToCover > 0);
  //   uint256 ethAssetId = 1; // collateral asset
  //   uint256 daiAssetId = 0; // debt asset

  //   // ETH reserve is inactive
  //   _updateActive(ethAssetId, false);
  //   vm.expectRevert(TestErrors.RESERVE_NOT_ACTIVE);
  //   vm.prank(LIQUIDATOR);
  //   hub.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  // }

  // function testFuzzRevertInactiveDebtReserveLiquidationCall(uint256 debtToCover) public {
  //   vm.assume(debtToCover > 0);
  //   uint256 ethAssetId = 1; // collateral asset
  //   uint256 daiAssetId = 0; // debt asset

  //   // DAI reserve is inactive
  //   _updateActive(daiAssetId, false);
  //   vm.expectRevert(TestErrors.RESERVE_NOT_ACTIVE);
  //   vm.prank(LIQUIDATOR);
  //   hub.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  // }

  // function testRevertLiquidationCallCurrencyNotBorrowed() public {
  //   uint256 ethAssetId = 1; // collateral asset
  //   uint256 daiAssetId = 0; // debt asset
  //   uint256 debtToCover = 1;

  //   vm.prank(LIQUIDATOR);
  //   vm.expectRevert(TestErrors.SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER);
  //   hub.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  // }

  // function testRevertLiquidationCallInvalidDebtToCover() public {
  //   uint256 ethAssetId = 1; // collateral asset
  //   uint256 daiAssetId = 0; // debt asset
  //   uint256 debtToCover = 0;

  //   vm.prank(LIQUIDATOR);
  //   vm.expectRevert(TestErrors.INVALID_DEBT_TO_COVER);
  //   hub.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  // }

  // function testLiquidationCallMaxCollateralToLiquidate() public {
  //   uint256 ethAssetId = 1; // collateral asset
  //   uint256 daiAssetId = 0; // debt asset
  //   // borrowed value > supplied value to simulate liquidation scenario
  //   // maxCollateralToLiquidate > userCollateralBalance
  //   uint256 daiAmount = 400e6;
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

  //   uint256 expectedCollateralLiquidated = hub.getUserBalance(ethAssetId, USER1);
  //   uint256 expectedDebtCovered = _getExpectedDebtCovered(
  //     ethAssetId,
  //     daiAssetId,
  //     expectedCollateralLiquidated
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

  // function _getExpectedDebtCovered(
  //   uint256 collateralAssetId,
  //   uint256 debtAssetId,
  //   uint256 collateralAmount
  // ) internal returns (uint256) {
  //   uint256 liquidationBonus = bm.getLiquidationBonus(collateralAssetId);
  //   return
  //     ((oracle.getAssetPrice(collateralAssetId) * collateralAmount) /
  //       (oracle.getAssetPrice(debtAssetId))).percentDiv(liquidationBonus);
  // }

  // function _getExpectedCollateralLiquidated(
  //   uint256 collateralAssetId,
  //   uint256 debtAssetId,
  //   uint256 debtAmount
  // ) internal returns (uint256) {
  //   uint256 liquidationBonus = bm.getLiquidationBonus(collateralAssetId);
  //   return
  //     (((oracle.getAssetPrice(debtAssetId) * debtAmount)) /
  //       (oracle.getAssetPrice(collateralAssetId))).percentMul(liquidationBonus);
  // }

  // function _updateActive(uint256 assetId, bool newActive) internal {
  //   LiquidityHub.ReserveConfig memory reserveConfig = hub.getReserve(assetId).config;
  //   reserveConfig.active = newActive;
  //   hub.updateReserve(assetId, reserveConfig);
  // }

  // function _updatePaused(uint256 assetId, bool newPaused) internal {
  //   LiquidityHub.ReserveConfig memory reserveConfig = hub.getReserve(assetId).config;
  //   reserveConfig.active = newPaused;
  //   hub.updateReserve(assetId, reserveConfig);
  // }
}
