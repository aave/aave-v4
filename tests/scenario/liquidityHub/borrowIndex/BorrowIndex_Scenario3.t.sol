// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/borrowIndex/BorrowIndexScenarioBase.t.sol';

contract BorrowIndex_Scenario3Test is BorrowIndexScenarioBaseTest {
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
    state.actions[SPOKE1_INDEX].supply[1].amount = 10e18;
    state.actions[SPOKE1_INDEX].draw[1].amount = 5e18;
    // time t3
    state.actions[SPOKE4_INDEX].supply[3].amount = 10e18;
    state.actions[SPOKE4_INDEX].draw[3].amount = 1e18;
    // time t4
    state.actions[SPOKE4_INDEX].supply[4].amount = 1e8;
    // time t8
    state.actions[SPOKE1_INDEX].supply[8].amount = 2e18;

    _testScenario();
  }

  // Assumptions:
  // - single assetId (fuzzed but does not vary from action to action)
  // - 0 risk premium
  function test_fuzz_borrowIndexScenario3(TestState memory _state) public {
    // see scenario4 for failing edge case where sum of spoke debt can exceed asset debt
    vm.skip(true, 'pending resolution of precision/rounding/shares impl');
    boundFuzzStates(state, _state);
    state.actions[SPOKE1_INDEX].draw[1].amount = bound(
      state.actions[SPOKE1_INDEX].draw[1].amount,
      MIN_BOUNDED_AMOUNT,
      MAX_BOUNDED_AMOUNT / 4
    );
    state.actions[SPOKE4_INDEX].draw[3].amount = bound(
      state.actions[SPOKE4_INDEX].draw[3].amount,
      MIN_BOUNDED_AMOUNT,
      MAX_BOUNDED_AMOUNT / 4
    );
    state.actions[SPOKE1_INDEX].supply[1].amount = bound(
      state.actions[SPOKE1_INDEX].supply[1].amount,
      (state.actions[SPOKE1_INDEX].draw[1].amount + state.actions[SPOKE4_INDEX].draw[3].amount) * 2, // to maintain 2x collateralization and buffer
      MAX_BOUNDED_AMOUNT
    );
    _testScenario();
  }

  function precondition(Stage stage) internal override {
    super.precondition(stage);
    mockBaseBorrowRate(state.baseBorrowRate[t]);

    if (stage == stages[5]) {
      // TODO: use max amount when implemented
      // spokes[SPOKE1_INDEX].actions.restore.t_i[5] = type(uint256).max;
      states.cumulatedBaseInterest.t_i[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );
      states.cumulatedSpokeBaseDebt[SPOKE1_INDEX].t_i[t] = states
        .cumulatedSpokeBaseDebt[SPOKE1_INDEX]
        .t_f[t - 1]
        .rayMul(states.cumulatedBaseInterest.t_i[t]);
      spokes[SPOKE1_INDEX].actions.restore[t].amount = states
        .cumulatedSpokeBaseDebt[SPOKE1_INDEX]
        .t_i[t];
    } else if (stage == stages[6]) {
      // TODO: use max amount when implemented
      // spokes[SPOKE4_INDEX].actions.restore[t].amount = type(uint256).max;
      states.cumulatedBaseInterest.t_i[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );
      states.cumulatedSpokeBaseDebt[SPOKE4_INDEX].t_i[t] = states
        .cumulatedSpokeBaseDebt[SPOKE4_INDEX]
        .t_f[t - 1]
        .rayMul(states.cumulatedBaseInterest.t_i[t]);

      spokes[SPOKE4_INDEX].actions.restore[t].amount = states
        .cumulatedSpokeBaseDebt[SPOKE4_INDEX]
        .t_i[t];
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
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].baseBorrowIndex,
        hub.DEFAULT_SPOKE_INDEX(),
        't1_i Spoke1 index'
      );
      assertEq(spokes[SPOKE1_INDEX].t_i[t].baseDebt, 0, 't1_i Spoke1 base debt');
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].lastUpdateTimestamp,
        0,
        't1_i Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == stages[2]) {
      // asset
      assertEq(
        assets[state.assetId].t_i[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't2_i Asset index'
      );
      assertEq(
        assets[state.assetId].t_i[t].baseDebt,
        spokes[SPOKE1_INDEX].actions.draw[t - 1].amount,
        't2_i Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't2_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].baseBorrowIndex,
        assets[state.assetId].t_i[t].baseBorrowIndex,
        't2_i Spoke1 index'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].baseDebt,
        spokes[SPOKE1_INDEX].t_f[t - 1].baseDebt,
        't2_i Spoke1 base debt'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].lastUpdateTimestamp,
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
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't3_i Spoke1 index'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].baseDebt,
        spokes[SPOKE1_INDEX].actions.draw[1].amount,
        't3_i Spoke1 base debt'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].lastUpdateTimestamp,
        timeAt(stages[1]),
        't3_i Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      // spoke index is out of sync with asset index
      // because spoke index is set to asset's next borrow index
      assertNotEq(
        spokes[SPOKE4_INDEX].t_i[t].baseBorrowIndex,
        assets[state.assetId].t_i[t].baseBorrowIndex,
        't3_i Spoke4 index out of sync with asset index'
      );
      assertEq(
        spokes[SPOKE4_INDEX].t_i[t].baseBorrowIndex,
        spokes[SPOKE4_INDEX].t_f[t - 1].baseBorrowIndex,
        't3_i Spoke4 index'
      );
      assertEq(spokes[SPOKE4_INDEX].t_i[t].baseDebt, 0, 't3_i Spoke4 base debt');
      assertEq(
        spokes[SPOKE4_INDEX].t_i[t].lastUpdateTimestamp,
        spokes[SPOKE4_INDEX].t_f[t - 1].lastUpdateTimestamp,
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
        spoke: spokes[SPOKE1_INDEX].spokeAddress,
        amount: spokes[SPOKE1_INDEX].actions.supply[t].amount,
        riskPremium: 0,
        user: bob,
        to: spokes[SPOKE1_INDEX].spokeAddress
      });
      Utils.draw({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[SPOKE1_INDEX].spokeAddress,
        amount: spokes[SPOKE1_INDEX].actions.draw[t].amount,
        riskPremium: 0,
        to: bob,
        onBehalfOf: spokes[SPOKE1_INDEX].spokeAddress
      });
    } else if (stage == stages[2]) {
      hub.addSpoke(state.assetId, spokeConfig, spokes[SPOKE4_INDEX].spokeAddress);
    } else if (stage == stages[3]) {
      Utils.supply({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[SPOKE4_INDEX].spokeAddress,
        amount: spokes[SPOKE4_INDEX].actions.supply[t].amount,
        riskPremium: 0,
        user: bob,
        to: spokes[SPOKE4_INDEX].spokeAddress
      });
      Utils.draw({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[SPOKE4_INDEX].spokeAddress,
        amount: spokes[SPOKE4_INDEX].actions.draw[t].amount,
        riskPremium: 0,
        to: bob,
        onBehalfOf: spokes[SPOKE4_INDEX].spokeAddress
      });
    } else if (stage == stages[4]) {
      Utils.supply({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[SPOKE4_INDEX].spokeAddress,
        amount: spokes[SPOKE4_INDEX].actions.supply[t].amount,
        riskPremium: 0,
        user: bob,
        to: spokes[SPOKE4_INDEX].spokeAddress
      });
    } else if (stage == stages[5]) {
      Utils.restore({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[SPOKE1_INDEX].spokeAddress,
        amount: spokes[SPOKE1_INDEX].actions.restore[t].amount,
        riskPremium: 0,
        repayer: bob
      });
    } else if (stage == stages[6]) {
      Utils.restore({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[SPOKE4_INDEX].spokeAddress,
        amount: spokes[SPOKE4_INDEX].actions.restore[t].amount,
        riskPremium: 0,
        repayer: bob
      });
    } else if (stage == stages[8]) {
      Utils.supply({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[SPOKE1_INDEX].spokeAddress,
        amount: spokes[SPOKE1_INDEX].actions.supply[t].amount,
        riskPremium: 0,
        user: bob,
        to: spokes[SPOKE1_INDEX].spokeAddress
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
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex,
        hub.DEFAULT_SPOKE_INDEX(),
        't0_f Spoke1 index'
      );
      assertEq(spokes[SPOKE1_INDEX].t_f[t].baseDebt, 0, 't0_f Spoke1 base debt');
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp,
        0,
        't0_f Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == stages[1]) {
      // asset
      assertEq(
        assets[state.assetId].t_f[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't1_f Asset index'
      );
      assertEq(
        assets[state.assetId].t_f[t].baseDebt,
        spokes[SPOKE1_INDEX].actions.draw[t].amount,
        't1_f Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't1_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't1_f Spoke1 index'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].baseDebt,
        spokes[SPOKE1_INDEX].actions.draw[t].amount,
        't1_f Spoke1 base debt'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp,
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
        spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex,
        spokes[SPOKE1_INDEX].t_f[t - 1].baseBorrowIndex,
        't2_f Spoke1 index'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].baseDebt,
        spokes[SPOKE1_INDEX].t_f[t - 1].baseDebt,
        't2_f Spoke1 base debt'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp,
        spokes[SPOKE1_INDEX].t_f[t - 1].lastUpdateTimestamp,
        't2_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      // spoke index is out of sync with asset index on init
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].baseBorrowIndex,
        hub.DEFAULT_SPOKE_INDEX(),
        't2_f Spoke4 index out of sync with asset index'
      );
      assertEq(spokes[SPOKE4_INDEX].t_f[t].baseDebt, 0, 't2_f Spoke4 base debt');
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].lastUpdateTimestamp,
        0,
        't2_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == stages[3]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[1])
      );
      states.cumulatedSpokeBaseDebt[SPOKE1_INDEX].t_f[t] = spokes[SPOKE1_INDEX]
        .t_f[t]
        .baseDebt
        .rayMul(states.cumulatedBaseInterest.t_f[t]);

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
          spokes[SPOKE4_INDEX].actions.draw[t].amount,
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
        spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex,
        spokes[SPOKE1_INDEX].t_f[1].baseBorrowIndex,
        't3_f Spoke1 index'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].baseDebt,
        spokes[SPOKE1_INDEX].t_f[1].baseDebt,
        't3_f Spoke1 base debt'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp,
        spokes[SPOKE1_INDEX].t_f[1].lastUpdateTimestamp,
        't3_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't3_f Spoke4 index'
      );
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].baseDebt,
        spokes[SPOKE4_INDEX].actions.draw[t].amount,
        't3_f Spoke4 base debt'
      );
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't3_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == stages[4]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[SPOKE4_INDEX].baseBorrowRate,
        timeAt(stages[SPOKE4_INDEX])
      );
      states.cumulatedSpokeBaseDebt[SPOKE1_INDEX].t_f[t] = states
        .cumulatedSpokeBaseDebt[SPOKE1_INDEX]
        .t_f[t - 1]
        .rayMul(states.cumulatedBaseInterest.t_f[t]);
      states.cumulatedSpokeBaseDebt[SPOKE4_INDEX].t_f[t] = spokes[SPOKE4_INDEX]
        .t_f[t - 1]
        .baseDebt
        .rayMul(states.cumulatedBaseInterest.t_f[t - 1]);

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
        spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex,
        spokes[SPOKE1_INDEX].t_f[1].baseBorrowIndex,
        't4_f Spoke1 index'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].baseDebt,
        spokes[SPOKE1_INDEX].t_f[1].baseDebt,
        't4_f Spoke1 base debt'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp,
        spokes[SPOKE1_INDEX].t_f[1].lastUpdateTimestamp,
        't4_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't4_f Spoke4 index'
      );
      assertApproxEqRel(
        spokes[SPOKE4_INDEX].t_f[t].baseDebt,
        spokes[SPOKE4_INDEX].t_f[SPOKE4_INDEX].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]),
        expectedPrecision,
        't4_f Spoke4 base debt'
      );
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't4_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == stages[5]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );
      states.cumulatedSpokeBaseDebt[SPOKE4_INDEX].t_f[t] = spokes[SPOKE4_INDEX]
        .t_f[t - 1]
        .baseDebt
        .rayMul(states.cumulatedBaseInterest.t_f[t]);
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
          spokes[SPOKE1_INDEX].actions.restore[t].amount,
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
        spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't5_f Spoke1 index'
      );
      assertEq(spokes[SPOKE1_INDEX].t_f[t].baseDebt, 0, 't5_f Spoke1 base debt'); // debt fully repaid
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't5_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].baseBorrowIndex,
        spokes[SPOKE4_INDEX].t_f[4].baseBorrowIndex,
        't5_f Spoke4 index'
      );
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].baseDebt,
        spokes[SPOKE4_INDEX].t_f[t - 1].baseDebt,
        't5_f Spoke4 base debt'
      );
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].lastUpdateTimestamp,
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
        spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex,
        spokes[SPOKE1_INDEX].t_f[t - 1].baseBorrowIndex,
        't6_f Spoke1 index'
      );
      assertEq(spokes[SPOKE1_INDEX].t_f[t].baseDebt, 0, 't6_f Spoke1 base debt');
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't6_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't6_f Spoke4 index'
      );
      assertEq(spokes[SPOKE4_INDEX].t_f[t].baseDebt, 0, 't6_f Spoke4 base debt'); // debt fully repaid
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].lastUpdateTimestamp,
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
        spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't8_f Spoke1 index'
      );
      assertEq(spokes[SPOKE1_INDEX].t_f[t].baseDebt, 0, 't8_f Spoke1 base debt');
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't8_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      // index remains same since last action
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].baseBorrowIndex,
        spokes[SPOKE4_INDEX].t_f[t - 2].baseBorrowIndex,
        't8_f Spoke4 index'
      );
      assertEq(spokes[SPOKE4_INDEX].t_f[t].baseDebt, 0, 't8_f Spoke4 base debt');
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t - 2]),
        't8_f Spoke4 lastUpdateTimestamp'
      );
    }
  }
}
