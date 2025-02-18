// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {Asset, SpokeData} from 'src/contracts/LiquidityHub.sol';

abstract contract LiquidityHubScenarioBaseTest is BaseTest {
  bool internal isPrintLogs = false;

  struct Timestamps {
    uint256 t0;
    uint256 t1;
    uint256 t2;
    uint256 t3;
    uint256 t4;
    uint256 t5;
    uint256 t6;
    uint256 t7;
    uint256 t8;
    uint256 t9;
  }

  struct SpokeDatas {
    SpokeData t0;
    SpokeData t1;
    SpokeData t2;
    SpokeData t3;
    SpokeData t4;
    SpokeData t5;
    SpokeData t6;
    SpokeData t7;
    SpokeData t8;
    SpokeData t9;
  }

  struct AssetDatas {
    Asset t0;
    Asset t1;
    Asset t2;
    Asset t3;
    Asset t4;
    Asset t5;
    Asset t6;
    Asset t7;
    Asset t8;
    Asset t9;
  }

  struct SpokeDataLocal {
    SpokeDatas spoke1;
    SpokeDatas spoke2;
    SpokeDatas spoke3;
    SpokeDatas spoke4;
  }

  // for either generic or specific asset data
  struct AssetDataLocal {
    AssetDatas assetData0;
    AssetDatas assetData1;
    AssetDatas assetData2;
    AssetDatas assetData3;
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

  struct SpokeActionAssetIds {
    Timestamps supplyAssetId;
    Timestamps withdrawAssetId;
    Timestamps drawAssetId;
    Timestamps restoreAssetId;
  }

  uint256[] internal timestamps;
  AssetDataLocal internal assets_i;
  AssetDataLocal internal assets_f;
  SpokeDataLocal internal spokes_i;
  SpokeDataLocal internal spokes_f;
  SpokeAmounts internal spoke1Amounts;
  SpokeActionAssetIds internal spoke1Actions;
  SpokeAmounts internal spoke2Amounts;
  SpokeActionAssetIds internal spoke2Actions;
  SpokeAmounts internal spoke3Amounts;
  SpokeActionAssetIds internal spoke3Actions;
  SpokeAmounts internal spoke4Amounts;
  SpokeActionAssetIds internal spoke4Actions;
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
