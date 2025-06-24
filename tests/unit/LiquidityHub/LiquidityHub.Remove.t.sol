// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBase.t.sol';

contract LiquidityHubRemoveTest is LiquidityHubBase {
  // using SharesMath for uint256;
  using WadRayMathExtended for uint256;

  function test_removef() public {
    uint256 amount = 100e18;

    // User supply
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: amount,
      user: alice,
      to: address(spoke1)
    });

    AssetPosition memory asset = getAssetPosition(hub, daiAssetId);
    ReservePosition memory reserve = getReservePosition(spoke1, _daiReserveId);

    // hub
    assertEq(asset.suppliedAmount, amount, 'hub supplied assets before');
    assertEq(
      asset.suppliedShares,
      hub.convertToSuppliedShares(daiAssetId, amount),
      'asset supplied shares before'
    );
    assertEq(asset.availableLiquidity, amount, 'asset availableLiquidity before');
    assertEq(asset.baseDebt, 0, 'asset baseDebt before');
    assertEq(asset.premiumDebt, 0, 'asset premiumDebt before');
    assertEq(asset.baseDebtIndex, WadRayMathExtended.RAY, 'asset baseDebtIndex before');
    assertEq(asset.baseBorrowRate, uint256(5_00).bpsToRay(), 'asset baseBorrowRate before');
    assertEq(asset.lastUpdateTimestamp, vm.getBlockTimestamp(), 'asset lastUpdateTimestamp before');
    // spoke
    assertEq(reserve.suppliedShares, asset.suppliedShares, 'reserve suppliedShares before');
    assertEq(reserve.suppliedAmount, asset.suppliedAmount, 'reserve suppliedAmount before');
    assertEq(reserve.baseDebt, asset.baseDebt, 'reserve baseDebt before');
    assertEq(reserve.premiumDebt, asset.premiumDebt, 'reserve premiumDebt before');
    assertEq(reserve.timestamp, asset.lastUpdateTimestamp, 'reserve timestamp before');
    // dai
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance before');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance before');
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount,
      'user token balance before'
    );

    vm.expectEmit(address(tokenList.dai));
    emit IERC20.Transfer(address(hub), alice, amount);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Remove(
      daiAssetId,
      address(spoke1),
      hub.convertToSuppliedSharesUp(daiAssetId, amount),
      amount
    );

    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount, alice);

    asset = getAssetPosition(hub, daiAssetId);
    reserve = getReservePosition(spoke1, _daiReserveId);

    // hub
    assertEq(asset.suppliedAmount, 0, 'asset supplied amount after');
    assertEq(asset.suppliedShares, 0, 'asset supplied shares after');
    assertEq(asset.availableLiquidity, 0, 'asset availableLiquidity after');
    assertEq(asset.baseDebt, 0, 'asset baseDebt after');
    assertEq(asset.premiumDebt, 0, 'asset premiumDebt after');
    assertEq(asset.baseDebtIndex, WadRayMathExtended.RAY, 'asset baseBorrowIndex after');
    assertEq(asset.baseBorrowRate, uint256(5_00).bpsToRay(), 'asset baseBorrowRate after');
    assertEq(asset.lastUpdateTimestamp, vm.getBlockTimestamp(), 'asset lastUpdateTimestamp after');
    // spoke
    assertEq(reserve.suppliedShares, asset.suppliedShares, 'reserve suppliedShares after');
    assertEq(reserve.baseDebt, asset.baseDebt, 'reserve baseDebt after');
    assertEq(reserve.premiumDebt, asset.premiumDebt, 'reserve premiumDebt after');
    assertEq(reserve.timestamp, asset.lastUpdateTimestamp, 'reserve timestamp after');
    // dai
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance after');
    assertEq(tokenList.dai.balanceOf(alice), MAX_SUPPLY_AMOUNT, 'user token balance after');
  }

  // single asset, multiple spokes supplied. No drawn
  function test_remove_fuzz_multi_spoke(
    uint256 amount,
    uint256 amount2,
    uint32 riskPremium
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 assetId = 0;
    //     amount = bound(amount, 1, MAX_SUPPLY_AMOUNT - 1);
    //     amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT - amount);
    //     riskPremium %= MAX_RISK_PREMIUM_BPS; // no effect on withdraw because no drawn

    //     IERC20 asset = hub.assetsList(assetId);

    //     Utils.supply({
    //       hub: hub,
    //       assetId: assetId,
    //       spoke: address(spoke1),
    //       amount: amount,
    //       riskPremium: riskPremium,
    //       user: alice,
    //       to: address(spoke1)
    //     });
    //     Utils.supply({
    //       hub: hub,
    //       assetId: assetId,
    //       spoke: address(spoke2),
    //       amount: amount2,
    //       riskPremium: riskPremium,
    //       user: alice,
    //       to: address(spoke2)
    //     });

    //     Utils.withdraw({
    //       hub: hub,
    //       assetId: assetId,
    //       spoke: address(spoke1),
    //       amount: amount,
    //       riskPremium: 0,
    //       to: alice
    //     });
    //     Utils.withdraw({
    //       hub: hub,
    //       assetId: assetId,
    //       spoke: address(spoke2),
    //       amount: amount2,
    //       riskPremium: 0,
    //       to: alice
    //     });

    //     DataTypes.Asset memory assetData = hub.getAsset(assetId);
    //     DataTypes.SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));
    //     DataTypes.SpokeData memory spoke2Data = hub.getSpoke(assetId, address(spoke2));

    //     // hub
    //     assertEq(hub.getTotalAssets(assetId), 0, 'hub total assets after');
    //     // asset
    //     assertEq(assetData.suppliedShares, 0, 'asset total shares after');
    //     assertEq(assetData.availableLiquidity, 0, 'asset availableLiquidity after');
    //     assertEq(assetData.baseDebt, 0, 'asset baseDebt after');
    //     assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium after');
    //     assertEq(assetData.baseBorrowIndex, WadRayMathExtended.RAY, 'asset baseBorrowIndex after');
    //     assertEq(
    //       assetData.baseBorrowRate,
    //       uint256(5_00).bpsToRay(),
    //       'asset baseBorrowRate after'
    //     );
    //     assertEq(assetData.riskPremium, 0, 'asset riskPremium after');
    //     assertEq(
    //       assetData.lastUpdateTimestamp,
    //       vm.getBlockTimestamp(),
    //       'asset lastUpdateTimestamp after'
    //     );
    //     // spoke
    //     assertEq(
    //       spokeData.suppliedShares,
    //       assetData.suppliedShares,
    //       'spoke suppliedShares after'
    //     );
    //     assertEq(spokeData.baseDebt, assetData.baseDebt, 'spoke baseDebt after');
    //     assertEq(
    //       spokeData.outstandingPremium,
    //       assetData.outstandingPremium,
    //       'spoke outstandingPremium after'
    //     );
    //     assertEq(
    //       spokeData.baseBorrowIndex,
    //       assetData.baseBorrowIndex,
    //       'spoke baseBorrowIndex after'
    //     );
    //     assertEq(spokeData.riskPremium, 0, 'spoke riskPremium after');
    //     assertEq(
    //       spokeData.lastUpdateTimestamp,
    //       assetData.lastUpdateTimestamp,
    //       'spoke lastUpdateTimestamp after'
    //     );
    //     // spoke
    //     assertEq(
    //       spoke2Data.suppliedShares,
    //       assetData.suppliedShares,
    //       'spoke suppliedShares after'
    //     );
    //     assertEq(spoke2Data.baseDebt, assetData.baseDebt, 'spoke baseDebt after');
    //     assertEq(
    //       spoke2Data.outstandingPremium,
    //       assetData.outstandingPremium,
    //       'spoke outstandingPremium after'
    //     );
    //     assertEq(
    //       spoke2Data.baseBorrowIndex,
    //       assetData.baseBorrowIndex,
    //       'spoke baseBorrowIndex after'
    //     );
    //     assertEq(spoke2Data.riskPremium, 0, 'spoke riskPremium after');
    //     assertEq(
    //       spoke2Data.lastUpdateTimestamp,
    //       assetData.lastUpdateTimestamp,
    //       'spoke lastUpdateTimestamp after'
    //     );
    //     // asset
    //     assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke1 token balance after');
    //     assertEq(asset.balanceOf(address(spoke2)), 0, 'spoke2 token balance after');
    //     assertEq(asset.balanceOf(address(hub)), 0, 'hub token balance after');
    //     assertEq(asset.balanceOf(alice), MAX_SUPPLY_AMOUNT, 'user token balance after');
  }

  function test_remove_fuzz(uint256 assetId, uint256 amount) public {
    vm.skip(true, 'pending refactor');

    //     assetId = bound(assetId, 0, hub.assetCount() - 2); // Exclude duplicated DAI
    //     amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    //     IERC20 asset = hub.assetsList(assetId);

    //     Utils.supply({
    //       hub: hub,
    //       assetId: assetId,
    //       spoke: address(spoke1),
    //       amount: amount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     DataTypes.Asset memory assetData = hub.getAsset(assetId);
    //     DataTypes.SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));

    //     uint256 timestamp = vm.getBlockTimestamp();

    //     // hub
    //     assertEq(hub.getTotalAssets(assetId), amount, 'hub total assets before');
    //     // asset
    //     assertEq(
    //       assetData.suppliedShares,
    //       hub.convertToShares(assetId, amount),
    //       'asset total shares before'
    //     );
    //     assertEq(assetData.availableLiquidity, amount, 'asset availableLiquidity before');
    //     assertEq(assetData.baseDebt, 0, 'asset baseDebt before');
    //     assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium before');
    //     assertEq(assetData.baseBorrowIndex, WadRayMathExtended.RAY, 'asset baseBorrowIndex before');
    //     assertEq(
    //       assetData.baseBorrowRate,
    //       uint256(5_00).bpsToRay(),
    //       'asset baseBorrowRate before'
    //     );
    //     assertEq(assetData.riskPremium, 0, 'asset riskPremium before');
    //     assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp before');
    //     // spoke
    //     assertEq(
    //       spokeData.suppliedShares,
    //       assetData.suppliedShares,
    //       'spoke suppliedShares before'
    //     );
    //     assertEq(spokeData.baseDebt, assetData.baseDebt, 'spoke baseDebt before');
    //     assertEq(
    //       spokeData.outstandingPremium,
    //       assetData.outstandingPremium,
    //       'spoke outstandingPremium before'
    //     );
    //     assertEq(
    //       spokeData.baseBorrowIndex,
    //       assetData.baseBorrowIndex,
    //       'spoke baseBorrowIndex before'
    //     );
    //     assertEq(spokeData.riskPremium, 0, 'spoke riskPremium before');
    //     assertEq(
    //       spokeData.lastUpdateTimestamp,
    //       assetData.lastUpdateTimestamp,
    //       'spoke lastUpdateTimestamp before'
    //     );
    //     // asset
    //     assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance before');
    //     assertEq(asset.balanceOf(address(hub)), amount, 'hub token balance before');
    //     assertEq(
    //       asset.balanceOf(alice),
    //       MAX_SUPPLY_AMOUNT - amount,
    //       'alice token balance before'
    //     );

    //     vm.expectEmit(address(asset));
    //     emit IERC20.Transfer(address(hub), alice, amount);

    //     vm.expectEmit(address(hub));
    //     emit ILiquidityHub.Withdraw(assetId, address(spoke1), alice, amount);

    //     Utils.withdraw({
    //       hub: hub,
    //       assetId: assetId,
    //       spoke: address(spoke1),
    //       amount: amount,
    //       riskPremium: 0,
    //       to: alice
    //     });

    //     assetData = hub.getAsset(assetId);
    //     spokeData = hub.getSpoke(assetId, address(spoke1));

    //     // hub
    //     assertEq(hub.getTotalAssets(assetId), 0, 'hub total assets after');
    //     // asset
    //     assertEq(assetData.suppliedShares, 0, 'asset total shares after');
    //     assertEq(assetData.availableLiquidity, 0, 'asset availableLiquidity after');
    //     assertEq(assetData.baseDebt, 0, 'asset baseDebt after');
    //     assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium after');
    //     assertEq(assetData.baseBorrowIndex, WadRayMathExtended.RAY, 'asset baseBorrowIndex after');
    //     assertEq(
    //       assetData.baseBorrowRate,
    //       uint256(5_00).bpsToRay(),
    //       'asset baseBorrowRate after'
    //     );
    //     assertEq(assetData.riskPremium, 0, 'asset riskPremium after');
    //     assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp after');
    //     // spoke
    //     assertEq(
    //       spokeData.suppliedShares,
    //       assetData.suppliedShares,
    //       'spoke suppliedShares after'
    //     );
    //     assertEq(spokeData.baseDebt, assetData.baseDebt, 'spoke baseDebt after');
    //     assertEq(
    //       spokeData.outstandingPremium,
    //       assetData.outstandingPremium,
    //       'spoke outstandingPremium after'
    //     );
    //     assertEq(
    //       spokeData.baseBorrowIndex,
    //       assetData.baseBorrowIndex,
    //       'spoke baseBorrowIndex after'
    //     );
    //     assertEq(spokeData.riskPremium, 0, 'spoke riskPremium after');
    //     assertEq(
    //       spokeData.lastUpdateTimestamp,
    //       assetData.lastUpdateTimestamp,
    //       'spoke lastUpdateTimestamp after'
    //     );
    //     // asset
    //     assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance after');
    //     assertEq(asset.balanceOf(address(hub)), 0, 'hub token balance after');
    //     assertEq(asset.balanceOf(alice), MAX_SUPPLY_AMOUNT, 'alice token balance after');
  }

  function test_remove_all_with_interest() public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;
    //     uint256 drawAmount = daiAmount / 2;
    //     uint32 riskPremium = 20_00;
    //     uint256 lastUpdateTimestamp = vm.getBlockTimestamp();
    //     uint256 rate = uint256(10_00).bpsToRay();

    //     _supplyAndDrawLiquidity({
    //       daiAmount: daiAmount,
    //       wethAmount: wethAmount,
    //       daiDrawAmount: drawAmount,
    //       riskPremium: riskPremium,
    //       rate: rate
    //     });

    //     skip(365 days);

    //     HubData memory hubData;
    //     hubData.daiData = hub.getAsset(daiAssetId);

    //     uint256 initialAvailableLiquidity = hubData.daiData.availableLiquidity;
    //     uint256 supply2Amount = 10e18;

    //     // bob supplies more DAI to trigger accrual
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: supply2Amount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     hubData.daiData1 = hub.getAsset(daiAssetId);

    //     uint256 restoreAmount = hubData.daiData1.baseDebt + hubData.daiData1.outstandingPremium;
    //     uint256 newBaseBorrowIndex = WadRayMathExtended.RAY +
    //       WadRayMathExtended.RAY.rayMul(
    //         MathUtils.calculateLinearInterest(
    //           hubData.daiData1.baseBorrowRate,
    //           uint40(lastUpdateTimestamp)
    //         ) - WadRayMathExtended.RAY
    //       );

    //     // alice restores all debt including accrual
    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, repayer: alice});

    //     hubData.daiData2 = hub.getAsset(daiAssetId);
    //     assertEq(
    //       hubData.daiData2.availableLiquidity,
    //       initialAvailableLiquidity + restoreAmount + supply2Amount,
    //       'dai availableLiquidity'
    //     );

    //     // bob withdraws all liquidity with interest
    //     vm.prank(address(spoke2));
    //     hub.withdraw({
    //       assetId: daiAssetId,
    //       amount: hubData.daiData2.availableLiquidity,
    //       riskPremium: 0,
    //       to: bob
    //     });

    //     assertEq(
    //       tokenList.dai.balanceOf(bob),
    //       MAX_SUPPLY_AMOUNT + hubData.daiData2.availableLiquidity - supply2Amount - daiAmount,
    //       'bob dai balance'
    //     );

    //     hubData.daiData3 = hub.getAsset(daiAssetId);
    //     hubData.spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    //     hubData.spoke2DaiData = hub.getSpoke(daiAssetId, address(spoke2));

    //     // hub
    //     assertEq(hub.getTotalAssets(daiAssetId), 0, 'hub totalAssets');
    //     assertEq(hubData.daiData3.suppliedShares, 0, 'dai suppliedShares');
    //     assertEq(hubData.daiData3.availableLiquidity, 0, 'dai availableLiquidity');
    //     assertEq(hubData.daiData3.baseDebt, 0, 'dai baseDebt');
    //     assertEq(hubData.daiData3.outstandingPremium, 0, 'dai outstandingPremium');
    //     assertEq(hubData.daiData3.baseBorrowIndex, newBaseBorrowIndex, 'dai baseBorrowIndex');
    //     assertEq(hubData.daiData3.baseBorrowRate, rate, 'dai baseBorrowRate');
    //     assertEq(hubData.daiData3.riskPremium, 0, 'dai riskPremium');
    //     assertEq(
    //       hubData.daiData3.lastUpdateTimestamp,
    //       vm.getBlockTimestamp(),
    //       'dai lastUpdateTimestamp'
    //     );
    //     // spoke1
    //     assertEq(hubData.spoke1DaiData.suppliedShares, 0, 'spoke1 suppliedShares');
    //     assertEq(hubData.spoke1DaiData.baseDebt, 0, 'spoke1 baseDebt');
    //     assertEq(hubData.spoke1DaiData.outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     assertEq(hubData.spoke1DaiData.baseBorrowIndex, newBaseBorrowIndex, 'spoke1 baseBorrowIndex');
    //     assertEq(hubData.spoke1DaiData.riskPremium, 0, 'spoke1 riskPremium');
    //     assertEq(
    //       hubData.spoke1DaiData.lastUpdateTimestamp,
    //       vm.getBlockTimestamp(),
    //       'spoke1 lastUpdateTimestamp'
    //     );
    //     // spoke2
    //     assertEq(hubData.spoke2DaiData.suppliedShares, 0, 'spoke2 suppliedShares');
    //     assertEq(hubData.spoke2DaiData.baseDebt, 0, 'spoke2 baseDebt');
    //     assertEq(hubData.spoke2DaiData.outstandingPremium, 0, 'spoke2 outstandingPremium');
    //     assertEq(hubData.spoke2DaiData.baseBorrowIndex, newBaseBorrowIndex, 'spoke2 baseBorrowIndex');
    //     assertEq(hubData.spoke2DaiData.riskPremium, 0, 'spoke2 riskPremium');
    //     assertEq(
    //       hubData.spoke2DaiData.lastUpdateTimestamp,
    //       vm.getBlockTimestamp(),
    //       'spoke2 lastUpdateTimestamp'
    //     );
    //     // dai - all to alice
    //     assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai balance');
    //     assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai balance');
    //     assertEq(
    //       tokenList.dai.balanceOf(alice),
    //       MAX_SUPPLY_AMOUNT + drawAmount - restoreAmount,
    //       'alice dai balance'
    //     );
  }

  function test_remove_fuzz_all_liquidity_with_interest(
    uint256 drawAmount,
    uint32 riskPremium,
    uint256 rate,
    uint256 skipTime
  ) public {
    vm.skip(true, 'pending refactor');

    //     uint256 daiAmount = 100e18;
    //     uint256 wethAmount = 10e18;

    //     drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    //     skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 day to 10 years
    //     rate = bound(rate, 0, 200_00).bpsToRay(); // .1% to 200%
    //     riskPremium %= MAX_RISK_PREMIUM_BPS;

    //     uint256 lastUpdateTimestamp = vm.getBlockTimestamp();

    //     _supplyAndDrawLiquidity({
    //       daiAmount: daiAmount,
    //       wethAmount: wethAmount,
    //       daiDrawAmount: drawAmount,
    //       riskPremium: riskPremium,
    //       rate: rate
    //     });

    //     skip(skipTime);
    //     HubData memory hubData;
    //     hubData.daiData = hub.getAsset(daiAssetId);

    //     hubData.accruedBase = hubData.daiData.baseDebt.rayMul(rate);
    //     hubData.initialAvailableLiquidity = hubData.daiData.availableLiquidity;
    //     hubData.initialSupplyShares = hubData.daiData.suppliedShares;

    //     hubData.supply2Amount = 10e18;
    //     hubData.expectedSupply2Shares = hubData.supply2Amount.toSharesDown(
    //       hub.getTotalAssets(daiAssetId) + hubData.accruedBase,
    //       hubData.daiData.suppliedShares
    //     );

    //     // bob supplies more DAI to trigger accrual
    //     Utils.supply({
    //       hub: hub,
    //       assetId: daiAssetId,
    //       spoke: address(spoke2),
    //       amount: hubData.supply2Amount,
    //       riskPremium: 0,
    //       user: bob,
    //       to: address(spoke2)
    //     });

    //     hubData.daiData = hub.getAsset(daiAssetId);

    //     uint256 restoreAmount = hubData.daiData.baseDebt + hubData.daiData.outstandingPremium;
    //     uint256 newBaseBorrowIndex = WadRayMathExtended.RAY +
    //       WadRayMathExtended.RAY.rayMul(
    //         MathUtils.calculateLinearInterest(
    //           hubData.daiData.baseBorrowRate,
    //           uint40(lastUpdateTimestamp)
    //         ) - WadRayMathExtended.RAY
    //       );

    //     // alice restores all debt including accrual
    //     vm.prank(address(spoke1));
    //     hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, repayer: alice});

    //     hubData.daiData = hub.getAsset(daiAssetId);
    //     assertEq(
    //       hubData.daiData.availableLiquidity,
    //       hubData.initialAvailableLiquidity + restoreAmount + hubData.supply2Amount,
    //       'dai availableLiquidity'
    //     );

    //     // bob withdraws all liquidity with interest
    //     vm.prank(address(spoke2));
    //     hub.withdraw({
    //       assetId: daiAssetId,
    //       amount: hubData.daiData.availableLiquidity,
    //       riskPremium: 0,
    //       to: bob
    //     });

    //     assertEq(
    //       tokenList.dai.balanceOf(bob),
    //       MAX_SUPPLY_AMOUNT + hubData.daiData.availableLiquidity - hubData.supply2Amount - daiAmount,
    //       'bob dai balance'
    //     );

    //     hubData.daiData = hub.getAsset(daiAssetId);
    //     hubData.spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    //     hubData.spoke2DaiData = hub.getSpoke(daiAssetId, address(spoke2));

    //     // hub
    //     assertEq(hub.getTotalAssets(daiAssetId), 0, 'hub totalAssets');
    //     assertEq(hubData.daiData.suppliedShares, 0, 'dai suppliedShares');
    //     assertEq(hubData.daiData.availableLiquidity, 0, 'dai availableLiquidity');
    //     assertEq(hubData.daiData.baseDebt, 0, 'dai baseDebt');
    //     assertEq(hubData.daiData.outstandingPremium, 0, 'dai outstandingPremium');
    //     assertEq(hubData.daiData.baseBorrowIndex, newBaseBorrowIndex, 'dai baseBorrowIndex');
    //     assertEq(hubData.daiData.baseBorrowRate, rate, 'dai baseBorrowRate');
    //     assertEq(hubData.daiData.riskPremium, 0, 'dai riskPremium');
    //     assertEq(
    //       hubData.daiData.lastUpdateTimestamp,
    //       vm.getBlockTimestamp(),
    //       'dai lastUpdateTimestamp'
    //     );
    //     // spoke1
    //     assertEq(hubData.spoke1DaiData.suppliedShares, 0, 'spoke1 suppliedShares');
    //     assertEq(hubData.spoke1DaiData.baseDebt, 0, 'spoke1 baseDebt');
    //     assertEq(hubData.spoke1DaiData.outstandingPremium, 0, 'spoke1 outstandingPremium');
    //     assertEq(hubData.spoke1DaiData.baseBorrowIndex, newBaseBorrowIndex, 'spoke1 baseBorrowIndex');
    //     assertEq(hubData.spoke1DaiData.riskPremium, 0, 'spoke1 riskPremium');
    //     assertEq(
    //       hubData.spoke1DaiData.lastUpdateTimestamp,
    //       vm.getBlockTimestamp(),
    //       'spoke1 lastUpdateTimestamp'
    //     );
    //     // spoke2
    //     assertEq(hubData.spoke2DaiData.suppliedShares, 0, 'spoke2 suppliedShares');
    //     assertEq(hubData.spoke2DaiData.baseDebt, 0, 'spoke2 baseDebt');
    //     assertEq(hubData.spoke2DaiData.outstandingPremium, 0, 'spoke2 outstandingPremium');
    //     assertEq(hubData.spoke2DaiData.baseBorrowIndex, newBaseBorrowIndex, 'spoke2 baseBorrowIndex');
    //     assertEq(hubData.spoke2DaiData.riskPremium, 0, 'spoke2 riskPremium');
    //     assertEq(
    //       hubData.spoke2DaiData.lastUpdateTimestamp,
    //       vm.getBlockTimestamp(),
    //       'spoke2 lastUpdateTimestamp'
    //     );
    //     // dai - all to alice
    //     assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai balance');
    //     assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai balance');
    //     assertEq(
    //       tokenList.dai.balanceOf(alice),
    //       MAX_SUPPLY_AMOUNT + drawAmount - restoreAmount,
    //       'alice dai balance'
    //     );
  }

  function test_remove_revertsWith_SuppliedAmountExceeded_zero_supplied() public {
    uint256 amount = 1;

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SuppliedAmountExceeded.selector, 0));
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount, address(spoke1));
  }

  function test_remove_revertsWith_SuppliedAmountExceeded() public {
    uint256 assetId = daiAssetId;
    uint256 amount = 100e18;

    // User supply
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: amount,
      user: alice,
      to: address(spoke1)
    });

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SuppliedAmountExceeded.selector, amount));
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount + 1, alice);

    // advance time, but no accrual
    skip(1e18);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SuppliedAmountExceeded.selector, amount));
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount + 1, alice);
  }

  function test_remove_revertsWith_NotAvailableLiquidity() public {
    uint256 amount = 100e18;
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: amount,
      user: alice,
      to: address(spoke1)
    });
    // spoke1 draw all of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: amount,
      to: alice,
      onBehalfOf: address(spoke1)
    });
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount, address(spoke1));
  }

  function test_remove_revertsWith_InvalidRemoveAmount() public {
    vm.expectRevert(ILiquidityHub.InvalidRemoveAmount.selector);
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, 0, alice);
  }

  function test_remove_revertsWith_AssetNotActive() public {
    uint256 amount = 100e18;
    updateAssetActive(hub, daiAssetId, false);

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount, alice);
  }

  function test_remove_revertsWith_AssetPaused() public {
    uint256 amount = 100e18;
    updateAssetPaused(hub, daiAssetId, true);

    vm.expectRevert(ILiquidityHub.AssetPaused.selector);
    vm.prank(address(spoke1));
    hub.remove(daiAssetId, amount, alice);
  }
}
