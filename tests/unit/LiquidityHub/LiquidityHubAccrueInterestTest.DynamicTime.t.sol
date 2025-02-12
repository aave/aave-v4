// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {SpokeData} from 'src/contracts/LiquidityHub.sol';
import {Asset} from 'src/contracts/LiquidityHub.sol';
import {Utils} from 'tests/Utils.t.sol';

contract LiquidityHubAccrueAssetInterestDynamicTimeTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public constant MAX_BPS = 999_99;

  DataTypes.SpokeConfig internal spokeConfig;

  function setUp() public override {
    super.setUp();
    initEnvironment();
    spokeMintAndApprove();

    // 2 scenarios:
    // 1) no spoke action, then add spoke at t1
    // 2) spoke draw action, then add spoke at t1

    spokeConfig = DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max});

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(10_00).bpsToRay())
    );
  }

  // t0: spoke1 draws
  // t1: spoke4 is added; draws
  // t2: trivial supply action to trigger accrual
  function test_accrueInterest_dynamicTime_scenario1() public {
    // spoke1 draws, t0
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: 10e18,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke1)
    });
    vm.prank(address(spoke1));
    hub.draw({assetId: wethAssetId, amount: 5e18, riskPremiumRad: 0, to: bob});

    skip(365 days);

    Spoke spoke4 = new Spoke(address(hub), address(oracle));
    hub.addSpoke(wethAssetId, spokeConfig, address(spoke4));

    uint256 debtAmount = 1e18;
    vm.prank(address(spoke4));
    hub.draw({assetId: wethAssetId, amount: debtAmount, riskPremiumRad: 0, to: bob});

    uint40 timestamp = uint40(vm.getBlockTimestamp());

    skip(365 days);

    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke4),
      amount: 1e18,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke4)
    });

    Asset memory wethData = hub.getAsset(wethAssetId);
    SpokeData memory spokeData = hub.getSpoke(wethAssetId, address(spoke4));

    console.log('wethData.baseBorrowIndex', wethData.baseBorrowIndex);
    console.log('spokeData baseDebt', spokeData.baseDebt);

    uint256 cumulated = MathUtils.calculateLinearInterest(wethData.baseBorrowRate, timestamp);

    console.log('expected base debt', cumulated.rayMul(debtAmount));

    assertEq(cumulated.rayMul(debtAmount), spokeData.baseDebt, 'base debt should match');
  }

  // t0: spoke1 draws
  // t1: spoke4 is added; draws
  // t2: trivial supply action to trigger accrual
  function test_accrueInterest_dynamicTime_scenario2() public {
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(10_00).bpsToRay())
    );

    // spoke1 draws, t0
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: 10e18,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke1)
    });
    vm.prank(address(spoke1));
    hub.draw({assetId: wethAssetId, amount: 5e18, riskPremiumRad: 0, to: bob});

    skip(365 days);

    Spoke spoke4 = new Spoke(address(hub), address(oracle));
    hub.addSpoke(wethAssetId, spokeConfig, address(spoke4));

    uint256 debtAmount = 1e18;
    vm.prank(address(spoke4));
    hub.draw({assetId: wethAssetId, amount: debtAmount, riskPremiumRad: 0, to: bob});

    uint40 timestamp = uint40(vm.getBlockTimestamp());

    skip(365 days);

    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke4),
      amount: 1e18,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke4)
    });

    Asset memory wethData = hub.getAsset(wethAssetId);
    SpokeData memory spokeData = hub.getSpoke(wethAssetId, address(spoke4));

    console.log('wethData.baseBorrowIndex', wethData.baseBorrowIndex);
    console.log('spokeData baseDebt', spokeData.baseDebt);

    uint256 cumulated = MathUtils.calculateLinearInterest(wethData.baseBorrowRate, timestamp);

    console.log('expected base debt', cumulated.rayMul(debtAmount));

    assertEq(cumulated.rayMul(debtAmount), spokeData.baseDebt, 'base debt should match');
  }
}
