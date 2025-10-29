// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubReportDeficitTest is HubBase {
  using SafeCast for *;
  using PercentageMath for uint256;

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
    _addLiquidity(address(tokenList.dai), MAX_SUPPLY_AMOUNT);
    _addLiquidity(address(tokenList.weth), MAX_SUPPLY_AMOUNT);
    _addLiquidity(address(tokenList.usdx), MAX_SUPPLY_AMOUNT);
  }

  function test_reportDeficit_revertsWith_SpokeNotActive(address caller) public {
    vm.assume(!hub1.getSpoke(address(tokenList.usdx), caller).active);

    vm.expectRevert(IHub.SpokeNotActive.selector);

    vm.prank(caller);
    hub1.reportDeficit(address(tokenList.usdx), 0, 0, IHubBase.PremiumDelta(0, 0, 0));
  }

  function test_reportDeficit_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);

    vm.prank(address(spoke1));
    hub1.reportDeficit(address(tokenList.usdx), 0, 0, IHubBase.PremiumDelta(0, 0, 0));
  }

  function test_reportDeficit_surplus_drawn_revertsWith_SurplusDeficitReported() public {
    uint256 skipTime = 2000 days;
    uint256 drawAmount = 999e18;

    Utils.add({
      hub: hub1,
      underlying: address(tokenList.dai),
      caller: address(spoke1),
      amount: drawAmount * 2,
      user: alice
    });

    Utils.draw({
      hub: hub1,
      underlying: address(tokenList.dai),
      caller: address(spoke1),
      amount: drawAmount,
      to: address(spoke1)
    });

    // skip to accrue interest
    skip(skipTime);

    uint256 drawn = hub1.getAssetTotalOwed(address(tokenList.dai));

    // We report 1 wei extra, but it rounds down to the correct number of shares
    assertEq(
      hub1.previewRestoreByAssets(address(tokenList.dai), drawn),
      hub1.previewRestoreByAssets(address(tokenList.dai), drawn + 1)
    );

    vm.expectRevert(abi.encodeWithSelector(IHub.SurplusDeficitReported.selector, drawn));
    vm.prank(address(spoke1));
    hub1.reportDeficit(address(tokenList.dai), drawn + 1, 0, IHubBase.PremiumDelta(0, 0, 0));
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
      underlying: address(tokenList.dai),
      caller: address(spoke1),
      amount: drawnAmount,
      to: address(spoke1)
    });

    // skip to accrue interest
    skip(skipTime);

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(address(tokenList.usdx), address(spoke1));
    vm.assume(baseAmount > drawn);

    premiumAmount = bound(premiumAmount, 0, UINT256_MAX - baseAmount);

    vm.expectRevert(abi.encodeWithSelector(IHub.SurplusDeficitReported.selector, premium));
    vm.prank(address(spoke1));
    hub1.reportDeficit(
      address(tokenList.usdx),
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
      address(tokenList.usdx),
      _usdxReserveId(spoke1),
      drawnAmount,
      skipTime
    );

    baseAmount = bound(baseAmount, 0, params.drawn);
    premiumAmount = bound(premiumAmount, 0, params.premium);
    vm.assume(baseAmount + premiumAmount > 0);

    params.deficitBefore = getDeficit(hub1, address(tokenList.usdx));
    params.supplyExchangeRateBefore = hub1.previewRemoveByShares(
      address(tokenList.usdx),
      WadRayMath.RAY
    );
    params.liquidityBefore = hub1.getAssetLiquidity(address(tokenList.usdx));
    params.balanceBefore = IERC20(hub1.getAsset(address(tokenList.usdx)).underlying).balanceOf(
      address(spoke1)
    );
    uint256 drawnSharesBefore = hub1.getAsset(address(tokenList.usdx)).drawnShares;
    uint256 totalDeficit = baseAmount + premiumAmount;

    IHub.Asset memory asset = hub1.getAsset(address(tokenList.usdx));

    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta(
      spoke1,
      alice,
      _usdxReserveId(spoke1),
      premiumAmount
    );

    uint256 baseDeficitShares = hub1.previewRestoreByAssets(address(tokenList.usdx), baseAmount);
    uint256 expectedNewPremiumShares = premiumDelta.sharesDelta < 0
      ? asset.premiumShares - uint256(-premiumDelta.sharesDelta)
      : asset.premiumShares + uint256(premiumDelta.sharesDelta);

    if (
      premiumDelta.realizedDelta < 0 && uint256(-premiumDelta.realizedDelta) > asset.realizedPremium
    ) {
      vm.expectRevert(stdError.arithmeticError);
      vm.prank(address(spoke1));
      hub1.reportDeficit(address(tokenList.usdx), baseAmount, premiumAmount, premiumDelta);
    } else if (
      expectedNewPremiumShares > (drawnSharesBefore - baseDeficitShares).percentMulUp(1000_00)
    ) {
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
      vm.prank(address(spoke1));
      hub1.reportDeficit(address(tokenList.usdx), baseAmount, premiumAmount, premiumDelta);
    } else {
      vm.expectEmit(address(hub1));
      emit IHubBase.ReportDeficit(
        address(tokenList.usdx),
        address(spoke1),
        hub1.previewRestoreByAssets(address(tokenList.usdx), baseAmount),
        premiumDelta,
        baseAmount,
        premiumAmount
      );
      vm.prank(address(spoke1));
      hub1.reportDeficit(address(tokenList.usdx), baseAmount, premiumAmount, premiumDelta);

      (params.drawnAfter, params.premiumAfter) = hub1.getAssetOwed(address(tokenList.usdx));

      params.deficitAfter = getDeficit(hub1, address(tokenList.usdx));
      params.supplyExchangeRateAfter = hub1.previewRemoveByShares(
        address(tokenList.usdx),
        WadRayMath.RAY
      );
      params.liquidityAfter = hub1.getAssetLiquidity(address(tokenList.usdx));
      params.balanceAfter = IERC20(hub1.getAsset(address(tokenList.usdx)).underlying).balanceOf(
        address(spoke1)
      );
      uint256 drawnSharesAfter = hub1.getAsset(address(tokenList.usdx)).drawnShares;

      // due to rounding of donation, drawn debt can differ by asset amount of one share
      // and 1 wei imprecision
      assertApproxEqAbs(
        params.drawnAfter,
        params.drawn - baseAmount,
        minimumAssetsPerDrawnShare(hub1, address(tokenList.usdx)) + 1,
        'drawn debt'
      );
      assertEq(
        drawnSharesAfter,
        drawnSharesBefore - hub1.previewRestoreByAssets(address(tokenList.usdx), baseAmount),
        'base drawn shares'
      );
      assertApproxEqAbs(params.premiumAfter, params.premium - premiumAmount, 1, 'premium debt');
      assertEq(params.balanceAfter, params.balanceBefore, 'balance change');
      assertEq(params.liquidityAfter, params.liquidityBefore, 'available liquidity');
      assertEq(params.deficitAfter, params.deficitBefore + totalDeficit, 'deficit accounting');
      assertGe(
        params.supplyExchangeRateAfter,
        params.supplyExchangeRateBefore,
        'supply exchange rate should increase'
      );
      assertBorrowRateSynced(hub1, address(tokenList.usdx), 'reportDeficit');
    }
  }
}
