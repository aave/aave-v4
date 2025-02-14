// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/LiquidityHub.ScenarioBase.t.sol';
import {SpokeData} from 'src/contracts/LiquidityHub.sol';
import {Asset} from 'src/contracts/LiquidityHub.sol';
import {Utils} from 'tests/Utils.t.sol';

contract BorrowIndex_Scenario1Test is LiquidityHubScenarioBaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  DataTypes.SpokeConfig internal spokeConfig;
  Spoke internal spoke4;

  uint256 internal constant INIT_INDEX = WadRayMath.RAY;

  // Scenario:
  // t0: asset added, spoke1 added, spoke1 draws
  // t1: spoke4 is added; spoke4 draws
  // t2: spoke4 trivial supply action to trigger accrual

  // Assumptions:
  // - constant 10% IR
  // - 1 year between each action

  function setUp() public override {
    super.setUp();
    initEnvironment();
    spokeMintAndApprove();

    spokeConfig = DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max});
  }

  function initialSetup() internal override {
    super.initialSetup();

    // mock constant 10% IR
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(10_00).bpsToRay())
    );
    spoke4 = new Spoke(address(hub), address(oracle));
  }
  function precondition(Stages stage) internal override {
    super.precondition(stage);

    if (stage == Stages.t0) {
      spoke1Amounts.supply.t0_i = 10e18;
      spoke1Amounts.draw.t0_i = 5e18;
    } else if (stage == Stages.t1) {
      spoke4Amounts.draw.t1_i = 1e18;
    } else if (stage == Stages.t2) {
      spoke4Amounts.supply.t2_i = 1e8;
    }
  }
  function initialAssertions(Stages stage) internal override {
    super.initialAssertions(stage);

    if (stage == Stages.t0) {
      assets.wethData.t0_i = hub.getAsset(wethAssetId);
      spokes.spoke1.t0_i = hub.getSpoke(wethAssetId, address(spoke1));

      // asset
      assertEq(assets.wethData.t0_i.baseBorrowIndex, INIT_INDEX, 't0_i Asset index');
      assertEq(assets.wethData.t0_i.baseDebt, 0, 't0_i Asset base debt');
      assertEq(
        assets.wethData.t0_i.lastUpdateTimestamp,
        timestamps[uint256(Stages.t0)],
        't0_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes.spoke1.t0_i.baseBorrowIndex, INIT_INDEX, 't0_i Spoke1 index');
      assertEq(spokes.spoke1.t0_i.baseDebt, 0, 't0_i Spoke1 base debt');
      assertEq(
        spokes.spoke1.t0_i.lastUpdateTimestamp,
        timestamps[uint256(Stages.t0)],
        't0_i Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == Stages.t1) {
      assets.wethData.t1_i = hub.getAsset(wethAssetId);
      spokes.spoke1.t1_i = hub.getSpoke(wethAssetId, address(spoke1));

      // asset
      assertEq(assets.wethData.t1_i.baseBorrowIndex, INIT_INDEX, 't1_i Asset index');
      assertEq(assets.wethData.t1_i.baseDebt, spoke1Amounts.draw.t0_i, 't1_i Asset base debt');
      assertEq(
        assets.wethData.t1_i.lastUpdateTimestamp,
        timestamps[uint256(Stages.t0)],
        't1_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes.spoke1.t1_i.baseBorrowIndex, INIT_INDEX, 't1_i Spoke1 index');
      assertEq(spokes.spoke1.t1_i.baseDebt, spoke1Amounts.draw.t0_i, 't1_i Spoke1 base debt');
      assertEq(
        spokes.spoke1.t1_i.lastUpdateTimestamp,
        timestamps[uint256(Stages.t0)],
        't1_i Spoke1 lastUpdateTimestamp'
      );
      // no spoke4 yet
    } else if (stage == Stages.t2) {
      assets.wethData.t2_i = hub.getAsset(wethAssetId);
      spokes.spoke1.t2_i = hub.getSpoke(wethAssetId, address(spoke1));
      spokes.spoke4.t2_i = hub.getSpoke(wethAssetId, address(spoke4));

      // asset
      assertEq(
        assets.wethData.t2_i.baseBorrowIndex,
        assets.wethData.t1_f.baseBorrowIndex,
        't2_i Asset index'
      );
      assertEq(
        assets.wethData.t2_i.baseDebt,
        assets.wethData.t1_f.baseDebt,
        't2_i Asset base debt'
      );
      assertEq(
        assets.wethData.t2_i.lastUpdateTimestamp,
        timestamps[uint256(Stages.t1)],
        't2_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes.spoke1.t2_i.baseBorrowIndex, INIT_INDEX, 't2_i Spoke1 index');
      assertEq(spokes.spoke1.t2_i.baseDebt, spoke1Amounts.draw.t0_i, 't2_i Spoke1 base debt');
      assertEq(
        spokes.spoke1.t2_i.lastUpdateTimestamp,
        timestamps[uint256(Stages.t0)],
        't2_i Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes.spoke4.t2_i.baseBorrowIndex,
        assets.wethData.t2_i.baseBorrowIndex,
        't2_i Spoke4 index'
      );
      assertEq(spokes.spoke4.t2_i.baseDebt, spoke4Amounts.draw.t1_i, 't2_i Spoke4 base debt');
      assertEq(
        spokes.spoke4.t2_i.lastUpdateTimestamp,
        timestamps[uint256(Stages.t1)],
        't2_i Spoke4 lastUpdateTimestamp'
      );
    }
  }

  function exec(Stages stage) internal override {
    super.exec(stage);

    if (stage == Stages.t0) {
      Utils.supply({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke1),
        amount: spoke1Amounts.supply.t0_i,
        riskPremiumRad: 0,
        user: bob,
        to: address(spoke1)
      });
      Utils.draw({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke1),
        amount: spoke1Amounts.draw.t0_i,
        riskPremiumRad: 0,
        to: bob,
        onBehalfOf: address(spoke1)
      });
    } else if (stage == Stages.t1) {
      hub.addSpoke(wethAssetId, spokeConfig, address(spoke4));
      Utils.draw({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke4),
        amount: spoke4Amounts.draw.t1_i,
        riskPremiumRad: 0,
        to: bob,
        onBehalfOf: address(spoke4)
      });
    } else if (stage == Stages.t2) {
      Utils.supply({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke4),
        amount: spoke4Amounts.supply.t2_i,
        riskPremiumRad: 0,
        user: bob,
        to: address(spoke4)
      });
    }
  }

  function skipTime(Stages stage) internal override {
    super.skipTime(stage);

    skip(365 days);
  }

  function finalAssertions(Stages t) internal override {
    if (t == Stages.t0) {
      assets.wethData.t0_f = hub.getAsset(wethAssetId);
      spokes.spoke1.t0_f = hub.getSpoke(wethAssetId, address(spoke1));

      // asset
      assertEq(assets.wethData.t0_f.baseBorrowIndex, INIT_INDEX, 't0_f Asset index');
      assertEq(assets.wethData.t0_f.baseDebt, spoke1Amounts.draw.t0_i, 't0_f Asset base debt');
      assertEq(
        assets.wethData.t0_f.lastUpdateTimestamp,
        timestamps[uint256(Stages.t0)],
        't0_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes.spoke1.t0_f.baseBorrowIndex, INIT_INDEX, 't0_f Spoke1 index');
      assertEq(spokes.spoke1.t0_f.baseDebt, spoke1Amounts.draw.t0_i, 't0_f Spoke1 base debt');
      assertEq(
        spokes.spoke1.t0_f.lastUpdateTimestamp,
        timestamps[uint256(Stages.t0)],
        't0_f Spoke1 lastUpdateTimestamp'
      );
      // no spoke4 yet
    } else if (t == Stages.t1) {
      assets.wethData.t1_f = hub.getAsset(wethAssetId);
      spokes.spoke1.t1_f = hub.getSpoke(wethAssetId, address(spoke1));
      spokes.spoke4.t1_f = hub.getSpoke(wethAssetId, address(spoke4));
      states.cumulatedBaseInterest.t1_f = MathUtils.calculateLinearInterest(
        assets.wethData.t0_f.baseBorrowRate,
        uint40(timestamps[uint256(Stages.t0)])
      );

      // asset
      assertEq(
        assets.wethData.t1_f.baseBorrowIndex,
        assets.wethData.t0_f.baseBorrowIndex.rayMul(states.cumulatedBaseInterest.t1_f),
        't1_f Asset index'
      );
      assertEq(
        assets.wethData.t1_f.baseDebt,
        spoke1Amounts.draw.t0_i.rayMul(states.cumulatedBaseInterest.t1_f) + spoke4Amounts.draw.t1_i,
        't1_f Asset base debt'
      );
      assertEq(
        assets.wethData.t1_f.lastUpdateTimestamp,
        timestamps[uint256(Stages.t1)],
        't1_f Asset lastUpdateTimestamp'
      );

      // spoke1
      // nothing changes vs t0 because no spoke1 action
      assertEq(
        spokes.spoke1.t1_f.baseBorrowIndex,
        spokes.spoke1.t0_f.baseBorrowIndex,
        't1_f Spoke1 index'
      );
      assertEq(spokes.spoke1.t1_f.baseDebt, spokes.spoke1.t0_f.baseDebt, 't1_f Spoke1 base debt');
      assertEq(
        spokes.spoke1.t1_f.lastUpdateTimestamp,
        spokes.spoke1.t0_f.lastUpdateTimestamp,
        't1_f Spoke1 base debt'
      );

      // spoke4
      assertEq(
        spokes.spoke4.t1_f.baseBorrowIndex,
        assets.wethData.t1_f.baseBorrowIndex,
        't1_f Spoke4 index'
      );
      assertEq(spokes.spoke4.t1_f.baseDebt, spoke4Amounts.draw.t1_i, 't1_f Spoke4 base debt');
      assertEq(
        spokes.spoke4.t1_f.lastUpdateTimestamp,
        timestamps[uint256(Stages.t1)],
        't1_f Spoke4 lastUpdateTimestamp'
      );
    } else if (t == Stages.t2) {
      assets.wethData.t2_f = hub.getAsset(wethAssetId);
      spokes.spoke1.t2_f = hub.getSpoke(wethAssetId, address(spoke1));
      spokes.spoke4.t2_f = hub.getSpoke(wethAssetId, address(spoke4));
      states.cumulatedBaseInterest.t2_f = MathUtils.calculateLinearInterest(
        assets.wethData.t1_f.baseBorrowRate,
        uint40(timestamps[uint256(Stages.t1)])
      );

      // asset
      assertEq(
        assets.wethData.t2_f.baseBorrowIndex,
        assets.wethData.t1_f.baseBorrowIndex.rayMul(states.cumulatedBaseInterest.t2_f),
        't2_f Asset index'
      );
      assertEq(
        assets.wethData.t2_f.baseDebt,
        assets.wethData.t1_f.baseDebt.rayMul(states.cumulatedBaseInterest.t2_f),
        't1_f Asset base debt'
      );

      // spoke1
      // nothing changes vs t0 because no spoke1 action
      assertEq(
        spokes.spoke1.t2_f.baseBorrowIndex,
        spokes.spoke1.t0_f.baseBorrowIndex,
        't2_f Spoke1 index'
      );
      assertEq(spokes.spoke1.t2_f.baseDebt, spokes.spoke1.t0_f.baseDebt, 't2_f Spoke1 base debt');
      assertEq(
        spokes.spoke1.t2_f.lastUpdateTimestamp,
        spokes.spoke1.t0_f.lastUpdateTimestamp,
        't2_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes.spoke4.t2_f.baseBorrowIndex,
        assets.wethData.t2_f.baseBorrowIndex,
        't2_f Spoke4 base debt'
      );
      assertEq(
        spokes.spoke4.t2_f.baseDebt,
        spoke4Amounts.draw.t1_i.rayMul(states.cumulatedBaseInterest.t2_f),
        't2_f Spoke4 base debt'
      );
      assertEq(
        spokes.spoke4.t2_f.lastUpdateTimestamp,
        timestamps[uint256(Stages.t2)],
        't2_f Spoke4 lastUpdateTimestamp'
      );
    }
  }
}
