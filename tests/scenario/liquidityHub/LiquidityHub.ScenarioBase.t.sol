// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

abstract contract LiquidityHubScenarioBase is Base {
  uint256 internal constant NUM_TIMESTAMPS = 10;
  uint256 internal constant NUM_SPOKES = 4;
  uint256 internal constant NUM_ASSETS = 4;
  bool internal isPrintLogs = false;

  // _i: initial, prior to action at a given time
  // _f: final, after action at a given time
  struct Timestamps {
    uint256[NUM_TIMESTAMPS] t_i;
    uint256[NUM_TIMESTAMPS] t_f;
  }

  struct SpokeDatas {
    DataTypes.SpokeData[NUM_TIMESTAMPS] t_i;
    DataTypes.SpokeData[NUM_TIMESTAMPS] t_f;
  }

  struct AssetDatas {
    DataTypes.Asset[NUM_TIMESTAMPS] t_i;
    DataTypes.Asset[NUM_TIMESTAMPS] t_f;
  }

  struct CalculatedStates {
    Timestamps cumulatedBaseInterest;
  }

  struct SpokeAmounts {
    Timestamps supply;
    Timestamps withdraw;
    Timestamps draw;
    Timestamps restore;
  }

  struct SpokeActionAssetIds {
    Timestamps supplyAssetId;
    Timestamps withdrawAssetId;
    Timestamps drawAssetId;
    Timestamps restoreAssetId;
  }

  uint256[] internal timestamps;
  AssetDatas[NUM_ASSETS] internal assets;
  SpokeDatas[NUM_SPOKES] internal spokes;
  SpokeActionAssetIds[NUM_SPOKES] internal spokeActions;
  SpokeAmounts[NUM_SPOKES] internal spokeAmounts;
  CalculatedStates internal states;

  enum Stages {
    t0,
    t1,
    t2,
    t3,
    t4,
    t5,
    t6,
    t7,
    t8,
    t9,
    t10
  }

  function setUp() public virtual override {
    super.setUp();

    timestamps.push(vm.getBlockTimestamp());
  }
  function precondition(Stages stage) internal virtual {}
  function initialAssertions(Stages stage) internal virtual {}

  function printInitialLog(Stages stage) internal virtual {}
  function exec(Stages stage) internal virtual {}
  function finalAssertions(Stages stage) internal virtual {}
  function skipTime(Stages stage) internal virtual {}
  function postcondition(Stages stage) internal virtual {
    timestamps.push(vm.getBlockTimestamp());
  }
  function printFinalLog(Stages stage) internal virtual {}

  function _testScenario() internal virtual {
    Stages stage = Stages.t0;

    for (uint256 t = 0; t < 10; t++) {
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

      stage = Stages(uint256(stage) + 1);
    }
  }

  function timeAt(Stages stage) internal view returns (uint40) {
    return uint40(timestamps[uint256(stage)]);
  }
}
