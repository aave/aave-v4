// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

type Stage is uint8;

function eq(Stage a, Stage b) pure returns (bool) {
  return Stage.unwrap(a) == Stage.unwrap(b);
}
using {eq as ==} for Stage global;

abstract contract LiquidityHubScenarioBaseTest is Base {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 internal constant NUM_TIMESTAMPS = 10;
  uint256 internal constant NUM_SPOKES = 4;
  uint256 internal constant NUM_ASSETS = 4;
  uint256 internal constant MAX_BOUNDED_AMOUNT = MAX_SUPPLY_AMOUNT / NUM_TIMESTAMPS;
  uint256 internal constant MIN_BOUNDED_AMOUNT = 1;
  bool internal isPrintLogs = false;
  uint256 internal t; // internal stage index

  uint256 internal constant SPOKE1_INDEX = 0;
  uint256 internal constant SPOKE2_INDEX = 1;
  uint256 internal constant SPOKE3_INDEX = 2;
  uint256 internal constant SPOKE4_INDEX = 3;

  struct TestState {
    uint256 assetId;
    uint256[NUM_TIMESTAMPS] baseBorrowRate;
    uint256[NUM_TIMESTAMPS] skipTime;
    SpokeActions[NUM_SPOKES] actions;
  }

  TestState internal state;
  DataTypes.SpokeConfig internal spokeConfig;
  Spoke internal spoke4; // init to be added during scenario tests

  // _i: initial, prior to action at a given time
  // _f: final, after action at a given time
  struct Timestamps {
    uint256[NUM_TIMESTAMPS] t_i;
    uint256[NUM_TIMESTAMPS] t_f;
  }

  struct SpokeDatas {
    DataTypes.SpokeData[NUM_TIMESTAMPS] t_i;
    DataTypes.SpokeData[NUM_TIMESTAMPS] t_f;
    address spokeAddress;
    SpokeActions actions;
  }

  struct AssetDatas {
    DataTypes.Asset[NUM_TIMESTAMPS] t_i;
    DataTypes.Asset[NUM_TIMESTAMPS] t_f;
  }

  struct CalculatedStates {
    Timestamps cumulatedBaseInterest;
    Timestamps cumulatedBaseDebt;
    Timestamps[NUM_SPOKES] cumulatedSpokeBaseDebt;
  }

  struct SpokeActions {
    SpokeAction[NUM_TIMESTAMPS] supply;
    SpokeAction[NUM_TIMESTAMPS] withdraw;
    SpokeAction[NUM_TIMESTAMPS] draw;
    SpokeAction[NUM_TIMESTAMPS] restore;
  }

  struct SpokeAction {
    uint256 amount;
    uint256 assetId;
  }

  uint256[] internal timestamps;
  AssetDatas[NUM_ASSETS] internal assets;
  SpokeDatas[NUM_SPOKES] internal spokes;
  Stage[NUM_TIMESTAMPS] internal stages;
  CalculatedStates internal states;

  function setUp() public virtual override {
    super.setUp();

    spokes[SPOKE1_INDEX].spokeAddress = address(spoke1);
    spokes[SPOKE2_INDEX].spokeAddress = address(spoke2);
    spokes[SPOKE3_INDEX].spokeAddress = address(spoke3);

    // init stages
    for (uint8 i = 0; i < NUM_TIMESTAMPS; i++) {
      stages[i] = Stage.wrap(i);
    }
    timestamps.push(vm.getBlockTimestamp());
  }

  // invoked once before the test scenario
  function preTestSetup() internal virtual {}

  // invoked on each time step
  function precondition(Stage stage) internal virtual {}
  function initialAssertions(Stage stage) internal virtual {}

  function printInitialLog(Stage stage) internal virtual {
    console.log(string.concat('----- t', vm.toString(t), '_i -----'));
  }
  function exec(Stage stage) internal virtual {}
  function finalAssertions(Stage stage) internal virtual {}
  function skipTime(Stage stage) internal virtual {}
  function postcondition(Stage stage) internal virtual {
    timestamps.push(vm.getBlockTimestamp());
  }
  function printFinalLog(Stage stage) internal virtual {
    console.log(string.concat('----- t', vm.toString(t), '_f -----'));
  }

  function _testScenario() internal virtual {
    Stage stage;

    preTestSetup();
    for (t = 0; t < NUM_TIMESTAMPS; t++) {
      stage = stages[t];
      precondition(stage);
      initialAssertions(stage);
      if (isPrintLogs) {
        printInitialLog(stage);
      }
      exec(stage);
      finalAssertions(stage);
      if (isPrintLogs) {
        printFinalLog(stage);
      }
      skipTime(stage);
      postcondition(stage);
    }
  }

  function timeAt(Stage stage) internal view returns (uint40) {
    return uint40(timestamps[uint256(Stage.unwrap(stage))]);
  }

  /// @param baseBorrowRate base borrow rate in bps
  function mockBaseBorrowRate(uint256 baseBorrowRate) internal {
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(baseBorrowRate.bpsToRay())
    );
  }

  // initialize state array for non-fuzz tests with constant skipTimes and borrowRates across actions
  function fillSkipTimeAndBaseBorrowRate(
    TestState storage state,
    uint256 time,
    uint256 borrowRate
  ) internal {
    for (uint256 i = 0; i < NUM_TIMESTAMPS; i++) {
      state.skipTime[i] = time;
      state.baseBorrowRate[i] = borrowRate;
    }
  }

  // TODO: bound fuzz states for riskPremium
  function boundFuzzStates(
    TestState storage state,
    TestState memory _state
  ) internal returns (uint256) {
    state.assetId = bound(_state.assetId, 0, NUM_ASSETS - 1);
    for (uint256 i = 0; i < NUM_TIMESTAMPS; i++) {
      state.baseBorrowRate[i] = bound(_state.baseBorrowRate[0], 0, MAX_BORROW_RATE);
      state.skipTime[i] = bound(_state.skipTime[0], 0, MAX_BORROW_RATE);

      for (uint256 j = 0; j < NUM_SPOKES; j++) {
        state.actions[j].supply[i].amount = bound(
          _state.actions[j].supply[i].amount,
          MIN_BOUNDED_AMOUNT,
          MAX_BOUNDED_AMOUNT
        );
        state.actions[j].draw[i].amount = bound(
          _state.actions[j].draw[i].amount,
          MIN_BOUNDED_AMOUNT,
          MAX_BOUNDED_AMOUNT
        );
        state.actions[j].withdraw[i].amount = bound(
          _state.actions[j].withdraw[i].amount,
          MIN_BOUNDED_AMOUNT,
          MAX_BOUNDED_AMOUNT
        );
        state.actions[j].restore[i].amount = bound(
          _state.actions[j].restore[i].amount,
          MIN_BOUNDED_AMOUNT,
          MAX_BOUNDED_AMOUNT
        );
      }
    }
  }
}
