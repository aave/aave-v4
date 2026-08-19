// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.LiquidationCall.Base.t.sol';
import {IDiscreteLiquidationSpoke} from 'src/spoke/interfaces/IDiscreteLiquidationSpoke.sol';

contract SpokeDiscreteLiquidationCallTest is SpokeLiquidationCallBaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using MathUtils for uint256;

  IDiscreteLiquidationSpoke internal discreteSpoke;
  address internal liquidationManager = makeAddr('liquidationManager');
  address internal user = makeAddr('user');

  uint256 internal collateralReserveId;
  uint256 internal debtReserveId;

  function setUp() public virtual override {
    super.setUp();

    // upgrade spoke1 to the discrete liquidation spoke instance
    bytes memory initCode = abi.encodePacked(
      vm.getCode(
        'src/spoke/instances/DiscreteLiquidationSpokeInstance.sol:DiscreteLiquidationSpokeInstance'
      ),
      abi.encode(spoke1.ORACLE(), Constants.MAX_ALLOWED_USER_RESERVES_LIMIT)
    );
    address impl;
    assembly ('memory-safe') {
      impl := create(0, add(initCode, 0x20), mload(initCode))
    }
    require(impl != address(0), 'DiscreteLiquidationSpokeInstance deployment failed');

    vm.prank(_getProxyAdminAddress(address(spoke1)));
    ITransparentUpgradeableProxy(address(spoke1)).upgradeToAndCall(impl, '');
    discreteSpoke = IDiscreteLiquidationSpoke(address(spoke1));

    vm.prank(ADMIN);
    discreteSpoke.updateLiquidationManager(liquidationManager);

    collateralReserveId = _wbtcReserveId(spoke1);
    debtReserveId = _daiReserveId(spoke1);
  }

  function _arr(uint256 a) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](1);
    arr[0] = a;
  }

  function _arr(uint256 a, uint256 b) internal pure returns (uint256[] memory arr) {
    arr = new uint256[](2);
    arr[0] = a;
    arr[1] = b;
  }

  /// @dev Supplies `collateralValue` (in units of Value) of collateral for `user` and borrows the
  /// debt reserve so the user health factor lands at `healthFactor`.
  function _setUpLiquidatableUser(uint256 collateralValue, uint256 healthFactor) internal {
    _increaseCollateralSupply(
      spoke1,
      collateralReserveId,
      _convertValueToAmount(spoke1, collateralReserveId, collateralValue),
      user
    );
    _makeUserLiquidatable(spoke1, user, debtReserveId, healthFactor);
    assertLt(
      _getUserHealthFactor(spoke1, user),
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      'user should be liquidatable'
    );
  }

  /// @dev Borrows `debtValue` (in units of Value) of `reserveId` for `user`.
  function _borrowSecondReserve(uint256 reserveId, uint256 debtValue) internal {
    uint256 borrowAmount = _convertValueToAmount(spoke1, reserveId, debtValue);
    _openSupplyPosition(spoke1, reserveId, borrowAmount);
    Utils.borrow(spoke1, reserveId, user, borrowAmount, user);
  }

  function _fundLiquidationManager(uint256 reserveId, uint256 amount) internal {
    deal(spoke1, reserveId, liquidationManager, amount);
    Utils.approve(spoke1, reserveId, liquidationManager, UINT256_MAX);
  }

  /// @dev Expected collateral seizure (in units of Value) for a repaid debt value, priced by the
  /// canonical bonus formula.
  function _expectedSeizedValue(uint256 debtValueCovered) internal view returns (uint256) {
    uint256 liquidationBonus = spoke1.getLiquidationBonus(
      collateralReserveId,
      user,
      spoke1.getUserAccountData(user).healthFactor
    );
    return debtValueCovered.percentMulDown(liquidationBonus);
  }

  /// @dev Expected repaid debt (in units of Value) for a seized collateral value, the inverse of the
  /// canonical bonus pricing.
  function _expectedRepaidValue(uint256 seizedValue) internal view returns (uint256) {
    uint256 liquidationBonus = spoke1.getLiquidationBonus(
      collateralReserveId,
      user,
      spoke1.getUserAccountData(user).healthFactor
    );
    return seizedValue.mulDivUp(PercentageMath.PERCENTAGE_FACTOR, liquidationBonus);
  }

  /// @dev Expected share of the seizure that goes to the liquidator after the liquidation fee.
  function _expectedLiquidatorValue(uint256 seizedValue) internal view returns (uint256) {
    uint256 liquidationBonus = spoke1.getLiquidationBonus(
      collateralReserveId,
      user,
      spoke1.getUserAccountData(user).healthFactor
    );
    uint256 liquidationFee = spoke1
      .getDynamicReserveConfig(
        collateralReserveId,
        spoke1.getUserPosition(collateralReserveId, user).dynamicConfigKey
      )
      .liquidationFee;
    return
      seizedValue -
      seizedValue.mulDivUp(
        liquidationFee * (liquidationBonus - PercentageMath.PERCENTAGE_FACTOR),
        liquidationBonus * PercentageMath.PERCENTAGE_FACTOR
      );
  }

  /// @dev Expected seized collateral shares for a seizure cap expressed in asset units.
  function _expectedSeizedShares(uint256 maxCollateralToReceive) internal view returns (uint256) {
    return
      _hub(spoke1, collateralReserveId).previewAddByAssets(
        _reserveAssetId(spoke1, collateralReserveId),
        maxCollateralToReceive
      );
  }

  function test_updateLiquidationManager() public {
    address newManager = makeAddr('newManager');

    vm.expectEmit(address(discreteSpoke));
    emit IDiscreteLiquidationSpoke.UpdateLiquidationManager(newManager);
    vm.prank(ADMIN);
    discreteSpoke.updateLiquidationManager(newManager);

    assertEq(discreteSpoke.getLiquidationManager(), newManager);
  }

  function test_revert_updateLiquidationManager_unauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    discreteSpoke.updateLiquidationManager(alice);
  }

  function test_revert_discreteLiquidationCall_notLiquidationManager() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(alice);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(1e18),
      user,
      1e8
    );
  }

  function test_revert_discreteLiquidationCall_healthFactorNotBelowThreshold() public {
    // Setup: healthy borrow position
    _increaseCollateralSupply(
      spoke1,
      collateralReserveId,
      _convertValueToAmount(spoke1, collateralReserveId, 100_000e26),
      user
    );
    uint256 borrowAmount = _convertValueToAmount(spoke1, debtReserveId, 10_000e26);
    _openSupplyPosition(spoke1, debtReserveId, borrowAmount);
    Utils.borrow(spoke1, debtReserveId, user, borrowAmount, user);

    // Act & Assert
    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(1e18),
      user,
      1e8
    );
  }

  function test_revert_discreteLiquidationCall_emptyDebtReserves() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(IDiscreteLiquidationSpoke.InvalidLiquidationCallArguments.selector);
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      new uint256[](0),
      new uint256[](0),
      user,
      1e8
    );
  }

  function test_revert_discreteLiquidationCall_mismatchedArrayLengths() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(IDiscreteLiquidationSpoke.InvalidLiquidationCallArguments.selector);
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(1e18, 1e18),
      user,
      1e8
    );
  }

  function test_revert_discreteLiquidationCall_invalidDebtToCover() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(ISpoke.InvalidDebtToCover.selector);
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(0),
      user,
      1e8
    );
  }

  function test_revert_discreteLiquidationCall_invalidMaxCollateralToReceive() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);

    vm.expectRevert(IDiscreteLiquidationSpoke.InvalidMaxCollateralToReceive.selector);
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(1e18),
      user,
      0
    );
  }

  function test_revert_discreteLiquidationCall_debtReservePaused() public {
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    _updateReservePausedFlag(spoke1, debtReserveId, true);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(1e18),
      user,
      1e8
    );
  }

  function test_discreteLiquidationCall_capNotBinding() public {
    // Setup
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 debtBefore = spoke1.getUserTotalDebt(debtReserveId, user);
    uint256 debtToCover = debtBefore / 2;
    _fundLiquidationManager(debtReserveId, debtToCover);

    uint256 debtValueCovered = _convertAmountToValue(spoke1, debtReserveId, debtToCover);
    uint256 expectedSeizedValue = _expectedSeizedValue(debtValueCovered);
    uint256 expectedLiquidatorValue = _expectedLiquidatorValue(expectedSeizedValue);
    uint256 userSuppliedBefore = spoke1.getUserSuppliedAssets(collateralReserveId, user);
    IERC20 collateralUnderlying = getAssetUnderlyingByReserveId(spoke1, collateralReserveId);
    uint256 liquidatorCollateralBefore = collateralUnderlying.balanceOf(liquidationManager);
    uint256 maxCollateralToReceive = userSuppliedBefore * 2; // not binding

    // Act
    vm.expectEmit(true, true, false, false, address(discreteSpoke));
    emit IDiscreteLiquidationSpoke.DiscreteLiquidationRepay({
      debtReserveId: debtReserveId,
      user: user,
      debtAmountRestored: 0,
      drawnSharesLiquidated: 0,
      premiumDelta: ZERO_PREMIUM_DELTA
    });
    vm.expectEmit(true, true, true, false, address(discreteSpoke));
    emit IDiscreteLiquidationSpoke.DiscreteLiquidationCall({
      collateralReserveId: collateralReserveId,
      user: user,
      liquidator: liquidationManager,
      collateralAmountRemoved: 0,
      collateralSharesLiquidated: 0,
      collateralSharesToLiquidator: 0
    });
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToReceive
    );

    // Assert: the requested debt is repaid and the seizure is priced by the canonical bonus formula
    assertApproxEqAbs(
      debtBefore - spoke1.getUserTotalDebt(debtReserveId, user),
      debtToCover,
      2,
      'repaid debt'
    );
    assertApproxEqRel(
      _convertAmountToValue(
        spoke1,
        collateralReserveId,
        userSuppliedBefore - spoke1.getUserSuppliedAssets(collateralReserveId, user)
      ),
      expectedSeizedValue,
      0.0001e18,
      'seized collateral value'
    );
    assertApproxEqRel(
      _convertAmountToValue(
        spoke1,
        collateralReserveId,
        collateralUnderlying.balanceOf(liquidationManager) - liquidatorCollateralBefore
      ),
      expectedLiquidatorValue,
      0.0001e18,
      'liquidator collateral value'
    );
  }

  function test_discreteLiquidationCall_capBinding() public {
    // Setup
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 debtBefore = spoke1.getUserTotalDebt(debtReserveId, user);
    uint256 debtToCover = debtBefore / 2;
    _fundLiquidationManager(debtReserveId, debtToCover);

    uint256 debtValueCovered = _convertAmountToValue(spoke1, debtReserveId, debtToCover);
    // cap the seizure at half of what the canonical bonus formula would seize
    uint256 maxCollateralToReceive = _convertValueToAmount(
      spoke1,
      collateralReserveId,
      _expectedSeizedValue(debtValueCovered) / 2
    );
    uint256 capValue = _convertAmountToValue(spoke1, collateralReserveId, maxCollateralToReceive);
    uint256 expectedSeizedShares = _expectedSeizedShares(maxCollateralToReceive);
    uint256 expectedRepaid = _convertValueToAmount(
      spoke1,
      debtReserveId,
      _expectedRepaidValue(capValue)
    );
    uint256 expectedLiquidatorValue = _expectedLiquidatorValue(capValue);
    uint256 debtBalanceBefore = getAssetUnderlyingByReserveId(spoke1, debtReserveId).balanceOf(
      liquidationManager
    );
    uint256 userSuppliedSharesBefore = spoke1.getUserSuppliedShares(collateralReserveId, user);
    IERC20 collateralUnderlying = getAssetUnderlyingByReserveId(spoke1, collateralReserveId);
    uint256 liquidatorCollateralBefore = collateralUnderlying.balanceOf(liquidationManager);

    // Act
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToReceive
    );

    // Assert: the cap is exactly consumed and the repayment is resized to its inverse value
    assertEq(
      userSuppliedSharesBefore - spoke1.getUserSuppliedShares(collateralReserveId, user),
      expectedSeizedShares,
      'seized collateral shares'
    );
    uint256 repaid = debtBefore - spoke1.getUserTotalDebt(debtReserveId, user);
    assertLt(repaid, debtToCover, 'repaid below requested');
    assertApproxEqRel(repaid, expectedRepaid, 0.0001e18, 'repaid debt');
    assertApproxEqAbs(
      debtBalanceBefore -
        getAssetUnderlyingByReserveId(spoke1, debtReserveId).balanceOf(liquidationManager),
      repaid,
      2,
      'liquidator debt spent'
    );
    assertApproxEqRel(
      _convertAmountToValue(
        spoke1,
        collateralReserveId,
        collateralUnderlying.balanceOf(liquidationManager) - liquidatorCollateralBefore
      ),
      expectedLiquidatorValue,
      0.0001e18,
      'liquidator collateral value'
    );
  }

  function test_discreteLiquidationCall_fullDebtRepay() public {
    // Setup
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    uint256 debtToCover = spoke1.getUserTotalDebt(debtReserveId, user);
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 maxCollateralToReceive = spoke1.getUserSuppliedAssets(collateralReserveId, user) * 2;

    // Act
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToReceive
    );

    // Assert: debt is fully cleared with no dust validation and no deficit
    assertEq(spoke1.getUserTotalDebt(debtReserveId, user), 0, 'user debt');
    (, bool isBorrowing) = spoke1.getUserReserveStatus(debtReserveId, user);
    assertFalse(isBorrowing, 'user borrowing status');
    assertEq(_getUserHealthFactor(spoke1, user), UINT256_MAX, 'user health factor');
    assertGt(spoke1.getUserSuppliedAssets(collateralReserveId, user), 0, 'remaining collateral');
  }

  function test_discreteLiquidationCall_noDustValidation() public {
    // Setup: small position, so both the remaining debt and collateral end up below the canonical
    // dust threshold; the discrete liquidation must not revert with MustNotLeaveDust
    _setUpLiquidatableUser(2_000e26, 0.9e18);
    uint256 debtBefore = spoke1.getUserTotalDebt(debtReserveId, user);
    uint256 debtToCover = debtBefore - _convertValueToAmount(spoke1, debtReserveId, 500e26);
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 maxCollateralToReceive = spoke1.getUserSuppliedAssets(collateralReserveId, user) * 2;

    // Act
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToReceive
    );

    // Assert: sub-dust debt and collateral remain
    uint256 remainingDebtValue = _convertAmountToValue(
      spoke1,
      debtReserveId,
      spoke1.getUserTotalDebt(debtReserveId, user)
    );
    uint256 remainingCollateralValue = _convertAmountToValue(
      spoke1,
      collateralReserveId,
      spoke1.getUserSuppliedAssets(collateralReserveId, user)
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

  function test_discreteLiquidationCall_multiDebt_continuesPastHealthFactorRecovery() public {
    // Setup: a dominant first debt reserve and a small second one, so clearing the first lifts the
    // health factor above the threshold before the second is repaid
    _increaseCollateralSupply(
      spoke1,
      collateralReserveId,
      _convertValueToAmount(spoke1, collateralReserveId, 100_000e26),
      user
    );
    uint256 usdxReserveId = _usdxReserveId(spoke1);
    _borrowSecondReserve(usdxReserveId, 1_000e26);
    _makeUserLiquidatable(spoke1, user, debtReserveId, 0.95e18);

    uint256 daiDebt = spoke1.getUserTotalDebt(debtReserveId, user);
    uint256 usdxDebtBefore = spoke1.getUserTotalDebt(usdxReserveId, user);
    uint256 usdxToCover = usdxDebtBefore / 2;
    _fundLiquidationManager(debtReserveId, daiDebt);
    _fundLiquidationManager(usdxReserveId, usdxToCover);

    // Premise: with the first debt reserve fully repaid, the health factor is already above the
    // threshold before the second debt reserve is touched
    uint256 intermediateCollateralValue = _convertAmountToValue(
      spoke1,
      collateralReserveId,
      spoke1.getUserSuppliedAssets(collateralReserveId, user)
    ) - _expectedSeizedValue(_convertAmountToValue(spoke1, debtReserveId, daiDebt));
    assertGt(
      intermediateCollateralValue
        .percentMulDown(_getCollateralFactor(spoke1, collateralReserveId, user))
        .mulDivDown(1e18, _convertAmountToValue(spoke1, usdxReserveId, usdxDebtBefore)),
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      'intermediate health factor above threshold'
    );

    // Act: the loop continues into the second debt reserve past health factor recovery
    uint256 maxCollateralToReceive = spoke1.getUserSuppliedAssets(collateralReserveId, user) * 2;
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId, usdxReserveId),
      _arr(daiDebt, usdxToCover),
      user,
      maxCollateralToReceive
    );

    // Assert
    assertEq(spoke1.getUserTotalDebt(debtReserveId, user), 0, 'first reserve debt cleared');
    assertApproxEqAbs(
      usdxDebtBefore - spoke1.getUserTotalDebt(usdxReserveId, user),
      usdxToCover,
      2,
      'second reserve repaid'
    );
    assertGt(
      _getUserHealthFactor(spoke1, user),
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      'final health factor'
    );
  }

  function test_discreteLiquidationCall_multiDebt_capBindsMidLoop() public {
    // Setup: two debt reserves with a cap that binds during the first repayment
    _increaseCollateralSupply(
      spoke1,
      collateralReserveId,
      _convertValueToAmount(spoke1, collateralReserveId, 100_000e26),
      user
    );
    uint256 usdxReserveId = _usdxReserveId(spoke1);
    _borrowSecondReserve(usdxReserveId, 1_000e26);
    _makeUserLiquidatable(spoke1, user, debtReserveId, 0.95e18);

    uint256 daiDebtBefore = spoke1.getUserTotalDebt(debtReserveId, user);
    uint256 daiToCover = daiDebtBefore / 2;
    uint256 usdxDebtBefore = spoke1.getUserTotalDebt(usdxReserveId, user);
    _fundLiquidationManager(debtReserveId, daiToCover);
    _fundLiquidationManager(usdxReserveId, usdxDebtBefore);
    uint256 usdxBalanceBefore = getAssetUnderlyingByReserveId(spoke1, usdxReserveId).balanceOf(
      liquidationManager
    );

    // cap the seizure at half of what the first repayment would seize
    uint256 maxCollateralToReceive = _convertValueToAmount(
      spoke1,
      collateralReserveId,
      _expectedSeizedValue(_convertAmountToValue(spoke1, debtReserveId, daiToCover)) / 2
    );
    uint256 expectedSeizedShares = _expectedSeizedShares(maxCollateralToReceive);
    uint256 userSuppliedSharesBefore = spoke1.getUserSuppliedShares(collateralReserveId, user);

    // Act
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId, usdxReserveId),
      _arr(daiToCover, usdxDebtBefore),
      user,
      maxCollateralToReceive
    );

    // Assert: the cap is exactly consumed by the resized first repayment and the loop stops early,
    // leaving the second debt reserve untouched
    assertEq(
      userSuppliedSharesBefore - spoke1.getUserSuppliedShares(collateralReserveId, user),
      expectedSeizedShares,
      'seized collateral shares'
    );
    assertLt(
      daiDebtBefore - spoke1.getUserTotalDebt(debtReserveId, user),
      daiToCover,
      'first reserve repaid below requested'
    );
    assertEq(
      spoke1.getUserTotalDebt(usdxReserveId, user),
      usdxDebtBefore,
      'second reserve untouched'
    );
    assertEq(
      getAssetUnderlyingByReserveId(spoke1, usdxReserveId).balanceOf(liquidationManager),
      usdxBalanceBefore,
      'second reserve funds unspent'
    );
  }

  function test_discreteLiquidationCall_pausedOtherDebtReserve() public {
    // Setup: user borrows a second reserve, which is then paused
    _increaseCollateralSupply(
      spoke1,
      collateralReserveId,
      _convertValueToAmount(spoke1, collateralReserveId, 100_000e26),
      user
    );
    uint256 usdxReserveId = _usdxReserveId(spoke1);
    _borrowSecondReserve(usdxReserveId, 1_000e26);
    _makeUserLiquidatable(spoke1, user, debtReserveId, 0.95e18);
    _updateReservePausedFlag(spoke1, usdxReserveId, true);

    uint256 debtBefore = spoke1.getUserTotalDebt(debtReserveId, user);
    uint256 debtToCover = debtBefore / 2;
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 maxCollateralToReceive = spoke1.getUserSuppliedAssets(collateralReserveId, user) * 2;

    // Act: liquidating the unpaused debt reserve succeeds
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToReceive
    );

    // Assert
    assertApproxEqAbs(
      debtBefore - spoke1.getUserTotalDebt(debtReserveId, user),
      debtToCover,
      2,
      'repaid debt'
    );
  }

  function test_discreteLiquidationCall_frozenCollateralReserve() public {
    // Setup
    _setUpLiquidatableUser(100_000e26, 0.95e18);
    _updateReserveFrozenFlag(spoke1, collateralReserveId, true);

    uint256 debtBefore = spoke1.getUserTotalDebt(debtReserveId, user);
    uint256 debtToCover = debtBefore / 2;
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 maxCollateralToReceive = spoke1.getUserSuppliedAssets(collateralReserveId, user) * 2;

    // Act: the liquidator receives underlying assets, so a frozen collateral reserve is liquidatable
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToReceive
    );

    // Assert
    assertApproxEqAbs(
      debtBefore - spoke1.getUserTotalDebt(debtReserveId, user),
      debtToCover,
      2,
      'repaid debt'
    );
  }

  function test_discreteLiquidationCall_deficit() public {
    // Setup: insolvent position where seizing all collateral cannot clear the debt
    _setUpLiquidatableUser(2_000e26, 0.5e18);
    uint256 debtToCover = _convertValueToAmount(spoke1, debtReserveId, 2_500e26);
    _fundLiquidationManager(debtReserveId, debtToCover);
    uint256 maxCollateralToReceive = spoke1.getUserSuppliedAssets(collateralReserveId, user) * 2;

    // Act
    vm.expectEmit(true, true, false, false, address(discreteSpoke));
    emit ISpoke.ReportDeficit({
      reserveId: debtReserveId,
      user: user,
      drawnShares: 0,
      premiumDelta: ZERO_PREMIUM_DELTA
    });
    vm.prank(liquidationManager);
    discreteSpoke.discreteLiquidationCall(
      collateralReserveId,
      _arr(debtReserveId),
      _arr(debtToCover),
      user,
      maxCollateralToReceive
    );

    // Assert: all collateral is seized and the remaining debt is written off as deficit
    assertEq(spoke1.getUserSuppliedShares(collateralReserveId, user), 0, 'user collateral');
    assertEq(spoke1.getUserTotalDebt(debtReserveId, user), 0, 'user debt');
    (, bool isBorrowing) = spoke1.getUserReserveStatus(debtReserveId, user);
    assertFalse(isBorrowing, 'user borrowing status');
    assertEq(spoke1.getUserLastRiskPremium(user), 0, 'user risk premium');
  }
}
