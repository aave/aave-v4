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

  /// @dev Borrows `debtValue` (in units of Value) of `reserveId` for `user`.
  function _borrowSecondReserve(uint256 reserveId, uint256 debtValue) internal {
    uint256 borrowAmount = _convertValueToAmount(spoke4, reserveId, debtValue);
    _openSupplyPositionNoCollateral(spoke4, reserveId, borrowAmount);
    SpokeActions.borrow({
      spoke: spoke4,
      reserveId: reserveId,
      caller: user,
      amount: borrowAmount,
      onBehalfOf: user
    });
  }

  function _expectedRemovedValue(uint256 debtValueCovered) internal view returns (uint256) {
    return _expectedRemovedValue(user, debtValueCovered);
  }

  function _expectedRepaidValue(uint256 removedValue) internal view returns (uint256) {
    return _expectedRepaidValue(user, removedValue);
  }

  function test_updateBabylonLiquidationConfig() public {
    address newManager = makeAddr('newManager');

    vm.expectEmit(address(babylonSpoke));
    emit IBabylonSpoke.UpdateBabylonLiquidationConfig(newManager, debtReserveId);
    vm.prank(ADMIN);
    babylonSpoke.updateBabylonLiquidationConfig(newManager, debtReserveId);

    (address manager, uint256 managedCollateralReserveId) = babylonSpoke
      .getBabylonLiquidationConfig();
    assertEq(manager, newManager, 'liquidation manager');
    assertEq(managedCollateralReserveId, debtReserveId, 'managed collateral reserve id');
  }

  function test_revert_updateBabylonLiquidationConfig_unauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    babylonSpoke.updateBabylonLiquidationConfig(alice, collateralReserveId);
  }

  function test_revert_updateBabylonLiquidationConfig_reserveNotListed() public {
    uint256 unlistedReserveId = spoke4.getReserveCount();

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(ADMIN);
    babylonSpoke.updateBabylonLiquidationConfig(liquidationManager, unlistedReserveId);
  }

  function test_setUsingAsCollateral_managedCollateralReserve() public {
    vm.startPrank(alice);
    spoke4.setUsingAsCollateral(collateralReserveId, true, alice);

    // the managed collateral can be disabled and registered again
    spoke4.setUsingAsCollateral(collateralReserveId, false, alice);
    spoke4.setUsingAsCollateral(collateralReserveId, true, alice);
    vm.stopPrank();

    (bool isUsingAsCollateral, ) = spoke4.getUserReserveStatus(collateralReserveId, alice);
    assertTrue(isUsingAsCollateral, 'managed collateral registered');
  }

  function test_revert_setUsingAsCollateral_unsupportedCollateralReserve() public {
    vm.expectRevert(IBabylonSpoke.UnsupportedCollateralReserve.selector);
    vm.prank(alice);
    spoke4.setUsingAsCollateral(debtReserveId, true, alice);
  }

  /// @dev Reachable when the managed collateral reserve is updated while a user still has the
  /// previous one registered.
  function test_revert_setUsingAsCollateral_collateralLimitExceeded() public {
    vm.prank(alice);
    spoke4.setUsingAsCollateral(collateralReserveId, true, alice);
    _setManagedCollateralReserve(debtReserveId);

    vm.expectRevert(IBabylonSpoke.CollateralLimitExceeded.selector);
    vm.prank(alice);
    spoke4.setUsingAsCollateral(debtReserveId, true, alice);
  }

  function test_revert_liquidationCall_notLiquidationManager() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(alice);
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(1e18), user, 1e8);
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
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(1e18), user, 1e8);
  }

  function test_revert_liquidationCall_emptyDebtReserves() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(IBabylonSpoke.InvalidLiquidationCallArguments.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(new uint256[](0), new uint256[](0), user, 1e8);
  }

  function test_revert_liquidationCall_mismatchedArrayLengths() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(IBabylonSpoke.InvalidLiquidationCallArguments.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(1e18, 1e18), user, 1e8);
  }

  function test_revert_liquidationCall_invalidDebtToCover() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(ISpoke.InvalidDebtToCover.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(0), user, 1e8);
  }

  /// @dev A zero cap degenerates to a zero-amount repayment, which the Hub rejects.
  function test_revert_liquidationCall_zeroMaxCollateralToRemove() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(1e18), user, 0);
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
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(debtToCover), user, 0);

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
  }

  function test_revert_liquidationCall_debtReservePaused() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    _updateReservePausedFlag(spoke4, debtReserveId, true);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(1e18), user, 1e8);
  }

  /// @dev A debt reserve the user does not borrow is skipped: repayments cannot be blocked by
  /// front-running liquidations.
  function test_liquidationCall_skipsNotBorrowedDebtReserve() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 usdxReserveId = _usdxReserveId(spoke4);
    uint256 debtToCover = 1e18;
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 debtBefore = spoke4.getUserTotalDebt(debtReserveId, user);

    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(
      _arr(usdxReserveId, debtReserveId),
      _arr(1e6, debtToCover),
      user,
      1e8
    );

    assertApproxEqAbs(
      debtBefore - spoke4.getUserTotalDebt(debtReserveId, user),
      debtToCover,
      2,
      'listed borrowed reserve repaid'
    );
    assertEq(spoke4.getUserTotalDebt(usdxReserveId, user), 0, 'skipped reserve untouched');
  }

  function test_revert_liquidationCall_duplicateDebtReserve() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(IBabylonSpoke.InvalidLiquidationCallArguments.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(debtReserveId, debtReserveId), _arr(1e18, 1e18), user, 1e8);
  }

  /// @dev Drives a partial liquidation through the full assertion engine.
  function test_liquidationCall_checked_partial() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 debtToCover = spoke4.getUserTotalDebt(debtReserveId, user) / 2;
    _fundLiquidationManager(debtReserveId, debtToCover);

    _checkedBabylonLiquidationCall(
      CheckedBabylonLiquidationCallParams({
        debtReserveIds: _arr(debtReserveId),
        debtToCoverAmounts: _arr(debtToCover),
        user: user,
        maxCollateralToRemove: spoke4.getUserSuppliedAssets(collateralReserveId, user) * 2,
        isSolvent: true
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
    vm.expectEmit(true, true, false, false, address(babylonSpoke));
    emit IBabylonSpoke.BabylonLiquidationCall({
      debtReserveId: debtReserveId,
      user: user,
      liquidator: liquidationManager,
      debtAmountRestored: 0,
      drawnSharesLiquidated: 0,
      premiumDelta: ZERO_PREMIUM_DELTA,
      collateralAmountRemoved: 0,
      collateralSharesLiquidated: 0
    });
    vm.expectEmit(true, true, false, false, address(babylonSpoke));
    emit IBabylonSpoke.BabylonLiquidationCallSummary({
      user: user,
      liquidator: liquidationManager,
      collateralAmountRemoved: 0,
      collateralSharesLiquidated: 0
    });
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToRemove
    );

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
    babylonSpoke.liquidationCall(
      _arr(debtReserveId),
      _arr(debtToCover),
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
    assertApproxEqRel(
      _convertAmountToValue(
        spoke4,
        collateralReserveId,
        collateralUnderlying.balanceOf(liquidationManager) - liquidatorCollateralBefore
      ),
      capValue,
      0.0001e18,
      'liquidator collateral value'
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
    babylonSpoke.liquidationCall(
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToRemove
    );

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
    babylonSpoke.liquidationCall(
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToRemove
    );

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

  function test_liquidationCall_multiDebt_continuesPastHealthFactorRecovery() public {
    // Setup: a dominant first debt reserve and a small second one, so clearing the first lifts the
    // health factor above the threshold before the second is repaid
    _increaseCollateralSupply(
      spoke4,
      collateralReserveId,
      _convertValueToAmount(spoke4, collateralReserveId, 100_000e26),
      user
    );
    uint256 usdxReserveId = _usdxReserveId(spoke4);
    _borrowSecondReserve(usdxReserveId, 1_000e26);
    _makeUserLiquidatable(spoke4, user, debtReserveId, 0.95e18);

    uint256 daiDebt = spoke4.getUserTotalDebt(debtReserveId, user);
    uint256 usdxDebtBefore = spoke4.getUserTotalDebt(usdxReserveId, user);
    uint256 usdxToCover = usdxDebtBefore / 2;
    _fundLiquidationManager(debtReserveId, daiDebt);
    _fundLiquidationManager(usdxReserveId, usdxToCover);

    // Premise: with the first debt reserve fully repaid, the health factor is already above the
    // threshold before the second debt reserve is touched
    uint256 intermediateCollateralValue = _convertAmountToValue(
      spoke4,
      collateralReserveId,
      spoke4.getUserSuppliedAssets(collateralReserveId, user)
    ) - _expectedRemovedValue(_convertAmountToValue(spoke4, debtReserveId, daiDebt));
    assertGt(
      intermediateCollateralValue
        .percentMulDown(_getCollateralFactor(spoke4, collateralReserveId, user))
        .mulDivDown(1e18, _convertAmountToValue(spoke4, usdxReserveId, usdxDebtBefore)),
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      'intermediate health factor above threshold'
    );

    // Act: the loop continues into the second debt reserve past health factor recovery
    uint256 maxCollateralToRemove = spoke4.getUserSuppliedAssets(collateralReserveId, user) * 2;
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(
      _arr(debtReserveId, usdxReserveId),
      _arr(daiDebt, usdxToCover),
      user,
      maxCollateralToRemove
    );

    // Assert
    assertEq(spoke4.getUserTotalDebt(debtReserveId, user), 0, 'first reserve debt cleared');
    assertApproxEqAbs(
      usdxDebtBefore - spoke4.getUserTotalDebt(usdxReserveId, user),
      usdxToCover,
      2,
      'second reserve repaid'
    );
    assertGt(
      _getUserHealthFactor(spoke4, user),
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      'final health factor'
    );
  }

  function test_liquidationCall_multiDebt_collateralCapEnforcedMidLoop() public {
    // Setup: two debt reserves with a cap that binds during the first repayment
    _increaseCollateralSupply(
      spoke4,
      collateralReserveId,
      _convertValueToAmount(spoke4, collateralReserveId, 100_000e26),
      user
    );
    uint256 usdxReserveId = _usdxReserveId(spoke4);
    _borrowSecondReserve(usdxReserveId, 1_000e26);
    _makeUserLiquidatable(spoke4, user, debtReserveId, 0.95e18);

    uint256 daiDebtBefore = spoke4.getUserTotalDebt(debtReserveId, user);
    uint256 daiToCover = daiDebtBefore / 2;
    uint256 usdxDebtBefore = spoke4.getUserTotalDebt(usdxReserveId, user);
    _fundLiquidationManager(debtReserveId, daiToCover);
    _fundLiquidationManager(usdxReserveId, usdxDebtBefore);
    uint256 usdxBalanceBefore = _getAssetUnderlyingByReserveId(spoke4, usdxReserveId).balanceOf(
      liquidationManager
    );

    // cap the removal at half of what the first repayment would remove
    uint256 maxCollateralToRemove = _convertValueToAmount(
      spoke4,
      collateralReserveId,
      _expectedRemovedValue(_convertAmountToValue(spoke4, debtReserveId, daiToCover)) / 2
    );
    uint256 expectedRemovedShares = _expectedRemovedShares(maxCollateralToRemove);
    uint256 userSuppliedSharesBefore = spoke4.getUserSuppliedShares(collateralReserveId, user);

    // Act
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(
      _arr(debtReserveId, usdxReserveId),
      _arr(daiToCover, usdxDebtBefore),
      user,
      maxCollateralToRemove
    );

    // Assert: the cap is exactly consumed by the resized first repayment and the loop stops early,
    // leaving the second debt reserve untouched
    assertEq(
      userSuppliedSharesBefore - spoke4.getUserSuppliedShares(collateralReserveId, user),
      expectedRemovedShares,
      'removed collateral shares'
    );
    assertLt(
      daiDebtBefore - spoke4.getUserTotalDebt(debtReserveId, user),
      daiToCover,
      'first reserve repaid below requested'
    );
    assertEq(
      spoke4.getUserTotalDebt(usdxReserveId, user),
      usdxDebtBefore,
      'second reserve untouched'
    );
    assertEq(
      _getAssetUnderlyingByReserveId(spoke4, usdxReserveId).balanceOf(liquidationManager),
      usdxBalanceBefore,
      'second reserve funds unspent'
    );
  }

  function test_liquidationCall_multiDebt_collateralCapEnforced_sharePriceAboveOne() public {
    // Setup: accrued borrow interest pushes the collateral supply share price above one. The
    // managed collateral is not borrowable on the babylon spoke, so the borrow accruing the
    // interest goes through spoke1, which shares the hub asset
    address wbtcBorrower = makeAddr('wbtcBorrower');
    uint256 usdxReserveId = _usdxReserveId(spoke4);
    uint256 wbtcBorrowAmount = _convertValueToAmount(spoke1, _wbtcReserveId(spoke1), 50_000e26);
    _openSupplyPosition(spoke1, _wbtcReserveId(spoke1), wbtcBorrowAmount * 2);
    _increaseCollateralSupply(
      spoke1,
      _usdxReserveId(spoke1),
      _convertValueToAmount(spoke1, _usdxReserveId(spoke1), 200_000e26),
      wbtcBorrower
    );
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      caller: wbtcBorrower,
      amount: wbtcBorrowAmount,
      onBehalfOf: wbtcBorrower
    });
    skip(365 days);

    IHubBase collateralHub = _hub(spoke4, collateralReserveId);
    uint256 collateralAssetId = _reserveAssetId(spoke4, collateralReserveId);
    assertGt(
      collateralHub.getAddedAssets(collateralAssetId),
      collateralHub.getAddedShares(collateralAssetId),
      'collateral supply share price above one'
    );

    // two debt reserves with a cap that binds during the second repayment
    _increaseCollateralSupply(
      spoke4,
      collateralReserveId,
      _convertValueToAmount(spoke4, collateralReserveId, 100_000e26),
      user
    );
    _borrowSecondReserve(usdxReserveId, 1_000e26);
    _makeUserLiquidatable(spoke4, user, debtReserveId, 0.95e18);

    uint256 daiToCover = spoke4.getUserTotalDebt(debtReserveId, user) / 2;
    uint256 usdxDebtBefore = spoke4.getUserTotalDebt(usdxReserveId, user);
    _fundLiquidationManager(debtReserveId, daiToCover);
    _fundLiquidationManager(usdxReserveId, usdxDebtBefore);

    // cap the removal between the first and the second priced removal
    uint256 maxCollateralToRemove = _convertValueToAmount(
      spoke4,
      collateralReserveId,
      _expectedRemovedValue(_convertAmountToValue(spoke4, debtReserveId, daiToCover)) +
        _expectedRemovedValue(_convertAmountToValue(spoke4, usdxReserveId, usdxDebtBefore)) / 2
    );
    IERC20 collateralUnderlying = _getAssetUnderlyingByReserveId(spoke4, collateralReserveId);
    uint256 liquidatorBalanceBefore = collateralUnderlying.balanceOf(liquidationManager);

    // Act
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(
      _arr(debtReserveId, usdxReserveId),
      _arr(daiToCover, usdxDebtBefore),
      user,
      maxCollateralToRemove
    );

    // Assert: the removed collateral does not exceed the cap in asset terms at any share price
    uint256 collateralAmountRemoved = collateralUnderlying.balanceOf(liquidationManager) -
      liquidatorBalanceBefore;
    assertLe(collateralAmountRemoved, maxCollateralToRemove, 'removed collateral within cap');
    assertApproxEqRel(
      collateralAmountRemoved,
      maxCollateralToRemove,
      0.01e18,
      'cap nearly consumed'
    );
    assertGt(spoke4.getUserTotalDebt(usdxReserveId, user), 0, 'second reserve partially repaid');
  }

  function test_liquidationCall_pausedOtherDebtReserve() public {
    // Setup: user borrows a second reserve, which is then paused
    _increaseCollateralSupply(
      spoke4,
      collateralReserveId,
      _convertValueToAmount(spoke4, collateralReserveId, 100_000e26),
      user
    );
    uint256 usdxReserveId = _usdxReserveId(spoke4);
    _borrowSecondReserve(usdxReserveId, 1_000e26);
    _makeUserLiquidatable(spoke4, user, debtReserveId, 0.95e18);
    _updateReservePausedFlag(spoke4, usdxReserveId, true);

    uint256 debtBefore = spoke4.getUserTotalDebt(debtReserveId, user);
    uint256 debtToCover = debtBefore / 2;
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 maxCollateralToRemove = spoke4.getUserSuppliedAssets(collateralReserveId, user) * 2;

    // Act: liquidating the unpaused debt reserve succeeds
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToRemove
    );

    // Assert
    assertApproxEqAbs(
      debtBefore - spoke4.getUserTotalDebt(debtReserveId, user),
      debtToCover,
      2,
      'repaid debt'
    );
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
    babylonSpoke.liquidationCall(
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToRemove
    );

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
    babylonSpoke.liquidationCall(
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToRemove
    );

    // Assert: all collateral is removed and the remaining debt is written off as deficit
    assertEq(spoke4.getUserSuppliedShares(collateralReserveId, user), 0, 'user collateral');
    assertEq(spoke4.getUserTotalDebt(debtReserveId, user), 0, 'user debt');
    (, bool isBorrowing) = spoke4.getUserReserveStatus(debtReserveId, user);
    assertFalse(isBorrowing, 'user borrowing status');
    assertEq(spoke4.getUserLastRiskPremium(user), 0, 'user risk premium');
  }
}
