// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './HubBase.t.sol';

contract HubRestoreTest is HubBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function test_restore_revertsWith_SurplusAmountRestored() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     uint256 drawAmount = daiAmount / 2;

    //     // spoke1 supply weth
    //     Utils.supply({
    //       hub: hub,
    //       assetId: wethAssetId,
    //       spoke: address(spoke1),
    //       amount: wethAmount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     // spoke2 supply dai
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     // spoke1 draw half of dai reserve liquidity
    //     Utils.draw({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       to: alice,
    //       spoke: address(spoke1),
    //       amount: drawAmount,
    //       riskPremium: 0,
    //       onBehalfOf: address(spoke1)
    //     });

    //     // alice restore invalid amount > drawn amount AND premium
    //     vm.expectRevert(
    //       abi.encodeWithSelector(IHub.SurplusAmountRestored.selector, drawAmount)
    //     );

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: drawAmount + 1, riskPremium: 0, restorer: alice});
  }

  function test_restore_revertsWith_InvalidRestoreAmount_zero() public {
    vm.skip(true, 'pending refactor');

    //     vm.expectRevert(IHub.InvalidRestoreAmount.selector);

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: 0, riskPremium: 0, restorer: alice});
  }

  function test_restore_revertsWith_AssetNotActive() public {
    vm.skip(true, 'pending refactor');

    //     updateAssetActive(hub, daiAssetId, false);

    //     assertFalse(hub.getAsset(daiAssetId).config.active);

    //     vm.expectRevert(IHub.AssetNotActive.selector);
    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: 1, riskPremium: 0, restorer: alice});
  }

  function test_restore_revertsWith_AssetPaused() public {
    vm.skip(true, 'pending refactor');

    //     updateAssetPaused(hub, daiAssetId, true);

    //     assertTrue(hub.getAsset(daiAssetId).config.paused);

    //     vm.expectRevert(IHub.AssetPaused.selector);
    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: 1, riskPremium: 0, restorer: alice});
  }

  function test_restore_revertsWith_SurplusAmountRestored_with_interest() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     uint256 drawAmount = daiAmount / 2;
    //     uint256 skipTime = 365 days / 2;
    //     uint256 rate = uint256(15_00).bpsToRay();

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(rate)
    //     );

    //     // spoke1 supply weth
    //     Utils.supply({
    //       hub: hub,
    //       assetId: wethAssetId,
    //       spoke: address(spoke1),
    //       amount: wethAmount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     // spoke2 supply dai
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     // spoke1 draw half of dai reserve liquidity
    //     Utils.draw({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       to: alice,
    //       spoke: address(spoke1),
    //       amount: drawAmount,
    //       riskPremium: 0,
    //       onBehalfOf: address(spoke1)
    //     });

    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    //     skip(skipTime);

    //     // spoke2 supply more dai to trigger accrual
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount / 5,
    //       riskPremium: 5_00,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(spoke1DaiData.lastUpdateTimestamp)
    //     );
    //     uint256 cumulatedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     assertTrue(cumulatedDrawnDebt > 0);

    //     // alice restore invalid amount > drawn amount (no premium)
    //     vm.expectRevert(
    //       abi.encodeWithSelector(IHub.SurplusAmountRestored.selector, cumulatedDrawnDebt)
    //     );

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedDrawnDebt + 1,
    //       riskPremium: 0,
    //       restorer: alice
    //     });
  }

  function test_restore_fuzz_revertsWith_SurplusAmountRestored_with_interest(
    uint256 drawAmount,
    uint256 skipTime,
    uint256 rate
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    //     skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 sec to 10 years
    //     rate = bound(rate, 1, 1000_00).bpsToRay(); // 0.01% to 1000%

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(rate)
    //     );

    //     // spoke1 supply weth
    //     Utils.supply({
    //       hub: hub,
    //       assetId: wethAssetId,
    //       spoke: address(spoke1),
    //       amount: wethAmount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     // spoke2 supply dai
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     // spoke1 draw half of dai reserve liquidity
    //     Utils.draw({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       to: alice,
    //       spoke: address(spoke1),
    //       amount: drawAmount,
    //       riskPremium: 0,
    //       onBehalfOf: address(spoke1)
    //     });

    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    //     skip(skipTime);

    //     // spoke2 supply more dai to trigger accrual
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount / 5,
    //       riskPremium: 5_00,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(spoke1DaiData.lastUpdateTimestamp)
    //     );
    //     uint256 cumulatedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     vm.assume(cumulatedDrawnDebt > 0);

    //     // alice restore invalid amount > drawn amount (no premium)
    //     vm.expectRevert(
    //       abi.encodeWithSelector(IHub.SurplusAmountRestored.selector, cumulatedDrawnDebt)
    //     );

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedDrawnDebt + 1,
    //       riskPremium: 0,
    //       restorer: alice
    //     });
  }

  function test_restore_revertsWith_SurplusAmountRestored_with_interest_and_premium() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     uint256 drawAmount = daiAmount / 2;
    //     uint256 skipTime = 365 days / 2;
    //     uint256 rate = uint256(15_00).bpsToRay();
    //     uint32 riskPremium = 30_00;

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(rate)
    //     );

    //     // spoke1 supply weth
    //     Utils.supply({
    //       hub: hub,
    //       assetId: wethAssetId,
    //       spoke: address(spoke1),
    //       amount: wethAmount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     // spoke2 supply dai
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     // spoke1 draw half of dai reserve liquidity
    //     Utils.draw({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       to: alice,
    //       spoke: address(spoke1),
    //       amount: drawAmount,
    //       riskPremium: riskPremium,
    //       onBehalfOf: address(spoke1)
    //     });

    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    //     skip(skipTime);

    //     // spoke2 supply more dai to trigger accrual
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount / 5,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(spoke1DaiData.lastUpdateTimestamp)
    //     );
    //     uint256 cumulatedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     uint256 accruedPremium = (cumulatedDrawnDebt - drawAmount).percentMul(riskPremium);
    //     assertTrue(accruedPremium > 0);

    //     // alice restore invalid amount > drawn amount AND premium
    //     vm.expectRevert(
    //       abi.encodeWithSelector(
    //         IHub.SurplusAmountRestored.selector,
    //         cumulatedDrawnDebt + accruedPremium
    //       )
    //     );

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedDrawnDebt + accruedPremium + 1,
    //       riskPremium: 0,
    //       restorer: alice
    //     });
  }

  function test_restore_fuzz_revertsWith_SurplusAmountRestored_with_interest_and_premium(
    uint256 drawAmount,
    uint256 skipTime,
    uint256 rate,
    uint32 riskPremium
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    //     skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 sec to 10 years
    //     rate = bound(rate, 1, 1000_00).bpsToRay(); // 0.01% to 1000%
    //     riskPremium %= MAX_RISK_PREMIUM_BPS;

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(rate)
    //     );

    //     // spoke1 supply weth
    //     Utils.supply({
    //       hub: hub,
    //       assetId: wethAssetId,
    //       spoke: address(spoke1),
    //       amount: wethAmount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     // spoke2 supply dai
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     // spoke1 draw half of dai reserve liquidity
    //     Utils.draw({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       to: alice,
    //       spoke: address(spoke1),
    //       amount: drawAmount,
    //       riskPremium: riskPremium,
    //       onBehalfOf: address(spoke1)
    //     });

    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    //     skip(skipTime);

    //     // spoke2 supply more dai to trigger accrual
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount / 5,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(spoke1DaiData.lastUpdateTimestamp)
    //     );
    //     uint256 cumulatedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     uint256 accruedPremium = (cumulatedDrawnDebt - drawAmount).percentMul(riskPremium);
    //     vm.assume(accruedPremium > 0); // accrued premium can round to 0 in edge case - ex. (cumulatedDrawnDebt - drawAmount) = 1, riskPremium = 1

    //     // alice restore invalid amount > drawn amount AND premium
    //     vm.expectRevert(
    //       abi.encodeWithSelector(
    //         IHub.SurplusAmountRestored.selector,
    //         cumulatedDrawnDebt + accruedPremium
    //       )
    //     );

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedDrawnDebt + accruedPremium + 1,
    //       riskPremium: 0,
    //       restorer: alice
    //     });
  }

  /// @dev Restore some amount less than premium
  function test_restore_partial_premium() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;
    //     uint256 drawAmount = daiAmount / 2;
    //     uint256 rate = uint256(15_00).bpsToRay();
    //     uint32 riskPremium = 30_00;

    //     _addAndDrawLiquidity({
    //       daiAmount: daiAmount,
    //       wethAmount: wethAmount,
    //       daiDrawAmount: drawAmount,
    //       riskPremium: riskPremium,
    //       rate: rate
    //     });
    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);

    //     skip(365 days);

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(daiData.lastUpdateTimestamp)
    //     );
    //     uint256 accruedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    //     uint256 accruedPremium = accruedDrawnDebt.percentMul(riskPremium);

    //     assertTrue(accruedPremium > 0);

    //     uint256 restoreAmount = accruedPremium / 2;

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, restorer: alice});

    //     daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // hub
    //     assertEq(
    //       hub.getTotalAssets(daiAssetId),
    //       daiAmount + accruedPremium + accruedDrawnDebt,
    //       'hub dai total assets'
    //     );
    //     assertEq(
    //       daiData.outstandingPremium,
    //       accruedPremium - restoreAmount,
    //       'hub dai outstandingPremium'
    //     );
    //     assertEq(daiData.drawn, accruedDrawnDebt + drawAmount, 'hub dai drawn');
    //     assertEq(
    //       daiData.liquidity,
    //       daiAmount - drawAmount + restoreAmount,
    //       'hub dai liquidity'
    //     );
    //     assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');

    //     assertEq(
    //       daiDebtData.asset.cumulativeDebt,
    //       daiData.drawn + daiData.outstandingPremium,
    //       'asset cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.asset.drawn, accruedDrawnDebt + drawAmount, 'asset drawn');
    //     assertEq(
    //       daiDebtData.asset.outstandingPremium,
    //       accruedPremium - restoreAmount,
    //       'asset outstandingPremium'
    //     );
    //     // spoke1
    //     assertEq(
    //       spoke1DaiData.outstandingPremium,
    //       daiData.outstandingPremium,
    //       'hub spoke1 outstandingPremium'
    //     );
    //     assertEq(spoke1DaiData.drawn, daiData.drawn, 'hub spoke1 drawn');
    //     assertEq(
    //       spoke1DaiData.lastUpdateTimestamp,
    //       daiData.lastUpdateTimestamp,
    //       'hub spoke1 lastUpdateTimestamp'
    //     );
    //     assertEq(
    //       daiDebtData.spoke[0].cumulativeDebt,
    //       daiData.drawn + daiData.outstandingPremium,
    //       'spoke1 cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.spoke[0].drawn, accruedDrawnDebt + drawAmount, 'spoke1 drawn');
    //     assertEq(
    //       daiDebtData.spoke[0].outstandingPremium,
    //       accruedPremium - restoreAmount,
    //       'spoke1 outstandingPremium'
    //     );
  }

  /// @dev Restore some amount less than premium
  function test_restore_fuzz_partial_premium(
    uint256 drawAmount,
    uint256 skipTime,
    uint256 rate,
    uint32 riskPremium,
    uint256 restoreAmount
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    //     skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 sec to 10 years
    //     rate = bound(rate, 1, 1000_00).bpsToRay(); // 0.01% to 1000%
    //     riskPremium %= MAX_RISK_PREMIUM_BPS;

    //     _addAndDrawLiquidity({
    //       daiAmount: daiAmount,
    //       wethAmount: wethAmount,
    //       daiDrawAmount: drawAmount,
    //       riskPremium: riskPremium,
    //       rate: rate
    //     });
    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);

    //     skip(skipTime);

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(daiData.lastUpdateTimestamp)
    //     );
    //     uint256 accruedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    //     uint256 accruedPremium = accruedDrawnDebt.percentMul(riskPremium);

    //     vm.assume(accruedPremium > 0);

    //     restoreAmount = bound(restoreAmount, 1, accruedPremium); // within accrued premium
    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, restorer: alice});

    //     daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // hub
    //     assertEq(
    //       hub.getTotalAssets(daiAssetId),
    //       daiAmount + accruedPremium + accruedDrawnDebt,
    //       'hub dai total assets'
    //     );
    //     assertEq(
    //       daiData.outstandingPremium,
    //       accruedPremium - restoreAmount,
    //       'hub dai outstandingPremium'
    //     );
    //     assertEq(daiData.drawn, accruedDrawnDebt + drawAmount, 'hub dai drawn');
    //     assertEq(
    //       daiData.liquidity,
    //       daiAmount - drawAmount + restoreAmount,
    //       'hub dai liquidity'
    //     );
    //     assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');

    //     assertEq(
    //       daiDebtData.asset.cumulativeDebt,
    //       daiData.drawn + daiData.outstandingPremium,
    //       'asset cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.asset.drawn, accruedDrawnDebt + drawAmount, 'asset drawn');
    //     assertEq(
    //       daiDebtData.asset.outstandingPremium,
    //       accruedPremium - restoreAmount,
    //       'asset outstandingPremium'
    //     );
    //     // spoke1
    //     assertEq(
    //       spoke1DaiData.outstandingPremium,
    //       daiData.outstandingPremium,
    //       'hub spoke1 outstandingPremium'
    //     );
    //     assertEq(spoke1DaiData.drawn, daiData.drawn, 'hub spoke1 drawn');
    //     assertEq(
    //       spoke1DaiData.lastUpdateTimestamp,
    //       daiData.lastUpdateTimestamp,
    //       'hub spoke1 lastUpdateTimestamp'
    //     );
    //     assertEq(
    //       daiDebtData.spoke[0].cumulativeDebt,
    //       daiData.drawn + daiData.outstandingPremium,
    //       'spoke1 cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.spoke[0].drawn, accruedDrawnDebt + drawAmount, 'spoke1 drawn');
    //     assertEq(
    //       daiDebtData.spoke[0].outstandingPremium,
    //       accruedPremium - restoreAmount,
    //       'spoke1 outstandingPremium'
    //     );
  }

  /// @dev Restore more than premium but partial amount to eat into drawn debt
  function test_restore_partial_premium_and_base() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;
    //     uint256 drawAmount = daiAmount / 2;
    //     uint256 rate = uint256(15_00).bpsToRay();
    //     uint32 riskPremium = 30_00;

    //     _addAndDrawLiquidity({
    //       daiAmount: daiAmount,
    //       wethAmount: wethAmount,
    //       daiDrawAmount: drawAmount,
    //       riskPremium: riskPremium,
    //       rate: rate
    //     });
    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);

    //     skip(365 days);

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(daiData.lastUpdateTimestamp)
    //     );
    //     uint256 accruedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    //     uint256 accruedPremium = accruedDrawnDebt.percentMul(riskPremium);
    //     assertTrue(accruedPremium > 0);
    //     uint256 restoreAmount = accruedPremium + 1; // restore amount partially contributes to drawn debt

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, restorer: alice});

    //     daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // hub
    //     assertEq(
    //       hub.getTotalAssets(daiAssetId),
    //       daiAmount + accruedPremium + accruedDrawnDebt,
    //       'hub dai total assets'
    //     );
    //     assertEq(daiData.outstandingPremium, 0, 'hub dai outstandingPremium');
    //     assertEq(daiData.drawn, accruedDrawnDebt + drawAmount - 1, 'hub dai drawn');
    //     assertEq(
    //       daiData.liquidity,
    //       daiAmount - drawAmount + restoreAmount,
    //       'hub dai liquidity'
    //     );
    //     assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');

    //     assertEq(
    //       daiDebtData.asset.cumulativeDebt,
    //       accruedDrawnDebt + drawAmount - 1,
    //       'asset cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.asset.drawn, accruedDrawnDebt + drawAmount - 1, 'asset drawn');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');
    //     // spoke1
    //     assertEq(
    //       spoke1DaiData.outstandingPremium,
    //       daiData.outstandingPremium,
    //       'hub spoke1 outstandingPremium'
    //     );
    //     assertEq(spoke1DaiData.drawn, daiData.drawn, 'hub spoke1 drawn');
    //     assertEq(
    //       spoke1DaiData.lastUpdateTimestamp,
    //       daiData.lastUpdateTimestamp,
    //       'hub spoke1 lastUpdateTimestamp'
    //     );
    //     assertEq(
    //       daiDebtData.spoke[0].cumulativeDebt,
    //       accruedDrawnDebt + drawAmount - 1,
    //       'spoke1 cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.spoke[0].drawn, accruedDrawnDebt + drawAmount - 1, 'spoke1 drawn');
    //     assertEq(daiDebtData.spoke[0].outstandingPremium, 0, 'spoke1 outstandingPremium');
  }

  /// @dev Restore more than premium but partial amount to eat into drawn debt
  function test_restore_fuzz_partial_premium_and_base(
    uint256 drawAmount,
    uint256 skipTime,
    uint256 rate,
    uint32 riskPremium,
    uint256 restoreAmount
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    //     skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 sec to 10 years
    //     rate = bound(rate, 1, 1000_00).bpsToRay(); // 0.01% to 1000%
    //     riskPremium %= MAX_RISK_PREMIUM_BPS;

    //     _addAndDrawLiquidity({
    //       daiAmount: daiAmount,
    //       wethAmount: wethAmount,
    //       daiDrawAmount: drawAmount,
    //       riskPremium: riskPremium,
    //       rate: rate
    //     });
    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);

    //     skip(skipTime);

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(daiData.lastUpdateTimestamp)
    //     );
    //     uint256 accruedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    //     uint256 accruedPremium = accruedDrawnDebt.percentMul(riskPremium);
    //     vm.assume(accruedPremium > 0);

    //     restoreAmount = bound(
    //       restoreAmount,
    //       accruedPremium + 1,
    //       accruedPremium + accruedDrawnDebt + drawAmount
    //     ); // more than accrued premium, less than total debt

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, restorer: alice});

    //     daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // hub
    //     assertEq(
    //       hub.getTotalAssets(daiAssetId),
    //       daiAmount + accruedPremium + accruedDrawnDebt,
    //       'hub dai total assets'
    //     );
    //     assertEq(daiData.outstandingPremium, 0, 'hub dai outstandingPremium');
    //     assertEq(
    //       daiData.drawn,
    //       accruedDrawnDebt + drawAmount - (restoreAmount - accruedPremium), // eat into drawn debt after premium is consumed
    //       'hub dai drawn'
    //     );
    //     assertEq(
    //       daiData.liquidity,
    //       daiAmount - drawAmount + restoreAmount,
    //       'hub dai liquidity'
    //     );
    //     assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');
    //     assertEq(
    //       daiDebtData.asset.cumulativeDebt,
    //       accruedDrawnDebt + drawAmount - (restoreAmount - accruedPremium),
    //       'asset cumulativeDebt'
    //     );
    //     assertEq(
    //       daiDebtData.asset.drawn,
    //       accruedDrawnDebt + drawAmount - (restoreAmount - accruedPremium),
    //       'asset drawn'
    //     );
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');
    //     // spoke1
    //     assertEq(
    //       spoke1DaiData.outstandingPremium,
    //       daiData.outstandingPremium,
    //       'hub spoke1 outstandingPremium'
    //     );
    //     assertEq(spoke1DaiData.drawn, daiData.drawn, 'hub spoke1 drawn');
    //     assertEq(
    //       spoke1DaiData.lastUpdateTimestamp,
    //       daiData.lastUpdateTimestamp,
    //       'hub spoke1 lastUpdateTimestamp'
    //     );
    //     assertEq(
    //       daiDebtData.spoke[0].cumulativeDebt,
    //       accruedDrawnDebt + drawAmount - (restoreAmount - accruedPremium),
    //       'spoke1 cumulativeDebt'
    //     );
    //     assertEq(
    //       daiDebtData.spoke[0].drawn,
    //       accruedDrawnDebt + drawAmount - (restoreAmount - accruedPremium),
    //       'spoke1 drawn'
    //     );
    //     assertEq(daiDebtData.spoke[0].outstandingPremium, 0, 'spoke1 outstandingPremium');
  }

  function test_restore_partial_same_block() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     uint256 drawAmount = daiAmount / 2;
    //     uint256 restoreAmount = daiAmount / 4;

    //     uint256 rate = uint256(15_00).bpsToRay();

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(rate)
    //     );

    //     // spoke1 supply weth
    //     Utils.supply({
    //       hub: hub,
    //       assetId: wethAssetId,
    //       spoke: address(spoke1),
    //       amount: wethAmount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     // spoke2 supply dai
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     // spoke1 draw half of dai reserve liquidity on behalf of user
    //     Utils.draw({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       to: alice,
    //       spoke: address(spoke1),
    //       amount: drawAmount,
    //       riskPremium: 0,
    //       onBehalfOf: address(spoke1)
    //     });

    //     vm.expectEmit(address(hub));
    //     emit IHub.Restore(daiAssetId, address(spoke1), restoreAmount);

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, restorer: alice});

    //     HubData memory hubData;
    //     hubData.daiData = hub.getAsset(daiAssetId);
    //     hubData.wethData = hub.getAsset(wethAssetId);
    //     hubData.spoke1WethData = hub.getSpoke(wethAssetId, address(spoke1));
    //     hubData.spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    //     hubData.spoke2DaiData = hub.getSpoke(daiAssetId, address(spoke2));
    //     hubData.timestamp = vm.getBlockTimestamp();

    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // hub
    //     assertEq(hub.getTotalAssets(wethAssetId), wethAmount, 'hub weth total assets post-restore');
    //     assertEq(hub.getTotalAssets(daiAssetId), daiAmount, 'hub dai total assets post-restore');
    //     // dai
    //     assertEq(
    //       hubData.daiData.suppliedShares,
    //       hub.convertToShares(daiAssetId, daiAmount),
    //       'hub dai total shares post-restore'
    //     );
    //     assertEq(
    //       hubData.daiData.liquidity,
    //       daiAmount - drawAmount + restoreAmount,
    //       'hub dai liquidity post-restore'
    //     );
    //     assertEq(hubData.daiData.drawn, drawAmount - restoreAmount, 'hub dai drawn post-restore');
    //     assertEq(hubData.daiData.outstandingPremium, 0, 'hub dai outstandingPremium post-restore');
    //     assertEq(
    //       hubData.daiData.baseBorrowIndex,
    //       INIT_BASE_BORROW_INDEX,
    //       'hub dai baseBorrowIndex post-restore'
    //     );
    //     assertEq(hubData.daiData.drawnRate, rate, 'hub dai drawnRate post-restore');
    //     assertEq(hubData.daiData.riskPremium, 0, 'hub dai riskPremium post-restore');
    //     assertEq(
    //       hubData.daiData.lastUpdateTimestamp,
    //       hubData.timestamp,
    //       'hub dai lastUpdateTimestamp post-restore'
    //     );
    //     assertEq(daiDebtData.asset.cumulativeDebt, drawAmount - restoreAmount, 'asset cumulativeDebt');
    //     assertEq(daiDebtData.asset.drawn, drawAmount - restoreAmount, 'asset drawn');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');
    //     // weth
    //     assertEq(
    //       hubData.wethData.suppliedShares,
    //       hub.convertToShares(wethAssetId, wethAmount),
    //       'hub weth total shares post-restore'
    //     );
    //     assertEq(
    //       hubData.wethData.liquidity,
    //       wethAmount,
    //       'hub weth liquidity post-restore'
    //     );
    //     assertEq(hubData.wethData.drawn, 0, 'hub weth drawn post-restore');
    //     assertEq(hubData.wethData.outstandingPremium, 0, 'hub weth outstandingPremium post-restore');
    //     assertEq(
    //       hubData.wethData.baseBorrowIndex,
    //       INIT_BASE_BORROW_INDEX,
    //       'hub weth baseBorrowIndex post-restore'
    //     );
    //     assertEq(hubData.wethData.drawnRate, rate, 'hub weth drawnRate post-restore');
    //     assertEq(hubData.wethData.riskPremium, 0, 'hub weth riskPremium post-restore');
    //     assertEq(
    //       hubData.wethData.lastUpdateTimestamp,
    //       hubData.timestamp,
    //       'hub weth lastUpdateTimestamp post-restore'
    //     );
    //     // spoke1 weth
    //     assertEq(
    //       hubData.spoke1WethData.suppliedShares,
    //       hubData.wethData.suppliedShares,
    //       'spoke1 total weth shares post-restore'
    //     );
    //     assertEq(hubData.spoke1WethData.drawn, hubData.wethData.drawn, 'spoke1 base weth debt');
    //     assertEq(
    //       hubData.spoke1WethData.outstandingPremium,
    //       hubData.wethData.outstandingPremium,
    //       'spoke1 weth outstandingPremium post-restore'
    //     );
    //     assertEq(
    //       hubData.spoke1WethData.baseBorrowIndex,
    //       hubData.wethData.baseBorrowIndex,
    //       'spoke1 weth baseBorrowIndex post-restore'
    //     );
    //     assertEq(hubData.spoke1WethData.riskPremium, 0, 'spoke1 weth riskPremium post-restore');
    //     assertEq(
    //       hubData.spoke1WethData.lastUpdateTimestamp,
    //       hubData.wethData.lastUpdateTimestamp,
    //       'spoke1 weth lastUpdateTimestamp post-restore'
    //     );
    //     // spoke1 dai
    //     assertEq(hubData.spoke1DaiData.suppliedShares, 0, 'spoke1 total dai shares post-restore');
    //     assertEq(
    //       hubData.spoke1DaiData.drawn,
    //       hubData.daiData.drawn,
    //       'spoke1 base dai debt post-restore'
    //     );
    //     assertEq(
    //       hubData.spoke1DaiData.outstandingPremium,
    //       hubData.daiData.outstandingPremium,
    //       'spoke1 dai outstandingPremium post-restore'
    //     );
    //     assertEq(
    //       hubData.spoke1DaiData.baseBorrowIndex,
    //       hubData.daiData.baseBorrowIndex,
    //       'spoke1 dai baseBorrowIndex post-restore'
    //     );
    //     assertEq(hubData.spoke1DaiData.riskPremium, 0, 'spoke1 dai riskPremium post-restore');
    //     assertEq(
    //       hubData.spoke1DaiData.lastUpdateTimestamp,
    //       hubData.daiData.lastUpdateTimestamp,
    //       'spoke1 dai lastUpdateTimestamp post-restore'
    //     );
    //     assertEq(
    //       daiDebtData.spoke[0].cumulativeDebt,
    //       drawAmount - restoreAmount,
    //       'spoke1 cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.spoke[0].drawn, drawAmount - restoreAmount, 'spoke1 drawn');
    //     assertEq(daiDebtData.spoke[0].outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     // spoke2 dai
    //     assertEq(
    //       hubData.spoke2DaiData.suppliedShares,
    //       hubData.daiData.suppliedShares,
    //       'spoke2 total dai shares post-restore'
    //     );
    //     assertEq(hubData.spoke2DaiData.drawn, 0, 'spoke2 base dai debt post-restore');
    //     assertEq(
    //       hubData.spoke2DaiData.outstandingPremium,
    //       hubData.daiData.outstandingPremium,
    //       'spoke2 dai outstandingPremium post-restore'
    //     );
    //     assertEq(
    //       hubData.spoke2DaiData.baseBorrowIndex,
    //       hubData.daiData.baseBorrowIndex,
    //       'spoke2 dai baseBorrowIndex post-restore'
    //     );
    //     assertEq(hubData.spoke2DaiData.riskPremium, 0, 'spoke2 dai riskPremium post-restore');
    //     assertEq(
    //       hubData.spoke2DaiData.lastUpdateTimestamp,
    //       hubData.daiData.lastUpdateTimestamp,
    //       'spoke2 dai lastUpdateTimestamp post-restore'
    //     );

    //     // token balance
    //     // dai
    //     assertEq(
    //       tokenList.dai.balanceOf(address(hub)),
    //       daiAmount - restoreAmount,
    //       'hub dai final balance'
    //     );
    //     assertEq(
    //       tokenList.dai.balanceOf(alice),
    //       drawAmount - restoreAmount + MAX_SUPPLY_AMOUNT,
    //       'alice dai final balance'
    //     );
    //     assertEq(tokenList.dai.balanceOf(bob), MAX_SUPPLY_AMOUNT - daiAmount, 'bob dai final balance');
    //     assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai final balance');
    //     assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai final balance');
    //     // weth
    //     assertEq(tokenList.weth.balanceOf(address(hub)), wethAmount, 'hub weth final balance');
    //     assertEq(
    //       tokenList.weth.balanceOf(alice),
    //       MAX_SUPPLY_AMOUNT - wethAmount,
    //       'alice weth final balance'
    //     );
    //     assertEq(tokenList.weth.balanceOf(bob), MAX_SUPPLY_AMOUNT, 'bob weth final balance');
    //     assertEq(tokenList.weth.balanceOf(address(spoke1)), 0, 'spoke1 weth final balance');
    //     assertEq(tokenList.weth.balanceOf(address(spoke2)), 0, 'spoke2 weth final balance');
  }

  function test_restore_full_amount_with_interest() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     uint256 drawAmount = daiAmount / 2;
    //     uint256 skipTime = 365 days / 2;
    //     uint256 rate = uint256(15_00).bpsToRay();

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(rate)
    //     );

    //     // spoke1 supply weth
    //     Utils.supply({
    //       hub: hub,
    //       assetId: wethAssetId,
    //       spoke: address(spoke1),
    //       amount: wethAmount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     // spoke2 supply dai
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     // spoke1 draw half of dai reserve liquidity
    //     Utils.draw({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       to: alice,
    //       spoke: address(spoke1),
    //       amount: drawAmount,
    //       riskPremium: 0,
    //       onBehalfOf: address(spoke1)
    //     });

    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    //     skip(skipTime);

    //     // spoke2 supply more dai to trigger accrual
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount / 5,
    //       riskPremium: 5_00,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(spoke1DaiData.lastUpdateTimestamp)
    //     );
    //     uint256 cumulatedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     assertTrue(cumulatedDrawnDebt > 0);

    //     // alice restore amount = drawn amount
    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: cumulatedDrawnDebt, riskPremium: 0, restorer: alice});

    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1Data = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // asset
    //     assertEq(daiData.drawn, 0, 'asset drawn');
    //     assertEq(daiData.outstandingPremium, 0, 'asset outstandingPremium');
    //     assertEq(daiDebtData.asset.cumulativeDebt, 0, 'asset cumulativeDebt');
    //     assertEq(daiDebtData.asset.drawn, 0, 'asset drawn');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');

    //     // spoke
    //     assertEq(spoke1Data.drawn, 0, 'spoke1 drawn');
    //     assertEq(spoke1Data.outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     assertEq(daiDebtData.spoke[0].cumulativeDebt, 0, 'spoke1 cumulativeDebt');
    //     assertEq(daiDebtData.spoke[0].drawn, 0, 'spoke1 drawn');
    //     assertEq(daiDebtData.spoke[0].outstandingPremium, 0, 'spoke1 outstandingPremium');
  }

  function test_restore_fuzz_full_restore_amount_with_interest(
    uint256 drawAmount,
    uint256 skipTime,
    uint256 rate
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    //     skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 sec to 10 years
    //     rate = bound(rate, 1, 1000_00).bpsToRay(); // 0.01% to 1000%

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(rate)
    //     );

    //     // spoke1 supply weth
    //     Utils.supply({
    //       hub: hub,
    //       assetId: wethAssetId,
    //       spoke: address(spoke1),
    //       amount: wethAmount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     // spoke2 supply dai
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     // spoke1 draw half of dai reserve liquidity
    //     Utils.draw({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       to: alice,
    //       spoke: address(spoke1),
    //       amount: drawAmount,
    //       riskPremium: 0,
    //       onBehalfOf: address(spoke1)
    //     });

    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    //     skip(skipTime);

    //     // spoke2 supply more dai to trigger accrual
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount / 5,
    //       riskPremium: 5_00,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(spoke1DaiData.lastUpdateTimestamp)
    //     );
    //     uint256 cumulatedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     vm.assume(cumulatedDrawnDebt > 0);

    //     // alice restore amount = drawn amount (no premium)

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: cumulatedDrawnDebt, riskPremium: 0, restorer: alice});

    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1Data = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // asset
    //     assertEq(daiData.drawn, 0, 'asset drawn');
    //     assertEq(daiData.outstandingPremium, 0, 'asset outstandingPremium');
    //     assertEq(daiDebtData.asset.cumulativeDebt, 0, 'asset cumulativeDebt');
    //     assertEq(daiDebtData.asset.drawn, 0, 'asset drawn');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');

    //     // spoke
    //     assertEq(spoke1Data.drawn, 0, 'spoke1 drawn');
    //     assertEq(spoke1Data.outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     assertEq(daiDebtData.spoke[0].cumulativeDebt, 0, 'spoke1 cumulativeDebt');
    //     assertEq(daiDebtData.spoke[0].drawn, 0, 'spoke1 drawn');
    //     assertEq(daiDebtData.spoke[0].outstandingPremium, 0, 'spoke1 outstandingPremium');
  }

  function test_restore_full_amount_with_interest_and_premium() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     uint256 drawAmount = daiAmount / 2;
    //     uint256 skipTime = 365 days / 2;
    //     uint256 rate = uint256(15_00).bpsToRay();
    //     uint32 riskPremium = 30_00;

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(rate)
    //     );

    //     // spoke1 supply weth
    //     Utils.supply({
    //       hub: hub,
    //       assetId: wethAssetId,
    //       spoke: address(spoke1),
    //       amount: wethAmount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     // spoke2 supply dai
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     // spoke1 draw half of dai reserve liquidity
    //     Utils.draw({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       to: alice,
    //       spoke: address(spoke1),
    //       amount: drawAmount,
    //       riskPremium: riskPremium,
    //       onBehalfOf: address(spoke1)
    //     });

    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    //     skip(skipTime);

    //     // spoke2 supply more dai to trigger accrual
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount / 5,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(spoke1DaiData.lastUpdateTimestamp)
    //     );
    //     uint256 cumulatedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     uint256 accruedPremium = (cumulatedDrawnDebt - drawAmount).percentMul(riskPremium);
    //     assertTrue(accruedPremium > 0);

    //     // alice restore amount = drawn amount AND premium

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedDrawnDebt + accruedPremium,
    //       riskPremium: 0,
    //       restorer: alice
    //     });

    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1Data = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // asset
    //     assertEq(daiData.drawn, 0, 'asset drawn');
    //     assertEq(daiData.outstandingPremium, 0, 'asset outstandingPremium');
    //     assertEq(daiDebtData.asset.cumulativeDebt, 0, 'asset cumulativeDebt');
    //     assertEq(daiDebtData.asset.drawn, 0, 'asset drawn');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');

    //     // spoke1
    //     assertEq(spoke1Data.drawn, 0, 'spoke1 drawn');
    //     assertEq(spoke1Data.outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     assertEq(daiDebtData.spoke[0].cumulativeDebt, 0, 'spoke1 cumulativeDebt');
    //     assertEq(daiDebtData.spoke[0].drawn, 0, 'spoke1 drawn');
    //     assertEq(daiDebtData.spoke[0].outstandingPremium, 0, 'spoke1 outstandingPremium');
  }

  function test_restore_fuzz_full_amount_with_interest_and_premium(
    uint256 drawAmount,
    uint256 skipTime,
    uint256 rate,
    uint32 riskPremium
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    //     skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 sec to 10 years
    //     rate = bound(rate, 1, 1000_00).bpsToRay(); // 0.01% to 1000%
    //     riskPremium %= MAX_RISK_PREMIUM_BPS;

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(rate)
    //     );

    //     // spoke1 supply weth
    //     Utils.supply({
    //       hub: hub,
    //       assetId: wethAssetId,
    //       spoke: address(spoke1),
    //       amount: wethAmount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     // spoke2 supply dai
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     // spoke1 draw half of dai reserve liquidity
    //     Utils.draw({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       to: alice,
    //       spoke: address(spoke1),
    //       amount: drawAmount,
    //       riskPremium: riskPremium,
    //       onBehalfOf: address(spoke1)
    //     });

    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    //     skip(skipTime);

    //     // spoke2 supply more dai to trigger accrual
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: daiAmount / 5,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       rate,
    //       uint40(spoke1DaiData.lastUpdateTimestamp)
    //     );
    //     uint256 cumulatedDrawnDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     uint256 accruedPremium = (cumulatedDrawnDebt - drawAmount).percentMul(riskPremium);
    //     vm.assume(accruedPremium > 0); // accrued premium can round to 0 in edge case - ex. (cumulatedDrawnDebt - drawAmount) = 1, riskPremium = 1

    //     // alice restore amount = drawn amount AND premium

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedDrawnDebt + accruedPremium,
    //       riskPremium: 0,
    //       restorer: alice
    //     });

    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1Data = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // asset
    //     assertEq(daiData.drawn, 0, 'asset drawn');
    //     assertEq(daiData.outstandingPremium, 0, 'asset outstandingPremium');
    //     assertEq(daiDebtData.asset.cumulativeDebt, 0, 'asset cumulativeDebt');
    //     assertEq(daiDebtData.asset.drawn, 0, 'asset drawn');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');

    //     // spoke
    //     assertEq(spoke1Data.drawn, 0, 'spoke1 drawn');
    //     assertEq(spoke1Data.outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     assertEq(daiDebtData.spoke[0].cumulativeDebt, 0, 'spoke1 cumulativeDebt');
    //     assertEq(daiDebtData.spoke[0].drawn, 0, 'spoke1 drawn');
    //     assertEq(daiDebtData.spoke[0].outstandingPremium, 0, 'spoke1 outstandingPremium');
  }
}
