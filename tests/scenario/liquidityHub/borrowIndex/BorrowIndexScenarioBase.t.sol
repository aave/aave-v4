// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/LiquidityHub.ScenarioBase.t.sol';

abstract contract BorrowIndexScenarioBaseTest is LiquidityHubScenarioBaseTest {
  uint256 internal constant expectedPrecision = 1e10; // 1e18 is 100%; 0.00000001%

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();
    spokeMintAndApprove();

    spokeConfig = DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max});
    spoke4 = new Spoke(address(hub), address(oracle)); // initialize spoke4 to be added during scenario tests
    spokes[SPOKE4_INDEX].spokeAddress = address(spoke4);
  }

  function preTestSetup() internal virtual override {
    super.preTestSetup();
    for (uint256 i = 0; i < NUM_SPOKES; i++) {
      spokes[i].actions = state.actions[i];
    }
  }

  function precondition(Stage stage) internal virtual override {
    super.precondition(stage);
  }
  function initialAssertions(Stage stage) internal virtual override {
    super.initialAssertions(stage);
    assets[state.assetId].t_i[t] = hub.getAsset(state.assetId);
    for (uint256 i = 0; i < NUM_SPOKES; i++) {
      spokes[i].t_i[t] = hub.getSpoke(state.assetId, spokes[i].spokeAddress);
    }
  }

  function finalAssertions(Stage stage) internal virtual override {
    super.finalAssertions(stage);
    assets[state.assetId].t_f[t] = hub.getAsset(state.assetId);
    for (uint256 i = 0; i < NUM_SPOKES; i++) {
      spokes[i].t_f[t] = hub.getSpoke(state.assetId, spokes[i].spokeAddress);
    }
  }

  function printInitialLog(Stage stage) internal virtual override {
    super.printInitialLog(stage);

    // Asset
    console.log('Asset borrow index %27e', assets[state.assetId].t_i[t].baseBorrowIndex);
    console.log('Asset base debt %e', assets[state.assetId].t_i[t].baseDebt);
    console.log('Asset last update timestamp', assets[state.assetId].t_i[t].lastUpdateTimestamp);

    // Spoke1
    console.log('Spoke1 borrow index %27e', spokes[SPOKE1_INDEX].t_i[t].baseBorrowIndex);
    console.log('Spoke1 base debt %e', spokes[SPOKE1_INDEX].t_i[t].baseDebt);
    console.log('Spoke1 last update timestamp', spokes[SPOKE1_INDEX].t_i[t].lastUpdateTimestamp);

    // Spoke4
    console.log('Spoke4 borrow index %27e', spokes[SPOKE4_INDEX].t_i[t].baseBorrowIndex);
    console.log('Spoke4 base debt %e', spokes[SPOKE4_INDEX].t_i[t].baseDebt);
    console.log('Spoke4 last update timestamp', spokes[SPOKE4_INDEX].t_i[t].lastUpdateTimestamp);
  }

  function printFinalLog(Stage stage) internal virtual override {
    super.printFinalLog(stage);

    // Asset
    console.log('Asset borrow index %27e', assets[state.assetId].t_f[t].baseBorrowIndex);
    console.log('Asset base debt %e', assets[state.assetId].t_f[t].baseDebt);
    console.log('Asset last update timestamp', assets[state.assetId].t_f[t].lastUpdateTimestamp);

    // Spoke1
    console.log('Spoke1 borrow index %27e', spokes[SPOKE1_INDEX].t_f[t].baseBorrowIndex);
    console.log('Spoke1 base debt %e', spokes[SPOKE1_INDEX].t_f[t].baseDebt);
    console.log('Spoke1 last update timestamp', spokes[SPOKE1_INDEX].t_f[t].lastUpdateTimestamp);

    // Spoke4
    console.log('Spoke4 borrow index %27e', spokes[SPOKE4_INDEX].t_f[t].baseBorrowIndex);
    console.log('Spoke4 base debt %e', spokes[SPOKE4_INDEX].t_f[t].baseDebt);
    console.log('Spoke4 last update timestamp', spokes[SPOKE4_INDEX].t_f[t].lastUpdateTimestamp);
  }
}
