// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/LiquidityHub.ScenarioBase.t.sol';
import {SpokeData} from 'src/contracts/LiquidityHub.sol';
import {Asset} from 'src/contracts/LiquidityHub.sol';
import {Utils} from 'tests/Utils.t.sol';

contract BorrowIndex_Scenario4Test is LiquidityHubScenarioBaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  DataTypes.SpokeConfig internal spokeConfig;
  Spoke internal spoke4;

  uint256 internal constant INIT_INDEX = WadRayMath.RAY;

  // Scenario:
  // t0	asset added, spoke1 added, spoke1 draw
  // t1	spoke1 supply; add spoke4
  // t2	spoke1 supply
  // t3	spoke4 draw
  // t4	spoke4 supply

  // Assumptions:
  // - constant 10% IR
  // - 1 year between each action

  function setUp() public override {
    super.setUp();
    initEnvironment();
    spokeMintAndApprove();

    spokeConfig = DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max});

    // Mock constant 10% IR
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(10_00).bpsToRay())
    );
    spoke4 = new Spoke(address(hub), address(oracle));

    isPrintLogs = true;
  }

  function precondition(Stages stage) internal override {
    super.precondition(stage);

    if (stage == Stages.t0) {
      spoke1Amounts.supply.t0_i = 10e18;
      spoke1Amounts.draw.t0_i = 5e18;
    } else if (stage == Stages.t1) {
      spoke1Amounts.supply.t1_i = 1e18;
    } else if (stage == Stages.t2) {
      spoke1Amounts.supply.t2_i = 1e18;
    } else if (stage == Stages.t3) {
      spoke4Amounts.draw.t3_i = 3e18;
    } else if (stage == Stages.t4) {
      spoke4Amounts.supply.t4_i = 1e18;
    }
  }

  function initialAssertions(Stages stage) internal override {
    super.initialAssertions(stage);

    if (stage == Stages.t0) {} else if (stage == Stages.t2) {} else if (stage == Stages.t3) {}
  }

  function exec(Stages stage) internal override {
    super.exec(stage);

    if (stage == Stages.t0) {
      Utils.supply({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke1),
        amount: spoke1Amounts.supply.t0_i,
        riskPremiumRad: 0,
        user: bob,
        to: address(spoke1)
      });
      Utils.draw({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke1),
        amount: spoke1Amounts.draw.t0_i,
        riskPremiumRad: 0,
        to: bob,
        onBehalfOf: address(spoke1)
      });
    } else if (stage == Stages.t1) {
      Utils.supply({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke1),
        amount: spoke1Amounts.supply.t1_i,
        riskPremiumRad: 0,
        user: bob,
        to: address(spoke1)
      });
      hub.addSpoke(wethAssetId, spokeConfig, address(spoke4));
    } else if (stage == Stages.t2) {
      Utils.supply({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke1),
        amount: spoke1Amounts.supply.t2_i,
        riskPremiumRad: 0,
        user: bob,
        to: address(spoke1)
      });
    } else if (stage == Stages.t3) {
      Utils.draw({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke4),
        amount: spoke4Amounts.draw.t3_i,
        riskPremiumRad: 0,
        to: bob,
        onBehalfOf: address(spoke4)
      });
    } else if (stage == Stages.t4) {
      Utils.supply({
        hub: hub,
        assetId: wethAssetId,
        spoke: address(spoke4),
        amount: spoke4Amounts.supply.t4_i,
        riskPremiumRad: 0,
        user: bob,
        to: address(spoke4)
      });
    }
  }

  function skipTime(Stages stage) internal override {
    super.skipTime(stage);
    skip(365 days);
  }

  function finalAssertions(Stages stage) internal override {
    if (stage == Stages.t0) {} else if (stage == Stages.t1) {} else if (
      stage == Stages.t2
    ) {} else if (stage == Stages.t3) {
      assets.wethData.t3_f = hub.getAsset(wethAssetId);
      spokes.spoke1.t3_f = hub.getSpoke(wethAssetId, address(spoke1));
      spokes.spoke4.t3_f = hub.getSpoke(wethAssetId, address(spoke4));
    } else if (stage == Stages.t4) {
      assets.wethData.t4_f = hub.getAsset(wethAssetId);
      spokes.spoke1.t4_f = hub.getSpoke(wethAssetId, address(spoke1));
      spokes.spoke4.t4_f = hub.getSpoke(wethAssetId, address(spoke4));
      states.cumulatedBaseInterest.t4_f = MathUtils.calculateLinearInterest(
        assets.wethData.t3_f.baseBorrowRate,
        uint40(timeAt(Stages.t3))
      );

      // // asset
      // assertEq(
      //   assets.wethData.t4_f.baseBorrowIndex,
      //   assets.wethData.t3_f.baseBorrowIndex.rayMul(states.cumulatedBaseInterest.t4_f),
      //   't4_f Asset index'
      // );
      // assertEq(
      //   assets.wethData.t4_f.baseDebt,
      //   assets.wethData.t3_f.baseDebt.rayMul(states.cumulatedBaseInterest.t4_f),
      //   't4_f Asset base debt'
      // );
      // assertEq(
      //   assets.wethData.t4_f.lastUpdateTimestamp,
      //   timeAt(Stages.t4),
      //   't4_f Asset lastUpdateTimestamp'
      // );

      // // spoke4
      // assertEq(
      //   spokes.spoke4.t4_f.baseBorrowIndex,
      //   assets.wethData.t4_f.baseBorrowIndex,
      //   't4_f Spoke4 index'
      // );
      // assertEq(
      //   spokes.spoke4.t4_f.baseDebt,
      //   spokes.spoke4.t3_f.baseDebt.rayMul(states.cumulatedBaseInterest.t4_f),
      //   't4_f Spoke4 base debt'
      // );
      // assertEq(
      //   spokes.spoke4.t4_f.lastUpdateTimestamp,
      //   timeAt(Stages.t4),
      //   't4_f Spoke4 lastUpdateTimestamp'
      // );
    }
  }

  function printInitialLog(Stages stage) internal override {
    if (stage == Stages.t0) {
      // console.log('----- t0_i -----');
      // // asset
      // console.log('Asset borrow index %e', assets.wethData.t0_i.baseBorrowIndex);
      // console.log('Asset base debt %e', assets.wethData.t0_i.baseDebt);
      // console.log('Asset last update timestamp', assets.wethData.t0_i.lastUpdateTimestamp);
      // console.log('no Spoke4 yet');
    } else if (stage == Stages.t1) {
      // console.log('----- t1_i -----');
      // // asset
      // console.log('Asset borrow index %e', assets.wethData.t1_i.baseBorrowIndex);
      // console.log('Asset base debt %e', assets.wethData.t1_i.baseDebt);
      // console.log('Asset last update timestamp', assets.wethData.t1_i.lastUpdateTimestamp);
      // // spoke1
      // console.log('Spoke1 borrow index %e', spokes.spoke1.t1_i.baseBorrowIndex);
      // console.log('Spoke1 base debt %e', spokes.spoke1.t1_i.baseDebt);
      // console.log('Spoke1 last update timestamp', spokes.spoke1.t1_i.lastUpdateTimestamp);
      // console.log('no Spoke4 yet');
    } else if (stage == Stages.t2) {
      // console.log('----- t2_i -----');
      // // asset
      // console.log('Asset borrow index %e', assets.wethData.t2_i.baseBorrowIndex);
      // console.log('Asset base debt %e', assets.wethData.t2_i.baseDebt);
      // console.log('Asset last update timestamp', assets.wethData.t2_i.lastUpdateTimestamp);
      // // spoke1
      // console.log('Spoke1 borrow index %e', spokes.spoke1.t2_i.baseBorrowIndex);
      // console.log('Spoke1 base debt %e', spokes.spoke1.t2_i.baseDebt);
      // console.log('Spoke1 last update timestamp', spokes.spoke1.t2_i.lastUpdateTimestamp);
      // console.log('no Spoke4 yet');
    } else if (stage == Stages.t3) {
      // console.log('----- t3_i -----');
      // // asset
      // console.log('Asset borrow index %e', assets.wethData.t3_i.baseBorrowIndex);
      // console.log('Asset base debt %e', assets.wethData.t3_i.baseDebt);
      // console.log('Asset last update timestamp', assets.wethData.t3_i.lastUpdateTimestamp);
      // // spoke1
      // console.log('Spoke1 borrow index %e', spokes.spoke1.t3_i.baseBorrowIndex);
      // console.log('Spoke1 base debt %e', spokes.spoke1.t3_i.baseDebt);
      // console.log('Spoke1 last update timestamp', spokes.spoke1.t3_i.lastUpdateTimestamp);
      // // spoke4
      // console.log('Spoke4 borrow index %e', spokes.spoke4.t3_i.baseBorrowIndex);
      // console.log('Spoke4 base debt %e', spokes.spoke4.t3_i.baseDebt);
      // console.log('Spoke4 last update timestamp', spokes.spoke4.t3_i.lastUpdateTimestamp);
    }
  }

  function printFinalLog(Stages stage) internal override {
    if (stage == Stages.t0) {
      // console.log('----- t0_f -----');
      // // asset
      // console.log('Asset borrow index %e', assets.wethData.t0_f.baseBorrowIndex);
      // console.log('Asset base debt %e', assets.wethData.t0_f.baseDebt);
      // console.log('Asset last update timestamp', assets.wethData.t0_f.lastUpdateTimestamp);
      // // spoke1
      // console.log('Spoke1 borrow index %e', spokes.spoke1.t0_f.baseBorrowIndex);
      // console.log('Spoke1 base debt %e', spokes.spoke1.t0_f.baseDebt);
      // console.log('Spoke1 last update timestamp', spokes.spoke1.t0_f.lastUpdateTimestamp);
      // console.log('no Spoke4 yet');
    } else if (stage == Stages.t1) {
      // console.log('----- t1_f -----');
      // // asset
      // console.log('Asset borrow index %e', assets.wethData.t1_f.baseBorrowIndex);
      // console.log('Asset base debt %e', assets.wethData.t1_f.baseDebt);
      // console.log('Asset last update timestamp', assets.wethData.t1_f.lastUpdateTimestamp);
      // // spoke1
      // console.log('Spoke1 borrow index %e', spokes.spoke1.t1_f.baseBorrowIndex);
      // console.log('Spoke1 base debt %e', spokes.spoke1.t1_f.baseDebt);
      // console.log('Spoke1 last update timestamp', spokes.spoke1.t1_f.lastUpdateTimestamp);
      // console.log('no Spoke4 yet');
    } else if (stage == Stages.t2) {
      // console.log('----- t2_f -----');
      // // asset
      // console.log('Asset borrow index %e', assets.wethData.t2_f.baseBorrowIndex);
      // console.log('Asset base debt %e', assets.wethData.t2_f.baseDebt);
      // console.log('Asset last update timestamp', assets.wethData.t2_f.lastUpdateTimestamp);
      // // spoke1
      // console.log('Spoke1 borrow index %e', spokes.spoke1.t2_f.baseBorrowIndex);
      // console.log('Spoke1 base debt %e', spokes.spoke1.t2_f.baseDebt);
      // console.log('Spoke1 last update timestamp', spokes.spoke1.t2_f.lastUpdateTimestamp);
      // // spoke4
      // console.log('Spoke4 borrow index %e', spokes.spoke4.t2_f.baseBorrowIndex);
      // console.log('Spoke4 base debt %e', spokes.spoke4.t2_f.baseDebt);
      // console.log('Spoke4 last update timestamp', spokes.spoke4.t2_f.lastUpdateTimestamp);
    } else if (stage == Stages.t3) {
      console.log('----- t3_f -----');

      // asset
      console.log('Asset borrow index %e', assets.wethData.t3_f.baseBorrowIndex);
      console.log('Asset base debt %e', assets.wethData.t3_f.baseDebt);
      console.log('Asset last update timestamp', assets.wethData.t3_f.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %e', spokes.spoke1.t3_f.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes.spoke1.t3_f.baseDebt);
      console.log('Spoke1 last update timestamp', spokes.spoke1.t3_f.lastUpdateTimestamp);

      // spoke4
      console.log('Spoke4 borrow index %e', spokes.spoke4.t3_f.baseBorrowIndex);
      console.log('Spoke4 base debt %e', spokes.spoke4.t3_f.baseDebt);
      console.log('Spoke4 last update timestamp', spokes.spoke4.t3_f.lastUpdateTimestamp);
    } else if (stage == Stages.t4) {
      console.log('----- t4_f -----');

      // asset
      console.log('Asset borrow index %e', assets.wethData.t4_f.baseBorrowIndex);
      console.log('Asset base debt %e', assets.wethData.t4_f.baseDebt);
      console.log('Asset last update timestamp', assets.wethData.t4_f.lastUpdateTimestamp);

      // spoke1
      console.log('Spoke1 borrow index %e', spokes.spoke1.t4_f.baseBorrowIndex);
      console.log('Spoke1 base debt %e', spokes.spoke1.t4_f.baseDebt);
      console.log('Spoke1 last update timestamp', spokes.spoke1.t4_f.lastUpdateTimestamp);

      // spoke4
      console.log('Spoke4 borrow index %e', spokes.spoke4.t4_f.baseBorrowIndex);
      console.log('Spoke4 base debt %e', spokes.spoke4.t4_f.baseDebt);
      console.log('Spoke4 last update timestamp', spokes.spoke4.t4_f.lastUpdateTimestamp);
    }
  }
}
