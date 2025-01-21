// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';
import {SpokeData} from 'src/contracts/LiquidityHub.sol';

contract UserRiskPremiumTest_ToMigrate is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public constant daiAssetId = 0;
  uint256 public constant ethAssetId = 1;
  uint256 public constant usdcId = 2;
  uint256 public constant wbtcAssetId = 3;

  function setUp() public override {
    super.setUp();

    address[] memory spokes = new address[](3);
    spokes[0] = address(spoke1);
    spokes[1] = address(spoke2);
    spokes[2] = address(spoke3);
    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](3);
    spokeConfigs[0] = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });
    spokeConfigs[1] = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });
    spokeConfigs[2] = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });

    Spoke.ReserveConfig[] memory reserveConfigs = new Spoke.ReserveConfig[](3);

    // Add dai
    reserveConfigs[0] = Spoke.ReserveConfig({
      lt: 0.75e4,
      lb: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({lt: 0.8e4, lb: 0, borrowable: true, collateral: true});
    reserveConfigs[2] = Spoke.ReserveConfig({
      lt: 0.77e4,
      lb: 0,
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

    // Add eth
    reserveConfigs[0] = Spoke.ReserveConfig({lt: 0.8e4, lb: 0, borrowable: true, collateral: true});
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.76e4,
      lb: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[2] = Spoke.ReserveConfig({
      lt: 0.79e4,
      lb: 0,
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

    // Add USDC
    reserveConfigs[0] = Spoke.ReserveConfig({
      lt: 0.78e4,
      lb: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.72e4,
      lb: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[2] = Spoke.ReserveConfig({
      lt: 0.75e4,
      lb: 0,
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
    MockPriceOracle(address(oracle)).setAssetPrice(usdcId, 1e8);

    // Add WBTC
    reserveConfigs[0] = Spoke.ReserveConfig({
      lt: 0.85e4,
      lb: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({
      lt: 0.84e4,
      lb: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[2] = Spoke.ReserveConfig({
      lt: 0.87e4,
      lb: 0,
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
    irStrategy.setInterestRateParams(
      usdcId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 9000, // 90.00%
        baseVariableBorrowRate: 500, // 5.00%
        variableRateSlope1: 500, // 5.00%
        variableRateSlope2: 500 // 5.00%
      })
    );
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

  function test_LHBorrowRate_NoActionTaken() public {
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    assertEq(borrowRate, 0);
  }

  function test_LHBorrowRate_Supply() public {
    deal(address(dai), address(spoke1), 1000e18);

    vm.startPrank(address(spoke1));
    SpokeData memory test = hub.getSpoke(daiAssetId, address(spoke1));
    dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // No change to risk premium, so borrow rate is just the base rate
    assertEq(_getBaseBorrowRate(daiAssetId), _getBorrowRate(daiAssetId));
    vm.stopPrank();
  }

  function test_LHBorrowRate_Borrow() public {
    // Spoke 1's first borrow should adjust the overall borrow rate with a risk premium of 10%
    uint256 newRiskPremium = 1e3;
    deal(address(dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    vm.stopPrank();
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);
  }

  function test_LHBorrowRate_BorrowFuzz(uint256 newRiskPremium) public {
    newRiskPremium = bound(newRiskPremium, 0, 99999);
    // Spoke 1's first borrow should set the overall borrow rate
    deal(address(dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    vm.stopPrank();
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);
  }

  function test_LHBorrowRate_BorrowAndSupply() public {
    uint256 newRiskPremium = 1e3;
    deal(address(dai), address(spoke1), 2000e18);
    vm.startPrank(address(spoke1));
    dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);

    // Now if we supply again, passing same risk premium, RP doesn't update
    dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, newRiskPremium, address(spoke1));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);
    vm.stopPrank();
  }

  function test_LHBorrowRate_BorrowAndSupplyFuzz(uint256 newRiskPremium) public {
    newRiskPremium = bound(newRiskPremium, 0, 99999);
    deal(address(dai), address(spoke1), 2000e18);
    vm.startPrank(address(spoke1));
    dai.approve(address(hub), 2000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);

    // Now if we supply again, passing same risk premium, RP doesn't update
    hub.supply(daiAssetId, 1000e18, newRiskPremium, address(spoke1));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);
    vm.stopPrank();
  }

  function test_LHBorrowRate_BorrowTwice() public {
    uint256 newRiskPremium = 1e3;
    deal(address(dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);

    // New risk premium from same spoke should replace avg risk premium
    uint256 newRiskPremium2 = 2e3;
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium2);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium2 * baseBorrowRate) / 1e4);
    vm.stopPrank();
  }

  function test_LHBorrowRate_BorrowTwiceFuzz(uint256 newRiskPremium) public {
    newRiskPremium = bound(newRiskPremium, 0, 99999);
    uint256 firstRiskPremium = 1e3;
    deal(address(dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, firstRiskPremium);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (firstRiskPremium * baseBorrowRate) / 1e4);

    // New risk premium from same spoke should replace avg risk premium
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);
    vm.stopPrank();
  }

  function test_LHBorrowRate_DrawTwoSpokes() public {
    uint256 rpSpoke1 = 1e3;
    uint256 rpSpoke2 = 2e3;
    deal(address(dai), address(spoke1), 5000e18);
    vm.startPrank(address(spoke1));
    dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, rpSpoke1);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1 * baseBorrowRate) / 1e4);
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    deal(address(dai), address(spoke2), 1000e18);
    vm.startPrank(address(spoke2));
    dai.approve(address(hub), 1000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    hub.draw(daiAssetId, address(spoke2), 100e18, rpSpoke2);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + ((rpSpoke1 + rpSpoke2) * baseBorrowRate) / 2e4);
    vm.stopPrank();
  }

  function test_LHBorrowRate_DrawTwoSpokesFuzz(uint256 rpSpoke1, uint256 rpSpoke2) public {
    rpSpoke1 = bound(rpSpoke1, 0, 99999);
    rpSpoke2 = bound(rpSpoke2, 0, 99999);
    deal(address(dai), address(spoke1), 5000e18);
    vm.startPrank(address(spoke1));
    dai.approve(address(hub), 5000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), 100e18, rpSpoke1);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1 * baseBorrowRate) / 1e4);
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    deal(address(dai), address(spoke2), 5000e18);
    vm.startPrank(address(spoke2));
    dai.approve(address(hub), 5000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    hub.draw(daiAssetId, address(spoke2), 100e18, rpSpoke2);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertApproxEqAbs(
      borrowRate,
      baseBorrowRate + ((rpSpoke1 + rpSpoke2) * baseBorrowRate) / 2e4,
      1
    );
    vm.stopPrank();
  }

  function test_LHBorrowRate_DrawTwoSpokesDiffWeights() public {
    uint256 rpSpoke1 = 1e3;
    uint256 rpSpoke2 = 2e3;
    uint256 drawSpoke1 = 100e18;
    uint256 drawSpoke2 = 200e18;
    deal(address(dai), address(spoke1), 5000e18);
    vm.startPrank(address(spoke1));
    dai.approve(address(hub), 5000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), drawSpoke1, rpSpoke1);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1 * baseBorrowRate) / 1e4);
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    deal(address(dai), address(spoke2), 5000e18);
    vm.startPrank(address(spoke2));
    dai.approve(address(hub), 5000e18);
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    hub.draw(daiAssetId, address(spoke2), drawSpoke2, rpSpoke2);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(
      borrowRate,
      baseBorrowRate +
        ((rpSpoke1 * drawSpoke1 + rpSpoke2 * drawSpoke2) * baseBorrowRate) /
        (1e4 * (drawSpoke1 + drawSpoke2))
    );
    vm.stopPrank();
  }

  function test_LHBorrowRate_DrawTwoSpokesDiffWeightsFuzz(
    uint256 rpSpoke1,
    uint256 drawSpoke1,
    uint256 supplySpoke1,
    uint256 rpSpoke2,
    uint256 drawSpoke2,
    uint256 supplySpoke2
  ) public {
    rpSpoke1 = bound(rpSpoke1, 0, 99999);
    supplySpoke1 = bound(supplySpoke1, 2, 1e60);
    drawSpoke1 = bound(drawSpoke1, 1, supplySpoke1 / 2);

    rpSpoke2 = bound(rpSpoke2, 0, 99999);
    supplySpoke2 = bound(supplySpoke2, 2, 1e60);
    drawSpoke2 = bound(drawSpoke2, 1, supplySpoke2 / 2);

    deal(address(dai), address(spoke1), supplySpoke1);
    deal(address(dai), address(spoke2), supplySpoke2);

    vm.startPrank(address(spoke1));
    dai.approve(address(hub), supplySpoke1);
    hub.supply(daiAssetId, supplySpoke1, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), drawSpoke1, rpSpoke1);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1 * baseBorrowRate) / 1e4);
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    vm.startPrank(address(spoke2));
    dai.approve(address(hub), supplySpoke2);
    hub.supply(daiAssetId, supplySpoke2, 0, address(spoke2));
    hub.draw(daiAssetId, address(spoke2), drawSpoke2, rpSpoke2);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertApproxEqAbs(
      borrowRate,
      baseBorrowRate +
        ((rpSpoke1 * drawSpoke1 + rpSpoke2 * drawSpoke2) * baseBorrowRate) /
        (1e4 * (drawSpoke1 + drawSpoke2)),
      1
    );
    vm.stopPrank();
  }

  function test_LHBorrowRate_DrawThreeSpokesDiffWeightsFuzz(
    uint256 rpSpoke1,
    uint256 drawSpoke1,
    uint256 rpSpoke2,
    uint256 drawSpoke2,
    uint256 rpSpoke3,
    uint256 drawSpoke3
  ) public {
    rpSpoke1 = bound(rpSpoke1, 0, 99999);
    drawSpoke1 = bound(drawSpoke1, 1, 1e40);

    rpSpoke2 = bound(rpSpoke2, 0, 99999);
    drawSpoke2 = bound(drawSpoke2, 1, 1e40);

    rpSpoke3 = bound(rpSpoke3, 0, 99999);
    drawSpoke3 = bound(drawSpoke3, 1, 1e40);

    deal(address(dai), address(spoke1), 2e40);
    deal(address(dai), address(spoke2), 2e40);
    deal(address(dai), address(spoke3), 2e40);

    vm.startPrank(address(spoke1));
    dai.approve(address(hub), 2e40);
    hub.supply(daiAssetId, 2e40, 0, address(spoke1));
    hub.draw(daiAssetId, address(spoke1), drawSpoke1, rpSpoke1);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1 * baseBorrowRate) / 1e4);
    vm.stopPrank();

    vm.startPrank(address(spoke2));
    dai.approve(address(hub), 2e40);
    hub.supply(daiAssetId, 2e40, 0, address(spoke2));
    hub.draw(daiAssetId, address(spoke2), drawSpoke2, rpSpoke2);
    vm.stopPrank();

    vm.startPrank(address(spoke3));
    dai.approve(address(hub), 2e40);
    hub.supply(daiAssetId, 2e40, 0, address(spoke3));
    hub.draw(daiAssetId, address(spoke3), drawSpoke3, rpSpoke3);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertApproxEqAbs(
      borrowRate,
      baseBorrowRate +
        ((rpSpoke1 * drawSpoke1 + rpSpoke2 * drawSpoke2 + rpSpoke3 * drawSpoke3) * baseBorrowRate) /
        (1e4 * (drawSpoke1 + drawSpoke2 + drawSpoke3)),
      1
    );
    vm.stopPrank();
  }

  // TODO: Test via calling functions on spokes - after spoke side is implemented

  function _getBaseBorrowRate(uint256 assetId) internal view returns (uint256) {
    return hub.getBaseInterestRate(assetId);
  }

  function _getBorrowRate(uint256 assetId) internal view returns (uint256) {
    return hub.getInterestRate(assetId);
  }
}
