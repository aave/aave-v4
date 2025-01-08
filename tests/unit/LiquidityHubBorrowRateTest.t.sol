// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract UserRiskPremiumTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public constant daiAssetId = 0;
  uint256 public constant ethAssetId = 1;
  uint256 public constant usdcId = 2;
  uint256 public constant wbtcAssetId = 3;

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
    reserveConfigs[0] = Spoke.ReserveConfig({
      lt: 0.75e4,
      lb: 0,
      borrowable: true,
      collateral: true
    });
    reserveConfigs[1] = Spoke.ReserveConfig({lt: 0.8e4, lb: 0, borrowable: true, collateral: true});
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
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0);
    // No change to risk premium, so borrow rate is just the base rate
    assertEq(_getBaseBorrowRate(daiAssetId), _getBorrowRate(daiAssetId));
  }

  function test_LHBorrowRate_Borrow() public {
    // Spoke 1's first borrow should adjust the overall borrow rate with a risk premium of 10%
    uint256 newRiskPremium = 1e3;
    deal(address(dai), address(hub), 1000e18);
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0);
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    vm.stopPrank();
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);
  }

  function test_LHBorrowRate_BorrowFuzz(uint256 newRiskPremium) public {
    newRiskPremium = bound(newRiskPremium, 0, 99999);
    // Spoke 1's first borrow should set the overall borrow rate
    deal(address(dai), address(hub), 1000e18);
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0);
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    vm.stopPrank();
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);
  }

  function test_LHBorrowRate_BorrowAndSupply() public {
    uint256 newRiskPremium = 1e3;
    deal(address(dai), address(hub), 1000e18);
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0);
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);

    // Now if we supply again, passing same risk premium, RP doesn't update
    hub.supply(daiAssetId, 1000e18, newRiskPremium);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);
    vm.stopPrank();
  }

  function test_LHBorrowRate_BorrowAndSupplyFuzz(uint256 newRiskPremium) public {
    newRiskPremium = bound(newRiskPremium, 0, 99999);
    deal(address(dai), address(hub), 1000e18);
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0);
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);

    // Now if we supply again, passing same risk premium, RP doesn't update
    hub.supply(daiAssetId, 1000e18, newRiskPremium);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);
    vm.stopPrank();
  }

  // TODO: Draw again from same spoke - show borrow rate calc uses avg of the drawn amounts / risk premiums
  // Actually drawing again from same spoke should replace the risk premium
  function test_LHBorrowRate_BorrowTwice() public {
    uint256 newRiskPremium = 1e3;
    deal(address(dai), address(hub), 1000e18);
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0);
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium);
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium * baseBorrowRate) / 1e4);

    // Now if we draw again, passing a different risk premium, the borrow rate should update
    uint256 newRiskPremium2 = 2e3;
    hub.draw(daiAssetId, address(spoke1), 100e18, newRiskPremium2);
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // TODO: Debug this assertion
    // assertEq(borrowRate, baseBorrowRate + (newRiskPremium2 * baseBorrowRate) / 1e4);
    vm.stopPrank();
  }

  // TODO: Draw from 2 different spokes - show borrow rate calc uses weighted avg

  // TODO: Test via calling functions on spokes - after spoke side is implemented

  function _getBaseBorrowRate(uint256 assetId) internal view returns (uint256) {
    return hub.getBaseInterestRate(assetId);
  }

  function _getBorrowRate(uint256 assetId) internal view returns (uint256) {
    return hub.getInterestRate(assetId);
  }
}
