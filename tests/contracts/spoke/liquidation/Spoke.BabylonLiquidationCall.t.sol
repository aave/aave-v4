// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/liquidation/Spoke.BabylonLiquidationCall.Base.t.sol';

contract SpokeBabylonLiquidationCallTest is SpokeBabylonLiquidationCallBaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using MathUtils for uint256;

  address internal user = makeAddr('user');
  uint256 internal debtReserveId;

  function setUp() public virtual override {
    super.setUp();
    debtReserveId = _daiReserveId(spoke4);
  }

  /// @dev Supplies `collateralValue` (in units of Value) of collateral for `user` and borrows the
  /// debt reserve so the user health factor lands at `healthFactor`.
  function _setUpLiquidatableUser(uint256 collateralValue, uint256 healthFactor) internal {
    _setUpLiquidatableUser(user, debtReserveId, collateralValue, healthFactor);
  }

  function _expectedRemovedValue(uint256 debtValueCovered) internal view returns (uint256) {
    return _expectedRemovedValue(user, debtValueCovered);
  }

  function _expectedRepaidValue(uint256 removedValue) internal view returns (uint256) {
    return _expectedRepaidValue(user, removedValue);
  }

  /// @dev The user reserves limit of one rejects borrowing a second debt reserve.
  function test_revert_borrow_secondDebtReserve() public {
    _increaseCollateralSupply(
      spoke4,
      collateralReserveId,
      _convertValueToAmount(spoke4, collateralReserveId, 100_000e26),
      user
    );
    _makeUserLiquidatable(spoke4, user, debtReserveId, 1.5e18);
    uint256 usdxReserveId = _usdxReserveId(spoke4);
    _openSupplyPositionNoCollateral(spoke4, usdxReserveId, 1e6);

    vm.expectRevert(ISpoke.MaximumUserReservesExceeded.selector);
    vm.prank(user);
    spoke4.borrow(usdxReserveId, 1e6, user);
  }

  function test_revert_liquidationCall_notLiquidationManager() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(alice);
    babylonSpoke.liquidationCall(debtReserveId, 1e18, user, 1e8);
  }

  function test_revert_liquidationCall_canonicalSignatureUnsupported() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(IBabylonSpoke.UnsupportedLiquidationCall.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(collateralReserveId, debtReserveId, user, 1e18, false);
  }

  function test_revert_liquidationCall_healthFactorNotBelowThreshold() public {
    // Setup: healthy borrow position
    _increaseCollateralSupply(
      spoke4,
      collateralReserveId,
      _convertValueToAmount(spoke4, collateralReserveId, 100_000e26),
      user
    );
    uint256 borrowAmount = _convertValueToAmount(spoke4, debtReserveId, 10_000e26);
    _openSupplyPositionNoCollateral(spoke4, debtReserveId, borrowAmount);
    SpokeActions.borrow({
      spoke: spoke4,
      reserveId: debtReserveId,
      caller: user,
      amount: borrowAmount,
      onBehalfOf: user
    });

    // Act & Assert
    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(debtReserveId, 1e18, user, 1e8);
  }

  function test_revert_liquidationCall_invalidDebtToCover() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(ISpoke.InvalidDebtToCover.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(debtReserveId, 0, user, 1e8);
  }

  /// @dev A zero cap degenerates to a zero-amount repayment, which the Hub rejects.
  function test_revert_liquidationCall_zeroMaxCollateralToRemove() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(debtReserveId, 1e18, user, 0);
  }

  /// @dev A repayment whose bonus-priced collateral removal floors to zero shares fits under a
  /// zero cap: debt can be liquidated even when there is no collateral left to receive.
  function test_liquidationCall_zeroCollateralRemoved() public {
    // Setup: a repayment small enough that its bonus-priced collateral removal floors to zero
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 debtToCover = 1e14;
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 debtBefore = spoke4.getUserTotalDebt(debtReserveId, user);
    uint256 suppliedBefore = spoke4.getUserSuppliedAssets(collateralReserveId, user);
    assertEq(_expectedRemovedShares(0), 0, 'zero cap in shares');

    // Act
    vm.prank(liquidationManager);
    (, uint256 collateralAmountRemoved) = babylonSpoke.liquidationCall(
      debtReserveId,
      debtToCover,
      user,
      0
    );

    // Assert: the debt is repaid while no collateral is removed
    assertApproxEqAbs(
      debtBefore - spoke4.getUserTotalDebt(debtReserveId, user),
      debtToCover,
      2,
      'debt repaid'
    );
    assertEq(
      spoke4.getUserSuppliedAssets(collateralReserveId, user),
      suppliedBefore,
      'no collateral removed'
    );
    assertEq(collateralAmountRemoved, 0, 'returned collateral amount removed');
  }

  function test_revert_liquidationCall_debtReservePaused() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    _updateReservePausedFlag(spoke4, debtReserveId, true);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(debtReserveId, 1e18, user, 1e8);
  }

  function test_revert_liquidationCall_debtReserveNotBorrowed() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 usdxReserveId = _usdxReserveId(spoke4);
    _fundLiquidationManager(usdxReserveId, 1e6);

    vm.expectRevert(ISpoke.ReserveNotBorrowed.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(usdxReserveId, 1e6, user, 1e8);
  }

  function test_revert_liquidationCall_selfLiquidation() public {
    vm.expectRevert(ISpoke.SelfLiquidation.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(debtReserveId, 1e18, liquidationManager, 1e8);
  }

  function test_revert_liquidationCall_collateralReservePaused() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    _updateReservePausedFlag(spoke4, collateralReserveId, true);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(debtReserveId, 1e18, user, 1e8);
  }

  /// @dev Drives a partial liquidation through the full assertion engine.
  function test_liquidationCall_checked_partial() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 debtToCover = spoke4.getUserTotalDebt(debtReserveId, user) / 2;
    _fundLiquidationManager(debtReserveId, debtToCover);

    _checkedBabylonLiquidationCall(
      CheckedBabylonLiquidationCallParams({
        debtReserveId: debtReserveId,
        debtToCover: debtToCover,
        user: user,
        maxCollateralToRemove: spoke4.getUserSuppliedAssets(collateralReserveId, user) * 2
      })
    );
  }

  function test_liquidationCall_collateralCapNotReached() public {
    // Setup
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 debtBefore = spoke4.getUserTotalDebt(debtReserveId, user);
    uint256 debtToCover = debtBefore / 2;
    _fundLiquidationManager(debtReserveId, debtToCover);

    uint256 debtValueCovered = _convertAmountToValue(spoke4, debtReserveId, debtToCover);
    uint256 expectedRemovedValue = _expectedRemovedValue(debtValueCovered);
    uint256 userSuppliedBefore = spoke4.getUserSuppliedAssets(collateralReserveId, user);
    IERC20 collateralUnderlying = _getAssetUnderlyingByReserveId(spoke4, collateralReserveId);
    uint256 liquidatorCollateralBefore = collateralUnderlying.balanceOf(liquidationManager);
    uint256 maxCollateralToRemove = userSuppliedBefore * 2; // above the priced removal

    // Act
    vm.expectEmit(true, true, true, false, address(babylonSpoke));
    emit IBabylonSpoke.BabylonLiquidationCall({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      user: user,
      liquidator: liquidationManager,
      debtAmountRestored: 0,
      drawnSharesLiquidated: 0,
      premiumDelta: ZERO_PREMIUM_DELTA,
      collateralAmountRemoved: 0,
      collateralSharesLiquidated: 0
    });
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Assert: the requested debt is repaid and the removed collateral is priced by the canonical bonus formula
    assertApproxEqAbs(
      debtBefore - spoke4.getUserTotalDebt(debtReserveId, user),
      debtToCover,
      2,
      'repaid debt'
    );
    assertApproxEqRel(
      _convertAmountToValue(
        spoke4,
        collateralReserveId,
        userSuppliedBefore - spoke4.getUserSuppliedAssets(collateralReserveId, user)
      ),
      expectedRemovedValue,
      0.0001e18,
      'removed collateral value'
    );
    assertApproxEqRel(
      _convertAmountToValue(
        spoke4,
        collateralReserveId,
        collateralUnderlying.balanceOf(liquidationManager) - liquidatorCollateralBefore
      ),
      expectedRemovedValue,
      0.0001e18,
      'liquidator collateral value'
    );
  }

  function test_liquidationCall_collateralCapEnforced() public {
    // Setup
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 debtBefore = spoke4.getUserTotalDebt(debtReserveId, user);
    uint256 debtToCover = debtBefore / 2;
    _fundLiquidationManager(debtReserveId, debtToCover);

    uint256 debtValueCovered = _convertAmountToValue(spoke4, debtReserveId, debtToCover);
    // cap the removal at half of what the canonical bonus formula would remove
    uint256 maxCollateralToRemove = _convertValueToAmount(
      spoke4,
      collateralReserveId,
      _expectedRemovedValue(debtValueCovered) / 2
    );
    uint256 capValue = _convertAmountToValue(spoke4, collateralReserveId, maxCollateralToRemove);
    uint256 expectedRemovedShares = _expectedRemovedShares(maxCollateralToRemove);
    uint256 expectedRepaid = _convertValueToAmount(
      spoke4,
      debtReserveId,
      _expectedRepaidValue(capValue)
    );
    uint256 debtBalanceBefore = _getAssetUnderlyingByReserveId(spoke4, debtReserveId).balanceOf(
      liquidationManager
    );
    uint256 userSuppliedSharesBefore = spoke4.getUserSuppliedShares(collateralReserveId, user);
    IERC20 collateralUnderlying = _getAssetUnderlyingByReserveId(spoke4, collateralReserveId);
    uint256 liquidatorCollateralBefore = collateralUnderlying.balanceOf(liquidationManager);

    // Act
    vm.prank(liquidationManager);
    (, uint256 collateralAmountRemoved) = babylonSpoke.liquidationCall(
      debtReserveId,
      debtToCover,
      user,
      maxCollateralToRemove
    );

    // Assert: the cap is exactly consumed and the repayment is resized to its inverse value
    assertEq(
      userSuppliedSharesBefore - spoke4.getUserSuppliedShares(collateralReserveId, user),
      expectedRemovedShares,
      'removed collateral shares'
    );
    uint256 repaid = debtBefore - spoke4.getUserTotalDebt(debtReserveId, user);
    assertLt(repaid, debtToCover, 'repaid below requested');
    assertApproxEqRel(repaid, expectedRepaid, 0.0001e18, 'repaid debt');
    assertApproxEqAbs(
      debtBalanceBefore -
        _getAssetUnderlyingByReserveId(spoke4, debtReserveId).balanceOf(liquidationManager),
      repaid,
      2,
      'liquidator debt spent'
    );
    uint256 liquidatorCollateralReceived = collateralUnderlying.balanceOf(liquidationManager) -
      liquidatorCollateralBefore;
    assertApproxEqRel(
      _convertAmountToValue(spoke4, collateralReserveId, liquidatorCollateralReceived),
      capValue,
      0.0001e18,
      'liquidator collateral value'
    );
    assertEq(
      collateralAmountRemoved,
      liquidatorCollateralReceived,
      'returned collateral amount removed'
    );
  }

  function test_liquidationCall_fullDebtRepay() public {
    // Setup
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 debtToCover = spoke4.getUserTotalDebt(debtReserveId, user);
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 maxCollateralToRemove = spoke4.getUserSuppliedAssets(collateralReserveId, user) * 2;

    // Act
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Assert: debt is fully cleared with no dust validation and no deficit
    assertEq(spoke4.getUserTotalDebt(debtReserveId, user), 0, 'user debt');
    (, bool isBorrowing) = spoke4.getUserReserveStatus(debtReserveId, user);
    assertFalse(isBorrowing, 'user borrowing status');
    assertEq(_getUserHealthFactor(spoke4, user), UINT256_MAX, 'user health factor');
    assertGt(spoke4.getUserSuppliedAssets(collateralReserveId, user), 0, 'remaining collateral');
  }

  function test_liquidationCall_noDustValidation() public {
    // Setup: small position, so both the remaining debt and collateral end up below the canonical
    // dust threshold; the Babylon liquidation must not revert with MustNotLeaveDust
    _setUpLiquidatableUser(2_000e26, 0.9e18);
    uint256 debtBefore = spoke4.getUserTotalDebt(debtReserveId, user);
    uint256 debtToCover = debtBefore - _convertValueToAmount(spoke4, debtReserveId, 500e26);
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 maxCollateralToRemove = spoke4.getUserSuppliedAssets(collateralReserveId, user) * 2;

    // Act
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Assert: sub-dust debt and collateral remain
    uint256 remainingDebtValue = _convertAmountToValue(
      spoke4,
      debtReserveId,
      spoke4.getUserTotalDebt(debtReserveId, user)
    );
    uint256 remainingCollateralValue = _convertAmountToValue(
      spoke4,
      collateralReserveId,
      spoke4.getUserSuppliedAssets(collateralReserveId, user)
    );
    assertGt(remainingDebtValue, 0, 'remaining debt');
    assertLt(remainingDebtValue, LiquidationLogic.DUST_LIQUIDATION_THRESHOLD, 'debt below dust');
    assertGt(remainingCollateralValue, 0, 'remaining collateral');
    assertLt(
      remainingCollateralValue,
      LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
      'collateral below dust'
    );
  }

  /// @dev The call returns the bonus it priced with and the collateral it removed, so the
  /// liquidation manager does not recompute them.
  function test_liquidationCall_returnsLiquidationData() public {
    // Setup
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 debtToCover = spoke4.getUserTotalDebt(debtReserveId, user) / 2;
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 expectedLiquidationBonus = spoke4.getLiquidationBonus(
      collateralReserveId,
      user,
      _getUserHealthFactor(spoke4, user)
    );
    IERC20 collateralUnderlying = _getAssetUnderlyingByReserveId(spoke4, collateralReserveId);
    uint256 liquidatorCollateralBefore = collateralUnderlying.balanceOf(liquidationManager);
    uint256 maxCollateralToRemove = spoke4.getUserSuppliedAssets(collateralReserveId, user) * 2;

    // Act
    vm.prank(liquidationManager);
    (uint256 liquidationBonus, uint256 collateralAmountRemoved) = babylonSpoke.liquidationCall(
      debtReserveId,
      debtToCover,
      user,
      maxCollateralToRemove
    );

    // Assert
    assertEq(liquidationBonus, expectedLiquidationBonus, 'liquidation bonus');
    assertEq(
      collateralAmountRemoved,
      collateralUnderlying.balanceOf(liquidationManager) - liquidatorCollateralBefore,
      'collateral amount removed'
    );
    assertGt(collateralAmountRemoved, 0, 'collateral removed');
  }

  function test_liquidationCall_frozenCollateralReserve() public {
    // Setup
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    _updateReserveFrozenFlag(spoke4, collateralReserveId, true);

    uint256 debtBefore = spoke4.getUserTotalDebt(debtReserveId, user);
    uint256 debtToCover = debtBefore / 2;
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 maxCollateralToRemove = spoke4.getUserSuppliedAssets(collateralReserveId, user) * 2;

    // Act: the liquidator receives underlying assets, so a frozen collateral reserve is liquidatable
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Assert
    assertApproxEqAbs(
      debtBefore - spoke4.getUserTotalDebt(debtReserveId, user),
      debtToCover,
      2,
      'repaid debt'
    );
  }

  function test_liquidationCall_deficit() public {
    // Setup: insolvent position where removing all collateral cannot clear the debt
    _setUpLiquidatableUser(2_000e26, 0.5e18);
    uint256 debtToCover = _convertValueToAmount(spoke4, debtReserveId, 2_500e26);
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 maxCollateralToRemove = spoke4.getUserSuppliedAssets(collateralReserveId, user) * 2;

    // Act
    vm.expectEmit(true, true, false, false, address(babylonSpoke));
    emit ISpoke.ReportDeficit({
      reserveId: debtReserveId,
      user: user,
      drawnShares: 0,
      premiumDelta: ZERO_PREMIUM_DELTA
    });
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(debtReserveId, debtToCover, user, maxCollateralToRemove);

    // Assert: all collateral is removed and the remaining debt is written off as deficit
    assertEq(spoke4.getUserSuppliedShares(collateralReserveId, user), 0, 'user collateral');
    assertEq(spoke4.getUserTotalDebt(debtReserveId, user), 0, 'user debt');
    (, bool isBorrowing) = spoke4.getUserReserveStatus(debtReserveId, user);
    assertFalse(isBorrowing, 'user borrowing status');
    assertEq(spoke4.getUserLastRiskPremium(user), 0, 'user risk premium');
  }
}
