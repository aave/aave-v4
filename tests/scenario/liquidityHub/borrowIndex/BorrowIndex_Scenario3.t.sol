// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/LiquidityHub.ScenarioBase.t.sol';
import {SpokeData} from 'src/contracts/LiquidityHub.sol';
import {Asset} from 'src/contracts/LiquidityHub.sol';
import {Utils} from 'tests/Utils.t.sol';

contract BorrowIndex_Scenario3Test is LiquidityHubScenarioBaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  DataTypes.SpokeConfig internal spokeConfig;
  Spoke internal spoke4;

  uint256 internal constant INIT_INDEX = WadRayMath.RAY;

  // Scenario:
  // t0	asset added, spoke1 added
  // t1	spoke1 supply, spoke1 draw
  // t2	spoke4 added
  // t3	spoke4 draw
  // t4	spoke4 supply

  // Assumptions:
  // - constant 10% IR
  // - 1 year between each action

  function setUp() public override {
    super.setUp();
    initEnvironment();
    spokeMintAndApprove();

    spokeConfig = DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max});

    // Mock constant 10% IR
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(10_00).bpsToRay())
    );
    spoke4 = new Spoke(address(hub), address(oracle));

    isPrintLogs = false;
  }

  function precondition(Stages stage) internal override {
    super.precondition(stage);

    if (stage == Stages.t1) {
      spoke1Amounts.supply.t1_i = 10e18;
      spoke1Amounts.draw.t1_i = 5e18;
    } else if (stage == Stages.t2) {
      // intentially left blank
    } else if (stage == Stages.t3) {
      spoke4Amounts.draw.t3_i = 1e18;
    } else if (stage == Stages.t4) {
      spoke4Amounts.supply.t4_i = 1e8;
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
        timeAt(Stages.t0),
        't0_i Asset lastUpdateTimestamp'
      );
    } else if (stage == Stages.t1) {
      assets.wethData.t1_i = hub.getAsset(wethAssetId);
      spokes.spoke1.t1_i = hub.getSpoke(wethAssetId, address(spoke1));

      // asset
      assertEq(assets.wethData.t1_i.baseBorrowIndex, INIT_INDEX, 't1_i Asset index');
      assertEq(assets.wethData.t1_i.baseDebt, 0, 't1_i Asset base debt');
      assertEq(
        assets.wethData.t1_i.lastUpdateTimestamp,
        timeAt(Stages.t0),
        't1_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes.spoke1.t1_i.baseBorrowIndex,
        assets.wethData.t1_i.baseBorrowIndex,
        't1_i Spoke1 index'
      );
      assertEq(spokes.spoke1.t1_i.baseDebt, 0, 't1_i Spoke1 base debt');
      assertEq(
        spokes.spoke1.t1_i.lastUpdateTimestamp,
        timeAt(Stages.t0),
        't1_i Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == Stages.t2) {
      assets.wethData.t2_i = hub.getAsset(wethAssetId);
      spokes.spoke1.t2_i = hub.getSpoke(wethAssetId, address(spoke1));
      spokes.spoke4.t2_i = hub.getSpoke(wethAssetId, address(spoke4));

      // asset
      assertEq(assets.wethData.t2_i.baseBorrowIndex, INIT_INDEX, 't2_i Asset index');
      assertEq(assets.wethData.t2_i.baseDebt, spoke1Amounts.draw.t1_i, 't2_i Asset base debt');
      assertEq(
        assets.wethData.t2_i.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't2_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes.spoke1.t2_i.baseBorrowIndex,
        assets.wethData.t2_i.baseBorrowIndex,
        't2_i Spoke1 index'
      );
      assertEq(spokes.spoke1.t2_i.baseDebt, spokes.spoke1.t1_f.baseDebt, 't2_i Spoke1 base debt');
      assertEq(
        spokes.spoke1.t2_i.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't2_i Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == Stages.t3) {
      assets.wethData.t3_i = hub.getAsset(wethAssetId);
      spokes.spoke1.t3_i = hub.getSpoke(wethAssetId, address(spoke1));
      spokes.spoke4.t3_i = hub.getSpoke(wethAssetId, address(spoke4));

      // asset
      assertEq(
        assets.wethData.t3_i.baseBorrowIndex,
        assets.wethData.t2_f.baseBorrowIndex,
        't3_i Asset index'
      );
      assertEq(
        assets.wethData.t3_i.baseDebt,
        assets.wethData.t2_f.baseDebt,
        't3_i Asset base debt'
      );
      assertEq(
        assets.wethData.t3_i.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't3_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes.spoke1.t3_i.baseBorrowIndex, INIT_INDEX, 't3_i Spoke1 index');
      assertEq(spokes.spoke1.t3_i.baseDebt, spoke1Amounts.draw.t1_i, 't3_i Spoke1 base debt');
      assertEq(
        spokes.spoke1.t3_i.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't3_i Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      // spoke index is out of sync with asset index
      // because spoke index is set to asset's next borrow index
      // assertEq(
      //   spokes.spoke4.t3_i.baseBorrowIndex,
      //   assets.wethData.t3_i.baseBorrowIndex,
      //   't3_i Spoke4 index'
      // );
      assertEq(spokes.spoke4.t3_i.baseDebt, 0, 't3_i Spoke4 base debt');
      assertEq(
        spokes.spoke4.t3_i.lastUpdateTimestamp,
        timeAt(Stages.t2),
        't3_i Spoke4 lastUpdateTimestamp'
      );
    }
  }

  function exec(Stages stage) internal override {
    super.exec(stage);

    if (stage == Stages.t1) {
      Utils.supply({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke1),
        amount: spoke1Amounts.supply.t1_i,
        riskPremiumRad: 0,
        user: bob,
        to: address(spoke1)
      });
      Utils.draw({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke1),
        amount: spoke1Amounts.draw.t1_i,
        riskPremiumRad: 0,
        to: bob,
        onBehalfOf: address(spoke1)
      });
    } else if (stage == Stages.t2) {
      hub.addSpoke(wethAssetId, spokeConfig, address(spoke4));
    } else if (stage == Stages.t3) {
      Utils.draw({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke4),
        amount: spoke4Amounts.draw.t3_i,
        riskPremiumRad: 0,
        to: bob,
        onBehalfOf: address(spoke4)
      });
    } else if (stage == Stages.t4) {
      Utils.supply({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke4),
        amount: spoke4Amounts.supply.t4_i,
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

  function finalAssertions(Stages stage) internal override {
    if (stage == Stages.t0) {
      assets.wethData.t0_f = hub.getAsset(wethAssetId);
      spokes.spoke1.t0_f = hub.getSpoke(wethAssetId, address(spoke1));

      // asset
      assertEq(assets.wethData.t0_f.baseBorrowIndex, INIT_INDEX, 't0_f Asset index');
      assertEq(assets.wethData.t0_f.baseDebt, 0, 't0_f Asset base debt');
      assertEq(assets.wethData.t0_f.lastUpdateTimestamp, timeAt(Stages.t0), 't0_f Asset base debt');

      // spoke1
      assertEq(spokes.spoke1.t0_f.baseBorrowIndex, INIT_INDEX, 't0_f Spoke1 index');
      assertEq(spokes.spoke1.t0_f.baseDebt, 0, 't0_f Spoke1 base debt');
      assertEq(
        spokes.spoke1.t0_f.lastUpdateTimestamp,
        timeAt(Stages.t0),
        't0_f Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == Stages.t1) {
      assets.wethData.t1_f = hub.getAsset(wethAssetId);
      spokes.spoke1.t1_f = hub.getSpoke(wethAssetId, address(spoke1));

      // asset
      assertEq(assets.wethData.t1_f.baseBorrowIndex, INIT_INDEX, 't1_f Asset index');
      assertEq(assets.wethData.t1_f.baseDebt, spoke1Amounts.draw.t1_i, 't1_f Asset base debt');
      assertEq(
        assets.wethData.t1_f.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't1_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes.spoke1.t1_f.baseBorrowIndex, INIT_INDEX, 't1_f Spoke1 index');
      assertEq(spokes.spoke1.t1_f.baseDebt, spoke1Amounts.draw.t1_i, 't1_f Spoke1 base debt');
      assertEq(
        spokes.spoke1.t1_f.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't1_f Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == Stages.t2) {
      assets.wethData.t2_f = hub.getAsset(wethAssetId);
      spokes.spoke1.t2_f = hub.getSpoke(wethAssetId, address(spoke1));
      spokes.spoke4.t2_f = hub.getSpoke(wethAssetId, address(spoke4));
      states.cumulatedBaseInterest.t2_f = MathUtils.calculateLinearInterest(
        assets.wethData.t1_f.baseBorrowRate,
        uint40(timeAt(Stages.t1))
      );

      // asset
      assertEq(
        assets.wethData.t2_f.baseBorrowIndex,
        assets.wethData.t1_f.baseBorrowIndex,
        't2_f Asset index'
      );
      assertEq(
        assets.wethData.t2_f.baseDebt,
        assets.wethData.t1_f.baseDebt,
        't2_f Asset base debt'
      );
      assertEq(
        assets.wethData.t2_f.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't2_f Asset lastUpdateTimestamp'
      );

      // spoke1
      // no action, should be the same as t1
      assertEq(
        spokes.spoke1.t2_f.baseBorrowIndex,
        spokes.spoke1.t1_f.baseBorrowIndex,
        't2_f Spoke1 index'
      );
      assertEq(spokes.spoke1.t2_f.baseDebt, spokes.spoke1.t1_f.baseDebt, 't2_f Spoke1 base debt');
      assertEq(
        spokes.spoke1.t2_f.lastUpdateTimestamp,
        spokes.spoke1.t1_f.lastUpdateTimestamp,
        't2_f Spoke1 base debt'
      );
    } else if (stage == Stages.t3) {
      assets.wethData.t3_f = hub.getAsset(wethAssetId);
      spokes.spoke1.t3_f = hub.getSpoke(wethAssetId, address(spoke1));
      spokes.spoke4.t3_f = hub.getSpoke(wethAssetId, address(spoke4));
      states.cumulatedBaseInterest.t3_f = MathUtils.calculateLinearInterest(
        assets.wethData.t2_f.baseBorrowRate,
        uint40(timeAt(Stages.t1))
      );

      // asset
      assertEq(
        assets.wethData.t3_f.baseBorrowIndex,
        assets.wethData.t2_f.baseBorrowIndex.rayMul(states.cumulatedBaseInterest.t3_f),
        't3_f Asset index'
      );
      assertEq(
        assets.wethData.t3_f.baseDebt,
        assets.wethData.t2_f.baseDebt.rayMul(states.cumulatedBaseInterest.t3_f) +
          spoke4Amounts.draw.t3_i,
        't3_f Asset base debt'
      );
      assertEq(
        assets.wethData.t3_f.lastUpdateTimestamp,
        timeAt(Stages.t3),
        't3_f Asset lastUpdateTimestamp'
      );

      // spoke1
      // no action, should be the same as t1
      assertEq(
        spokes.spoke1.t3_f.baseBorrowIndex,
        spokes.spoke1.t1_f.baseBorrowIndex,
        't3_f Spoke1 index'
      );
      assertEq(spokes.spoke1.t3_f.baseDebt, spokes.spoke1.t1_f.baseDebt, 't3_f Spoke1 base debt');
      assertEq(
        spokes.spoke1.t3_f.lastUpdateTimestamp,
        spokes.spoke1.t1_f.lastUpdateTimestamp,
        't3_f Spoke1 base debt'
      );

      // spoke4
      assertEq(
        spokes.spoke4.t3_f.baseBorrowIndex,
        assets.wethData.t3_f.baseBorrowIndex,
        't3_f Spoke4 index'
      );
      assertEq(spokes.spoke4.t3_f.baseDebt, spoke4Amounts.draw.t3_i, 't3_f Spoke4 base debt');
      assertEq(
        spokes.spoke4.t3_f.lastUpdateTimestamp,
        timeAt(Stages.t3),
        't3_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == Stages.t4) {
      assets.wethData.t4_f = hub.getAsset(wethAssetId);
      spokes.spoke1.t4_f = hub.getSpoke(wethAssetId, address(spoke1));
      spokes.spoke4.t4_f = hub.getSpoke(wethAssetId, address(spoke4));
      states.cumulatedBaseInterest.t4_f = MathUtils.calculateLinearInterest(
        assets.wethData.t3_f.baseBorrowRate,
        uint40(timeAt(Stages.t3))
      );

      // asset
      assertEq(
        assets.wethData.t4_f.baseBorrowIndex,
        assets.wethData.t3_f.baseBorrowIndex.rayMul(states.cumulatedBaseInterest.t4_f),
        't4_f Asset index'
      );
      assertEq(
        assets.wethData.t4_f.baseDebt,
        assets.wethData.t3_f.baseDebt.rayMul(states.cumulatedBaseInterest.t4_f),
        't4_f Asset base debt'
      );
      assertEq(
        assets.wethData.t4_f.lastUpdateTimestamp,
        timeAt(Stages.t4),
        't4_f Asset lastUpdateTimestamp'
      );

      // spoke1
      // no action, should be the same as t1
      assertEq(
        spokes.spoke1.t4_f.baseBorrowIndex,
        spokes.spoke1.t1_f.baseBorrowIndex,
        't4_f Spoke1 index'
      );
      assertEq(spokes.spoke1.t4_f.baseDebt, spokes.spoke1.t1_f.baseDebt, 't4_f Spoke1 base debt');
      assertEq(
        spokes.spoke1.t4_f.lastUpdateTimestamp,
        spokes.spoke1.t1_f.lastUpdateTimestamp,
        't4_f Spoke1 base debt'
      );

      // spoke4
      assertEq(
        spokes.spoke4.t4_f.baseBorrowIndex,
        assets.wethData.t4_f.baseBorrowIndex,
        't4_f Spoke4 index'
      );
      assertEq(
        spokes.spoke4.t4_f.baseDebt,
        spokes.spoke4.t3_f.baseDebt.rayMul(states.cumulatedBaseInterest.t4_f),
        't4_f Spoke4 base debt'
      );
      assertEq(
        spokes.spoke4.t4_f.lastUpdateTimestamp,
        timeAt(Stages.t4),
        't4_f Spoke4 lastUpdateTimestamp'
      );
    }
  }

  function printInitialLog(Stages stage) internal override {
    if (stage == Stages.t0) {
      console.log('----- t0_i -----');

      // asset
      console.log('Asset borrow index %e', assets.wethData.t0_i.baseBorrowIndex);
      console.log('Asset base debt %e', assets.wethData.t0_i.baseDebt);
      console.log('Asset last update timestamp', assets.wethData.t0_i.lastUpdateTimestamp);

      console.log('no Spoke4 yet');
    } else if (stage == Stages.t1) {
      console.log('----- t1_i -----');

      // asset
      console.log('Asset borrow index %e', assets.wethData.t1_i.baseBorrowIndex);
      console.log('Asset base debt %e', assets.wethData.t1_i.baseDebt);
      console.log('Asset last update timestamp', assets.wethData.t1_i.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %e', spokes.spoke1.t1_i.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes.spoke1.t1_i.baseDebt);
      console.log('Spoke1 last update timestamp', spokes.spoke1.t1_i.lastUpdateTimestamp);

      console.log('no Spoke4 yet');
    } else if (stage == Stages.t2) {
      console.log('----- t2_i -----');

      // asset
      console.log('Asset borrow index %e', assets.wethData.t2_i.baseBorrowIndex);
      console.log('Asset base debt %e', assets.wethData.t2_i.baseDebt);
      console.log('Asset last update timestamp', assets.wethData.t2_i.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %e', spokes.spoke1.t2_i.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes.spoke1.t2_i.baseDebt);
      console.log('Spoke1 last update timestamp', spokes.spoke1.t2_i.lastUpdateTimestamp);

      console.log('no Spoke4 yet');
    } else if (stage == Stages.t3) {
      console.log('----- t3_i -----');

      // asset
      console.log('Asset borrow index %e', assets.wethData.t3_i.baseBorrowIndex);
      console.log('Asset base debt %e', assets.wethData.t3_i.baseDebt);
      console.log('Asset last update timestamp', assets.wethData.t3_i.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %e', spokes.spoke1.t3_i.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes.spoke1.t3_i.baseDebt);
      console.log('Spoke1 last update timestamp', spokes.spoke1.t3_i.lastUpdateTimestamp);

      // spoke4
      console.log('Spoke4 borrow index %e', spokes.spoke4.t3_i.baseBorrowIndex);
      console.log('Spoke4 base debt %e', spokes.spoke4.t3_i.baseDebt);
      console.log('Spoke4 last update timestamp', spokes.spoke4.t3_i.lastUpdateTimestamp);
    }
  }

  function printFinalLog(Stages stage) internal override {
    if (stage == Stages.t0) {
      console.log('----- t0_f -----');

      // asset
      console.log('Asset borrow index %e', assets.wethData.t0_f.baseBorrowIndex);
      console.log('Asset base debt %e', assets.wethData.t0_f.baseDebt);
      console.log('Asset last update timestamp', assets.wethData.t0_f.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %e', spokes.spoke1.t0_f.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes.spoke1.t0_f.baseDebt);
      console.log('Spoke1 last update timestamp', spokes.spoke1.t0_f.lastUpdateTimestamp);

      console.log('no Spoke4 yet');
    } else if (stage == Stages.t1) {
      console.log('----- t1_f -----');

      // asset
      console.log('Asset borrow index %e', assets.wethData.t1_f.baseBorrowIndex);
      console.log('Asset base debt %e', assets.wethData.t1_f.baseDebt);
      console.log('Asset last update timestamp', assets.wethData.t1_f.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %e', spokes.spoke1.t1_f.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes.spoke1.t1_f.baseDebt);
      console.log('Spoke1 last update timestamp', spokes.spoke1.t1_f.lastUpdateTimestamp);

      console.log('no Spoke4 yet');
    } else if (stage == Stages.t2) {
      console.log('----- t2_f -----');

      // asset
      console.log('Asset borrow index %e', assets.wethData.t2_f.baseBorrowIndex);
      console.log('Asset base debt %e', assets.wethData.t2_f.baseDebt);
      console.log('Asset last update timestamp', assets.wethData.t2_f.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %e', spokes.spoke1.t2_f.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes.spoke1.t2_f.baseDebt);
      console.log('Spoke1 last update timestamp', spokes.spoke1.t2_f.lastUpdateTimestamp);

      // spoke4
      console.log('Spoke4 borrow index %e', spokes.spoke4.t2_f.baseBorrowIndex);
      console.log('Spoke4 base debt %e', spokes.spoke4.t2_f.baseDebt);
      console.log('Spoke4 last update timestamp', spokes.spoke4.t2_f.lastUpdateTimestamp);
    } else if (stage == Stages.t3) {
      console.log('----- t3_f -----');

      // asset
      console.log('Asset borrow index %e', assets.wethData.t3_f.baseBorrowIndex);
      console.log('Asset base debt %e', assets.wethData.t3_f.baseDebt);
      console.log('Asset last update timestamp', assets.wethData.t3_f.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %e', spokes.spoke1.t3_f.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes.spoke1.t3_f.baseDebt);
      console.log('Spoke1 last update timestamp', spokes.spoke1.t3_f.lastUpdateTimestamp);

      // spoke4
      console.log('Spoke4 borrow index %e', spokes.spoke4.t3_f.baseBorrowIndex);
      console.log('Spoke4 base debt %e', spokes.spoke4.t3_f.baseDebt);
      console.log('Spoke4 last update timestamp', spokes.spoke4.t3_f.lastUpdateTimestamp);
    }
  }
}
