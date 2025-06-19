// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMultipleHubBase is SpokeBase {
  // New hub and spoke
  ILiquidityHub internal newHub;
  MockPriceOracle internal newOracle;
  ISpoke internal newSpoke;
  IAssetInterestRateStrategy internal newIrStrategy;

  TestnetERC20 internal assetA;
  TestnetERC20 internal assetB;

  DataTypes.DynamicReserveConfig internal dynReserveConfig =
    DataTypes.DynamicReserveConfig({
      collateralFactor: 80_00 // 80.00%
    });
  IAssetInterestRateStrategy.InterestRateData internal irData =
    IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 90_00, // 90.00%
      baseVariableBorrowRate: 5_00, // 5.00%
      variableRateSlope1: 5_00, // 5.00%
      variableRateSlope2: 5_00 // 5.00%
    });

  function setUp() public virtual override {
    deployFixtures();
  }

  function deployFixtures() internal virtual override {
    // Canonical hub and spoke
    hub = new LiquidityHub();
    oracle1 = new MockPriceOracle();
    spoke1 = new Spoke(address(oracle1));
    irStrategy = new AssetInterestRateStrategy();

    // New hub and spoke
    newHub = new LiquidityHub();
    newOracle = new MockPriceOracle();
    newSpoke = new Spoke(address(newOracle));
    newIrStrategy = new AssetInterestRateStrategy();

    assetA = new TestnetERC20('Asset A', 'A', 18);
    assetB = new TestnetERC20('Asset B', 'B', 18);
  }
}
