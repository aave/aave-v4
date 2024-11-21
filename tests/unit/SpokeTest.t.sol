// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract SpokeTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function setUp() public override {
    super.setUp();

    // Add dai
    uint256 daiAssetId = 0;
    hub.addAsset(
      LiquidityHub.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      address(dai)
    );
    spoke1.addReserve(
      daiAssetId,
      Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false}),
      address(dai)
    );
    hub.addSpoke(
      daiAssetId,
      LiquidityHub.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max}),
      address(spoke1)
    );
    spoke2.addReserve(
      daiAssetId,
      Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false}),
      address(dai)
    );
    hub.addSpoke(
      daiAssetId,
      LiquidityHub.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max}),
      address(spoke2)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(daiAssetId, 1e8);

    // Add eth
    uint256 ethAssetId = 1;
    hub.addAsset(
      LiquidityHub.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      address(eth)
    );
    spoke1.addReserve(
      ethAssetId,
      Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false}),
      address(eth)
    );
    hub.addSpoke(
      ethAssetId,
      LiquidityHub.SpokeConfig({supplyCap: type(uint256).max, drawCap: 0}),
      address(spoke1)
    );
    spoke2.addReserve(
      ethAssetId,
      Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false}),
      address(eth)
    );
    hub.addSpoke(
      ethAssetId,
      LiquidityHub.SpokeConfig({supplyCap: type(uint256).max, drawCap: 0}),
      address(spoke2)
    );
    MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 2000e8);

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
      LiquidityHub.AssetConfig({
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

  function test_first_supply() public {}

  function test_first_borrow() public {}

  function test_withdraw() public {}

  function test_borrow() public {}

  function test_repay() public {}
}
