// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBase.t.sol';

contract LiquidityHubRestoreTest is LiquidityHubBase {
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
    //       abi.encodeWithSelector(ILiquidityHub.SurplusAmountRestored.selector, drawAmount)
    //     );

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: drawAmount + 1, riskPremium: 0, repayer: alice});
  }

  function test_restore_revertsWith_InvalidRestoreAmount_zero() public {
    vm.skip(true, 'pending refactor');

    //     vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: 0, riskPremium: 0, repayer: alice});
  }

  function test_restore_revertsWith_AssetNotActive() public {
    vm.skip(true, 'pending refactor');

    //     updateAssetActive(hub, daiAssetId, false);

    //     assertFalse(hub.getAsset(daiAssetId).config.active);

    //     vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: 1, riskPremium: 0, repayer: alice});
  }

  function test_restore_revertsWith_AssetPaused() public {
    vm.skip(true, 'pending refactor');

    //     updateAssetPaused(hub, daiAssetId, true);

    //     assertTrue(hub.getAsset(daiAssetId).config.paused);

    //     vm.expectRevert(ILiquidityHub.AssetPaused.selector);
    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: 1, riskPremium: 0, repayer: alice});
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
    //     uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     assertTrue(cumulatedBaseDebt > 0);

    //     // alice restore invalid amount > drawn amount (no premium)
    //     vm.expectRevert(
    //       abi.encodeWithSelector(ILiquidityHub.SurplusAmountRestored.selector, cumulatedBaseDebt)
    //     );

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedBaseDebt + 1,
    //       riskPremium: 0,
    //       repayer: alice
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
    //     uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     vm.assume(cumulatedBaseDebt > 0);

    //     // alice restore invalid amount > drawn amount (no premium)
    //     vm.expectRevert(
    //       abi.encodeWithSelector(ILiquidityHub.SurplusAmountRestored.selector, cumulatedBaseDebt)
    //     );

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedBaseDebt + 1,
    //       riskPremium: 0,
    //       repayer: alice
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
    //     uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     uint256 accruedPremium = (cumulatedBaseDebt - drawAmount).percentMul(riskPremium);
    //     assertTrue(accruedPremium > 0);

    //     // alice restore invalid amount > drawn amount AND premium
    //     vm.expectRevert(
    //       abi.encodeWithSelector(
    //         ILiquidityHub.SurplusAmountRestored.selector,
    //         cumulatedBaseDebt + accruedPremium
    //       )
    //     );

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedBaseDebt + accruedPremium + 1,
    //       riskPremium: 0,
    //       repayer: alice
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
    //     uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     uint256 accruedPremium = (cumulatedBaseDebt - drawAmount).percentMul(riskPremium);
    //     vm.assume(accruedPremium > 0); // accrued premium can round to 0 in edge case - ex. (cumulatedBaseDebt - drawAmount) = 1, riskPremium = 1

    //     // alice restore invalid amount > drawn amount AND premium
    //     vm.expectRevert(
    //       abi.encodeWithSelector(
    //         ILiquidityHub.SurplusAmountRestored.selector,
    //         cumulatedBaseDebt + accruedPremium
    //       )
    //     );

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedBaseDebt + accruedPremium + 1,
    //       riskPremium: 0,
    //       repayer: alice
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

    //     _supplyAndDrawLiquidity({
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
    //     uint256 accruedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    //     uint256 accruedPremium = accruedBaseDebt.percentMul(riskPremium);

    //     assertTrue(accruedPremium > 0);

    //     uint256 restoreAmount = accruedPremium / 2;

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, repayer: alice});

    //     daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // hub
    //     assertEq(
    //       hub.getTotalAssets(daiAssetId),
    //       daiAmount + accruedPremium + accruedBaseDebt,
    //       'hub dai total assets'
    //     );
    //     assertEq(
    //       daiData.outstandingPremium,
    //       accruedPremium - restoreAmount,
    //       'hub dai outstandingPremium'
    //     );
    //     assertEq(daiData.baseDebt, accruedBaseDebt + drawAmount, 'hub dai baseDebt');
    //     assertEq(
    //       daiData.availableLiquidity,
    //       daiAmount - drawAmount + restoreAmount,
    //       'hub dai availableLiquidity'
    //     );
    //     assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');

    //     assertEq(
    //       daiDebtData.asset.cumulativeDebt,
    //       daiData.baseDebt + daiData.outstandingPremium,
    //       'asset cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.asset.baseDebt, accruedBaseDebt + drawAmount, 'asset baseDebt');
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
    //     assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'hub spoke1 baseDebt');
    //     assertEq(
    //       spoke1DaiData.lastUpdateTimestamp,
    //       daiData.lastUpdateTimestamp,
    //       'hub spoke1 lastUpdateTimestamp'
    //     );
    //     assertEq(
    //       daiDebtData.spoke[0].cumulativeDebt,
    //       daiData.baseDebt + daiData.outstandingPremium,
    //       'spoke1 cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.spoke[0].baseDebt, accruedBaseDebt + drawAmount, 'spoke1 baseDebt');
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

    //     _supplyAndDrawLiquidity({
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
    //     uint256 accruedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    //     uint256 accruedPremium = accruedBaseDebt.percentMul(riskPremium);

    //     vm.assume(accruedPremium > 0);

    //     restoreAmount = bound(restoreAmount, 1, accruedPremium); // within accrued premium
    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, repayer: alice});

    //     daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // hub
    //     assertEq(
    //       hub.getTotalAssets(daiAssetId),
    //       daiAmount + accruedPremium + accruedBaseDebt,
    //       'hub dai total assets'
    //     );
    //     assertEq(
    //       daiData.outstandingPremium,
    //       accruedPremium - restoreAmount,
    //       'hub dai outstandingPremium'
    //     );
    //     assertEq(daiData.baseDebt, accruedBaseDebt + drawAmount, 'hub dai baseDebt');
    //     assertEq(
    //       daiData.availableLiquidity,
    //       daiAmount - drawAmount + restoreAmount,
    //       'hub dai availableLiquidity'
    //     );
    //     assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');

    //     assertEq(
    //       daiDebtData.asset.cumulativeDebt,
    //       daiData.baseDebt + daiData.outstandingPremium,
    //       'asset cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.asset.baseDebt, accruedBaseDebt + drawAmount, 'asset baseDebt');
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
    //     assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'hub spoke1 baseDebt');
    //     assertEq(
    //       spoke1DaiData.lastUpdateTimestamp,
    //       daiData.lastUpdateTimestamp,
    //       'hub spoke1 lastUpdateTimestamp'
    //     );
    //     assertEq(
    //       daiDebtData.spoke[0].cumulativeDebt,
    //       daiData.baseDebt + daiData.outstandingPremium,
    //       'spoke1 cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.spoke[0].baseDebt, accruedBaseDebt + drawAmount, 'spoke1 baseDebt');
    //     assertEq(
    //       daiDebtData.spoke[0].outstandingPremium,
    //       accruedPremium - restoreAmount,
    //       'spoke1 outstandingPremium'
    //     );
  }

  /// @dev Restore more than premium but partial amount to eat into base debt
  function test_restore_partial_premium_and_base() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;
    //     uint256 drawAmount = daiAmount / 2;
    //     uint256 rate = uint256(15_00).bpsToRay();
    //     uint32 riskPremium = 30_00;

    //     _supplyAndDrawLiquidity({
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
    //     uint256 accruedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    //     uint256 accruedPremium = accruedBaseDebt.percentMul(riskPremium);
    //     assertTrue(accruedPremium > 0);
    //     uint256 restoreAmount = accruedPremium + 1; // restore amount partially contributes to base debt

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, repayer: alice});

    //     daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // hub
    //     assertEq(
    //       hub.getTotalAssets(daiAssetId),
    //       daiAmount + accruedPremium + accruedBaseDebt,
    //       'hub dai total assets'
    //     );
    //     assertEq(daiData.outstandingPremium, 0, 'hub dai outstandingPremium');
    //     assertEq(daiData.baseDebt, accruedBaseDebt + drawAmount - 1, 'hub dai baseDebt');
    //     assertEq(
    //       daiData.availableLiquidity,
    //       daiAmount - drawAmount + restoreAmount,
    //       'hub dai availableLiquidity'
    //     );
    //     assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');

    //     assertEq(
    //       daiDebtData.asset.cumulativeDebt,
    //       accruedBaseDebt + drawAmount - 1,
    //       'asset cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.asset.baseDebt, accruedBaseDebt + drawAmount - 1, 'asset baseDebt');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');
    //     // spoke1
    //     assertEq(
    //       spoke1DaiData.outstandingPremium,
    //       daiData.outstandingPremium,
    //       'hub spoke1 outstandingPremium'
    //     );
    //     assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'hub spoke1 baseDebt');
    //     assertEq(
    //       spoke1DaiData.lastUpdateTimestamp,
    //       daiData.lastUpdateTimestamp,
    //       'hub spoke1 lastUpdateTimestamp'
    //     );
    //     assertEq(
    //       daiDebtData.spoke[0].cumulativeDebt,
    //       accruedBaseDebt + drawAmount - 1,
    //       'spoke1 cumulativeDebt'
    //     );
    //     assertEq(daiDebtData.spoke[0].baseDebt, accruedBaseDebt + drawAmount - 1, 'spoke1 baseDebt');
    //     assertEq(daiDebtData.spoke[0].outstandingPremium, 0, 'spoke1 outstandingPremium');
  }

  /// @dev Restore more than premium but partial amount to eat into base debt
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

    //     _supplyAndDrawLiquidity({
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
    //     uint256 accruedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    //     uint256 accruedPremium = accruedBaseDebt.percentMul(riskPremium);
    //     vm.assume(accruedPremium > 0);

    //     restoreAmount = bound(
    //       restoreAmount,
    //       accruedPremium + 1,
    //       accruedPremium + accruedBaseDebt + drawAmount
    //     ); // more than accrued premium, less than total debt

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, repayer: alice});

    //     daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // hub
    //     assertEq(
    //       hub.getTotalAssets(daiAssetId),
    //       daiAmount + accruedPremium + accruedBaseDebt,
    //       'hub dai total assets'
    //     );
    //     assertEq(daiData.outstandingPremium, 0, 'hub dai outstandingPremium');
    //     assertEq(
    //       daiData.baseDebt,
    //       accruedBaseDebt + drawAmount - (restoreAmount - accruedPremium), // eat into base debt after premium is consumed
    //       'hub dai baseDebt'
    //     );
    //     assertEq(
    //       daiData.availableLiquidity,
    //       daiAmount - drawAmount + restoreAmount,
    //       'hub dai availableLiquidity'
    //     );
    //     assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');
    //     assertEq(
    //       daiDebtData.asset.cumulativeDebt,
    //       accruedBaseDebt + drawAmount - (restoreAmount - accruedPremium),
    //       'asset cumulativeDebt'
    //     );
    //     assertEq(
    //       daiDebtData.asset.baseDebt,
    //       accruedBaseDebt + drawAmount - (restoreAmount - accruedPremium),
    //       'asset baseDebt'
    //     );
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');
    //     // spoke1
    //     assertEq(
    //       spoke1DaiData.outstandingPremium,
    //       daiData.outstandingPremium,
    //       'hub spoke1 outstandingPremium'
    //     );
    //     assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'hub spoke1 baseDebt');
    //     assertEq(
    //       spoke1DaiData.lastUpdateTimestamp,
    //       daiData.lastUpdateTimestamp,
    //       'hub spoke1 lastUpdateTimestamp'
    //     );
    //     assertEq(
    //       daiDebtData.spoke[0].cumulativeDebt,
    //       accruedBaseDebt + drawAmount - (restoreAmount - accruedPremium),
    //       'spoke1 cumulativeDebt'
    //     );
    //     assertEq(
    //       daiDebtData.spoke[0].baseDebt,
    //       accruedBaseDebt + drawAmount - (restoreAmount - accruedPremium),
    //       'spoke1 baseDebt'
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
    //     emit ILiquidityHub.Restore(daiAssetId, address(spoke1), restoreAmount);

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, repayer: alice});

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
    //       hubData.daiData.availableLiquidity,
    //       daiAmount - drawAmount + restoreAmount,
    //       'hub dai availableLiquidity post-restore'
    //     );
    //     assertEq(hubData.daiData.baseDebt, drawAmount - restoreAmount, 'hub dai baseDebt post-restore');
    //     assertEq(hubData.daiData.outstandingPremium, 0, 'hub dai outstandingPremium post-restore');
    //     assertEq(
    //       hubData.daiData.baseBorrowIndex,
    //       INIT_BASE_BORROW_INDEX,
    //       'hub dai baseBorrowIndex post-restore'
    //     );
    //     assertEq(hubData.daiData.baseBorrowRate, rate, 'hub dai baseBorrowRate post-restore');
    //     assertEq(hubData.daiData.riskPremium, 0, 'hub dai riskPremium post-restore');
    //     assertEq(
    //       hubData.daiData.lastUpdateTimestamp,
    //       hubData.timestamp,
    //       'hub dai lastUpdateTimestamp post-restore'
    //     );
    //     assertEq(daiDebtData.asset.cumulativeDebt, drawAmount - restoreAmount, 'asset cumulativeDebt');
    //     assertEq(daiDebtData.asset.baseDebt, drawAmount - restoreAmount, 'asset baseDebt');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');
    //     // weth
    //     assertEq(
    //       hubData.wethData.suppliedShares,
    //       hub.convertToShares(wethAssetId, wethAmount),
    //       'hub weth total shares post-restore'
    //     );
    //     assertEq(
    //       hubData.wethData.availableLiquidity,
    //       wethAmount,
    //       'hub weth availableLiquidity post-restore'
    //     );
    //     assertEq(hubData.wethData.baseDebt, 0, 'hub weth baseDebt post-restore');
    //     assertEq(hubData.wethData.outstandingPremium, 0, 'hub weth outstandingPremium post-restore');
    //     assertEq(
    //       hubData.wethData.baseBorrowIndex,
    //       INIT_BASE_BORROW_INDEX,
    //       'hub weth baseBorrowIndex post-restore'
    //     );
    //     assertEq(hubData.wethData.baseBorrowRate, rate, 'hub weth baseBorrowRate post-restore');
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
    //     assertEq(hubData.spoke1WethData.baseDebt, hubData.wethData.baseDebt, 'spoke1 base weth debt');
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
    //       hubData.spoke1DaiData.baseDebt,
    //       hubData.daiData.baseDebt,
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
    //     assertEq(daiDebtData.spoke[0].baseDebt, drawAmount - restoreAmount, 'spoke1 baseDebt');
    //     assertEq(daiDebtData.spoke[0].outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     // spoke2 dai
    //     assertEq(
    //       hubData.spoke2DaiData.suppliedShares,
    //       hubData.daiData.suppliedShares,
    //       'spoke2 total dai shares post-restore'
    //     );
    //     assertEq(hubData.spoke2DaiData.baseDebt, 0, 'spoke2 base dai debt post-restore');
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
    //     uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     assertTrue(cumulatedBaseDebt > 0);

    //     // alice restore amount = drawn amount
    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: cumulatedBaseDebt, riskPremium: 0, repayer: alice});

    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1Data = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // asset
    //     assertEq(daiData.baseDebt, 0, 'asset baseDebt');
    //     assertEq(daiData.outstandingPremium, 0, 'asset outstandingPremium');
    //     assertEq(daiDebtData.asset.cumulativeDebt, 0, 'asset cumulativeDebt');
    //     assertEq(daiDebtData.asset.baseDebt, 0, 'asset baseDebt');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');

    //     // spoke
    //     assertEq(spoke1Data.baseDebt, 0, 'spoke1 baseDebt');
    //     assertEq(spoke1Data.outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     assertEq(daiDebtData.spoke[0].cumulativeDebt, 0, 'spoke1 cumulativeDebt');
    //     assertEq(daiDebtData.spoke[0].baseDebt, 0, 'spoke1 baseDebt');
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
    //     uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     vm.assume(cumulatedBaseDebt > 0);

    //     // alice restore amount = drawn amount (no premium)

    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: cumulatedBaseDebt, riskPremium: 0, repayer: alice});

    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1Data = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // asset
    //     assertEq(daiData.baseDebt, 0, 'asset baseDebt');
    //     assertEq(daiData.outstandingPremium, 0, 'asset outstandingPremium');
    //     assertEq(daiDebtData.asset.cumulativeDebt, 0, 'asset cumulativeDebt');
    //     assertEq(daiDebtData.asset.baseDebt, 0, 'asset baseDebt');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');

    //     // spoke
    //     assertEq(spoke1Data.baseDebt, 0, 'spoke1 baseDebt');
    //     assertEq(spoke1Data.outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     assertEq(daiDebtData.spoke[0].cumulativeDebt, 0, 'spoke1 cumulativeDebt');
    //     assertEq(daiDebtData.spoke[0].baseDebt, 0, 'spoke1 baseDebt');
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
    //     uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     uint256 accruedPremium = (cumulatedBaseDebt - drawAmount).percentMul(riskPremium);
    //     assertTrue(accruedPremium > 0);

    //     // alice restore amount = drawn amount AND premium

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedBaseDebt + accruedPremium,
    //       riskPremium: 0,
    //       repayer: alice
    //     });

    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1Data = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // asset
    //     assertEq(daiData.baseDebt, 0, 'asset baseDebt');
    //     assertEq(daiData.outstandingPremium, 0, 'asset outstandingPremium');
    //     assertEq(daiDebtData.asset.cumulativeDebt, 0, 'asset cumulativeDebt');
    //     assertEq(daiDebtData.asset.baseDebt, 0, 'asset baseDebt');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');

    //     // spoke1
    //     assertEq(spoke1Data.baseDebt, 0, 'spoke1 baseDebt');
    //     assertEq(spoke1Data.outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     assertEq(daiDebtData.spoke[0].cumulativeDebt, 0, 'spoke1 cumulativeDebt');
    //     assertEq(daiDebtData.spoke[0].baseDebt, 0, 'spoke1 baseDebt');
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
    //     uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    //     uint256 accruedPremium = (cumulatedBaseDebt - drawAmount).percentMul(riskPremium);
    //     vm.assume(accruedPremium > 0); // accrued premium can round to 0 in edge case - ex. (cumulatedBaseDebt - drawAmount) = 1, riskPremium = 1

    //     // alice restore amount = drawn amount AND premium

    //     vm.prank(address(spoke1));
    //     hub.restore({
    //       assetId: daiAssetId,
    //       amount: cumulatedBaseDebt + accruedPremium,
    //       riskPremium: 0,
    //       repayer: alice
    //     });

    //     DataTypes.Asset memory daiData = hub.getAsset(daiAssetId);
    //     DataTypes.SpokeData memory spoke1Data = hub.getSpoke(daiAssetId, address(spoke1));
    //     DebtData memory daiDebtData = _getDebt(daiAssetId);

    //     // asset
    //     assertEq(daiData.baseDebt, 0, 'asset baseDebt');
    //     assertEq(daiData.outstandingPremium, 0, 'asset outstandingPremium');
    //     assertEq(daiDebtData.asset.cumulativeDebt, 0, 'asset cumulativeDebt');
    //     assertEq(daiDebtData.asset.baseDebt, 0, 'asset baseDebt');
    //     assertEq(daiDebtData.asset.outstandingPremium, 0, 'asset outstandingPremium');

    //     // spoke
    //     assertEq(spoke1Data.baseDebt, 0, 'spoke1 baseDebt');
    //     assertEq(spoke1Data.outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     assertEq(daiDebtData.spoke[0].cumulativeDebt, 0, 'spoke1 cumulativeDebt');
    //     assertEq(daiDebtData.spoke[0].baseDebt, 0, 'spoke1 baseDebt');
    //     assertEq(daiDebtData.spoke[0].outstandingPremium, 0, 'spoke1 outstandingPremium');
  }
}
