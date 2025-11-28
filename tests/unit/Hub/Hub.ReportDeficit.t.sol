// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubReportDeficitTest is HubBase {
  using SafeCast for *;
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  struct ReportDeficitTestParams {
    uint256 drawn;
    uint256 premiumRay;
    uint256 deficitRayBefore;
    uint256 deficitRayAfter;
    uint256 supplyExchangeRateBefore;
    uint256 supplyExchangeRateAfter;
    uint256 liquidityBefore;
    uint256 liquidityAfter;
    uint256 balanceBefore;
    uint256 balanceAfter;
    uint256 drawnAfter;
    uint256 premiumRayAfter;
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
    hub1.reportDeficit(usdxAssetId, 0, ZERO_PREMIUM_DELTA);
  }

  function test_reportDeficit_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);

    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 0, ZERO_PREMIUM_DELTA);
  }

  function test_reportDeficit_fuzz_revertsWith_SurplusDrawnDeficitReported(
    uint256 drawnAmount
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);

    // draw usdx liquidity to be restored
    _drawLiquidity(usdxAssetId, drawnAmount, true, true, address(spoke1));

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(usdxAssetId, address(spoke1));
    assertGt(drawn, 0);
    assertGt(premium, 0);

    uint256 drawnDeficit = vm.randomUint(drawn + 1, UINT256_MAX);

    (uint256 spokePremiumShares, int256 spokePremiumOffsetRay) = hub1.getSpokePremiumData(
      usdxAssetId,
      address(spoke1)
    );
    uint256 spokePremiumRay = _calculatePremiumDebtRay(
      hub1,
      usdxAssetId,
      spokePremiumShares,
      spokePremiumOffsetRay
    );

    uint256 premiumDeficitRay = vm.randomUint(0, spokePremiumRay);

    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      hub: hub1,
      assetId: usdxAssetId,
      oldPremiumShares: spokePremiumShares,
      oldPremiumOffsetRay: spokePremiumOffsetRay,
      drawnShares: 0,
      riskPremium: 0,
      restoredPremiumRay: premiumDeficitRay
    });

    vm.expectRevert(abi.encodeWithSelector(IHub.SurplusDrawnDeficitReported.selector, drawn));
    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, drawnDeficit, premiumDelta);
  }

  function test_reportDeficit_fuzz_revertsWith_SurplusPremiumRayDeficitReported(
    uint256 drawnAmount
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);

    // draw usdx liquidity to be restored
    _drawLiquidity(usdxAssetId, drawnAmount, true, true, address(spoke1));

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(usdxAssetId, address(spoke1));
    assertGt(drawn, 0);
    assertGt(premium, 0);

    IHub.SpokeData memory spokeData = hub1.getSpoke(usdxAssetId, address(spoke1));
    uint256 spokePremiumRay = _calculatePremiumDebtRay(
      hub1,
      usdxAssetId,
      spokeData.premiumShares,
      spokeData.premiumOffsetRay
    );

    uint256 drawnDeficit = vm.randomUint(0, drawn);
    uint256 premiumDeficitRay = vm.randomUint(spokePremiumRay + 1, UINT256_MAX);

    vm.expectRevert(
      abi.encodeWithSelector(IHub.SurplusPremiumRayDeficitReported.selector, spokePremiumRay)
    );
    vm.prank(address(spoke1));
    hub1.reportDeficit(
      usdxAssetId,
      drawnDeficit,
      // `_getExpectedPremiumDelta` underflows in this case
      IHubBase.PremiumDelta({
        sharesDelta: 0,
        offsetRayDelta: premiumDeficitRay.toInt256(),
        restoredPremiumRay: premiumDeficitRay
      })
    );
  }

  function test_reportDeficit_with_premium() public {
    uint256 drawnAmount = 10_000e6;
    test_reportDeficit_fuzz_with_premium({
      drawnAmount: drawnAmount,
      baseAmount: drawnAmount / 2,
      premiumAmountRay: 0,
      skipTime: 365 days
    });
  }

  function test_reportDeficit_fuzz_with_premium(
    uint256 drawnAmount,
    uint256 baseAmount,
    uint256 premiumAmountRay,
    uint256 skipTime
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    ReportDeficitTestParams memory params;

    // create premium debt via spoke1
    (params.drawn, params.premiumRay) = _drawLiquidityFromSpoke(
      address(spoke1),
      usdxAssetId,
      _usdxReserveId(spoke1),
      drawnAmount,
      skipTime
    );

    IHub.Asset memory asset = hub1.getAsset(usdxAssetId);

    baseAmount = bound(baseAmount, 0, params.drawn);
    uint256 drawnShares = hub1.previewRestoreByAssets(usdxAssetId, baseAmount);
    premiumAmountRay = bound(premiumAmountRay, 0, params.premiumRay);
    uint256 totalDeficitRay = drawnShares * hub1.getAssetDrawnIndex(usdxAssetId) + premiumAmountRay;
    vm.assume(totalDeficitRay > 0);

    params.deficitRayBefore = hub1.getAssetDeficitRay(usdxAssetId);
    params.supplyExchangeRateBefore = hub1.previewRemoveByShares(usdxAssetId, WadRayMath.RAY);
    params.liquidityBefore = hub1.getAssetLiquidity(usdxAssetId);
    params.balanceBefore = IERC20(hub1.getAsset(usdxAssetId).underlying).balanceOf(address(spoke1));
    uint256 drawnSharesBefore = hub1.getAsset(usdxAssetId).drawnShares;

    ISpoke.UserPosition memory userPosition = spoke1.getUserPosition(_usdxReserveId(spoke1), alice);
    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      hub: hub1,
      assetId: usdxAssetId,
      oldPremiumShares: userPosition.premiumShares,
      oldPremiumOffsetRay: userPosition.premiumOffsetRay,
      drawnShares: 0,
      riskPremium: 0,
      restoredPremiumRay: premiumAmountRay
    });

    uint256 expectedNewPremiumShares = premiumDelta.sharesDelta < 0
      ? asset.premiumShares - uint256(-premiumDelta.sharesDelta)
      : asset.premiumShares + uint256(premiumDelta.sharesDelta);

    if (premiumDelta.restoredPremiumRay > params.premiumRay) {
      vm.expectRevert(stdError.arithmeticError);
      vm.prank(address(spoke1));
      hub1.reportDeficit(usdxAssetId, baseAmount, premiumDelta);
    } else if (expectedNewPremiumShares > (drawnSharesBefore - drawnShares).percentMulUp(1000_00)) {
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
      vm.prank(address(spoke1));
      hub1.reportDeficit(usdxAssetId, baseAmount, premiumDelta);
    } else {
      vm.expectEmit(address(hub1));
      emit IHubBase.ReportDeficit(
        usdxAssetId,
        address(spoke1),
        drawnShares,
        premiumDelta,
        totalDeficitRay
      );
      vm.prank(address(spoke1));
      hub1.reportDeficit(usdxAssetId, baseAmount, premiumDelta);

      (params.drawnAfter, ) = hub1.getAssetOwed(usdxAssetId);
      params.premiumRayAfter = hub1.getAssetPremiumRay(usdxAssetId);

      params.deficitRayAfter = hub1.getAssetDeficitRay(usdxAssetId);
      params.supplyExchangeRateAfter = hub1.previewRemoveByShares(usdxAssetId, WadRayMath.RAY);
      params.liquidityAfter = hub1.getAssetLiquidity(usdxAssetId);
      params.balanceAfter = IERC20(hub1.getAsset(usdxAssetId).underlying).balanceOf(
        address(spoke1)
      );
      uint256 drawnSharesAfter = hub1.getAsset(usdxAssetId).drawnShares;

      // due to rounding of donation, drawn debt can differ by asset amount of one share
      // and 1 wei imprecision
      assertApproxEqAbs(
        params.drawnAfter,
        params.drawn - baseAmount,
        minimumAssetsPerDrawnShare(hub1, usdxAssetId) + 1,
        'drawn debt'
      );
      assertEq(drawnSharesAfter, drawnSharesBefore - drawnShares, 'base drawn shares');
      assertApproxEqAbs(
        params.premiumRayAfter,
        params.premiumRay - premiumAmountRay,
        1,
        'premium debt'
      );
      assertEq(params.balanceAfter, params.balanceBefore, 'balance change');
      assertEq(params.liquidityAfter, params.liquidityBefore, 'available liquidity');
      assertEq(
        params.deficitRayAfter,
        params.deficitRayBefore + totalDeficitRay,
        'deficit accounting'
      );
      assertGe(
        params.supplyExchangeRateAfter,
        params.supplyExchangeRateBefore,
        'supply exchange rate should increase'
      );
      _assertBorrowRateSynced(hub1, usdxAssetId, 'reportDeficit');
    }
  }
}
