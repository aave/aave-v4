// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/borrowIndex/BorrowIndexBase.t.sol';

contract BorrowIndex_Scenario1Test is BorrowIndexBase {
  using WadRayMath for uint256;

  // Scenario:
  // t0: asset added, spoke1 added, spoke1 draws
  // t1: spoke4 is added; spoke4 supplies, spoke4 draws
  // t2: spoke4 trivial supply action to trigger accrual

  function setUp() public override {
    super.setUp();

    isPrintLogs = false;
  }

  // Assumptions:
  // - constant 10% IR
  // - 1 year between each action
  // - single asset (weth)
  // - 0 risk premium
  function test_borrowIndexScenario1() public {
    uint256 assetId = wethAssetId;

    state.assetId = assetId;
    fillSkipTimeAndBaseBorrowRate(state, 365 days, 10_00);
    // time t0
    state.actions[spoke1Index].supply[0].amount = 10e18;
    state.actions[spoke1Index].draw[0].amount = 5e18;
    // time t1
    state.actions[spoke4Index].supply[1].amount = 10e18;
    state.actions[spoke4Index].draw[1].amount = 1e18;
    // time t2
    state.actions[spoke4Index].supply[2].amount = 1e8;

    _testScenario();
  }

  // Assumptions:
  // - single assetId (fuzzed but does not vary from action to action)
  // - 0 risk premium
  function test_fuzz_borrowIndexScenario1(TestState memory _state) public {
    boundFuzzStates(state, _state);
    vm.assume(
      state.actions[0].supply[0].amount >
        state.actions[0].draw[0].amount + state.actions[3].draw[1].amount
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
        assets[state.assetId].t_i[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't0_i Asset index'
      );
      assertEq(assets[state.assetId].t_i[t].baseDebt, 0, 't0_i Asset base debt');
      assertEq(
        assets[state.assetId].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't0_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_i[t].baseBorrowIndex, hub.DEFAULT_SPOKE_INDEX(), 't0_i Spoke1 index');
      assertEq(spokes[0].t_i[t].baseDebt, 0, 't0_i Spoke1 base debt');
      assertEq(spokes[0].t_i[t].lastUpdateTimestamp, 0, 't0_i Spoke1 lastUpdateTimestamp');
    } else if (stage == stages[1]) {
      // asset
      assertEq(
        assets[state.assetId].t_i[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't1_i Asset index'
      );
      assertEq(
        assets[state.assetId].t_i[t].baseDebt,
        spokes[0].actions.draw[t - 1].amount,
        't1_i Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't1 Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes[0].t_i[t].baseBorrowIndex,
        assets[state.assetId].t_i[t - 1].baseBorrowIndex,
        't1_i Spoke1 index'
      );
      assertEq(
        spokes[0].t_i[t].baseDebt,
        spokes[0].actions.draw[t - 1].amount,
        't1_i Spoke1 base debt'
      );
      assertEq(
        spokes[0].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't1_i Spoke1 lastUpdateTimestamp'
      );
      // no spoke4 yet
    } else if (stage == stages[2]) {
      // asset
      assertEq(
        assets[state.assetId].t_i[t].baseBorrowIndex,
        assets[state.assetId].t_f[t - 1].baseBorrowIndex,
        't2_i Asset index'
      );
      assertEq(
        assets[state.assetId].t_i[t].baseDebt,
        assets[state.assetId].t_f[t - 1].baseDebt,
        't2_i Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't2_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_i[t].baseBorrowIndex, hub.DEFAULT_ASSET_INDEX(), 't2_i Spoke1 index');
      assertEq(
        spokes[0].t_i[t].baseDebt,
        spokes[0].actions.draw[0].amount,
        't2_i Spoke1 base debt'
      );
      assertEq(
        spokes[0].t_i[t].lastUpdateTimestamp,
        timeAt(stages[0]),
        't2_i Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[3].t_i[t].baseBorrowIndex,
        assets[state.assetId].t_i[t].baseBorrowIndex,
        't2_i Spoke4 index'
      );
      assertEq(
        spokes[3].t_i[t].baseDebt,
        spokes[3].actions.draw[t - 1].amount,
        't2_i Spoke4 base debt'
      );
      assertEq(
        spokes[3].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't2_i Spoke4 lastUpdateTimestamp'
      );
    }
  }

  function exec(Stage stage) internal override {
    super.exec(stage);

    if (stage == stages[0]) {
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
    } else if (stage == stages[1]) {
      hub.addSpoke(state.assetId, spokeConfig, spokes[3].addr);
      Utils.supply({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[3].addr,
        amount: spokes[3].actions.supply[t].amount,
        riskPremium: 0,
        user: bob,
        to: spokes[3].addr
      });
      Utils.draw({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[3].addr,
        amount: spokes[3].actions.draw[t].amount,
        riskPremium: 0,
        to: bob,
        onBehalfOf: spokes[3].addr
      });
    } else if (stage == stages[2]) {
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
        assets[state.assetId].t_f[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't0_f Asset index'
      );
      assertEq(
        assets[state.assetId].t_f[t].baseDebt,
        spokes[0].actions.draw[t].amount,
        't0_f Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't0_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_f[t].baseBorrowIndex, hub.DEFAULT_ASSET_INDEX(), 't0_f Spoke1 index');
      assertEq(
        spokes[0].t_f[t].baseDebt,
        spokes[0].actions.draw[t].amount,
        't0_f Spoke1 base debt'
      );
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't0_f Spoke1 lastUpdateTimestamp'
      );
      // no spoke4 yet
    } else if (stage == stages[1]) {
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
        't1_f Asset index'
      );
      assertApproxEqRel(
        assets[state.assetId].t_f[t].baseDebt,
        spokes[0].actions.draw[t - 1].amount.rayMul(states.cumulatedBaseInterest.t_f[t]) +
          spokes[3].actions.draw[t].amount,
        expectedPrecision,
        't1_f Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't1_f Asset lastUpdateTimestamp'
      );

      // spoke1
      // nothing changes vs t0 because no spoke1 action
      assertEq(
        spokes[0].t_f[t].baseBorrowIndex,
        spokes[0].t_f[t - 1].baseBorrowIndex,
        't1_f Spoke1 index'
      );
      assertEq(spokes[0].t_f[t].baseDebt, spokes[0].t_f[t - 1].baseDebt, 't1_f Spoke1 base debt');
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        spokes[0].t_f[t - 1].lastUpdateTimestamp,
        't1_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[3].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't1_f Spoke4 index'
      );
      assertEq(
        spokes[3].t_f[t].baseDebt,
        spokes[3].actions.draw[t].amount,
        't1_f Spoke4 base debt'
      );
      assertEq(
        spokes[3].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't1_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == stages[2]) {
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
        't2_f Asset index'
      );
      assertApproxEqRel(
        assets[state.assetId].t_f[t].baseDebt,
        assets[state.assetId].t_f[t - 1].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]),
        expectedPrecision,
        't2_f Asset base debt'
      );

      // spoke1
      // nothing changes vs t0 because no spoke1 action
      assertEq(
        spokes[0].t_f[t].baseBorrowIndex,
        spokes[0].t_f[t - 2].baseBorrowIndex,
        't2_f Spoke1 index'
      );
      assertEq(spokes[0].t_f[t].baseDebt, spokes[0].t_f[t - 2].baseDebt, 't2_f Spoke1 base debt');
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        spokes[0].t_f[t - 2].lastUpdateTimestamp,
        't2_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[3].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't2_f Spoke4 index'
      );
      assertApproxEqRel(
        spokes[3].t_f[t].baseDebt,
        spokes[3].actions.draw[t - 1].amount.rayMul(states.cumulatedBaseInterest.t_f[t]),
        expectedPrecision,
        't2_f Spoke4 base debt'
      );
      assertEq(
        spokes[3].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't2_f Spoke4 lastUpdateTimestamp'
      );
    }
  }
}
