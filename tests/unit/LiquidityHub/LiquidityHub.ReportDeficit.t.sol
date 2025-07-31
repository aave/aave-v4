// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubReportDeficitTest is LiquidityHubBase {
  struct ReportDeficitTestParams {
    uint256 baseDebt;
    uint256 premiumDebt;
    uint256 deficitBefore;
    uint256 deficitAfter;
    uint256 supplyExchangeRateBefore;
    uint256 supplyExchangeRateAfter;
    uint256 availableLiquidityBefore;
    uint256 availableLiquidityAfter;
    uint256 balanceBefore;
    uint256 balanceAfter;
    uint256 baseDebtAfter;
    uint256 premiumDebtAfter;
  }

  function setUp() public override {
    super.setUp();

    // deploy borrowable liquidity
    _addLiquidity(daiAssetId, MAX_SUPPLY_AMOUNT);
    _addLiquidity(wethAssetId, MAX_SUPPLY_AMOUNT);
    _addLiquidity(usdxAssetId, MAX_SUPPLY_AMOUNT);
  }

  function test_reportDeficit_revertsWith_SpokeNotActive(address caller) public {
    vm.assume(!hub.getSpoke(usdxAssetId, caller).config.active);

    vm.expectRevert(ILiquidityHub.SpokeNotActive.selector);

    vm.prank(caller);
    hub.reportDeficit(usdxAssetId, 0, 0, DataTypes.PremiumDelta(0, 0, 0));
  }

  function test_reportDeficit_revertsWith_InvalidDeficitAmount() public {
    vm.expectRevert(ILiquidityHub.InvalidDeficitAmount.selector);

    vm.prank(address(spoke1));
    hub.reportDeficit(usdxAssetId, 0, 0, DataTypes.PremiumDelta(0, 0, 0));
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
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: drawnAmount,
      to: address(spoke1)
    });

    // skip to accrue interest
    skip(skipTime);

    (uint256 baseDebt, ) = hub.getSpokeDebt(usdxAssetId, address(spoke1));
    vm.assume(baseAmount > baseDebt);

    premiumAmount = bound(premiumAmount, 0, UINT256_MAX - baseAmount);

    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.SurplusDeficitReported.selector, baseDebt)
    );
    vm.prank(address(spoke1));
    hub.reportDeficit(
      usdxAssetId,
      baseAmount,
      premiumAmount,
      DataTypes.PremiumDelta(0, 0, -int256(premiumAmount))
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
    (params.baseDebt, params.premiumDebt) = _drawLiquidityFromSpoke(
      address(spoke1),
      usdxAssetId,
      drawnAmount,
      skipTime,
      true
    );

    baseAmount = bound(baseAmount, 0, params.baseDebt);
    premiumAmount = bound(premiumAmount, 0, params.premiumDebt);
    vm.assume(baseAmount + premiumAmount > 0);

    params.deficitBefore = getDeficit(hub, usdxAssetId);
    params.supplyExchangeRateBefore = hub.convertToSuppliedAssets(usdxAssetId, WadRayMath.RAY);
    params.availableLiquidityBefore = hub.getAvailableLiquidity(usdxAssetId);
    params.balanceBefore = IERC20(hub.getAsset(usdxAssetId).underlying).balanceOf(address(spoke1));
    uint256 baseDrawnSharesBefore = hub.getAsset(usdxAssetId).baseDrawnShares;
    uint256 totalDeficit = baseAmount + premiumAmount;

    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      drawnSharesDelta: 0,
      offsetDelta: 0,
      realizedDelta: -int256(premiumAmount)
    });

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitReported(
      usdxAssetId,
      address(spoke1),
      hub.convertToDrawnShares(usdxAssetId, baseAmount),
      premiumDelta,
      totalDeficit
    );
    vm.prank(address(spoke1));
    hub.reportDeficit(usdxAssetId, baseAmount, premiumAmount, premiumDelta);

    (params.baseDebtAfter, params.premiumDebtAfter) = hub.getAssetDebt(usdxAssetId);

    params.deficitAfter = getDeficit(hub, usdxAssetId);
    params.supplyExchangeRateAfter = hub.convertToSuppliedAssets(usdxAssetId, WadRayMath.RAY);
    params.availableLiquidityAfter = hub.getAvailableLiquidity(usdxAssetId);
    params.balanceAfter = IERC20(hub.getAsset(usdxAssetId).underlying).balanceOf(address(spoke1));
    uint256 baseDrawnSharesAfter = hub.getAsset(usdxAssetId).baseDrawnShares;

    // due to rounding of donation, base debt can differ by asset amount of one share
    // and 1 wei imprecision
    assertApproxEqAbs(
      params.baseDebtAfter,
      params.baseDebt - baseAmount,
      minimumAssetsPerDrawnShare(hub, usdxAssetId) + 1,
      'base debt'
    );
    assertEq(
      baseDrawnSharesAfter,
      baseDrawnSharesBefore - hub.convertToDrawnShares(usdxAssetId, baseAmount),
      'base drawn shares'
    );
    assertEq(params.premiumDebtAfter, params.premiumDebt - premiumAmount, 'premium debt');
    assertEq(params.balanceAfter, params.balanceBefore, 'balance change');
    assertEq(
      params.availableLiquidityAfter,
      params.availableLiquidityBefore,
      'available liquidity'
    );
    assertEq(params.deficitAfter, params.deficitBefore + totalDeficit, 'deficit accounting');
    assertGe(
      params.supplyExchangeRateAfter,
      params.supplyExchangeRateBefore,
      'supply exchange rate should increase'
    );
    assertBorrowRateSynced(hub, usdxAssetId, 'reportDeficit');
  }
}
