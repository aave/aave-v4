// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract HubReportDeficitTest is Base {
  using SafeCast for *;
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  struct ReportDeficitLocal {
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
    uint256 drawnShares;
    uint256 totalDeficitRay;
    uint256 drawnSharesBefore;
  }

  function setUp() public override {
    super.setUp();

    // deploy borrowable liquidity
    _addLiquidity(hub1, daiAssetId, MAX_SUPPLY_AMOUNT_DAI);
    _addLiquidity(hub1, wethAssetId, MAX_SUPPLY_AMOUNT_WETH);
    _addLiquidity(hub1, usdxAssetId, MAX_SUPPLY_AMOUNT_USDX);
  }

  function test_reportDeficit_revertsWith_SpokeNotActive(address caller) public {
    vm.assume(
      !hub1.getSpoke(usdxAssetId, caller).active && caller != _getProxyAdminAddress(address(hub1))
    );

    vm.expectRevert(IHub.SpokeNotActive.selector);

    vm.prank(caller);
    hub1.reportDeficit(usdxAssetId, 1, ZERO_PREMIUM_DELTA);
  }

  function test_reportDeficit_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);

    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 0, ZERO_PREMIUM_DELTA);
  }

  function test_reportDeficit_fuzz_revertsWith_SurplusDrawnDeficitReported(
    uint256 drawnAmount
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT_USDX);

    // draw usdx liquidity to be restored
    _drawLiquidity({
      hub: hub1,
      assetId: usdxAssetId,
      amount: drawnAmount,
      withPremium: true,
      skipTime: true,
      spoke: address(spoke1)
    });

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
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT_USDX);

    // draw usdx liquidity to be restored
    _drawLiquidity({
      hub: hub1,
      assetId: usdxAssetId,
      amount: drawnAmount,
      withPremium: true,
      skipTime: true,
      spoke: address(spoke1)
    });

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
    uint256 premiumDeficitRay = vm.randomUint(spokePremiumRay + 1, 2 ** 255 - 1);

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

  /// @dev halted spoke can still report deficit
  function test_reportDeficit_halted() public {
    // draw usdx liquidity to be restored
    _drawLiquidity({
      hub: hub1,
      assetId: usdxAssetId,
      amount: 1,
      withPremium: true,
      skipTime: true,
      spoke: address(spoke1)
    });

    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true);

    // even if spoke is halted, it can report deficit
    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 1, ZERO_PREMIUM_DELTA);
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
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT_USDX);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    ReportDeficitLocal memory params;

    // create premium debt via spoke1
    _drawLiquidity({
      hub: hub1,
      assetId: usdxAssetId,
      amount: drawnAmount,
      withPremium: true,
      skipTime: skipTime,
      spoke: address(spoke1)
    });
    (params.drawn, ) = hub1.getAssetOwed(usdxAssetId);
    params.premiumRay = hub1.getAssetPremiumRay(usdxAssetId);

    IHub.Asset memory asset = hub1.getAsset(usdxAssetId);

    baseAmount = bound(baseAmount, 0, params.drawn);
    params.drawnShares = hub1.previewRestoreByAssets(usdxAssetId, baseAmount);
    premiumAmountRay = bound(premiumAmountRay, 0, params.premiumRay);
    params.totalDeficitRay =
      params.drawnShares * hub1.getAssetDrawnIndex(usdxAssetId) +
      premiumAmountRay;
    vm.assume(params.totalDeficitRay > 0);

    params.deficitRayBefore = hub1.getAssetDeficitRay(usdxAssetId);
    params.supplyExchangeRateBefore = hub1.previewRemoveByShares(usdxAssetId, WadRayMath.RAY);
    params.liquidityBefore = hub1.getAssetLiquidity(usdxAssetId);
    params.balanceBefore = IERC20(hub1.getAsset(usdxAssetId).underlying).balanceOf(address(spoke1));
    params.drawnSharesBefore = hub1.getAsset(usdxAssetId).drawnShares;

    IHubBase.PremiumDelta memory premiumDelta;
    {
      (uint256 spokePremiumShares, int256 spokePremiumOffsetRay) = hub1.getSpokePremiumData(
        usdxAssetId,
        address(spoke1)
      );
      premiumDelta = _getExpectedPremiumDelta({
        hub: hub1,
        assetId: usdxAssetId,
        oldPremiumShares: spokePremiumShares,
        oldPremiumOffsetRay: spokePremiumOffsetRay,
        drawnShares: 0,
        riskPremium: 0,
        restoredPremiumRay: premiumAmountRay
      });
    }

    uint256 expectedNewPremiumShares = premiumDelta.sharesDelta < 0
      ? asset.premiumShares - uint256(-premiumDelta.sharesDelta)
      : asset.premiumShares + uint256(premiumDelta.sharesDelta);

    if (premiumDelta.restoredPremiumRay > params.premiumRay) {
      vm.expectRevert(stdError.arithmeticError);
      vm.prank(address(spoke1));
      hub1.reportDeficit(usdxAssetId, baseAmount, premiumDelta);
    } else if (
      expectedNewPremiumShares >
      (params.drawnSharesBefore - params.drawnShares).percentMulUp(1000_00)
    ) {
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
      vm.prank(address(spoke1));
      hub1.reportDeficit(usdxAssetId, baseAmount, premiumDelta);
    } else {
      vm.expectEmit(address(hub1));
      emit IHubBase.ReportDeficit(
        usdxAssetId,
        address(spoke1),
        params.drawnShares,
        premiumDelta,
        params.totalDeficitRay
      );
      vm.prank(address(spoke1));
      (uint256 returnedDrawnShares, uint256 returnedDeficitAmount) = hub1.reportDeficit(
        usdxAssetId,
        baseAmount,
        premiumDelta
      );

      assertEq(returnedDrawnShares, params.drawnShares, 'returned drawn shares');
      assertEq(
        returnedDeficitAmount,
        params.totalDeficitRay.fromRayUp(),
        'returned deficit amount'
      );

      (params.drawnAfter, ) = hub1.getAssetOwed(usdxAssetId);
      params.premiumRayAfter = hub1.getAssetPremiumRay(usdxAssetId);

      params.deficitRayAfter = hub1.getAssetDeficitRay(usdxAssetId);
      params.supplyExchangeRateAfter = hub1.previewRemoveByShares(usdxAssetId, WadRayMath.RAY);
      params.liquidityAfter = hub1.getAssetLiquidity(usdxAssetId);
      params.balanceAfter = IERC20(hub1.getAsset(usdxAssetId).underlying).balanceOf(
        address(spoke1)
      );

      // due to rounding of donation, drawn debt can differ by asset amount of one share
      // and 1 wei imprecision
      assertApproxEqAbs(
        params.drawnAfter,
        params.drawn - baseAmount,
        _minimumAssetsPerDrawnShare(hub1, usdxAssetId) + 1,
        'drawn debt'
      );
      assertEq(
        hub1.getAsset(usdxAssetId).drawnShares,
        params.drawnSharesBefore - params.drawnShares,
        'base drawn shares'
      );
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
        params.deficitRayBefore + params.totalDeficitRay,
        'deficit accounting'
      );
      assertGe(
        params.supplyExchangeRateAfter,
        params.supplyExchangeRateBefore,
        'supply exchange rate should increase'
      );
      _assertDrawnRateSynced(hub1, usdxAssetId, 'reportDeficit');
    }
  }
}
