// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/borrowIndex/BorrowIndexScenarioBase.t.sol';

// TODO: resolve after precision/rounding/shares impl
// and after LH tests are migrated to use getters instead of reading from storage baseDebt, outstandingPremium, etc.
// see https://github.com/aave/aave-v4/issues/195
contract BorrowIndex_Scenario4Test is BorrowIndexScenarioBaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  // Scenario: (duplicated from scenario3 but with failing edge case combinations of skip time/borrow rate)
  // t0	asset added, spoke1 added
  // t1	spoke1 supply, spoke1 draw
  // t2	spoke4 added
  // t3	spoke4 draw
  // t4	spoke4 supply
  // t5 spoke1 repay
  // t6 spoke4 repay

  function setUp() public override {
    super.setUp();
    isPrintLogs = false;

    // comment below to see failing test scenario (test_borrowIndexScenario4)
    vm.skip(true, 'pending resolution of precision/rounding/shares impl');
  }

  function test_borrowIndexScenario4() public {
    state.assetId = wethAssetId;
    // failing edge case combinations lead to scenarios where repay amounts are not clean/round numbers
    // fillSkipTimeAndBaseBorrowRate(state, 1 days, 10_00); // failing edge case combination
    fillSkipTimeAndBaseBorrowRate(state, 50 days, 1_00); // failing edge case combination

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
  /// forge-config: default.fuzz.runs = 100
  /// forge-config: default.fuzz.show-logs = true
  function test_fuzz_borrowIndexScenario4(TestState memory _state) public {
    vm.skip(true, 'pending resolution of precision/rounding/shares impl');
    boundFuzzStates(state, _state);
    vm.assume(
      state.actions[SPOKE1_INDEX].supply[1].amount >
        state.actions[SPOKE1_INDEX].draw[1].amount + state.actions[SPOKE4_INDEX].draw[3].amount
    );
    _testScenario();
  }

  function precondition(Stage stage) internal override {
    super.precondition(stage);
    mockBaseBorrowRate(state.baseBorrowRate[t]);

    if (stage == stages[5]) {
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

      uint256 sumSpokeDebt = hub.getSpokeCumulativeDebt(
        state.assetId,
        spokes[SPOKE1_INDEX].spokeAddress
      ) + hub.getSpokeCumulativeDebt(state.assetId, spokes[SPOKE4_INDEX].spokeAddress);
      console.log('time t5');
      console.log('sum of all spoke debt %e', sumSpokeDebt);
      console.log('asset cumulative debt %e', hub.getAssetCumulativeDebt(state.assetId));
      console.log(
        'sum of all spoke debt > asset debt?',
        sumSpokeDebt > hub.getAssetCumulativeDebt(state.assetId)
      );
    } else if (stage == stages[6]) {
      spokes[SPOKE4_INDEX].actions.restore[t].amount = hub.getSpokeCumulativeDebt(
        state.assetId,
        spokes[SPOKE4_INDEX].spokeAddress
      );
      uint256 sumSpokeDebt = hub.getSpokeCumulativeDebt(
        state.assetId,
        spokes[SPOKE1_INDEX].spokeAddress
      ) + hub.getSpokeCumulativeDebt(state.assetId, spokes[SPOKE4_INDEX].spokeAddress);
      console.log('time t6');
      console.log('sum of all spoke debt %e', sumSpokeDebt);
      console.log('asset cumulative debt %e', hub.getAssetCumulativeDebt(state.assetId));
      console.log(
        'sum of all spoke debt > asset debt?',
        sumSpokeDebt > hub.getAssetCumulativeDebt(state.assetId)
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
      // failing in this action during a restore for spoke4
      // in LH - spoke4's spoke.baseDebt > asset.baseDebt
      // in LH - reverts due to underflow on _updateRiskPremiumAndBaseDebt -> MathUtils.subtractFromWeightedAverage
      Utils.restore({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[SPOKE4_INDEX].spokeAddress,
        amount: spokes[SPOKE4_INDEX].actions.restore[t].amount,
        riskPremium: 0,
        repayer: bob
      });
    }
  }

  function skipTime(Stage stage) internal override {
    super.skipTime(stage);
    skip(state.skipTime[t]);
  }

  function finalAssertions(Stage stage) internal override {
    super.finalAssertions(stage);

    if (stage == stages[2]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
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
    } else if (stage == stages[5]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );
      states.cumulatedSpokeBaseDebt[SPOKE4_INDEX].t_f[t] = spokes[SPOKE4_INDEX]
        .t_f[t - 1]
        .baseDebt
        .rayMul(states.cumulatedBaseInterest.t_f[t]);
    } else if (stage == stages[6]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );
    } else if (stage == stages[8]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 2])
      );
    }
  }
}
