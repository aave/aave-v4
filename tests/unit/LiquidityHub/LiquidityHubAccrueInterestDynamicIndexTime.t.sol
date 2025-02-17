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

  struct SpokeDataLocal {
    SpokeData t0;
    SpokeData t1;
    SpokeData t2;
    SpokeData t3;
    SpokeData t4;
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

  // t0: asset added, spoke1 added, spoke1 draws
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

    assetData.t0 = hub.getAsset(wethAssetId);
    assertEq(assetData.t0.baseBorrowIndex, INIT_INDEX, 't0 Asset index');
    assertEq(assetData.t0.baseDebt, spoke1Amounts.draw0, 't0 Asset base debt');

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

  // t0: asset added, spoke1 added
  // t1: spoke1 draws
  // t2: spoke4 is added; draws
  // t3: spoke4 trivial supply action to trigger accrual
  function test_accrueInterest_dynamicTime_scenario2() public {
    Timestamps memory timestamps;
    AssetDataLocal memory assetData;
    SpokeDataLocal memory spokeData;
    Spoke1Amounts memory spoke1Amounts;
    Spoke4Amounts memory spoke4Amounts;
    CumulatedInterest memory cumulated;

    // t0
    timestamps.t0 = uint40(vm.getBlockTimestamp());
    assetData.t0 = hub.getAsset(wethAssetId);
    assertEq(assetData.t0.baseBorrowIndex, INIT_INDEX, 't0 Asset index');
    assertEq(assetData.t0.baseDebt, 0, 't0 Asset base debt');

    // t1: spoke1 supplies/draws
    skip(365 days);
    timestamps.t1 = uint40(vm.getBlockTimestamp());
    spoke1Amounts.supply1 = 10e18;
    spoke1Amounts.draw1 = 5e18;

    assetData.t1 = hub.getAsset(wethAssetId);
    assertEq(assetData.t1.baseBorrowIndex, INIT_INDEX, 't1 Asset index');
    assertEq(assetData.t1.baseDebt, 0, 't1 Asset base debt');

    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: spoke1Amounts.supply1,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke1)
    });
    Utils.draw({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: spoke1Amounts.draw1,
      riskPremiumRad: 0,
      to: bob,
      onBehalfOf: address(spoke1)
    });

    assetData.t1 = hub.getAsset(wethAssetId);
    // t1 last time since debt in the system
    cumulated.t1 = MathUtils.calculateLinearInterest(assetData.t1.baseBorrowRate, timestamps.t1);

    assertEq(cumulated.t1, WadRayMath.RAY, 't1 Cumulated interest');
    assertEq(assetData.t1.baseBorrowIndex, INIT_INDEX, 't1 Asset index'); // since no time elapsed
    assertEq(assetData.t1.baseDebt, spoke1Amounts.draw1, 't1 Asset base debt');

    // t2: add spoke4; draws
    skip(365 days);
    timestamps.t2 = uint40(vm.getBlockTimestamp());
    spoke4Amounts.draw2 = 1e18;

    hub.addSpoke(wethAssetId, spokeConfig, address(spoke4));
    Utils.draw({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke4),
      amount: spoke4Amounts.draw2,
      riskPremiumRad: 0,
      to: bob,
      onBehalfOf: address(spoke4)
    });

    assetData.t2 = hub.getAsset(wethAssetId);
    spokeData.t2 = hub.getSpoke(wethAssetId, address(spoke4));
    cumulated.t2 = MathUtils.calculateLinearInterest(assetData.t2.baseBorrowRate, timestamps.t1); // last action since last draw

    assertEq(
      assetData.t2.baseBorrowIndex,
      assetData.t1.baseBorrowIndex.rayMul(cumulated.t2),
      't2 Asset index'
    );
    assertEq(
      assetData.t2.baseDebt,
      spoke1Amounts.draw1.rayMul(cumulated.t2) + spoke4Amounts.draw2,
      't2 Asset base debt'
    );
    assertEq(spokeData.t2.baseBorrowIndex, assetData.t2.baseBorrowIndex, 't2 Spoke4 index');
    assertEq(spokeData.t2.baseDebt, spoke4Amounts.draw2, 't2 Spoke4 base debt');

    // t3: spoke4 trivial supply to trigger accrual
    skip(365 days);
    timestamps.t3 = uint40(vm.getBlockTimestamp());
    spoke4Amounts.supply3 = 1e8;

    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke4),
      amount: spoke4Amounts.supply3,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke4)
    });

    assetData.t3 = hub.getAsset(wethAssetId);
    spokeData.t3 = hub.getSpoke(wethAssetId, address(spoke4));
    cumulated.t3 = MathUtils.calculateLinearInterest(assetData.t3.baseBorrowRate, timestamps.t2);

    assertEq(
      assetData.t3.baseBorrowIndex,
      assetData.t2.baseBorrowIndex.rayMul(cumulated.t3),
      't3 Asset index'
    );
    assertEq(spoke4Amounts.draw2.rayMul(cumulated.t3), spokeData.t3.baseDebt, 't3 Asset base debt');
    assertEq(assetData.t3.baseBorrowIndex, spokeData.t3.baseBorrowIndex, 't2 Spoke4 index');
    assertEq(
      spoke4Amounts.draw2.rayMul(cumulated.t3),
      spokeData.t3.baseDebt,
      't3 Spoke4 base debt'
    );
  }

  // t0	asset added, spoke1 added
  // t1	spoke1 supply, spoke1 draw
  // t2	spoke4 added
  // t3	spoke4 draw
  // t4	spoke4 supply
  function test_accrueInterest_dynamicTime_scenario4() public {
    uint256 rate = uint256(10_00).bpsToRay();
    _mockInterestRate((rate * 1e4) / 1e27);
    Timestamps memory timestamps;
    AssetDataLocal memory assetData;
    SpokeDataLocal memory spokeData;
    Spoke1Amounts memory spoke1Amounts;
    Spoke4Amounts memory spoke4Amounts;
    CumulatedInterest memory cumulated;

    // t0: initial state
    timestamps.t0 = uint40(vm.getBlockTimestamp());
    assetData.t0 = hub.getAsset(wethAssetId);
    assertEq(assetData.t0.baseBorrowIndex, INIT_INDEX, 't0 Asset index');
    assertEq(assetData.t0.baseDebt, 0, 't0 Asset base debt');

    // t1: spoke1 supply and draw
    skip(365 days);
    timestamps.t1 = uint40(vm.getBlockTimestamp());
    spoke1Amounts.supply1 = 10e18;
    spoke1Amounts.draw1 = 1e18;

    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: spoke1Amounts.supply1,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke1)
    });
    Utils.draw({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: spoke1Amounts.draw1,
      riskPremiumRad: 0,
      to: bob,
      onBehalfOf: address(spoke1)
    });

    assetData.t1 = hub.getAsset(wethAssetId);
    // No time has passed between supply/draw and asset state update,
    // so the index remains at INIT_INDEX.
    assertEq(assetData.t1.baseBorrowIndex, INIT_INDEX, 't1 Asset index');
    assertEq(assetData.t1.baseDebt, spoke1Amounts.draw1, 't1 Asset base debt');

    // t2: add spoke4 (its state is set to the current asset index)
    skip(365 days);
    timestamps.t2 = uint40(vm.getBlockTimestamp());

    hub.addSpoke(wethAssetId, spokeConfig, address(spoke4));
    spokeData.t2 = hub.getSpoke(wethAssetId, address(spoke4));

    assertEq(
      spokeData.t2.baseBorrowIndex,
      MathUtils.calculateLinearInterest(rate, timestamps.t1),
      't2 Spoke4 index'
    );
    assertEq(spokeData.t2.baseDebt, 0, 't2 Spoke4 base debt');

    // t3: spoke4 draw
    skip(365 days);
    timestamps.t3 = uint40(vm.getBlockTimestamp());
    spoke4Amounts.draw3 = 1e18;

    Utils.draw({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke4),
      amount: spoke4Amounts.draw3,
      riskPremiumRad: 0,
      to: bob,
      onBehalfOf: address(spoke4)
    });

    assetData.t3 = hub.getAsset(wethAssetId);
    spokeData.t3 = hub.getSpoke(wethAssetId, address(spoke4));
    // Accrue interest for the asset from the last update at t1.
    cumulated.t3 = MathUtils.calculateLinearInterest(assetData.t3.baseBorrowRate, timestamps.t1);

    assertEq(
      assetData.t3.baseBorrowIndex,
      assetData.t1.baseBorrowIndex.rayMul(cumulated.t3),
      't3 Asset index'
    );
    // Total asset debt includes spoke1’s drawn amount (accrued from t1) plus the new spoke4 draw.
    assertEq(
      assetData.t3.baseDebt,
      spoke1Amounts.draw1.rayMul(cumulated.t3) + spoke4Amounts.draw3,
      't3 Asset base debt'
    );
    // The newly added spoke4 should have its index updated to match the asset and
    // its debt is only the draw amount (which hasn’t yet accrued).
    assertEq(spokeData.t3.baseBorrowIndex, assetData.t3.baseBorrowIndex, 't3 Spoke4 index');
    assertEq(spokeData.t3.baseDebt, spoke4Amounts.draw3, 't3 Spoke4 base debt');

    // t4: spoke4 supply (trigger accrual)
    skip(365 days);
    timestamps.t4 = uint40(vm.getBlockTimestamp());
    spoke4Amounts.supply4 = 1e8;

    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke4),
      amount: spoke4Amounts.supply4,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke4)
    });

    assetData.t4 = hub.getAsset(wethAssetId);
    spokeData.t4 = hub.getSpoke(wethAssetId, address(spoke4));
    // Accrue interest from t3 to t4.
    cumulated.t4 = MathUtils.calculateLinearInterest(assetData.t4.baseBorrowRate, timestamps.t3);

    assertEq(
      assetData.t4.baseBorrowIndex,
      assetData.t3.baseBorrowIndex.rayMul(cumulated.t4),
      't4 Asset index'
    );
    // The overall asset debt accrues interest from t3:
    //  - spoke1's debt becomes spoke1Amounts.draw1.rayMul(cumulated.t3) and then accrues from t3 to t4,
    //  - spoke4's debt accrues from t3 to t4.
    assertEq(
      assetData.t4.baseDebt,
      (spoke1Amounts.draw1.rayMul(cumulated.t3) + spoke4Amounts.draw3).rayMul(cumulated.t4),
      't4 Asset base debt'
    );
    // For spoke4, only its own drawn amount accrues interest.
    assertEq(spokeData.t4.baseBorrowIndex, assetData.t4.baseBorrowIndex, 't4 Spoke4 index');
    assertEq(
      spokeData.t4.baseDebt,
      spoke4Amounts.draw3.rayMul(cumulated.t4),
      't4 Spoke4 base debt'
    );
  }

  function _mockInterestRate(uint256 bps) internal {
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(bps.bpsToRay())
    );
  }
}
