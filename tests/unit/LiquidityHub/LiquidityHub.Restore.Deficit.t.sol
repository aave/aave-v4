// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBase.t.sol';

contract LiquidityHubRestoreDeficitTest is LiquidityHubBase {
  function setUp() public override {
    super.setUp();

    _deployLiquidity(spoke1, wethAssetId, MAX_SUPPLY_AMOUNT);
    _deployLiquidity(spoke1, usdxAssetId, MAX_SUPPLY_AMOUNT);

    // IERC20 asset = hub.assetsList(wethAssetId);
    vm.startPrank(address(spoke1));
    hub.assetsList(wethAssetId).approve(address(hub), type(uint256).max);
    hub.assetsList(usdxAssetId).approve(address(hub), type(uint256).max);
    vm.stopPrank();

    deal(address(tokenList.usdx), address(spoke1), 1e60);
  }

  /// @dev Restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (no accrual)
  function test_restore_revertsWith_InvalidDeficitAmount_with_deficit() public {
    test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual({
      drawnAmount: 10_000e6,
      deficitAmountRestored: 10_000e6 + 1,
      skipTime: 0,
      baseDebtRestored: 10_000e6,
      premiumDebtRestored: 25e6
    });
  }

  /// @dev Fuzz - restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (no accrual)
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

  /// @dev Restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (with accrual)
  function test_restore_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual() public {
    test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual({
      drawnAmount: 10_000e6,
      deficitAmountRestored: 20_000e6,
      skipTime: 365 days,
      baseDebtRestored: 10_500e6,
      premiumDebtRestored: 25e6
    });
  }

  /// @dev Fuzz - restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (with accrual)
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

    deficitAmountRestored = bound(
      deficitAmountRestored,
      baseDebt + premiumDebt + 1,
      type(uint256).max
    );

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

  /// @dev Restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (with premium)
  function test_restore_revertsWith_InvalidDeficitAmount_with_deficit_with_premium() public {
    test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_premium({
      drawnAmount: 10_000e6,
      deficitAmountRestored: 20_000e6,
      skipTime: 365 days,
      baseDebtRestored: 10_500e6,
      premiumDebtRestored: 25e6
    });
  }

  /// @dev Restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (with premium)
  function test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_premium(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 skipTime,
    uint256 baseDebtRestored,
    uint256 premiumDebtRestored
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    _createBorrowPositionWithPremium(spoke1, _usdxReserveId(spoke1), drawnAmount, skipTime);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(usdxAssetId, address(spoke1));
    vm.assume(premiumDebt > 0);

    baseDebtRestored = bound(baseDebtRestored, 0, baseDebt);
    premiumDebtRestored = bound(premiumDebtRestored, 0, premiumDebt);
    vm.assume(baseDebtRestored + premiumDebtRestored > 0);

    uint256 totalDebt = baseDebt + premiumDebt;
    deficitAmountRestored = bound(deficitAmountRestored, totalDebt + 1, type(uint256).max);

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

  function test_restore_with_deficit() public {
    uint256 drawnAmount = 10_000e6;

    // draw usdx liquidity to be restored
    Utils.draw(hub, usdxAssetId, address(spoke1), address(spoke1), drawnAmount, address(spoke1));

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(usdxAssetId, address(spoke1));

    uint256 baseDebtRestored = baseDebt;
    uint256 premiumDebtRestored = premiumDebt;
    // vm.assume(baseDebtRestored + premiumDebtRestored > 0);

    console.log('baseDebt: %e', baseDebt);
    console.log('premiumDebt: %e', premiumDebt);

    uint256 deficitAmountRestored = baseDebt / 2;
    uint256 deficitBefore = hub.getAsset(usdxAssetId).deficit;
    uint256 supplyExchangeRateBefore = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );

    // Set up the spoke to have a deficit
    // Restore the deficit
    vm.prank(address(spoke1));
    hub.restore(
      usdxAssetId,
      baseDebtRestored,
      premiumDebtRestored,
      deficitAmountRestored,
      address(spoke1)
    );

    uint256 deficitAfter = hub.getAsset(usdxAssetId).deficit;
    uint256 supplyExchangeRateAfter = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );

    console.log('supplyExchangeRateBefore: %e', supplyExchangeRateBefore);
    console.log('supplyExchangeRateAfter: %e', supplyExchangeRateAfter);

    assertEq(deficitAfter, deficitBefore + deficitAmountRestored, 'deficit accounting');
    assertEq(supplyExchangeRateAfter, supplyExchangeRateBefore, 'supply exchange rate');
  }

  function test_restore_fuzz_with_deficit(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 baseDebtRestored,
    uint256 premiumDebtRestored
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);

    // draw usdx liquidity to be restored
    Utils.draw(hub, usdxAssetId, address(spoke1), address(spoke1), drawnAmount, address(spoke1));

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(usdxAssetId, address(spoke1));

    baseDebtRestored = bound(baseDebtRestored, 0, baseDebt);
    premiumDebtRestored = bound(premiumDebtRestored, 0, premiumDebt);
    vm.assume(baseDebtRestored + premiumDebtRestored > 0);

    deficitAmountRestored = bound(deficitAmountRestored, 1, baseDebtRestored + premiumDebtRestored);

    uint256 deficitBefore = hub.getAsset(usdxAssetId).deficit;
    uint256 supplyExchangeRateBefore = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );

    // Set up the spoke to have a deficit
    // Restore the deficit
    vm.prank(address(spoke1));
    hub.restore(
      usdxAssetId,
      baseDebtRestored,
      premiumDebtRestored,
      deficitAmountRestored,
      address(spoke1)
    );
    // Check that the spoke's deficit has been restored

    uint256 deficitAfter = hub.getAsset(usdxAssetId).deficit;
    uint256 supplyExchangeRateAfter = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );

    assertEq(deficitAfter, deficitBefore + deficitAmountRestored, 'deficit accounting');
    assertEq(supplyExchangeRateAfter, supplyExchangeRateBefore, 'supply exchange rate');
  }

  function test_restore_fuzz_with_deficit_with_accrual(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 baseDebtRestored,
    uint256 premiumDebtRestored,
    uint256 skipTime
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    // draw usdx liquidity to be restored
    Utils.draw(hub, usdxAssetId, address(spoke1), address(spoke1), drawnAmount, address(spoke1));

    skip(skipTime);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(usdxAssetId, address(spoke1));

    baseDebtRestored = bound(baseDebtRestored, 0, baseDebt);
    premiumDebtRestored = bound(premiumDebtRestored, 0, premiumDebt);
    vm.assume(baseDebtRestored + premiumDebtRestored > 0);

    deficitAmountRestored = bound(deficitAmountRestored, 1, baseDebtRestored + premiumDebtRestored);

    uint256 deficitBefore = hub.getAsset(usdxAssetId).deficit;
    uint256 supplyExchangeRateBefore = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );

    // Restore with deficit
    vm.prank(address(spoke1));
    hub.restore(
      usdxAssetId,
      baseDebtRestored,
      premiumDebtRestored,
      deficitAmountRestored,
      address(spoke1)
    );

    uint256 deficitAfter = hub.getAsset(usdxAssetId).deficit;
    uint256 supplyExchangeRateAfter = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );

    assertEq(deficitAfter, deficitBefore + deficitAmountRestored, 'deficit accounting');
    assertGe(supplyExchangeRateAfter, supplyExchangeRateBefore, 'supply exchange rate ge');
    assertApproxEqAbs(
      supplyExchangeRateAfter,
      supplyExchangeRateBefore,
      1,
      'supply exchange rate approx eq'
    );
  }

  function test_restore_fuzz_with_deficit_with_premium(
    uint256 drawnAmount,
    uint256 deficitAmountRestored,
    uint256 baseDebtRestored,
    uint256 premiumDebtRestored,
    uint256 skipTime
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);

    // draw usdx liquidity to be restored
    Utils.draw(hub, usdxAssetId, address(spoke1), address(spoke1), drawnAmount, address(spoke1));

    // skip to accrue interest
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    // console.log('yeras', skipTime / 365 days);

    _createBorrowPositionWithPremium(spoke1, _usdxReserveId(spoke1), drawnAmount, skipTime);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(usdxAssetId, address(spoke1));

    baseDebtRestored = bound(baseDebtRestored, 0, baseDebt);
    premiumDebtRestored = bound(premiumDebtRestored, 0, premiumDebt);
    vm.assume(baseDebtRestored + premiumDebtRestored > 0);

    deficitAmountRestored = bound(deficitAmountRestored, 1, baseDebtRestored + premiumDebtRestored);

    uint256 deficitBefore = hub.getAsset(usdxAssetId).deficit;
    uint256 supplyExchangeRateBefore = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );

    // Set up the spoke to have a deficit
    // Restore the deficit
    vm.prank(address(spoke1));
    hub.restore(
      usdxAssetId,
      baseDebtRestored,
      premiumDebtRestored,
      deficitAmountRestored,
      address(spoke1)
    );
    // Check that the spoke's deficit has been restored

    uint256 deficitAfter = hub.getAsset(usdxAssetId).deficit;
    uint256 supplyExchangeRateAfter = hub.convertToSuppliedAssets(
      usdxAssetId,
      WadRayMathExtended.RAY
    );

    console.log(
      'hub ex rate %e %e',
      hub.convertToSuppliedAssets(usdxAssetId, 1),
      premiumDebtRestored
    );

    assertEq(deficitAfter, deficitBefore + deficitAmountRestored, 'deficit accounting');
    assertGe(supplyExchangeRateAfter, supplyExchangeRateBefore, 'supply exchange rate ge');
    assertApproxEqAbs(
      supplyExchangeRateAfter,
      supplyExchangeRateBefore,
      1,
      'supply exchange rate approx eq'
    );
  }

  /// Create a borrow position thru user interaction with spoke, to accrue premium on spoke debt in hub
  /// Bob supplies max wbtc collateral thru spoke
  function _createBorrowPositionWithPremium(
    ISpoke spoke,
    uint256 reserveId,
    uint256 borrowAmount,
    uint256 skipTime
  ) internal {
    // Bob supplies collateral
    Utils.supplyCollateral(spoke1, _wbtcReserveId(spoke1), bob, MAX_SUPPLY_AMOUNT, bob);
    // Bob borrows reserve
    Utils.borrow(spoke, reserveId, bob, borrowAmount, address(bob));
    // skip to accrue interest
    skip(skipTime);
  }
}
