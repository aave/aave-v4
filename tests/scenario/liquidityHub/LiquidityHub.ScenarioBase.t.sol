// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {Asset, SpokeData} from 'src/contracts/LiquidityHub.sol';

abstract contract LiquidityHubScenarioBaseTest is BaseTest {
  bool internal isPrintLogs = false;

  // t0_i: prior to action
  // t0_f: after action
  struct Timestamps {
    uint256 t0_i;
    uint256 t0_f;
    uint256 t1_i;
    uint256 t1_f;
    uint256 t2_i;
    uint256 t2_f;
    uint256 t3_i;
    uint256 t3_f;
    uint256 t4_i;
    uint256 t4_f;
    uint256 t5_i;
    uint256 t5_f;
    uint256 t6_i;
    uint256 t6_f;
    uint256 t7_i;
    uint256 t7_f;
    uint256 t8_i;
    uint256 t8_f;
    uint256 t9_i;
    uint256 t9_f;
  }

  struct SpokeDatas {
    SpokeData t0_i;
    SpokeData t0_f;
    SpokeData t1_i;
    SpokeData t1_f;
    SpokeData t2_i;
    SpokeData t2_f;
    SpokeData t3_i;
    SpokeData t3_f;
    SpokeData t4_i;
    SpokeData t4_f;
    SpokeData t5_i;
    SpokeData t5_f;
    SpokeData t6_i;
    SpokeData t6_f;
    SpokeData t7_i;
    SpokeData t7_f;
    SpokeData t8_i;
    SpokeData t8_f;
    SpokeData t9_i;
    SpokeData t9_f;
  }

  struct AssetDatas {
    Asset t0_i;
    Asset t0_f;
    Asset t1_i;
    Asset t1_f;
    Asset t2_i;
    Asset t2_f;
    Asset t3_i;
    Asset t3_f;
    Asset t4_i;
    Asset t4_f;
    Asset t5_i;
    Asset t5_f;
    Asset t6_i;
    Asset t6_f;
    Asset t7_i;
    Asset t7_f;
    Asset t8_i;
    Asset t8_f;
    Asset t9_i;
    Asset t9_f;
  }

  struct SpokeDataLocal {
    SpokeDatas spoke1;
    SpokeDatas spoke2;
    SpokeDatas spoke3;
    SpokeDatas spoke4;
  }

  struct AssetDataLocal {
    AssetDatas wethData;
    AssetDatas daiData;
    AssetDatas usdcData;
    AssetDatas wbtcData;
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

  // Timestamps internal timestamps;
  uint256[] internal timestamps;
  AssetDataLocal internal assets;
  SpokeDataLocal internal spokes;
  SpokeAmounts internal spoke1Amounts;
  SpokeAmounts internal spoke2Amounts;
  SpokeAmounts internal spoke3Amounts;
  SpokeAmounts internal spoke4Amounts;
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

  function testScenario() public virtual {
    Stages stage = Stages.t0;

    for (uint256 t = 0; t < 10; t++) {
      precondition(stage);
      initialAssertions(stage);
      if (isPrintLogs) {
        printInitialLog(stage);
      }
      exec(stage);
      finalAssertions(stage);
      skipTime(stage);
      postcondition(stage);
      if (isPrintLogs) {
        printFinalLog(stage);
      }
      stage = Stages(uint256(stage) + 1);
    }
  }
}
