// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBase.t.sol';

contract LiquidityHubRestoreTest is LiquidityHubBase {
  using WadRayMathExtended for uint256;

  function test_restore_revertsWith_SurplusAmountRestored() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;

    // spoke1 supply weth
    Utils.add({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: drawAmount,
      onBehalfOf: address(spoke1)
    });

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(daiAssetId, address(spoke1));

    // alice restore invalid amount > baseDebt
    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.SurplusAmountRestored.selector, drawAmount)
    );

    vm.prank(address(spoke1));
    hub.restore(daiAssetId, baseDebt + 1, premiumDebt, alice);
  }

  function test_restore_revertsWith_InvalidRestoreAmount_zero() public {
    vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);

    vm.prank(address(spoke1));
    hub.restore(daiAssetId, 0, 0, alice);
  }

  function test_restore_revertsWith_AssetNotActive() public {
    updateAssetActive(hub, daiAssetId, false);

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(address(spoke1));
    hub.restore(daiAssetId, 1, 0, alice);
  }

  function test_restore_revertsWith_AssetPaused() public {
    updateAssetPaused(hub, daiAssetId, true);

    vm.expectRevert(ILiquidityHub.AssetPaused.selector);
    vm.prank(address(spoke1));
    hub.restore(daiAssetId, 1, 0, alice);
  }

  function test_restore_revertsWith_SurplusAmountRestored_with_interest() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;
    uint256 skipTime = 365 days / 2;

    // spoke1 supply weth
    Utils.add({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: drawAmount,
      onBehalfOf: address(spoke1)
    });

    ReservePosition memory spoke1DaiData = getReservePosition(spoke1, _daiReserveId);

    skip(skipTime);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(daiAssetId, address(spoke1));
    assertEq(premiumDebt, 0);

    // alice restore invalid amount > drawn amount (no premium)
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SurplusAmountRestored.selector, baseDebt));

    vm.prank(address(spoke1));
    hub.restore(daiAssetId, baseDebt + 1, premiumDebt, alice);
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
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;
    uint256 skipTime = 365 days / 2;

    // spoke1 supply weth
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      user: alice,
      amount: wethAmount,
      onBehalfOf: alice
    });

    // spoke2 supply dai
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: daiAmount,
      onBehalfOf: bob
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: alice,
      amount: drawAmount,
      onBehalfOf: alice
    });

    ReservePosition memory spoke1DaiData = getReservePosition(spoke1, _daiReserveId);

    skip(skipTime);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(daiAssetId, address(spoke1));
    assertGt(premiumDebt, 0);

    // alice restore invalid amount > baseDebt; premiumDebt settled separately
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SurplusAmountRestored.selector, baseDebt));

    vm.prank(address(spoke1));
    hub.restore({
      assetId: daiAssetId,
      baseAmount: baseDebt + 1,
      premiumAmount: premiumDebt,
      from: alice
    });
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
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;

    // spoke1 add weth
    Utils.add({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity on behalf of user
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: drawAmount,
      onBehalfOf: address(spoke1)
    });

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(daiAssetId, address(spoke1));
    uint256 baseDebtRestored = baseDebt / 2;
    uint256 restoreAmount = baseDebtRestored + premiumDebt;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.Restore(
      daiAssetId,
      address(spoke1),
      hub.convertToDrawnShares(daiAssetId, baseDebtRestored),
      baseDebtRestored + premiumDebt
    );

    vm.prank(address(spoke1));
    hub.restore(daiAssetId, baseDebtRestored, premiumDebt, alice);

    HubData memory hubData;
    hubData.daiData = getAssetPosition(hub, daiAssetId);
    hubData.wethData = getAssetPosition(hub, wethAssetId);
    hubData.spoke1WethData = getReservePosition(spoke1, _wethReserveId);
    hubData.spoke1DaiData = getReservePosition(spoke1, _daiReserveId);
    hubData.spoke2DaiData = getReservePosition(spoke2, _daiReserveId);

    // hub
    // dai
    assertEq(hubData.daiData.suppliedAmount, daiAmount, 'hub dai total assets post-restore');
    assertEq(
      hubData.daiData.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, daiAmount),
      'hub dai total shares post-restore'
    );
    assertEq(
      hubData.daiData.availableLiquidity,
      daiAmount - drawAmount + restoreAmount,
      'hub dai availableLiquidity post-restore'
    );
    assertEq(hubData.daiData.baseDebt, drawAmount - restoreAmount, 'hub dai baseDebt post-restore');
    assertEq(hubData.daiData.premiumDebt, 0, 'hub dai premiumDebt post-restore');
    assertEq(
      hubData.daiData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'hub dai lastUpdateTimestamp post-restore'
    );
    // weth
    assertEq(hubData.wethData.suppliedAmount, wethAmount, 'hub weth total assets post-restore');
    assertEq(
      hubData.wethData.suppliedShares,
      hub.convertToSuppliedShares(wethAssetId, wethAmount),
      'hub weth total shares post-restore'
    );
    assertEq(
      hubData.wethData.availableLiquidity,
      wethAmount,
      'hub weth availableLiquidity post-restore'
    );
    assertEq(hubData.wethData.baseDebt, 0, 'hub weth baseDebt post-restore');
    assertEq(hubData.wethData.premiumDebt, 0, 'hub weth premiumDebt post-restore');
    assertEq(
      hubData.wethData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'hub weth lastUpdateTimestamp post-restore'
    );
    // spoke1 weth
    assertEq(hubData.spoke1WethData, hubData.wethData);
    // spoke1 dai
    assertEq(hubData.spoke1DaiData.suppliedShares, 0, 'spoke1 total dai shares post-restore');
    assertEq(
      hubData.spoke1DaiData.baseDebt,
      hubData.daiData.baseDebt,
      'spoke1 base dai debt post-restore'
    );
    assertEq(
      hubData.spoke1DaiData.premiumDebt,
      hubData.daiData.premiumDebt,
      'spoke1 dai premiumDebt post-restore'
    );
    assertEq(
      hubData.spoke1DaiData.timestamp,
      hubData.daiData.lastUpdateTimestamp,
      'spoke1 dai timestamp post-restore'
    );
    // spoke2 dai
    assertEq(
      hubData.spoke2DaiData.suppliedShares,
      hubData.daiData.suppliedShares,
      'spoke2 total dai shares post-restore'
    );
    assertEq(hubData.spoke2DaiData.baseDebt, 0, 'spoke2 base dai debt post-restore');
    assertEq(
      hubData.spoke2DaiData.premiumDebt,
      hubData.daiData.premiumDebt,
      'spoke2 dai premiumDebt post-restore'
    );
    assertEq(
      hubData.spoke2DaiData.timestamp,
      hubData.daiData.lastUpdateTimestamp,
      'spoke2 dai timestamp post-restore'
    );

    IERC20 dai = IERC20(hub.getAsset(daiAssetId).underlying);
    IERC20 weth = IERC20(hub.getAsset(wethAssetId).underlying);

    // token balance
    // dai
    assertEq(dai.balanceOf(address(hub)), daiAmount - restoreAmount, 'hub dai final balance');
    assertEq(
      dai.balanceOf(alice),
      drawAmount - restoreAmount + MAX_SUPPLY_AMOUNT,
      'alice dai final balance'
    );
    assertEq(dai.balanceOf(bob), MAX_SUPPLY_AMOUNT - daiAmount, 'bob dai final balance');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'spoke1 dai final balance');
    assertEq(dai.balanceOf(address(spoke2)), 0, 'spoke2 dai final balance');
    // weth
    assertEq(weth.balanceOf(address(hub)), wethAmount, 'hub weth final balance');
    assertEq(weth.balanceOf(alice), MAX_SUPPLY_AMOUNT - wethAmount, 'alice weth final balance');
    assertEq(weth.balanceOf(bob), MAX_SUPPLY_AMOUNT, 'bob weth final balance');
    assertEq(weth.balanceOf(address(spoke1)), 0, 'spoke1 weth final balance');
    assertEq(weth.balanceOf(address(spoke2)), 0, 'spoke2 weth final balance');
  }

  function test_restore_full_amount_with_interest() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;
    uint256 skipTime = 365 days / 2;

    // spoke1 supply weth
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      amount: wethAmount,
      user: alice,
      onBehalfOf: alice
    });

    // spoke2 supply dai
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      amount: daiAmount,
      user: bob,
      onBehalfOf: bob
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: drawAmount,
      onBehalfOf: address(spoke1)
    });

    ReservePosition memory spoke1DaiData = getReservePosition(spoke1, _daiReserveId);

    skip(skipTime);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(daiAssetId, address(spoke1));

    // spoke1 restore full base debt
    vm.prank(address(spoke1));
    hub.restore(daiAssetId, baseDebt, premiumDebt, alice);

    AssetPosition memory daiData = getAssetPosition(hub, daiAssetId);
    ReservePosition memory spoke1Data = getReservePosition(spoke1, _daiReserveId);
    address daiFeeReceiver = _getFeeReceiver(daiAssetId);
    address wethFeeReceiver = _getFeeReceiver(wethAssetId);

    // asset
    assertEq(daiData.baseDebt, 0, 'asset baseDebt');
    assertEq(daiData.premiumDebt, 0, 'asset outstandingPremium');

    // spoke
    assertApproxEqAbs(
      daiData.suppliedAmount,
      hub.getSpokeSuppliedAmount(daiAssetId, daiFeeReceiver) +
        hub.getSpokeSuppliedAmount(daiAssetId, address(spoke2)),
      1,
      'spoke suppliedAmount'
    );
    assertApproxEqAbs(
      daiData.suppliedShares,
      hub.getSpokeSuppliedShares(daiAssetId, daiFeeReceiver) +
        hub.getSpokeSuppliedShares(daiAssetId, address(spoke2)),
      1,
      'spoke suppliedShares'
    );
    assertEq(spoke1Data.baseDebt, 0, 'spoke1 baseDebt');
    assertEq(spoke1Data.premiumDebt, 0, 'spoke1 premiumDebt');
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
