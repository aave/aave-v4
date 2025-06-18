// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBase.t.sol';

contract LiquidityHubRestoreDeficitTest is LiquidityHubBase {
  struct RestoreDeficitTestParams {
    uint256 baseDebt;
    uint256 premiumDebt;
    uint256 actualAmountRestored;
    uint256 deficitBefore;
    uint256 deficitAfter;
    uint256 supplyExchangeRateBefore;
    uint256 supplyExchangeRateAfter;
    uint256 availableLiquidityBefore;
    uint256 availableLiquidityAfter;
    uint256 balanceBefore;
    uint256 balanceAfter;
    uint256 baseBorrowRateAfter;
    uint256 baseBorrowRateExpected;
  }
  function setUp() public override {
    super.setUp();

    // deploy borrowable liquidity
    _deployLiquidity(spoke1, wethAssetId, MAX_SUPPLY_AMOUNT);
    _deployLiquidity(spoke1, usdxAssetId, MAX_SUPPLY_AMOUNT);

    // max approve
    vm.startPrank(address(spoke1));
    hub.assetsList(wethAssetId).approve(address(hub), UINT256_MAX);
    hub.assetsList(usdxAssetId).approve(address(hub), UINT256_MAX);
    vm.stopPrank();

    // mint usdx to spoke1 to be able to repay after accrual
    deal(address(tokenList.usdx), address(spoke1), 1e60);
  }

  /// @notice Restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (no accrual).
  function test_restore_revertsWith_InvalidDeficitAmount_with_deficit() public {
    test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual({
      drawnAmount: 10_000e6,
      deficitAmountRestored: 10_000e6 + 1,
      skipTime: 0,
      baseDebtRestored: 10_000e6,
      premiumDebtRestored: 25e6
    });
  }

  /// @notice Fuzz - restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (no accrual).
  function test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 baseDebtRestored,
    uint256 premiumDebtRestored
  ) public {
    test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual({
      drawnAmount: drawnAmount,
      deficitAmountRestored: deficitAmountRestored,
      skipTime: 0,
      baseDebtRestored: baseDebtRestored,
      premiumDebtRestored: premiumDebtRestored
    });
  }

  /// @notice Restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (with accrual).
  function test_restore_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual() public {
    test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual({
      drawnAmount: 10_000e6,
      deficitAmountRestored: 20_000e6,
      skipTime: 365 days,
      baseDebtRestored: 10_500e6,
      premiumDebtRestored: 25e6
    });
  }

  /// @notice Fuzz - restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (with accrual).
  function test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 skipTime,
    uint256 baseDebtRestored,
    uint256 premiumDebtRestored
  ) public {
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);

    // draw usdx liquidity to be restored
    Utils.draw(hub, usdxAssetId, address(spoke1), address(spoke1), drawnAmount, address(spoke1));

    // skip to accrue interest
    skip(skipTime);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(usdxAssetId, address(spoke1));
    baseDebtRestored = bound(baseDebtRestored, 0, baseDebt);
    premiumDebtRestored = bound(premiumDebtRestored, 0, premiumDebt);
    vm.assume(baseDebtRestored + premiumDebtRestored > 0);

    deficitAmountRestored = bound(deficitAmountRestored, baseDebt + premiumDebt + 1, UINT256_MAX);

    vm.expectRevert(ILiquidityHub.InvalidDeficitAmount.selector);

    vm.prank(address(spoke1));
    hub.restore(
      usdxAssetId,
      baseDebtRestored,
      premiumDebtRestored,
      deficitAmountRestored,
      address(spoke1)
    );
  }

  /// @notice Restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (with premium).
  function test_restore_revertsWith_InvalidDeficitAmount_with_deficit_with_premium() public {
    test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_premium({
      drawnAmount: 10_000e6,
      deficitAmountRestored: 20_000e6,
      skipTime: 365 days,
      baseDebtRestored: 10_500e6,
      premiumDebtRestored: 25e6
    });
  }

  /// @notice Restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (with premium).
  function test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_premium(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 skipTime,
    uint256 baseDebtRestored,
    uint256 premiumDebtRestored
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    (uint256 baseDebt, uint256 premiumDebt) = _createBorrowPositionWithPremium(
      spoke1,
      _usdxReserveId(spoke1),
      drawnAmount,
      skipTime
    );
    vm.assume(premiumDebt > 0);

    baseDebtRestored = bound(baseDebtRestored, 0, baseDebt);
    premiumDebtRestored = bound(premiumDebtRestored, 0, premiumDebt);
    vm.assume(baseDebtRestored + premiumDebtRestored > 0);

    uint256 totalDebt = baseDebt + premiumDebt;
    deficitAmountRestored = bound(deficitAmountRestored, totalDebt + 1, UINT256_MAX);

    vm.expectRevert(ILiquidityHub.InvalidDeficitAmount.selector);

    vm.prank(address(spoke1));
    hub.restore(
      usdxAssetId,
      baseDebtRestored,
      premiumDebtRestored,
      deficitAmountRestored,
      address(spoke1)
    );
  }

  /// @notice Restore with deficit, with base debt and without premium debt, without accrual
  function test_restore_with_deficit() public {
    uint256 drawnAmount = 10_000e6;
    test_restore_fuzz_with_deficit({
      drawnAmount: drawnAmount,
      deficitAmountRestored: drawnAmount / 2,
      baseDebtRestored: drawnAmount,
      premiumDebtRestored: 0
    });
  }

  /// @notice Fuzz - restore with deficit, with base debt and without premium debt, without accrual
  function test_restore_fuzz_with_deficit(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 baseDebtRestored,
    uint256 premiumDebtRestored
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);

    RestoreDeficitTestParams memory params;

    // draw usdx liquidity to be restored
    Utils.draw(hub, usdxAssetId, address(spoke1), address(spoke1), drawnAmount, address(spoke1));

    (params.baseDebt, params.premiumDebt) = hub.getSpokeDebt(usdxAssetId, address(spoke1));

    baseDebtRestored = bound(baseDebtRestored, 0, params.baseDebt);
    premiumDebtRestored = bound(premiumDebtRestored, 0, params.premiumDebt);
    vm.assume(baseDebtRestored + premiumDebtRestored > 0);

    deficitAmountRestored = bound(deficitAmountRestored, 1, baseDebtRestored + premiumDebtRestored);
    params.actualAmountRestored = baseDebtRestored + premiumDebtRestored - deficitAmountRestored;

    params.deficitBefore = hub.getDeficit(usdxAssetId);
    params.supplyExchangeRateBefore = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );
    params.availableLiquidityBefore = hub.getAvailableLiquidity(usdxAssetId);
    params.balanceBefore = hub.assetsList(usdxAssetId).balanceOf(address(spoke1));
    params.baseBorrowRateExpected = _calcExpectedBorrowRate(
      usdxAssetId,
      _calculateLiquidityAdded(baseDebtRestored, premiumDebtRestored, deficitAmountRestored),
      0
    );

    // Restore the deficit
    vm.prank(address(spoke1));
    hub.restore(
      usdxAssetId,
      baseDebtRestored,
      premiumDebtRestored,
      deficitAmountRestored,
      address(spoke1)
    );

    params.deficitAfter = hub.getDeficit(usdxAssetId);
    params.supplyExchangeRateAfter = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );
    params.availableLiquidityAfter = hub.getAvailableLiquidity(usdxAssetId);
    params.balanceAfter = hub.assetsList(usdxAssetId).balanceOf(address(spoke1));
    params.baseBorrowRateAfter = hub.getAsset(usdxAssetId).baseBorrowRate;

    assertEq(params.baseBorrowRateAfter, params.baseBorrowRateExpected, 'base borrow rate');
    assertEq(
      params.balanceAfter + params.actualAmountRestored,
      params.balanceBefore,
      'balance change'
    );
    assertEq(
      params.availableLiquidityAfter,
      params.availableLiquidityBefore + params.actualAmountRestored,
      'available liquidity'
    );
    assertEq(
      params.deficitAfter,
      params.deficitBefore + deficitAmountRestored,
      'deficit accounting'
    );
    assertEq(
      params.supplyExchangeRateAfter,
      params.supplyExchangeRateBefore,
      'supply exchange rate'
    );
  }

  /// @notice Restore with deficit, with base debt accrual but without premium debt
  function test_restore_fuzz_with_deficit_with_accrual(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 baseDebtRestored,
    uint256 premiumDebtRestored
  ) public {
    test_restore_fuzz_with_deficit_with_premium({
      drawnAmount: drawnAmount,
      deficitAmountRestored: deficitAmountRestored,
      baseDebtRestored: baseDebtRestored,
      premiumDebtRestored: premiumDebtRestored,
      skipTime: 0
    });
  }

  /// @notice Restore with deficit, with base debt and premium debt
  function test_restore_fuzz_with_deficit_with_premium(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 baseDebtRestored,
    uint256 premiumDebtRestored,
    uint256 skipTime
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    RestoreDeficitTestParams memory params;

    (params.baseDebt, params.premiumDebt) = _createBorrowPositionWithPremium(
      spoke1,
      _usdxReserveId(spoke1),
      drawnAmount,
      skipTime
    );
    vm.assume(params.premiumDebt > 0);

    baseDebtRestored = bound(baseDebtRestored, 0, params.baseDebt);
    premiumDebtRestored = bound(premiumDebtRestored, 0, params.premiumDebt);
    vm.assume(baseDebtRestored + premiumDebtRestored > 0);

    // restore deficit amount <= total debt amount restored
    deficitAmountRestored = bound(deficitAmountRestored, 1, baseDebtRestored + premiumDebtRestored);

    params.actualAmountRestored = baseDebtRestored + premiumDebtRestored - deficitAmountRestored;

    params.deficitBefore = hub.getDeficit(usdxAssetId);
    params.supplyExchangeRateBefore = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );
    params.availableLiquidityBefore = hub.getAvailableLiquidity(usdxAssetId);
    params.balanceBefore = hub.assetsList(usdxAssetId).balanceOf(address(spoke1));
    params.baseBorrowRateExpected = _calcExpectedBorrowRate(
      usdxAssetId,
      _calculateLiquidityAdded(baseDebtRestored, premiumDebtRestored, deficitAmountRestored),
      0
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitCreated(usdxAssetId, address(spoke1), deficitAmountRestored);

    // Restore with deficit
    vm.prank(address(spoke1));
    hub.restore(
      usdxAssetId,
      baseDebtRestored,
      premiumDebtRestored,
      deficitAmountRestored,
      address(spoke1)
    );

    params.deficitAfter = hub.getDeficit(usdxAssetId);
    params.supplyExchangeRateAfter = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );
    params.availableLiquidityAfter = hub.getAvailableLiquidity(usdxAssetId);
    params.balanceAfter = hub.assetsList(usdxAssetId).balanceOf(address(spoke1));
    params.baseBorrowRateAfter = hub.getAsset(usdxAssetId).baseBorrowRate;

    assertEq(params.baseBorrowRateAfter, params.baseBorrowRateExpected, 'base borrow rate');
    assertEq(
      params.balanceAfter + params.actualAmountRestored,
      params.balanceBefore,
      'balance change'
    );
    assertEq(
      params.availableLiquidityAfter,
      params.availableLiquidityBefore + params.actualAmountRestored,
      'available liquidity'
    );
    assertEq(
      params.deficitAfter,
      params.deficitBefore + deficitAmountRestored,
      'deficit accounting'
    );
    assertGe(
      params.supplyExchangeRateAfter,
      params.supplyExchangeRateBefore,
      'supply exchange rate ge'
    );
  }

  /// @notice Restore with deficit amount <= premium amount
  function test_restore_fuzz_with_deficit_only_premium(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 baseDebtRestored,
    uint256 premiumDebtRestored,
    uint256 skipTime
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    RestoreDeficitTestParams memory params;
    (params.baseDebt, params.premiumDebt) = _createBorrowPositionWithPremium(
      spoke1,
      _usdxReserveId(spoke1),
      drawnAmount,
      skipTime
    );
    vm.assume(params.premiumDebt > 0);

    baseDebtRestored = bound(baseDebtRestored, 0, params.baseDebt);
    premiumDebtRestored = bound(premiumDebtRestored, 1, params.premiumDebt);

    // restore deficit amount <= premium amount
    deficitAmountRestored = bound(deficitAmountRestored, 1, premiumDebtRestored);

    params.actualAmountRestored = baseDebtRestored + premiumDebtRestored - deficitAmountRestored;
    params.deficitBefore = hub.getDeficit(usdxAssetId);
    params.supplyExchangeRateBefore = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );
    params.availableLiquidityBefore = hub.getAvailableLiquidity(usdxAssetId);
    params.balanceBefore = hub.assetsList(usdxAssetId).balanceOf(address(spoke1));
    params.baseBorrowRateExpected = _calcExpectedBorrowRate(
      usdxAssetId,
      _calculateLiquidityAdded(baseDebtRestored, premiumDebtRestored, deficitAmountRestored),
      0
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitCreated(usdxAssetId, address(spoke1), deficitAmountRestored);

    // Restore with deficit
    vm.prank(address(spoke1));
    hub.restore(
      usdxAssetId,
      baseDebtRestored,
      premiumDebtRestored,
      deficitAmountRestored,
      address(spoke1)
    );

    params.deficitAfter = hub.getDeficit(usdxAssetId);
    params.supplyExchangeRateAfter = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );
    params.availableLiquidityAfter = hub.getAvailableLiquidity(usdxAssetId);
    params.balanceAfter = hub.assetsList(usdxAssetId).balanceOf(address(spoke1));
    params.baseBorrowRateAfter = hub.getAsset(usdxAssetId).baseBorrowRate;

    assertEq(params.baseBorrowRateAfter, params.baseBorrowRateExpected, 'base borrow rate');
    assertEq(
      params.balanceAfter + params.actualAmountRestored,
      params.balanceBefore,
      'balance change'
    );
    assertEq(
      params.availableLiquidityAfter,
      params.availableLiquidityBefore + params.actualAmountRestored,
      'available liquidity'
    );
    assertEq(
      params.deficitAfter,
      params.deficitBefore + deficitAmountRestored,
      'deficit accounting'
    );
    assertGe(
      params.supplyExchangeRateAfter,
      params.supplyExchangeRateBefore,
      'supply exchange rate ge'
    );
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
  }

  /// Calculate the expected borrow rate after a restore action
  function _calcExpectedBorrowRate(
    uint256 assetId,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal view returns (uint256) {
    (uint256 baseDebt, ) = hub.getAssetDebt(assetId);

    return
      irStrategy.calculateInterestRates(
        DataTypes.CalculateInterestRatesParams({
          liquidityAdded: liquidityAdded,
          liquidityTaken: liquidityTaken,
          totalDebt: baseDebt,
          liquidityFee: 0,
          assetId: assetId,
          virtualUnderlyingBalance: hub.getAvailableLiquidity(assetId),
          usingVirtualBalance: true
        })
      );
  }

  /// Calculate the expected liquidity added in a restore action accounting for the deficit
  function _calculateLiquidityAdded(
    uint256 baseAmount,
    uint256 premiumAmount,
    uint256 deficitAmount
  ) internal pure returns (uint256) {
    uint256 flooredSub = deficitAmount > premiumAmount ? deficitAmount - premiumAmount : 0;
    return baseAmount - flooredSub;
  }
}
