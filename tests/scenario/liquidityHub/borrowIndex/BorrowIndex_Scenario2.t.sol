// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/borrowIndex/BorrowIndexBase.t.sol';
contract BorrowIndex_Scenario2Test is BorrowIndexBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  // Scenario:
  // t0: asset added, spoke1 added
  // t1: spoke1 supplies; spoke1 draws
  // t2: spoke4 is added; spoke4 draws
  // t3: spoke4 trivial supply action to trigger accrual

  // Assumptions:
  // - constant 10% IR
  // - 1 year between each action
  // - single asset (weth)

  function setUp() public override {
    super.setUp();

    isPrintLogs = false;
  }

  function test_borrowIndexScenario2() public {
    state.assetId = wethAssetId;
    fillSkipTimeAndBaseBorrowRate(state, 365 days, 10_00);
    state.actions[0].supply[1].amount = 10e18;
    state.actions[0].draw[1].amount = 5e18;
    state.actions[3].draw[2].amount = 1e18;
    state.actions[3].supply[3].amount = 1e8;
    _testScenario();
  }

  /// forge-config: default.fuzz.runs = 100
  /// forge-config: default.fuzz.show-logs = true
  function test_fuzz_borrowIndexScenario2(TestState memory _state) public {
    state.assetId = bound(_state.assetId, 0, NUM_ASSETS - 1);
    boundFuzzStates(state, _state);

    vm.assume(
      state.actions[0].supply[1].amount >
        state.actions[0].draw[1].amount + state.actions[3].draw[2].amount
    );
    _testScenario();
  }

  function precondition(Stage stage) internal override {
    super.precondition(stage);
    mockBaseBorrowRate(state.baseBorrowRate[t]);
  }

  function initialAssertions(Stage stage) internal override {
    super.initialAssertions(stage);

    if (stage == stages[0]) {
      // asset
      assertEq(
        assets[state.assetId].t_i[0].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't0_i Asset index'
      );
      assertEq(assets[state.assetId].t_i[0].baseDebt, 0, 't0_i Asset base debt');
      assertEq(
        assets[state.assetId].t_i[0].lastUpdateTimestamp,
        timeAt(stages[0]),
        't0_i Asset lastUpdateTimestamp'
      );
    } else if (stage == stages[1]) {
      // asset
      assertEq(
        assets[state.assetId].t_i[1].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't1_i Asset index'
      );
      assertEq(assets[state.assetId].t_i[1].baseDebt, 0, 't1_i Asset base debt');
      assertEq(
        assets[state.assetId].t_i[1].lastUpdateTimestamp,
        timeAt(stages[0]),
        't1_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_i[1].baseBorrowIndex, hub.DEFAULT_SPOKE_INDEX(), 't1_i Spoke1 index');
      assertEq(spokes[0].t_i[1].baseDebt, 0, 't1_i Spoke1 base debt');
      assertEq(spokes[0].t_i[1].lastUpdateTimestamp, 0, 't1_i Spoke1 lastUpdateTimestamp');
    } else if (stage == stages[2]) {
      // asset
      assertEq(
        assets[state.assetId].t_i[2].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't2_i Asset index'
      );
      assertEq(
        assets[state.assetId].t_i[2].baseDebt,
        spokes[0].actions.draw[1].amount,
        't2_i Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_i[2].lastUpdateTimestamp,
        timeAt(stages[1]),
        't2_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes[0].t_i[2].baseBorrowIndex,
        assets[state.assetId].t_i[2].baseBorrowIndex,
        't2_i Spoke1 index'
      );
      assertEq(spokes[0].t_i[2].baseDebt, spokes[0].t_f[1].baseDebt, 't2_i Spoke1 base debt');
      assertEq(
        spokes[0].t_i[2].lastUpdateTimestamp,
        timeAt(stages[1]),
        't2_i Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == stages[3]) {
      // asset
      assertEq(
        assets[state.assetId].t_i[3].baseBorrowIndex,
        assets[state.assetId].t_f[2].baseBorrowIndex,
        't3_i Asset index'
      );
      assertEq(
        assets[state.assetId].t_i[3].baseDebt,
        assets[state.assetId].t_f[2].baseDebt,
        't3_i Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_i[3].lastUpdateTimestamp,
        timeAt(stages[2]),
        't3_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_i[3].baseBorrowIndex, hub.DEFAULT_ASSET_INDEX(), 't3_i Spoke1 index');
      assertEq(
        spokes[0].t_i[3].baseDebt,
        spokes[0].actions.draw[1].amount,
        't3_i Spoke1 base debt'
      );
      assertEq(
        spokes[0].t_i[3].lastUpdateTimestamp,
        timeAt(stages[1]),
        't3_i Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[3].t_i[3].baseBorrowIndex,
        assets[state.assetId].t_i[3].baseBorrowIndex,
        't3_i Spoke4 index'
      );
      assertEq(
        spokes[3].t_i[3].baseDebt,
        spokes[3].actions.draw[2].amount,
        't3_i Spoke4 base debt'
      );
      assertEq(
        spokes[3].t_i[3].lastUpdateTimestamp,
        timeAt(stages[2]),
        't3_i Spoke4 lastUpdateTimestamp'
      );
    }
  }

  function exec(Stage stage) internal override {
    super.exec(stage);

    if (stage == stages[1]) {
      Utils.supply({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[0].addr,
        amount: spokes[0].actions.supply[t].amount,
        riskPremium: 0,
        user: bob,
        to: spokes[0].addr
      });
      Utils.draw({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[0].addr,
        amount: spokes[0].actions.draw[t].amount,
        riskPremium: 0,
        to: bob,
        onBehalfOf: spokes[0].addr
      });
    } else if (stage == stages[2]) {
      hub.addSpoke(state.assetId, spokeConfig, spokes[3].addr);
      Utils.draw({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[3].addr,
        amount: spokes[3].actions.draw[t].amount,
        riskPremium: 0,
        to: bob,
        onBehalfOf: spokes[3].addr
      });
    } else if (stage == stages[3]) {
      Utils.supply({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[3].addr,
        amount: spokes[3].actions.supply[t].amount,
        riskPremium: 0,
        user: bob,
        to: spokes[3].addr
      });
    }
  }

  function skipTime(Stage stage) internal override {
    super.skipTime(stage);
    skip(state.skipTime[t]);
  }

  function finalAssertions(Stage stage) internal override {
    super.finalAssertions(stage);

    if (stage == stages[0]) {
      // asset
      assertEq(
        assets[state.assetId].t_f[0].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't0_f Asset index'
      );
      assertEq(assets[state.assetId].t_f[0].baseDebt, 0, 't0_f Asset base debt');
      assertEq(
        assets[state.assetId].t_f[0].lastUpdateTimestamp,
        timeAt(stages[0]),
        't0_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_f[0].baseBorrowIndex, hub.DEFAULT_SPOKE_INDEX(), 't0_f Spoke1 index');
      assertEq(spokes[0].t_f[0].baseDebt, 0, 't0_f Spoke1 base debt');
      assertEq(spokes[0].t_f[0].lastUpdateTimestamp, 0, 't0_f Spoke1 lastUpdateTimestamp');
    } else if (stage == stages[1]) {
      // asset
      assertEq(
        assets[state.assetId].t_f[1].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't1_f Asset index'
      );
      assertEq(
        assets[state.assetId].t_f[1].baseDebt,
        spokes[0].actions.draw[1].amount,
        't1_f Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_f[1].lastUpdateTimestamp,
        timeAt(stages[1]),
        't1_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_f[1].baseBorrowIndex, hub.DEFAULT_ASSET_INDEX(), 't1_f Spoke1 index');
      assertEq(
        spokes[0].t_f[1].baseDebt,
        spokes[0].actions.draw[1].amount,
        't1_f Spoke1 base debt'
      );
      assertEq(
        spokes[0].t_f[1].lastUpdateTimestamp,
        timeAt(stages[1]),
        't1_f Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == stages[2]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t].baseBorrowRate,
        timeAt(stages[t - 1])
      );

      // asset
      assertEq(
        assets[state.assetId].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t - 1].baseBorrowIndex.rayMul(
          states.cumulatedBaseInterest.t_f[t]
        ),
        't2_f Asset index'
      );
      assertEq(
        assets[state.assetId].t_f[t].baseDebt,
        assets[state.assetId].t_f[t - 1].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]) +
          spokes[3].actions.draw[t].amount,
        't2_f Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't2_f Asset lastUpdateTimestamp'
      );

      // spoke1
      // no action, should be the same as t1
      assertEq(
        spokes[0].t_f[t].baseBorrowIndex,
        spokes[0].t_f[t - 1].baseBorrowIndex,
        't2_f Spoke1 index'
      );
      assertEq(spokes[0].t_f[t].baseDebt, spokes[0].t_f[t - 1].baseDebt, 't2_f Spoke1 base debt');
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        spokes[0].t_f[t - 1].lastUpdateTimestamp,
        't2_f Spoke1 lastUpdateTimestampt'
      );
      // spoke4
      assertEq(
        spokes[3].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't2_f Spoke4 index'
      );
      assertEq(
        spokes[3].t_f[t].baseDebt,
        spokes[3].actions.draw[t].amount,
        't2_f Spoke4 base debt'
      );
      assertEq(
        spokes[3].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't2_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == stages[3]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );

      // asset
      assertEq(
        assets[state.assetId].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t - 1].baseBorrowIndex.rayMul(
          states.cumulatedBaseInterest.t_f[t]
        ),
        't3_f Asset index'
      );
      assertApproxEqRel(
        assets[state.assetId].t_f[t].baseDebt,
        assets[state.assetId].t_f[t - 1].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]),
        expectedPrecision,
        't3_f Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't3_f Asset lastUpdateTimestamp'
      );

      // spoke1
      // no action, should be the same as t1
      assertEq(
        spokes[0].t_f[t].baseBorrowIndex,
        spokes[0].t_f[1].baseBorrowIndex,
        't3_f Spoke1 index'
      );
      assertEq(spokes[0].t_f[t].baseDebt, spokes[0].t_f[1].baseDebt, 't3_f Spoke1 base debt');
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        spokes[0].t_f[1].lastUpdateTimestamp,
        't3_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[3].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't3_f Spoke4 index'
      );
      assertApproxEqRel(
        spokes[3].t_f[t].baseDebt,
        spokes[3].t_f[t - 1].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]),
        expectedPrecision,
        't3_f Spoke4 base debt'
      );
      assertEq(
        spokes[3].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't3_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == stages[4]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );
    }
  }
}
