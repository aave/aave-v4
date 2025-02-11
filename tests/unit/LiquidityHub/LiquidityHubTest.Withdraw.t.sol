// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {Asset, SpokeData} from 'src/contracts/LiquidityHub.sol';

contract LiquidityHubWithdrawTest is LiquidityHubBaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function test_withdraw() public {
    uint256 amount = 100e18;

    // User supply
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    Asset memory assetData = hub.getAsset(daiAssetId);
    SpokeData memory spokeData = hub.getSpoke(daiAssetId, address(spoke1));

    uint256 timestamp = vm.getBlockTimestamp();

    // hub
    assertEq(hub.getTotalAssets(daiAssetId), amount, 'hub total assets pre-withdraw');
    // asset
    assertEq(
      assetData.suppliedShares,
      hub.convertToSharesUp(daiAssetId, amount),
      'asset total shares pre-withdraw'
    );
    assertEq(assetData.availableLiquidity, amount, 'asset availableLiquidity pre-withdraw');
    assertEq(assetData.baseDebt, 0, 'asset baseDebt pre-withdraw');
    assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium pre-withdraw');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex pre-withdraw');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'asset baseBorrowRate pre-withdraw'
    );
    assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad pre-withdraw');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp pre-withdraw');
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'spoke suppliedShares pre-withdraw'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'spoke baseDebt pre-withdraw');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'spoke outstandingPremium pre-withdraw'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'spoke baseBorrowIndex pre-withdraw'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'spoke riskPremiumRad pre-withdraw');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'spoke lastUpdateTimestamp pre-withdraw'
    );
    // dai
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-withdraw');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance pre-withdraw');
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount,
      'user token balance pre-withdraw'
    );

    vm.expectEmit(address(tokenList.dai));
    emit Transfer(address(hub), alice, amount);
    vm.expectEmit(address(hub));
    emit Withdraw(daiAssetId, address(spoke1), alice, amount);

    vm.prank(address(spoke1));
    hub.withdraw({assetId: daiAssetId, amount: amount, riskPremiumRad: 0, to: alice});

    assetData = hub.getAsset(daiAssetId);
    spokeData = hub.getSpoke(daiAssetId, address(spoke1));

    // hub
    assertEq(hub.getTotalAssets(daiAssetId), 0, 'hub total assets post-withdraw');
    // asset
    assertEq(assetData.suppliedShares, 0, 'asset total shares post-withdraw');
    assertEq(assetData.availableLiquidity, 0, 'asset availableLiquidity post-withdraw');
    assertEq(assetData.baseDebt, 0, 'asset baseDebt post-withdraw');
    assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium post-withdraw');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex post-withdraw');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'asset baseBorrowRate post-withdraw'
    );
    assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad post-withdraw');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp post-withdraw');
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'spoke suppliedShares post-withdraw'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'spoke baseDebt post-withdraw');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'spoke outstandingPremium post-withdraw'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'spoke baseBorrowIndex post-withdraw'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'spoke riskPremiumRad post-withdraw');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'spoke lastUpdateTimestamp post-withdraw'
    );
    // dai
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-withdraw');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance post-withdraw');
    assertEq(tokenList.dai.balanceOf(alice), MAX_SUPPLY_AMOUNT, 'user token balance post-withdraw');
  }

  // single asset, multiple spokes supplied. No drawn
  function test_withdraw_fuzz_multi_spoke(
    uint256 amount,
    uint256 amount2,
    uint256 riskPremiumRad
  ) public {
    uint256 assetId = 0;
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT - 1);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT - amount);
    riskPremiumRad = bound(riskPremiumRad, 0, maxRiskPremiumRad); // no effect on withdraw because no drawn

    IERC20 asset = hub.assetsList(assetId);

    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: riskPremiumRad,
      user: alice,
      to: address(spoke1)
    });
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke2),
      amount: amount2,
      riskPremiumRad: riskPremiumRad,
      user: alice,
      to: address(spoke2)
    });

    Utils.withdraw({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      to: alice
    });
    Utils.withdraw({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke2),
      amount: amount2,
      riskPremiumRad: 0,
      to: alice
    });

    Asset memory assetData = hub.getAsset(assetId);
    SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));
    SpokeData memory spoke2Data = hub.getSpoke(assetId, address(spoke2));

    // hub
    assertEq(hub.getTotalAssets(assetId), 0, 'hub total assets post-withdraw');
    // asset
    assertEq(assetData.suppliedShares, 0, 'asset total shares post-withdraw');
    assertEq(assetData.availableLiquidity, 0, 'asset availableLiquidity post-withdraw');
    assertEq(assetData.baseDebt, 0, 'asset baseDebt post-withdraw');
    assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium post-withdraw');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex post-withdraw');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'asset baseBorrowRate post-withdraw'
    );
    assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad post-withdraw');
    assertEq(
      assetData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp post-withdraw'
    );
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'spoke suppliedShares post-withdraw'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'spoke baseDebt post-withdraw');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'spoke outstandingPremium post-withdraw'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'spoke baseBorrowIndex post-withdraw'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'spoke riskPremiumRad post-withdraw');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'spoke lastUpdateTimestamp post-withdraw'
    );
    // spoke
    assertEq(
      spoke2Data.suppliedShares,
      assetData.suppliedShares,
      'spoke suppliedShares post-withdraw'
    );
    assertEq(spoke2Data.baseDebt, assetData.baseDebt, 'spoke baseDebt post-withdraw');
    assertEq(
      spoke2Data.outstandingPremium,
      assetData.outstandingPremium,
      'spoke outstandingPremium post-withdraw'
    );
    assertEq(
      spoke2Data.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'spoke baseBorrowIndex post-withdraw'
    );
    assertEq(spoke2Data.riskPremiumRad, 0, 'spoke riskPremiumRad post-withdraw');
    assertEq(
      spoke2Data.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'spoke lastUpdateTimestamp post-withdraw'
    );
    // asset
    assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke1 token balance post-withdraw');
    assertEq(asset.balanceOf(address(spoke2)), 0, 'spoke2 token balance post-withdraw');
    assertEq(asset.balanceOf(address(hub)), 0, 'hub token balance post-withdraw');
    assertEq(asset.balanceOf(alice), MAX_SUPPLY_AMOUNT, 'user token balance post-withdraw');
  }

  function test_withdraw_fuzz(uint256 assetId, uint256 amount) public {
    assetId = bound(assetId, 0, hub.assetCount() - 2); // Exclude duplicated DAI
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    IERC20 asset = hub.assetsList(assetId);

    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    Asset memory assetData = hub.getAsset(assetId);
    SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));

    uint256 timestamp = vm.getBlockTimestamp();

    // hub
    assertEq(hub.getTotalAssets(assetId), amount, 'hub total assets pre-withdraw');
    // asset
    assertEq(
      assetData.suppliedShares,
      hub.convertToSharesUp(assetId, amount),
      'asset total shares pre-withdraw'
    );
    assertEq(assetData.availableLiquidity, amount, 'asset availableLiquidity pre-withdraw');
    assertEq(assetData.baseDebt, 0, 'asset baseDebt pre-withdraw');
    assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium pre-withdraw');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex pre-withdraw');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'asset baseBorrowRate pre-withdraw'
    );
    assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad pre-withdraw');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp pre-withdraw');
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'spoke suppliedShares pre-withdraw'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'spoke baseDebt pre-withdraw');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'spoke outstandingPremium pre-withdraw'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'spoke baseBorrowIndex pre-withdraw'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'spoke riskPremiumRad pre-withdraw');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'spoke lastUpdateTimestamp pre-withdraw'
    );
    // asset
    assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance pre-withdraw');
    assertEq(asset.balanceOf(address(hub)), amount, 'hub token balance pre-withdraw');
    assertEq(
      asset.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount,
      'alice token balance pre-withdraw'
    );

    vm.expectEmit(address(asset));
    emit Transfer(address(hub), alice, amount);

    vm.expectEmit(address(hub));
    emit Withdraw(assetId, address(spoke1), alice, amount);

    Utils.withdraw({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      to: alice
    });

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));

    // hub
    assertEq(hub.getTotalAssets(assetId), 0, 'hub total assets post-withdraw');
    // asset
    assertEq(assetData.suppliedShares, 0, 'asset total shares post-withdraw');
    assertEq(assetData.availableLiquidity, 0, 'asset availableLiquidity post-withdraw');
    assertEq(assetData.baseDebt, 0, 'asset baseDebt post-withdraw');
    assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium post-withdraw');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex post-withdraw');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'asset baseBorrowRate post-withdraw'
    );
    assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad post-withdraw');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp post-withdraw');
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'spoke suppliedShares post-withdraw'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'spoke baseDebt post-withdraw');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'spoke outstandingPremium post-withdraw'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'spoke baseBorrowIndex post-withdraw'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'spoke riskPremiumRad post-withdraw');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'spoke lastUpdateTimestamp post-withdraw'
    );
    // asset
    assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-withdraw');
    assertEq(asset.balanceOf(address(hub)), 0, 'hub token balance post-withdraw');
    assertEq(asset.balanceOf(alice), MAX_SUPPLY_AMOUNT, 'alice token balance post-withdraw');
  }

  function test_withdraw_all_with_interest() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 riskPremiumRad = uint256(20_00).bpsToRad();
    uint256 lastUpdateTimestamp = vm.getBlockTimestamp();
    uint256 rate = uint256(10_00).bpsToRay();

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      wethAmount: wethAmount,
      daiDrawAmount: drawAmount,
      riskPremiumRad: riskPremiumRad,
      rate: rate
    });

    skip(365 days);

    HubData memory hubData;
    hubData.daiData = hub.getAsset(daiAssetId);

    uint256 initialAvailableLiquidity = hubData.daiData.availableLiquidity;
    uint256 supply2Amount = 10e18;

    // bob supplies more DAI to trigger accrual
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: supply2Amount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    hubData.daiData1 = hub.getAsset(daiAssetId);

    uint256 restoreAmount = hubData.daiData1.baseDebt + hubData.daiData1.outstandingPremium;
    uint256 newBaseBorrowIndex = WadRayMath.RAY +
      WadRayMath.RAY.rayMul(
        MathUtils.calculateLinearInterest(
          hubData.daiData1.baseBorrowRate,
          uint40(lastUpdateTimestamp)
        ) - WadRayMath.RAY
      );

    // alice restores all debt including accrual
    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremiumRad: 0, repayer: alice});

    hubData.daiData2 = hub.getAsset(daiAssetId);
    assertEq(
      hubData.daiData2.availableLiquidity,
      initialAvailableLiquidity + restoreAmount + supply2Amount,
      'dai availableLiquidity'
    );

    // bob withdraws all liquidity with interest
    vm.prank(address(spoke2));
    hub.withdraw({
      assetId: daiAssetId,
      amount: hubData.daiData2.availableLiquidity,
      riskPremiumRad: 0,
      to: bob
    });

    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT + hubData.daiData2.availableLiquidity - supply2Amount - daiAmount,
      'bob dai balance'
    );

    hubData.daiData3 = hub.getAsset(daiAssetId);
    hubData.spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    hubData.spoke2DaiData = hub.getSpoke(daiAssetId, address(spoke2));

    // hub
    assertEq(hub.getTotalAssets(daiAssetId), 0, 'hub totalAssets');
    assertEq(hubData.daiData3.suppliedShares, 0, 'dai suppliedShares');
    assertEq(hubData.daiData3.availableLiquidity, 0, 'dai availableLiquidity');
    assertEq(hubData.daiData3.baseDebt, 0, 'dai baseDebt');
    assertEq(hubData.daiData3.outstandingPremium, 0, 'dai outstandingPremium');
    assertEq(hubData.daiData3.baseBorrowIndex, newBaseBorrowIndex, 'dai baseBorrowIndex');
    assertEq(hubData.daiData3.baseBorrowRate, rate, 'dai baseBorrowRate');
    assertEq(hubData.daiData3.riskPremiumRad, 0, 'dai riskPremiumRad');
    assertEq(
      hubData.daiData3.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'dai lastUpdateTimestamp'
    );
    // spoke1
    assertEq(hubData.spoke1DaiData.suppliedShares, 0, 'spoke1 suppliedShares');
    assertEq(hubData.spoke1DaiData.baseDebt, 0, 'spoke1 baseDebt');
    assertEq(hubData.spoke1DaiData.outstandingPremium, 0, 'spoke1 outstandingPremium');
    assertEq(hubData.spoke1DaiData.baseBorrowIndex, newBaseBorrowIndex, 'spoke1 baseBorrowIndex');
    assertEq(hubData.spoke1DaiData.riskPremiumRad, 0, 'spoke1 riskPremiumRad');
    assertEq(
      hubData.spoke1DaiData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'spoke1 lastUpdateTimestamp'
    );
    // spoke2
    assertEq(hubData.spoke2DaiData.suppliedShares, 0, 'spoke2 suppliedShares');
    assertEq(hubData.spoke2DaiData.baseDebt, 0, 'spoke2 baseDebt');
    assertEq(hubData.spoke2DaiData.outstandingPremium, 0, 'spoke2 outstandingPremium');
    assertEq(hubData.spoke2DaiData.baseBorrowIndex, WadRayMath.RAY, 'spoke2 baseBorrowIndex');
    assertEq(hubData.spoke2DaiData.riskPremiumRad, 0, 'spoke2 riskPremiumRad');
    assertEq(
      hubData.spoke2DaiData.lastUpdateTimestamp,
      lastUpdateTimestamp,
      'spoke2 lastUpdateTimestamp'
    );
    // dai - all to alice
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai balance');
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT + drawAmount - restoreAmount,
      'alice dai balance'
    );
  }

  function test_withdraw_fuzz_all_liquidity_with_interest(
    uint256 drawAmount,
    uint256 riskPremiumRad,
    uint256 rate,
    uint256 skipTime
  ) public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 day to 10 years
    rate = bound(rate, 0, 200_00).bpsToRay(); // .1% to 200%
    riskPremiumRad = bound(riskPremiumRad, 0, maxRiskPremiumRad);

    uint256 lastUpdateTimestamp = vm.getBlockTimestamp();

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      wethAmount: wethAmount,
      daiDrawAmount: drawAmount,
      riskPremiumRad: riskPremiumRad,
      rate: rate
    });

    skip(skipTime);
    HubData memory hubData;
    hubData.daiData = hub.getAsset(daiAssetId);

    hubData.accruedBase = hubData.daiData.baseDebt.rayMul(rate);
    hubData.initialAvailableLiquidity = hubData.daiData.availableLiquidity;
    hubData.initialSupplyShares = hubData.daiData.suppliedShares;

    hubData.supply2Amount = 10e18;
    hubData.expectedSupply2Shares = hubData.supply2Amount.toSharesDown(
      hub.getTotalAssets(daiAssetId) + hubData.accruedBase,
      hubData.daiData.suppliedShares
    );

    // bob supplies more DAI to trigger accrual
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: hubData.supply2Amount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    hubData.daiData = hub.getAsset(daiAssetId);

    uint256 restoreAmount = hubData.daiData.baseDebt + hubData.daiData.outstandingPremium;
    uint256 newBaseBorrowIndex = WadRayMath.RAY +
      WadRayMath.RAY.rayMul(
        MathUtils.calculateLinearInterest(
          hubData.daiData.baseBorrowRate,
          uint40(lastUpdateTimestamp)
        ) - WadRayMath.RAY
      );

    // alice restores all debt including accrual
    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremiumRad: 0, repayer: alice});

    hubData.daiData = hub.getAsset(daiAssetId);
    assertEq(
      hubData.daiData.availableLiquidity,
      hubData.initialAvailableLiquidity + restoreAmount + hubData.supply2Amount,
      'dai availableLiquidity'
    );

    // bob withdraws all liquidity with interest
    vm.prank(address(spoke2));
    hub.withdraw({
      assetId: daiAssetId,
      amount: hubData.daiData.availableLiquidity,
      riskPremiumRad: 0,
      to: bob
    });

    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT + hubData.daiData.availableLiquidity - hubData.supply2Amount - daiAmount,
      'bob dai balance'
    );

    hubData.daiData = hub.getAsset(daiAssetId);
    hubData.spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    hubData.spoke2DaiData = hub.getSpoke(daiAssetId, address(spoke2));

    // hub
    assertEq(hub.getTotalAssets(daiAssetId), 0, 'hub totalAssets');
    assertEq(hubData.daiData.suppliedShares, 0, 'dai suppliedShares');
    assertEq(hubData.daiData.availableLiquidity, 0, 'dai availableLiquidity');
    assertEq(hubData.daiData.baseDebt, 0, 'dai baseDebt');
    assertEq(hubData.daiData.outstandingPremium, 0, 'dai outstandingPremium');
    assertEq(hubData.daiData.baseBorrowIndex, newBaseBorrowIndex, 'dai baseBorrowIndex');
    assertEq(hubData.daiData.baseBorrowRate, rate, 'dai baseBorrowRate');
    assertEq(hubData.daiData.riskPremiumRad, 0, 'dai riskPremiumRad');
    assertEq(
      hubData.daiData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'dai lastUpdateTimestamp'
    );
    // spoke1
    assertEq(hubData.spoke1DaiData.suppliedShares, 0, 'spoke1 suppliedShares');
    assertEq(hubData.spoke1DaiData.baseDebt, 0, 'spoke1 baseDebt');
    assertEq(hubData.spoke1DaiData.outstandingPremium, 0, 'spoke1 outstandingPremium');
    assertEq(hubData.spoke1DaiData.baseBorrowIndex, newBaseBorrowIndex, 'spoke1 baseBorrowIndex');
    assertEq(hubData.spoke1DaiData.riskPremiumRad, 0, 'spoke1 riskPremiumRad');
    assertEq(
      hubData.spoke1DaiData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'spoke1 lastUpdateTimestamp'
    );
    // spoke2
    assertEq(hubData.spoke2DaiData.suppliedShares, 0, 'spoke2 suppliedShares');
    assertEq(hubData.spoke2DaiData.baseDebt, 0, 'spoke2 baseDebt');
    assertEq(hubData.spoke2DaiData.outstandingPremium, 0, 'spoke2 outstandingPremium');
    assertEq(hubData.spoke2DaiData.baseBorrowIndex, WadRayMath.RAY, 'spoke2 baseBorrowIndex');
    assertEq(hubData.spoke2DaiData.riskPremiumRad, 0, 'spoke2 riskPremiumRad');
    assertEq(
      hubData.spoke2DaiData.lastUpdateTimestamp,
      lastUpdateTimestamp,
      'spoke2 lastUpdateTimestamp'
    );
    // dai - all to alice
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai balance');
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT + drawAmount - restoreAmount,
      'alice dai balance'
    );
  }

  function test_withdraw_revertsWith_zero_supplied() public {
    uint256 assetId = 0;
    uint256 amount = 1;

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw({assetId: assetId, amount: amount, riskPremiumRad: 0, to: address(spoke1)});
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded() public {
    uint256 assetId = daiAssetId;
    uint256 amount = 100e18;

    // User supply
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw({assetId: assetId, amount: amount + 1, riskPremiumRad: 0, to: alice});

    // advance time, but no accumulation
    skip(1e18);
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw({assetId: assetId, amount: amount + 1, riskPremiumRad: 0, to: alice});
  }

  function test_withdraw_revertsWith_not_available_liquidity() public {
    uint256 amount = 100e18;

    // User supply
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
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
      riskPremiumRad: 0,
      onBehalfOf: address(spoke1)
    });

    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);

    vm.prank(address(spoke1));
    hub.withdraw({assetId: daiAssetId, amount: amount, riskPremiumRad: 0, to: address(spoke1)});
  }

  function test_withdraw_revertsWith_invalid_withdraw_amount() public {
    uint256 amount = 100e18;

    // User supply
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    vm.expectRevert(TestErrors.INVALID_WITHDRAW_AMOUNT);
    vm.prank(address(spoke1));
    hub.withdraw({assetId: daiAssetId, amount: 0, riskPremiumRad: 0, to: alice});
  }

  function test_withdraw_revertsWith_asset_not_active() public {
    uint256 amount = 100e18;
    _updateActive(daiAssetId, false);

    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    vm.prank(address(spoke1));
    hub.withdraw({assetId: daiAssetId, amount: amount, riskPremiumRad: 0, to: alice});
  }
}
