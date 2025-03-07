// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/borrowIndex/BorrowIndexScenarioBase.t.sol';

contract BorrowIndex_Scenario1Test is BorrowIndexScenarioBaseTest {
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
    state.actions[SPOKE1_INDEX].supply[0].amount = 10e18;
    state.actions[SPOKE1_INDEX].draw[0].amount = 5e18;
    // time t1
    state.actions[SPOKE4_INDEX].supply[1].amount = 10e18;
    state.actions[SPOKE4_INDEX].draw[1].amount = 1e18;
    // time t2
    state.actions[SPOKE4_INDEX].supply[2].amount = 1e8;

    _testScenario();
  }

  // Assumptions:
  // - single assetId (fuzzed but does not vary from action to action)
  // - 0 risk premium
  function test_fuzz_borrowIndexScenario1(TestState memory _state) public {
    boundFuzzStates(state, _state);

    state.actions[SPOKE1_INDEX].draw[0].amount = bound(
      state.actions[SPOKE1_INDEX].draw[0].amount,
      MIN_BOUNDED_AMOUNT,
      MAX_BOUNDED_AMOUNT / 4
    );
    state.actions[SPOKE4_INDEX].draw[1].amount = bound(
      state.actions[SPOKE4_INDEX].draw[1].amount,
      MIN_BOUNDED_AMOUNT,
      MAX_BOUNDED_AMOUNT / 4
    );
    state.actions[SPOKE1_INDEX].supply[0].amount = bound(
      state.actions[SPOKE1_INDEX].supply[0].amount,
      (state.actions[SPOKE1_INDEX].draw[0].amount + state.actions[SPOKE4_INDEX].draw[1].amount) * 2, // to maintain 2x collateralization and buffer
      MAX_BOUNDED_AMOUNT
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
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].baseBorrowIndex,
        hub.DEFAULT_SPOKE_INDEX(),
        't0_i Spoke1 index'
      );
      assertEq(spokes[SPOKE1_INDEX].t_i[t].baseDebt, 0, 't0_i Spoke1 base debt');
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].lastUpdateTimestamp,
        0,
        't0_i Spoke1 lastUpdateTimestamp'
      );
    } else if (stage == stages[1]) {
      // asset
      assertEq(
        assets[state.assetId].t_i[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't1_i Asset index'
      );
      assertEq(
        assets[state.assetId].t_i[t].baseDebt,
        spokes[SPOKE1_INDEX].actions.draw[t - 1].amount,
        't1_i Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't1 Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].baseBorrowIndex,
        assets[state.assetId].t_i[t - 1].baseBorrowIndex,
        't1_i Spoke1 index'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].baseDebt,
        spokes[SPOKE1_INDEX].actions.draw[t - 1].amount,
        't1_i Spoke1 base debt'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].lastUpdateTimestamp,
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
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't2_i Spoke1 index'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].baseDebt,
        spokes[SPOKE1_INDEX].actions.draw[0].amount,
        't2_i Spoke1 base debt'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_i[t].lastUpdateTimestamp,
        timeAt(stages[0]),
        't2_i Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[SPOKE4_INDEX].t_i[t].baseBorrowIndex,
        assets[state.assetId].t_i[t].baseBorrowIndex,
        't2_i Spoke4 index'
      );
      assertEq(
        spokes[SPOKE4_INDEX].t_i[t].baseDebt,
        spokes[SPOKE4_INDEX].actions.draw[t - 1].amount,
        't2_i Spoke4 base debt'
      );
      assertEq(
        spokes[SPOKE4_INDEX].t_i[t].lastUpdateTimestamp,
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
    } else if (stage == stages[1]) {
      hub.addSpoke(state.assetId, spokeConfig, spokes[SPOKE4_INDEX].spokeAddress);
      vm.assume(
        hub.convertToShares(state.assetId, spokes[SPOKE4_INDEX].actions.supply[t].amount) > 0
      );
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
    } else if (stage == stages[2]) {
      vm.assume(
        hub.convertToShares(state.assetId, spokes[SPOKE4_INDEX].actions.supply[t].amount) > 0
      );
      Utils.supply({
        hub: hub,
        assetId: state.assetId,
        spoke: spokes[SPOKE4_INDEX].spokeAddress,
        amount: spokes[SPOKE4_INDEX].actions.supply[t].amount,
        riskPremium: 0,
        user: bob,
        to: spokes[SPOKE4_INDEX].spokeAddress
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
        spokes[SPOKE1_INDEX].actions.draw[t].amount,
        't0_f Asset base debt'
      );
      assertEq(
        assets[state.assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't0_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't0_f Spoke1 index'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].baseDebt,
        spokes[SPOKE1_INDEX].actions.draw[t].amount,
        't0_f Spoke1 base debt'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp,
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
        spokes[SPOKE1_INDEX].actions.draw[t - 1].amount.rayMul(
          states.cumulatedBaseInterest.t_f[t]
        ) + spokes[SPOKE4_INDEX].actions.draw[t].amount,
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
        spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex,
        spokes[SPOKE1_INDEX].t_f[t - 1].baseBorrowIndex,
        't1_f Spoke1 index'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].baseDebt,
        spokes[SPOKE1_INDEX].t_f[t - 1].baseDebt,
        't1_f Spoke1 base debt'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp,
        spokes[SPOKE1_INDEX].t_f[t - 1].lastUpdateTimestamp,
        't1_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't1_f Spoke4 index'
      );
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].baseDebt,
        spokes[SPOKE4_INDEX].actions.draw[t].amount,
        't1_f Spoke4 base debt'
      );
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].lastUpdateTimestamp,
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
      // only assert on expectedPrecision if the precision percentage is greater than 1 wei
      if (assets[state.assetId].t_f[t].baseDebt.wadMul(expectedPrecision) > 1) {
        assertApproxEqRel(
          assets[state.assetId].t_f[t].baseDebt,
          assets[state.assetId].t_f[t - 1].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]),
          expectedPrecision,
          't2_f Asset base debt'
        );
      } else {
        assertApproxEqAbs(
          assets[state.assetId].t_f[t].baseDebt,
          assets[state.assetId].t_f[t - 1].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]),
          1,
          't2_f Asset base debt'
        );
      }

      // spoke1
      // nothing changes vs t0 because no spoke1 action
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex,
        spokes[SPOKE1_INDEX].t_f[t - 2].baseBorrowIndex,
        't2_f Spoke1 index'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].baseDebt,
        spokes[SPOKE1_INDEX].t_f[t - 2].baseDebt,
        't2_f Spoke1 base debt'
      );
      assertEq(
        spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp,
        spokes[SPOKE1_INDEX].t_f[t - 2].lastUpdateTimestamp,
        't2_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].baseBorrowIndex,
        assets[state.assetId].t_f[t].baseBorrowIndex,
        't2_f Spoke4 index'
      );
      // only assert on expectedPrecision if the precision percentage is greater than 1 wei
      if (spokes[SPOKE4_INDEX].t_f[t].baseDebt.wadMul(expectedPrecision) > 1) {
        assertApproxEqRel(
          spokes[SPOKE4_INDEX].t_f[t].baseDebt,
          spokes[SPOKE4_INDEX].actions.draw[t - 1].amount.rayMul(
            states.cumulatedBaseInterest.t_f[t]
          ),
          expectedPrecision,
          't2_f Spoke4 base debt'
        );
      } else {
        assertApproxEqAbs(
          spokes[SPOKE4_INDEX].t_f[t].baseDebt,
          spokes[SPOKE4_INDEX].actions.draw[t - 1].amount.rayMul(
            states.cumulatedBaseInterest.t_f[t]
          ),
          1,
          't2_f Spoke4 base debt'
        );
      }
      assertEq(
        spokes[SPOKE4_INDEX].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't2_f Spoke4 lastUpdateTimestamp'
      );
    }
  }
}
