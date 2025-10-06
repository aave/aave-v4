// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubReportDeficitTest is HubBase {
  struct ReportDeficitTestParams {
    uint256 drawn;
    uint256 premium;
    uint256 deficitBefore;
    uint256 deficitAfter;
    uint256 supplyExchangeRateBefore;
    uint256 supplyExchangeRateAfter;
    uint256 liquidityBefore;
    uint256 liquidityAfter;
    uint256 balanceBefore;
    uint256 balanceAfter;
    uint256 drawnAfter;
    uint256 premiumAfter;
  }

  function setUp() public override {
    super.setUp();

    // deploy borrowable liquidity
    _addLiquidity(daiAssetId, MAX_SUPPLY_AMOUNT);
    _addLiquidity(wethAssetId, MAX_SUPPLY_AMOUNT);
    _addLiquidity(usdxAssetId, MAX_SUPPLY_AMOUNT);
  }

  function test_reportDeficit_revertsWith_SpokeNotActive(address caller) public {
    vm.assume(!hub1.getSpoke(usdxAssetId, caller).active);

    vm.expectRevert(IHub.SpokeNotActive.selector);

    vm.prank(caller);
    hub1.reportDeficit(usdxAssetId, 0, 0, IHubBase.PremiumDelta(0, 0, 0));
  }

  function test_reportDeficit_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);

    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 0, 0, IHubBase.PremiumDelta(0, 0, 0));
  }

  function test_reportDeficit_fuzz_revertsWith_SurplusDeficitReported(
    uint256 drawnAmount,
    uint256 skipTime,
    uint256 baseAmount,
    uint256 premiumAmount
  ) public {
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);

    // draw usdx liquidity to be restored
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: drawnAmount,
      to: address(spoke1)
    });

    // skip to accrue interest
    skip(skipTime);

    (uint256 drawn, ) = hub1.getSpokeOwed(usdxAssetId, address(spoke1));
    vm.assume(baseAmount > drawn);

    premiumAmount = bound(premiumAmount, 0, UINT256_MAX - baseAmount);

    vm.expectRevert(abi.encodeWithSelector(IHub.SurplusDeficitReported.selector, drawn));
    vm.prank(address(spoke1));
    hub1.reportDeficit(
      usdxAssetId,
      baseAmount,
      premiumAmount,
      IHubBase.PremiumDelta(0, 0, -int256(premiumAmount))
    );
  }

  function test_reportDeficit_with_premium() public {
    uint256 drawnAmount = 10_000e6;
    test_reportDeficit_fuzz_with_premium({
      drawnAmount: drawnAmount,
      baseAmount: drawnAmount / 2,
      premiumAmount: 0,
      skipTime: 365 days
    });
  }

  function test_reportDeficit_fuzz_with_premium(
    uint256 drawnAmount,
    uint256 baseAmount,
    uint256 premiumAmount,
    uint256 skipTime
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    ReportDeficitTestParams memory params;

    // create premium debt via spoke1
    (params.drawn, params.premium) = _drawLiquidityFromSpoke(
      address(spoke1),
      usdxAssetId,
      drawnAmount,
      skipTime,
      true
    );

    baseAmount = bound(baseAmount, 0, params.drawn);
    premiumAmount = bound(premiumAmount, 0, params.premium);
    vm.assume(baseAmount + premiumAmount > 0);

    params.deficitBefore = getDeficit(hub1, usdxAssetId);
    params.supplyExchangeRateBefore = hub1.convertToAddedAssets(usdxAssetId, WadRayMath.RAY);
    params.liquidityBefore = hub1.getLiquidity(usdxAssetId);
    params.balanceBefore = IERC20(hub1.getAsset(usdxAssetId).underlying).balanceOf(address(spoke1));
    uint256 drawnSharesBefore = hub1.getAsset(usdxAssetId).drawnShares;
    uint256 totalDeficit = baseAmount + premiumAmount;

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: 0,
      offsetDelta: 0,
      realizedDelta: -int256(premiumAmount)
    });

    vm.expectEmit(address(hub1));
    emit IHubBase.ReportDeficit(
      usdxAssetId,
      address(spoke1),
      hub1.previewRestoreByAssets(usdxAssetId, baseAmount),
      premiumDelta,
      baseAmount,
      premiumAmount
    );
    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, baseAmount, premiumAmount, premiumDelta);

    (params.drawnAfter, params.premiumAfter) = hub1.getAssetOwed(usdxAssetId);

    params.deficitAfter = getDeficit(hub1, usdxAssetId);
    params.supplyExchangeRateAfter = hub1.convertToAddedAssets(usdxAssetId, WadRayMath.RAY);
    params.liquidityAfter = hub1.getLiquidity(usdxAssetId);
    params.balanceAfter = IERC20(hub1.getAsset(usdxAssetId).underlying).balanceOf(address(spoke1));
    uint256 drawnSharesAfter = hub1.getAsset(usdxAssetId).drawnShares;

    // due to rounding of donation, drawn debt can differ by asset amount of one share
    // and 1 wei imprecision
    assertApproxEqAbs(
      params.drawnAfter,
      params.drawn - baseAmount,
      minimumAssetsPerDrawnShare(hub1, usdxAssetId) + 1,
      'drawn debt'
    );
    assertEq(
      drawnSharesAfter,
      drawnSharesBefore - hub1.previewRestoreByAssets(usdxAssetId, baseAmount),
      'base drawn shares'
    );
    assertEq(params.premiumAfter, params.premium - premiumAmount, 'premium debt');
    assertEq(params.balanceAfter, params.balanceBefore, 'balance change');
    assertEq(params.liquidityAfter, params.liquidityBefore, 'available liquidity');
    assertEq(params.deficitAfter, params.deficitBefore + totalDeficit, 'deficit accounting');
    assertGe(
      params.supplyExchangeRateAfter,
      params.supplyExchangeRateBefore,
      'supply exchange rate should increase'
    );
    assertBorrowRateSynced(hub1, usdxAssetId, 'reportDeficit');
  }
}
