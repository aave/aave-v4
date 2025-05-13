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
  }

  /// @dev Restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (no accrual)
  function test_restore_revertsWith_InvalidDeficitAmount_with_deficit() public {
    test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual({
      drawnAmount: 10_000e6,
      deficitAmountToRestore: 10_000e6 + 1,
      skipTime: 0
    });
  }

  /// @dev Fuzz - restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (no accrual)
  function test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit(
    uint256 drawnAmount,
    uint256 deficitAmountToRestore
  ) public {
    test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual({
      drawnAmount: drawnAmount,
      deficitAmountToRestore: deficitAmountToRestore,
      skipTime: 0
    });
  }

  /// @dev Restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (with accrual)
  function test_restore_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual() public {
    test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual({
      drawnAmount: 10_000e6,
      deficitAmountToRestore: 20_000e6,
      skipTime: 365 days
    });
  }

  /// @dev Fuzz - restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (with accrual)
  function test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_accrual(
    uint256 drawnAmount,
    uint256 deficitAmountToRestore,
    uint256 skipTime
  ) public {
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);

    // draw usdx liquidity to be restored
    Utils.draw(hub, usdxAssetId, address(spoke1), address(spoke1), drawnAmount, address(spoke1));

    // skip to accrue interest
    skip(skipTime);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(usdxAssetId, address(spoke1));
    deficitAmountToRestore = bound(
      deficitAmountToRestore,
      baseDebt + premiumDebt + 1,
      type(uint256).max
    );

    vm.expectRevert(ILiquidityHub.InvalidDeficitAmount.selector);

    vm.prank(address(spoke1));
    hub.restore(usdxAssetId, baseDebt, premiumDebt, deficitAmountToRestore, address(spoke1));
  }

  /// @dev Restore reverts with InvalidDeficitAmount when deficit amount is greater than the debt amount (with accrual)
  function test_restore_revertsWith_InvalidDeficitAmount_with_deficit_with_premium() public {
    test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_premium({
      drawnAmount: 10_000_000e6,
      deficitAmountToRestore: 20_000_000e6,
      skipTime: 365 days
    });
  }

  function test_restore_fuzz_revertsWith_InvalidDeficitAmount_with_deficit_with_premium(
    uint256 drawnAmount,
    uint256 deficitAmountToRestore,
    uint256 skipTime
  ) public {
    drawnAmount = bound(drawnAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, 365 days);

    _createBorrowPositionWithPremium(spoke1, _usdxReserveId(spoke1), drawnAmount, 365 days);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getSpokeDebt(usdxAssetId, address(spoke1));
    vm.assume(premiumDebt > 0);

    uint256 totalDebt = baseDebt + premiumDebt;
    deficitAmountToRestore = bound(deficitAmountToRestore, totalDebt + 1, type(uint256).max);

    vm.expectRevert(ILiquidityHub.InvalidDeficitAmount.selector);

    vm.prank(address(spoke1));
    hub.restore(usdxAssetId, baseDebt, premiumDebt, deficitAmountToRestore, address(spoke1));
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
