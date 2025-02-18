// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/LiquidityHub.ScenarioBase.t.sol';
import {SpokeData} from 'src/contracts/LiquidityHub.sol';
import {Asset} from 'src/contracts/LiquidityHub.sol';
import {Utils} from 'tests/Utils.t.sol';

contract BorrowIndex_Scenario2Test is LiquidityHubScenarioBaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  DataTypes.SpokeConfig internal spokeConfig;
  Spoke internal spoke4;

  // Scenario:
  // t0: asset added, spoke1 added
  // t1: spoke1 supplies; spoke1 draws
  // t2: spoke4 is added; spoke4 draws
  // t3: spoke4 trivial supply action to trigger accrual

  // Assumptions:
  // - constant 10% IR
  // - 1 year between each action
  // - single asset (weth)

  uint256 internal assetId;

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
    assetId = wethAssetId;
  }

  function test_borrowIndexScenario2() public {
    _testScenario();
  }

  function precondition(Stages stage) internal override {
    super.precondition(stage);

    if (stage == Stages.t1) {
      spoke1Amounts.supply.t1 = 10e18;
      spoke1Amounts.draw.t1 = 5e18;
    } else if (stage == Stages.t2) {
      spoke4Amounts.draw.t2 = 1e18;
    } else if (stage == Stages.t3) {
      spoke4Amounts.supply.t3 = 1e8;
    }
  }

  function initialAssertions(Stages stage) internal override {
    super.initialAssertions(stage);

    if (stage == Stages.t0) {
      assets_i.assetData0.t0 = hub.getAsset(assetId);
      spokes_i.spoke1.t0 = hub.getSpoke(assetId, address(spoke1));

      // asset
      assertEq(
        assets_i.assetData0.t0.baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't0_i Asset index'
      );
      assertEq(assets_i.assetData0.t0.baseDebt, 0, 't0_i Asset base debt');
      assertEq(
        assets_i.assetData0.t0.lastUpdateTimestamp,
        timeAt(Stages.t0),
        't0_i Asset lastUpdateTimestamp'
      );
    } else if (stage == Stages.t1) {
      assets_i.assetData0.t1 = hub.getAsset(assetId);
      spokes_i.spoke1.t1 = hub.getSpoke(assetId, address(spoke1));

      // asset
      assertEq(
        assets_i.assetData0.t1.baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't1_i Asset index'
      );
      assertEq(assets_i.assetData0.t1.baseDebt, 0, 't1_i Asset base debt');
      assertEq(
        assets_i.assetData0.t1.lastUpdateTimestamp,
        timeAt(Stages.t0),
        't1_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes_i.spoke1.t1.baseBorrowIndex, hub.DEFAULT_SPOKE_INDEX(), 't1_i Spoke1 index');
      assertEq(spokes_i.spoke1.t1.baseDebt, 0, 't1_i Spoke1 base debt');
      assertEq(spokes_i.spoke1.t1.lastUpdateTimestamp, 0, 't1_i Spoke1 lastUpdateTimestamp');
    } else if (stage == Stages.t2) {
      assets_i.assetData0.t2 = hub.getAsset(assetId);
      spokes_i.spoke1.t2 = hub.getSpoke(assetId, address(spoke1));
      spokes_i.spoke4.t2 = hub.getSpoke(assetId, address(spoke4));

      // asset
      assertEq(
        assets_i.assetData0.t2.baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't2_i Asset index'
      );
      assertEq(assets_i.assetData0.t2.baseDebt, spoke1Amounts.draw.t1, 't2_i Asset base debt');
      assertEq(
        assets_i.assetData0.t2.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't2_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes_i.spoke1.t2.baseBorrowIndex,
        assets_i.assetData0.t2.baseBorrowIndex,
        't2_i Spoke1 index'
      );
      assertEq(spokes_i.spoke1.t2.baseDebt, spokes_f.spoke1.t1.baseDebt, 't2_i Spoke1 base debt');
      assertEq(
        spokes_i.spoke1.t2.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't2_i Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == Stages.t3) {
      assets_i.assetData0.t3 = hub.getAsset(assetId);
      spokes_i.spoke1.t3 = hub.getSpoke(assetId, address(spoke1));
      spokes_i.spoke4.t3 = hub.getSpoke(assetId, address(spoke4));

      // asset
      assertEq(
        assets_i.assetData0.t3.baseBorrowIndex,
        assets_f.assetData0.t2.baseBorrowIndex,
        't3_i Asset index'
      );
      assertEq(
        assets_i.assetData0.t3.baseDebt,
        assets_f.assetData0.t2.baseDebt,
        't3_i Asset base debt'
      );
      assertEq(
        assets_i.assetData0.t3.lastUpdateTimestamp,
        timeAt(Stages.t2),
        't3_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes_i.spoke1.t3.baseBorrowIndex, hub.DEFAULT_ASSET_INDEX(), 't3_i Spoke1 index');
      assertEq(spokes_i.spoke1.t3.baseDebt, spoke1Amounts.draw.t1, 't3_i Spoke1 base debt');
      assertEq(
        spokes_i.spoke1.t3.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't3_i Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes_i.spoke4.t3.baseBorrowIndex,
        assets_i.assetData0.t3.baseBorrowIndex,
        't3_i Spoke4 index'
      );
      assertEq(spokes_i.spoke4.t3.baseDebt, spoke4Amounts.draw.t2, 't3_i Spoke4 base debt');
      assertEq(
        spokes_i.spoke4.t3.lastUpdateTimestamp,
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
        assetId: assetId,
        spoke: address(spoke1),
        amount: spoke1Amounts.supply.t1,
        riskPremiumRad: 0,
        user: bob,
        to: address(spoke1)
      });
      Utils.draw({
        hub: hub,
        assetId: assetId,
        spoke: address(spoke1),
        amount: spoke1Amounts.draw.t1,
        riskPremiumRad: 0,
        to: bob,
        onBehalfOf: address(spoke1)
      });
    } else if (stage == Stages.t2) {
      hub.addSpoke(assetId, spokeConfig, address(spoke4));
      Utils.draw({
        hub: hub,
        assetId: assetId,
        spoke: address(spoke4),
        amount: spoke4Amounts.draw.t2,
        riskPremiumRad: 0,
        to: bob,
        onBehalfOf: address(spoke4)
      });
    } else if (stage == Stages.t3) {
      Utils.supply({
        hub: hub,
        assetId: assetId,
        spoke: address(spoke4),
        amount: spoke4Amounts.supply.t3,
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
      assets_f.assetData0.t0 = hub.getAsset(assetId);
      spokes_f.spoke1.t0 = hub.getSpoke(assetId, address(spoke1));

      // asset
      assertEq(
        assets_f.assetData0.t0.baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't0_f Asset index'
      );
      assertEq(assets_f.assetData0.t0.baseDebt, 0, 't0_f Asset base debt');
      assertEq(
        assets_f.assetData0.t0.lastUpdateTimestamp,
        timeAt(Stages.t0),
        't0_f Asset base debt'
      );

      // spoke1
      assertEq(spokes_f.spoke1.t0.baseBorrowIndex, hub.DEFAULT_SPOKE_INDEX(), 't0_f Spoke1 index');
      assertEq(spokes_f.spoke1.t0.baseDebt, 0, 't0_f Spoke1 base debt');
      assertEq(spokes_f.spoke1.t0.lastUpdateTimestamp, 0, 't0_f Spoke1 lastUpdateTimestamp');
    } else if (stage == Stages.t1) {
      assets_f.assetData0.t1 = hub.getAsset(assetId);
      spokes_f.spoke1.t1 = hub.getSpoke(assetId, address(spoke1));

      // asset
      assertEq(
        assets_f.assetData0.t1.baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't1_f Asset index'
      );
      assertEq(assets_f.assetData0.t1.baseDebt, spoke1Amounts.draw.t1, 't1_f Asset base debt');
      assertEq(
        assets_f.assetData0.t1.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't1_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes_f.spoke1.t1.baseBorrowIndex, hub.DEFAULT_ASSET_INDEX(), 't1_f Spoke1 index');
      assertEq(spokes_f.spoke1.t1.baseDebt, spoke1Amounts.draw.t1, 't1_f Spoke1 base debt');
      assertEq(
        spokes_f.spoke1.t1.lastUpdateTimestamp,
        timeAt(Stages.t1),
        't1_f Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == Stages.t2) {
      assets_f.assetData0.t2 = hub.getAsset(assetId);
      spokes_f.spoke1.t2 = hub.getSpoke(assetId, address(spoke1));
      spokes_f.spoke4.t2 = hub.getSpoke(assetId, address(spoke4));
      states.cumulatedBaseInterest.t2 = MathUtils.calculateLinearInterest(
        assets_f.assetData0.t1.baseBorrowRate,
        timeAt(Stages.t1)
      );

      // asset
      assertEq(
        assets_f.assetData0.t2.baseBorrowIndex,
        assets_f.assetData0.t1.baseBorrowIndex.rayMul(states.cumulatedBaseInterest.t2),
        't2_f Asset index'
      );
      assertEq(
        assets_f.assetData0.t2.baseDebt,
        assets_f.assetData0.t1.baseDebt.rayMul(states.cumulatedBaseInterest.t2) +
          spoke4Amounts.draw.t2,
        't2_f Asset base debt'
      );
      assertEq(
        assets_f.assetData0.t2.lastUpdateTimestamp,
        timeAt(Stages.t2),
        't2_f Asset lastUpdateTimestamp'
      );

      // spoke1
      // no action, should be the same as t1
      assertEq(
        spokes_f.spoke1.t2.baseBorrowIndex,
        spokes_f.spoke1.t1.baseBorrowIndex,
        't2_f Spoke1 index'
      );
      assertEq(spokes_f.spoke1.t2.baseDebt, spokes_f.spoke1.t1.baseDebt, 't2_f Spoke1 base debt');
      assertEq(
        spokes_f.spoke1.t2.lastUpdateTimestamp,
        spokes_f.spoke1.t1.lastUpdateTimestamp,
        't2_f Spoke1 base debt'
      );

      // spoke4
      assertEq(
        spokes_f.spoke4.t2.baseBorrowIndex,
        assets_f.assetData0.t2.baseBorrowIndex,
        't2_f Spoke4 index'
      );
      assertEq(spokes_f.spoke4.t1.baseDebt, spoke4Amounts.draw.t1, 't2_f Spoke4 base debt');
      assertEq(
        spokes_f.spoke4.t2.lastUpdateTimestamp,
        timeAt(Stages.t2),
        't2_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == Stages.t3) {
      assets_f.assetData0.t3 = hub.getAsset(assetId);
      spokes_f.spoke1.t3 = hub.getSpoke(assetId, address(spoke1));
      spokes_f.spoke4.t3 = hub.getSpoke(assetId, address(spoke4));
      states.cumulatedBaseInterest.t3 = MathUtils.calculateLinearInterest(
        assets_f.assetData0.t2.baseBorrowRate,
        timeAt(Stages.t2)
      );

      // asset
      assertEq(
        assets_f.assetData0.t3.baseBorrowIndex,
        assets_f.assetData0.t2.baseBorrowIndex.rayMul(states.cumulatedBaseInterest.t3),
        't3_f Asset index'
      );
      assertEq(
        assets_f.assetData0.t3.baseDebt,
        assets_f.assetData0.t2.baseDebt.rayMul(states.cumulatedBaseInterest.t3),
        't3_f Asset base debt'
      );
      assertEq(
        assets_f.assetData0.t3.lastUpdateTimestamp,
        timeAt(Stages.t3),
        't3_f Asset lastUpdateTimestamp'
      );

      // spoke1
      // no action, should be the same as t1
      assertEq(
        spokes_f.spoke1.t3.baseBorrowIndex,
        spokes_f.spoke1.t1.baseBorrowIndex,
        't3_f Spoke1 index'
      );
      assertEq(spokes_f.spoke1.t3.baseDebt, spokes_f.spoke1.t1.baseDebt, 't3_f Spoke1 base debt');
      assertEq(
        spokes_f.spoke1.t3.lastUpdateTimestamp,
        spokes_f.spoke1.t1.lastUpdateTimestamp,
        't3_f Spoke1 base debt'
      );

      // spoke4
      assertEq(
        spokes_f.spoke4.t3.baseBorrowIndex,
        assets_f.assetData0.t3.baseBorrowIndex,
        't3_f Spoke4 index'
      );
      assertEq(
        spokes_f.spoke4.t3.baseDebt,
        spokes_f.spoke4.t2.baseDebt.rayMul(states.cumulatedBaseInterest.t3),
        't3_f Spoke4 base debt'
      );
      assertEq(
        spokes_f.spoke4.t3.lastUpdateTimestamp,
        timeAt(Stages.t3),
        't3_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == Stages.t4) {
      assets_f.assetData0.t4 = hub.getAsset(assetId);
      spokes_f.spoke1.t4 = hub.getSpoke(assetId, address(spoke1));
      spokes_f.spoke4.t4 = hub.getSpoke(assetId, address(spoke4));
      states.cumulatedBaseInterest.t4 = MathUtils.calculateLinearInterest(
        assets_f.assetData0.t3.baseBorrowRate,
        timeAt(Stages.t3)
      );
    }
  }

  function printInitialLog(Stages stage) internal override {
    if (stage == Stages.t0) {
      console.log('----- t0_i -----');

      // asset
      console.log('Asset borrow index %27e', assets_i.assetData0.t0.baseBorrowIndex);
      console.log('Asset base debt %e', assets_i.assetData0.t0.baseDebt);
      console.log('Asset last update timestamp', assets_i.assetData0.t0.lastUpdateTimestamp);

      console.log('no Spoke4 yet');
    } else if (stage == Stages.t1) {
      console.log('----- t1_i -----');

      // asset
      console.log('Asset borrow index %27e', assets_i.assetData0.t1.baseBorrowIndex);
      console.log('Asset base debt %e', assets_i.assetData0.t1.baseDebt);
      console.log('Asset last update timestamp', assets_i.assetData0.t1.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %27e', spokes_i.spoke1.t1.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes_i.spoke1.t1.baseDebt);
      console.log('Spoke1 last update timestamp', spokes_i.spoke1.t1.lastUpdateTimestamp);

      console.log('no Spoke4 yet');
    } else if (stage == Stages.t2) {
      console.log('----- t2_i -----');

      // asset
      console.log('Asset borrow index %27e', assets_i.assetData0.t2.baseBorrowIndex);
      console.log('Asset base debt %e', assets_i.assetData0.t2.baseDebt);
      console.log('Asset last update timestamp', assets_i.assetData0.t2.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %27e', spokes_i.spoke1.t2.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes_i.spoke1.t2.baseDebt);
      console.log('Spoke1 last update timestamp', spokes_i.spoke1.t2.lastUpdateTimestamp);

      console.log('no Spoke4 yet');
    } else if (stage == Stages.t3) {
      console.log('----- t3_i -----');

      // asset
      console.log('Asset borrow index %27e', assets_i.assetData0.t3.baseBorrowIndex);
      console.log('Asset base debt %e', assets_i.assetData0.t3.baseDebt);
      console.log('Asset last update timestamp', assets_i.assetData0.t3.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %27e', spokes_i.spoke1.t3.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes_i.spoke1.t3.baseDebt);
      console.log('Spoke1 last update timestamp', spokes_i.spoke1.t3.lastUpdateTimestamp);

      // spoke4
      console.log('Spoke4 borrow index %27e', spokes_i.spoke4.t3.baseBorrowIndex);
      console.log('Spoke4 base debt %e', spokes_i.spoke4.t3.baseDebt);
      console.log('Spoke4 last update timestamp', spokes_i.spoke4.t3.lastUpdateTimestamp);
    }
  }

  function printFinalLog(Stages stage) internal override {
    if (stage == Stages.t0) {
      console.log('----- t0_f -----');

      // asset
      console.log('Asset borrow index %27e', assets_f.assetData0.t0.baseBorrowIndex);
      console.log('Asset base debt %e', assets_f.assetData0.t0.baseDebt);
      console.log('Asset last update timestamp', assets_f.assetData0.t0.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %27e', spokes_f.spoke1.t0.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes_f.spoke1.t0.baseDebt);
      console.log('Spoke1 last update timestamp', spokes_f.spoke1.t0.lastUpdateTimestamp);

      console.log('no Spoke4 yet');
    } else if (stage == Stages.t1) {
      console.log('----- t1_f -----');

      // asset
      console.log('Asset borrow index %27e', assets_f.assetData0.t1.baseBorrowIndex);
      console.log('Asset base debt %e', assets_f.assetData0.t1.baseDebt);
      console.log('Asset last update timestamp', assets_f.assetData0.t1.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %27e', spokes_f.spoke1.t1.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes_f.spoke1.t1.baseDebt);
      console.log('Spoke1 last update timestamp', spokes_f.spoke1.t1.lastUpdateTimestamp);

      console.log('no Spoke4 yet');
    } else if (stage == Stages.t2) {
      console.log('----- t2_f -----');

      // asset
      console.log('Asset borrow index %27e', assets_f.assetData0.t2.baseBorrowIndex);
      console.log('Asset base debt %e', assets_f.assetData0.t2.baseDebt);
      console.log('Asset last update timestamp', assets_f.assetData0.t2.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %27e', spokes_f.spoke1.t2.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes_f.spoke1.t2.baseDebt);
      console.log('Spoke1 last update timestamp', spokes_f.spoke1.t2.lastUpdateTimestamp);

      // spoke4
      console.log('Spoke4 borrow index %27e', spokes_f.spoke4.t2.baseBorrowIndex);
      console.log('Spoke4 base debt %e', spokes_f.spoke4.t2.baseDebt);
      console.log('Spoke4 last update timestamp', spokes_f.spoke4.t2.lastUpdateTimestamp);
    } else if (stage == Stages.t3) {
      console.log('----- t3_f -----');

      // asset
      console.log('Asset borrow index %27e', assets_f.assetData0.t3.baseBorrowIndex);
      console.log('Asset base debt %e', assets_f.assetData0.t3.baseDebt);
      console.log('Asset last update timestamp', assets_f.assetData0.t3.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %27e', spokes_f.spoke1.t3.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes_f.spoke1.t3.baseDebt);
      console.log('Spoke1 last update timestamp', spokes_f.spoke1.t3.lastUpdateTimestamp);

      // spoke4
      console.log('Spoke4 borrow index %27e', spokes_f.spoke4.t3.baseBorrowIndex);
      console.log('Spoke4 base debt %e', spokes_f.spoke4.t3.baseDebt);
      console.log('Spoke4 last update timestamp', spokes_f.spoke4.t3.lastUpdateTimestamp);
    }
  }
}
