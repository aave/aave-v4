// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/borrowIndex/BorrowIndexBase.t.sol';

contract BorrowIndex_Scenario4Test is BorrowIndexBase {
  // TODO: resolve after precision/rounding/shares impl
  // and after LH tests are migrated to use getters instead of reading from storage baseDebt, outstandingPremium, etc.
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  // Scenario:
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

    vm.skip(true, 'pending resolution of precision/rounding/shares impl');
  }

  function test_borrowIndexScenario4() public {
    state.assetId = wethAssetId;
    // fillSkipTimeAndBaseBorrowRate(state, 1 days, 10_00); // failing edge case combination
    fillSkipTimeAndBaseBorrowRate(state, 50 days, 1_00); // failing edge case combination

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
  /// forge-config: default.fuzz.runs = 100
  /// forge-config: default.fuzz.show-logs = true
  function test_fuzz_borrowIndexScenario3(TestState memory _state) public {
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
      states.cumulatedBaseInterest.t_i[t] = MathUtils.calculateLinearInterest(
        assets[state.assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );
      states.cumulatedSpokeBaseDebt[0].t_i[t] = states.cumulatedSpokeBaseDebt[0].t_f[t - 1].rayMul(
        states.cumulatedBaseInterest.t_i[t]
      );
      spokes[0].actions.restore[t].amount = states.cumulatedSpokeBaseDebt[0].t_i[t];
    } else if (stage == stages[6]) {
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
      // failing in this action during a restore for spoke4
      // in LH - spoke4's spoke.baseDebt > asset.baseDebt
      // in LH - reverts due to _updateRiskPremiumAndBaseDebt -> MathUtils.subtractFromWeightedAverage
      Utils.restore({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[3].addr,
        amount: spokes[3].actions.restore[t].amount,
        riskPremium: 0,
        repayer: bob
      });
    }
  }

  function skipTime(Stage stage) internal override {
    super.skipTime(stage);
    skip(state.skipTime[t]);
  }
}
