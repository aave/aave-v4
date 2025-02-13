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
  Spoke internal spoke4;

  uint256 internal constant INIT_INDEX = WadRayMath.RAY;

  function setUp() public override {
    super.setUp();
    initEnvironment();
    spokeMintAndApprove();

    spokeConfig = DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max});

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(10_00).bpsToRay())
    );

    spoke4 = new Spoke(address(hub), address(oracle));
  }

  struct Timestamps {
    uint40 t0;
    uint40 t1;
    uint40 t2;
    uint40 t3;
    uint40 t4;
  }

  struct SpokeDataLocal {
    SpokeData t0;
    SpokeData t1;
    SpokeData t2;
    SpokeData t3;
    SpokeData t4;
  }

  struct AssetDataLocal {
    Asset t0;
    Asset t1;
    Asset t2;
    Asset t3;
    Asset t4;
  }

  struct CumulatedInterest {
    uint256 t1;
    uint256 t2;
    uint256 t3;
    uint256 t4;
  }

  struct Spoke1Amounts {
    uint256 draw0;
    uint256 draw1;
    uint256 draw2;
    uint256 draw3;
    uint256 draw4;
    uint256 supply0;
    uint256 supply1;
    uint256 supply2;
    uint256 supply3;
    uint256 supply4;
  }

  struct Spoke4Amounts {
    uint256 draw0;
    uint256 draw1;
    uint256 draw2;
    uint256 draw3;
    uint256 draw4;
    uint256 supply0;
    uint256 supply1;
    uint256 supply2;
    uint256 supply3;
    uint256 supply4;
  }

  // t0: spoke1 draws
  // t1: spoke4 is added; draws
  // t2: spoke4 trivial supply action to trigger accrual
  function test_accrueInterest_dynamicTime_scenario1() public {
    Timestamps memory timestamps;
    AssetDataLocal memory assetData;
    SpokeDataLocal memory spokeData;
    Spoke1Amounts memory spoke1Amounts;
    Spoke4Amounts memory spoke4Amounts;
    CumulatedInterest memory cumulated;

    // t0: spoke1 supplies/draws
    timestamps.t0 = uint40(vm.getBlockTimestamp());
    spoke1Amounts.supply0 = 10e18;
    spoke1Amounts.draw0 = 5e18;

    assetData.t0 = hub.getAsset(wethAssetId);
    assertEq(assetData.t0.baseBorrowIndex, INIT_INDEX, 't0 Asset index');
    assertEq(assetData.t0.baseDebt, 0, 't0 Asset base debt');

    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: spoke1Amounts.supply0,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke1)
    });
    Utils.draw({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: spoke1Amounts.draw0,
      riskPremiumRad: 0,
      to: bob,
      onBehalfOf: address(spoke1)
    });

    // t1: add spoke4; draws
    skip(365 days);
    spoke4Amounts.draw1 = 1e18;
    timestamps.t1 = uint40(vm.getBlockTimestamp());

    hub.addSpoke(wethAssetId, spokeConfig, address(spoke4));
    Utils.draw({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke4),
      amount: spoke4Amounts.draw1,
      riskPremiumRad: 0,
      to: bob,
      onBehalfOf: address(spoke4)
    });

    assetData.t1 = hub.getAsset(wethAssetId);
    spokeData.t1 = hub.getSpoke(wethAssetId, address(spoke4));
    cumulated.t1 = MathUtils.calculateLinearInterest(assetData.t1.baseBorrowRate, timestamps.t0);

    assertEq(
      assetData.t1.baseBorrowIndex,
      assetData.t0.baseBorrowIndex.rayMul(cumulated.t1),
      't1 Asset index'
    );
    assertEq(
      assetData.t1.baseDebt,
      spoke1Amounts.draw0.rayMul(cumulated.t1) + spoke4Amounts.draw1,
      't1 Asset base debt'
    );
    assertEq(spokeData.t1.baseBorrowIndex, assetData.t1.baseBorrowIndex, 't1 Spoke4 index');
    assertEq(spokeData.t1.baseDebt, spoke4Amounts.draw1, 't1 Spoke4 base debt');

    // t2: spoke4 trivial supply to trigger accrual
    skip(365 days);
    spoke4Amounts.supply2 = 1e8;

    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke4),
      amount: spoke4Amounts.supply2,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke4)
    });

    assetData.t2 = hub.getAsset(wethAssetId);
    spokeData.t2 = hub.getSpoke(wethAssetId, address(spoke4));
    cumulated.t2 = MathUtils.calculateLinearInterest(assetData.t2.baseBorrowRate, timestamps.t1);

    assertEq(
      assetData.t2.baseBorrowIndex,
      assetData.t1.baseBorrowIndex.rayMul(cumulated.t2),
      't2 Asset index'
    );
    assertEq(spoke4Amounts.draw1.rayMul(cumulated.t2), spokeData.t2.baseDebt, 't2 Asset base debt');
    assertEq(assetData.t2.baseBorrowIndex, spokeData.t2.baseBorrowIndex, 't2 Spoke4 index');
    assertEq(
      spoke4Amounts.draw1.rayMul(cumulated.t2),
      spokeData.t2.baseDebt,
      't2 Spoke4 base debt'
    );
  }

  // t0: skip
  // t1: spoke1 draws
  // t2: spoke4 is added; draws
  // t3: spoke4 trivial supply action to trigger accrual
  function skip_test_accrueInterest_dynamicTime_scenario2() public {
    skip(365 days);

    // t1: spoke1 draws
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

    // t2: add spoke4; draws
    hub.addSpoke(wethAssetId, spokeConfig, address(spoke4));

    uint256 debtAmount = 1e18;
    vm.prank(address(spoke4));
    hub.draw({assetId: wethAssetId, amount: debtAmount, riskPremiumRad: 0, to: bob});

    uint40 timestamp2 = uint40(vm.getBlockTimestamp());

    skip(365 days);

    // t3: spoke4 trivial supply to trigger accrual
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

    uint256 expectedBaseDebt = MathUtils
      .calculateLinearInterest(wethData.baseBorrowRate, timestamp2)
      .rayMul(debtAmount);

    assertEq(expectedBaseDebt, spokeData.baseDebt, 'updated base debt');
    assertEq(wethData.baseBorrowIndex, spokeData.baseBorrowIndex, 'updated base index');
  }

  // t0: spoke1 draws
  // t1: spoke4 is added; draws
  // t2: spoke1 trivial supply action to trigger asset accrual
  // t3: spoke4 trivial supply action to trigger spoke accrual
  function skip_test_accrueInterest_dynamicTime_scenario3() public {
    // t0: spoke1 draws
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

    // t1: add spoke4; draws
    hub.addSpoke(wethAssetId, spokeConfig, address(spoke4));

    uint256 debtAmount = 1e18;
    vm.prank(address(spoke4));
    hub.draw({assetId: wethAssetId, amount: debtAmount, riskPremiumRad: 0, to: bob});

    uint40 timestamp = uint40(vm.getBlockTimestamp());

    skip(365 days);

    // t2: spoke1 trivial supply to trigger accrual
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: 1e18,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke1)
    });

    Asset memory wethData = hub.getAsset(wethAssetId);
    SpokeData memory spokeData = hub.getSpoke(wethAssetId, address(spoke4));

    assertEq(debtAmount, spokeData.baseDebt, 'non-accrued base debt');
    console.log('baseBorrowIndex', spokeData.baseBorrowIndex);
    console.log('wethData baseBorrowIndex', wethData.baseBorrowIndex);

    console.log(MathUtils.calculateLinearInterest(wethData.baseBorrowRate, timestamp));

    // uint256 expectedBaseDebt = MathUtils
    //   .calculateLinearInterest(wethData.baseBorrowRate, timestamp)
    //   .rayMul(debtAmount);

    // assertEq(expectedBaseDebt, spokeData.baseDebt, 'updated base debt');
    // assertEq(wethData.baseBorrowIndex, spokeData.baseBorrowIndex, 'updated base index');
  }
}
