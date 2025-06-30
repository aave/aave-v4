// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBase.t.sol';

contract LiquidityHubReportDeficitTest is LiquidityHubBase {
  struct RestoreDeficitTestParams {
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
    uint256 baseBorrowRateBefore;
    uint256 baseBorrowRateAfter;
  }
  function setUp() public override {
    super.setUp();

    // deploy borrowable liquidity
    _addLiquidity(wethAssetId, MAX_SUPPLY_AMOUNT);
    _addLiquidity(usdxAssetId, MAX_SUPPLY_AMOUNT);

    // max approve
    vm.startPrank(address(spoke1));
    IERC20(hub.getAsset(wethAssetId).underlying).approve(address(hub), UINT256_MAX);
    IERC20(hub.getAsset(usdxAssetId).underlying).approve(address(hub), UINT256_MAX);
    vm.stopPrank();

    // mint usdx to spoke1 to be able to repay after accrual
    deal(address(tokenList.usdx), address(spoke1), 1e60);
  }

  function test_reportDeficit_revertsWith_InvalidDeficitAmount() public {
    vm.expectRevert(ILiquidityHub.InvalidDeficitAmount.selector);

    vm.prank(address(spoke1));
    hub.reportDeficit(usdxAssetId, 0, 0);
  }

  function test_reportDeficit_revertsWith_AssetNotActive() public {
    uint256 baseAmount = 10e6;
    uint256 premiumAmount = 1e6;

    // set asset as inactive
    updateAssetActive(hub, usdxAssetId, false);

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);

    vm.prank(address(spoke1));
    hub.reportDeficit(usdxAssetId, baseAmount, premiumAmount);
  }

  function test_reportDeficit_revertsWith_AssetPaused() public {
    uint256 baseAmount = 10e6;
    uint256 premiumAmount = 1e6;

    // set asset as paused
    updateAssetPaused(hub, usdxAssetId, true);

    vm.expectRevert(ILiquidityHub.AssetPaused.selector);

    vm.prank(address(spoke1));
    hub.reportDeficit(usdxAssetId, baseAmount, premiumAmount);
  }

  function test_reportDeficit_fuzz_revertsWith_SurplusDeficitReported(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 skipTime,
    uint256 baseAmount,
    uint256 premiumAmount
  ) public {
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);

    // draw usdx liquidity to be restored
    Utils.draw(hub, usdxAssetId, address(spoke1), address(spoke1), drawnAmount, address(spoke1));

    // skip to accrue interest
    skip(skipTime);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(usdxAssetId, address(spoke1));
    vm.assume(baseAmount > baseDebt);

    premiumAmount = bound(premiumAmount, 0, UINT256_MAX - baseAmount);

    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.SurplusDeficitReported.selector, baseDebt)
    );

    vm.prank(address(spoke1));
    hub.reportDeficit(usdxAssetId, baseAmount, premiumAmount);
  }

  function test_reportDeficit() public {
    uint256 drawnAmount = 10_000e6;
    test_reportDeficit_fuzz({
      drawnAmount: drawnAmount,
      baseAmount: drawnAmount / 2,
      premiumAmount: 0,
      skipTime: 365 days
    });
  }

  function test_reportDeficit_fuzz(
    uint256 drawnAmount,
    uint256 baseAmount,
    uint256 premiumAmount,
    uint256 skipTime
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    RestoreDeficitTestParams memory params;

    // create premium debt via spoke1
    (params.baseDebt, params.premiumDebt) = _createBorrowPositionWithPremium(
      spoke1,
      _usdxReserveId(spoke1),
      drawnAmount,
      skipTime
    );

    baseAmount = bound(baseAmount, 0, params.baseDebt);
    premiumAmount = bound(premiumAmount, 0, params.premiumDebt);
    vm.assume(baseAmount + premiumAmount > 0);

    params.deficitBefore = getDeficit(hub, usdxAssetId);
    params.supplyExchangeRateBefore = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );
    params.availableLiquidityBefore = hub.getAvailableLiquidity(usdxAssetId);
    params.balanceBefore = IERC20(hub.getAsset(usdxAssetId).underlying).balanceOf(address(spoke1));
    params.baseBorrowRateBefore = getBaseBorrowRate(hub, usdxAssetId);

    uint256 totalDeficit = baseAmount + premiumAmount;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitCreated(
      usdxAssetId,
      address(spoke1),
      hub.convertToDrawnShares(usdxAssetId, baseAmount),
      totalDeficit
    );

    // Restore the deficit
    vm.prank(address(spoke1));
    hub.reportDeficit(usdxAssetId, baseAmount, premiumAmount);

    params.deficitAfter = getDeficit(hub, usdxAssetId);
    params.supplyExchangeRateAfter = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );
    params.availableLiquidityAfter = hub.getAvailableLiquidity(usdxAssetId);
    params.balanceAfter = IERC20(hub.getAsset(usdxAssetId).underlying).balanceOf(address(spoke1));
    params.baseBorrowRateAfter = getBaseBorrowRate(hub, usdxAssetId);

    assertEq(params.baseBorrowRateBefore, params.baseBorrowRateAfter, 'base borrow rate');
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
  }

  /// Calculate the expected borrow rate after a restore action
  function _calcExpectedBorrowRate(
    uint256 assetId,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal view returns (uint256) {
    (uint256 baseDebt, ) = hub.getAssetDebt(assetId);

    return
      irStrategy.calculateInterestRate({
        assetId: assetId,
        availableLiquidity: hub.getAvailableLiquidity(assetId),
        totalDebt: baseDebt,
        liquidityAdded: liquidityAdded,
        liquidityTaken: liquidityTaken
      });
  }

  /// Create a borrow position thru user interaction with spoke, to accrue premium on spoke debt in hub
  /// Bob supplies max wbtc collateral thru spoke
  function _createBorrowPositionWithPremium(
    ISpoke spoke,
    uint256 reserveId,
    uint256 borrowAmount,
    uint256 skipTime
  ) internal returns (uint256 baseDebt, uint256 premiumDebt) {
    // Bob supplies max wbtc collateral and borrows
    Utils.supplyCollateral(spoke1, _wbtcReserveId(spoke1), bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.borrow(spoke, reserveId, bob, borrowAmount, address(bob));
    // skip to accrue interest
    skip(skipTime);

    (baseDebt, premiumDebt) = spoke.getUserDebt(reserveId, bob);

    assertGt(premiumDebt, 0);
  }
}
