// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/borrowIndex/BorrowIndexBase.t.sol';

contract BorrowIndex_Scenario3Test is BorrowIndexBase {
  using WadRayMath for uint256;

  // Scenario:
  // t0	asset added, spoke1 added
  // t1	spoke1 supply, spoke1 draw
  // t2	spoke4 added
  // t3	spoke4 supply, spoke4 draw
  // t4	spoke4 supply
  // t5 spoke1 repay
  // t6 spoke4 repay
  // t7
  // t8 spoke1 supply (check asset index)

  function setUp() public override {
    super.setUp();
    isPrintLogs = false;
  }

  // Assumptions:
  // - constant 10% IR
  // - 1 year between each action
  // - single asset (weth)
  // - 0 risk premium
  function test_borrowIndexScenario3() public {
    state.assetId = wethAssetId;
    fillSkipTimeAndBaseBorrowRate(state, 365 days, 10_00);
    // time t1
    state.actions[spoke1Index].supply[1].amount = 10e18;
    state.actions[spoke1Index].draw[1].amount = 5e18;
    // time t3
    state.actions[spoke4Index].supply[3].amount = 10e18;
    state.actions[spoke4Index].draw[3].amount = 1e18;
    // time t4
    state.actions[spoke4Index].supply[4].amount = 1e8;
    // time t8
    state.actions[spoke1Index].supply[8].amount = 2e18;

    _testScenario();
  }

  // Assumptions:
  // - single assetId (fuzzed but does not vary from action to action)
  // - 0 risk premium
  function fuzz_borrowIndexScenario3(TestState memory _state) public {
    vm.skip(true, 'pending resolution of precision/rounding/shares impl');
    boundFuzzStates(state, _state);
    vm.assume(
      state.actions[0].supply[1].amount >
        state.actions[0].draw[1].amount + state.actions[3].draw[3].amount
    );
    _testScenario();
  }

  function precondition(Stage stage) internal override {
    super.precondition(stage);
    mockBaseBorrowRate(state.baseBorrowRate[t]);

    if (stage == stages[5]) {
      // TODO: use max amount when implemented
      // spokes[0].actions.restore.t_i[5] = type(uint256).max;
      states.cumulatedBaseInterest.t_i[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );
      states.cumulatedSpokeBaseDebt[0].t_i[t] = states.cumulatedSpokeBaseDebt[0].t_f[t - 1].rayMul(
        states.cumulatedBaseInterest.t_i[t]
      );
      spokes[0].actions.restore[t].amount = states.cumulatedSpokeBaseDebt[0].t_i[t];
    } else if (stage == stages[6]) {
      // TODO: use max amount when implemented
      // spokes[3].actions.restore[t].amount = type(uint256).max;
      states.cumulatedBaseInterest.t_i[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );
      states.cumulatedSpokeBaseDebt[3].t_i[t] = states.cumulatedSpokeBaseDebt[3].t_f[t - 1].rayMul(
        states.cumulatedBaseInterest.t_i[t]
      );

      spokes[3].actions.restore[t].amount = states.cumulatedSpokeBaseDebt[3].t_i[t];
    }
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
    } else if (stage == stages[1]) {
      // asset
      assertEq(
        assets[state.assetId].t_i[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't1_i Asset index'
      );
      assertEq(assets[state.assetId].t_i[t].baseDebt, 0, 't1_i Asset base debt');
      assertEq(
        assets[state.assetId].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't1_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_i[t].baseBorrowIndex, hub.DEFAULT_SPOKE_INDEX(), 't1_i Spoke1 index');
      assertEq(spokes[0].t_i[t].baseDebt, 0, 't1_i Spoke1 base debt');
      assertEq(spokes[0].t_i[t].lastUpdateTimestamp, 0, 't1_i Spoke1 lastUpdateTimestamp');
    } else if (stage == stages[2]) {
      // asset
      assertEq(
        assets[state.assetId].t_i[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't2_i Asset index'
      );
      assertEq(
        assets[state.assetId].t_i[t].baseDebt,
        spokes[0].actions.draw[t - 1].amount,
        't2_i Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't2_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes[0].t_i[t].baseBorrowIndex,
        assets[state.assetId].t_i[t].baseBorrowIndex,
        't2_i Spoke1 index'
      );
      assertEq(spokes[0].t_i[t].baseDebt, spokes[0].t_f[t - 1].baseDebt, 't2_i Spoke1 base debt');
      assertEq(
        spokes[0].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't2_i Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == stages[3]) {
      // asset
      assertEq(
        assets[state.assetId].t_i[t].baseBorrowIndex,
        assets[state.assetId].t_f[t - 1].baseBorrowIndex,
        't3_i Asset index'
      );
      assertEq(
        assets[state.assetId].t_i[t].baseDebt,
        assets[state.assetId].t_f[t - 1].baseDebt,
        't3_i Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_i[t].lastUpdateTimestamp,
        timeAt(stages[1]),
        't3_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_i[t].baseBorrowIndex, hub.DEFAULT_ASSET_INDEX(), 't3_i Spoke1 index');
      assertEq(
        spokes[0].t_i[t].baseDebt,
        spokes[0].actions.draw[1].amount,
        't3_i Spoke1 base debt'
      );
      assertEq(
        spokes[0].t_i[t].lastUpdateTimestamp,
        timeAt(stages[1]),
        't3_i Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      // spoke index is out of sync with asset index
      // because spoke index is set to asset's next borrow index
      assertNotEq(
        spokes[3].t_i[t].baseBorrowIndex,
        assets[state.assetId].t_i[t].baseBorrowIndex,
        't3_i Spoke4 index out of sync with asset index'
      );
      assertEq(
        spokes[3].t_i[t].baseBorrowIndex,
        spokes[3].t_f[t - 1].baseBorrowIndex,
        't3_i Spoke4 index'
      );
      assertEq(spokes[3].t_i[t].baseDebt, 0, 't3_i Spoke4 base debt');
      assertEq(
        spokes[3].t_i[t].lastUpdateTimestamp,
        spokes[3].t_f[t - 1].lastUpdateTimestamp,
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
      Utils.draw({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[3].addr,
        amount: spokes[3].actions.draw[t].amount,
        riskPremium: 0,
        to: bob,
        onBehalfOf: spokes[3].addr
      });
    } else if (stage == stages[4]) {
      Utils.supply({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[3].addr,
        amount: spokes[3].actions.supply[t].amount,
        riskPremium: 0,
        user: bob,
        to: spokes[3].addr
      });
    } else if (stage == stages[5]) {
      Utils.restore({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[0].addr,
        amount: spokes[0].actions.restore[t].amount,
        riskPremium: 0,
        repayer: bob
      });
    } else if (stage == stages[6]) {
      Utils.restore({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[3].addr,
        amount: spokes[3].actions.restore[t].amount,
        riskPremium: 0,
        repayer: bob
      });
    } else if (stage == stages[8]) {
      Utils.supply({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[0].addr,
        amount: spokes[0].actions.supply[t].amount,
        riskPremium: 0,
        user: bob,
        to: spokes[0].addr
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
      assertEq(assets[state.assetId].t_f[t].baseDebt, 0, 't0_f Asset base debt');
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't0_f Asset base debt'
      );

      // spoke1
      assertEq(spokes[0].t_f[t].baseBorrowIndex, hub.DEFAULT_SPOKE_INDEX(), 't0_f Spoke1 index');
      assertEq(spokes[0].t_f[t].baseDebt, 0, 't0_f Spoke1 base debt');
      assertEq(spokes[0].t_f[t].lastUpdateTimestamp, 0, 't0_f Spoke1 lastUpdateTimestamp');
    } else if (stage == stages[1]) {
      // asset
      assertEq(
        assets[state.assetId].t_f[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't1_f Asset index'
      );
      assertEq(
        assets[state.assetId].t_f[t].baseDebt,
        spokes[0].actions.draw[t].amount,
        't1_f Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't1_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_f[t].baseBorrowIndex, hub.DEFAULT_ASSET_INDEX(), 't1_f Spoke1 index');
      assertEq(
        spokes[0].t_f[t].baseDebt,
        spokes[0].actions.draw[t].amount,
        't1_f Spoke1 base debt'
      );
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't1_f Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == stages[2]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );

      // asset
      assertEq(
        assets[state.assetId].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t - 1].baseBorrowIndex,
        't2_f Asset index'
      );
      assertEq(
        assets[state.assetId].t_f[t].baseDebt,
        assets[state.assetId].t_f[t - 1].baseDebt,
        't2_f Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
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
        't2_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      // spoke index is out of sync with asset index on init
      assertEq(
        spokes[3].t_f[t].baseBorrowIndex,
        hub.DEFAULT_SPOKE_INDEX(),
        't2_f Spoke4 index out of sync with asset index'
      );
      assertEq(spokes[3].t_f[t].baseDebt, 0, 't2_f Spoke4 base debt');
      assertEq(spokes[3].t_f[t].lastUpdateTimestamp, 0, 't2_f Spoke4 lastUpdateTimestamp');
    } else if (stage == stages[3]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[1])
      );
      states.cumulatedSpokeBaseDebt[0].t_f[t] = spokes[0].t_f[t].baseDebt.rayMul(
        states.cumulatedBaseInterest.t_f[t]
      );

      // asset
      assertEq(
        assets[state.assetId].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t - 1].baseBorrowIndex.rayMul(
          states.cumulatedBaseInterest.t_f[t]
        ),
        't3_f Asset index'
      );
      assertEq(
        assets[state.assetId].t_f[t].baseDebt,
        assets[state.assetId].t_f[t - 1].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]) +
          spokes[3].actions.draw[t].amount,
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
      assertEq(
        spokes[3].t_f[t].baseDebt,
        spokes[3].actions.draw[t].amount,
        't3_f Spoke4 base debt'
      );
      assertEq(
        spokes[3].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't3_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == stages[4]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[3].baseBorrowRate,
        timeAt(stages[3])
      );
      states.cumulatedSpokeBaseDebt[0].t_f[t] = states.cumulatedSpokeBaseDebt[0].t_f[t - 1].rayMul(
        states.cumulatedBaseInterest.t_f[t]
      );
      states.cumulatedSpokeBaseDebt[3].t_f[t] = spokes[3].t_f[t - 1].baseDebt.rayMul(
        states.cumulatedBaseInterest.t_f[t - 1]
      );

      // asset
      assertEq(
        assets[state.assetId].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t - 1].baseBorrowIndex.rayMul(
          states.cumulatedBaseInterest.t_f[t]
        ),
        't4_f Asset index'
      );
      assertApproxEqRel(
        assets[state.assetId].t_f[t].baseDebt,
        assets[state.assetId].t_f[t - 1].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]),
        expectedPrecision,
        't4_f Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't4_f Asset lastUpdateTimestamp'
      );

      // spoke1
      // no action, should be the same as t1
      assertEq(
        spokes[0].t_f[t].baseBorrowIndex,
        spokes[0].t_f[1].baseBorrowIndex,
        't4_f Spoke1 index'
      );
      assertEq(spokes[0].t_f[t].baseDebt, spokes[0].t_f[1].baseDebt, 't4_f Spoke1 base debt');
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        spokes[0].t_f[1].lastUpdateTimestamp,
        't4_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[3].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't4_f Spoke4 index'
      );
      assertApproxEqRel(
        spokes[3].t_f[t].baseDebt,
        spokes[3].t_f[3].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]),
        expectedPrecision,
        't4_f Spoke4 base debt'
      );
      assertEq(
        spokes[3].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't4_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == stages[5]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );
      states.cumulatedSpokeBaseDebt[3].t_f[t] = spokes[3].t_f[t - 1].baseDebt.rayMul(
        states.cumulatedBaseInterest.t_f[t]
      );
      // asset
      assertEq(
        assets[state.assetId].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t - 1].baseBorrowIndex.rayMul(
          states.cumulatedBaseInterest.t_f[t]
        ),
        't5_f Asset index'
      );
      assertApproxEqRel(
        assets[state.assetId].t_f[t].baseDebt,
        assets[state.assetId].t_f[t - 1].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]) -
          spokes[0].actions.restore[t].amount,
        expectedPrecision,
        't5_f Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't5_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes[0].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't5_f Spoke1 index'
      );
      assertEq(spokes[0].t_f[t].baseDebt, 0, 't5_f Spoke1 base debt'); // debt fully repaid
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't5_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[3].t_f[t].baseBorrowIndex,
        spokes[3].t_f[4].baseBorrowIndex,
        't5_f Spoke4 index'
      );
      assertEq(spokes[3].t_f[t].baseDebt, spokes[3].t_f[t - 1].baseDebt, 't5_f Spoke4 base debt');
      assertEq(
        spokes[3].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't5_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == stages[6]) {
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
        't6_f Asset index'
      );
      assertEq(assets[state.assetId].t_f[t].baseDebt, 0, 't6_f Asset base debt');
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't6_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes[0].t_f[t].baseBorrowIndex,
        spokes[0].t_f[t - 1].baseBorrowIndex,
        't6_f Spoke1 index'
      );
      assertEq(spokes[0].t_f[t].baseDebt, 0, 't6_f Spoke1 base debt');
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't6_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[3].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't6_f Spoke4 index'
      );
      assertEq(spokes[3].t_f[t].baseDebt, 0, 't6_f Spoke4 base debt'); // debt fully repaid
      assertEq(
        spokes[3].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't6_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == stages[8]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 2])
      );
      // asset
      // asset index continues growing
      assertEq(
        assets[state.assetId].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t - 2].baseBorrowIndex.rayMul(
          states.cumulatedBaseInterest.t_f[t]
        ), // 2 years worth of accumulation since last action
        't8_f Asset index'
      );
      assertEq(assets[state.assetId].t_f[t].baseDebt, 0, 't8_f Asset base debt');
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't8_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes[0].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't8_f Spoke1 index'
      );
      assertEq(spokes[0].t_f[t].baseDebt, 0, 't8_f Spoke1 base debt');
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't8_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      // index remains same since last action
      assertEq(
        spokes[3].t_f[t].baseBorrowIndex,
        spokes[3].t_f[t - 2].baseBorrowIndex,
        't8_f Spoke4 index'
      );
      assertEq(spokes[3].t_f[t].baseDebt, 0, 't8_f Spoke4 base debt');
      assertEq(
        spokes[3].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t - 2]),
        't8_f Spoke4 lastUpdateTimestamp'
      );
    }
  }
}
