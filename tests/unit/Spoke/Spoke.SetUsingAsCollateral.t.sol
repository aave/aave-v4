// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeSetUsingAsCollateralTest is SpokeBase {
  using SafeCast for uint256;
  using ReserveFlagsMap for ReserveFlags;

  function test_setUsingAsCollateral_revertsWith_ReserveNotListed() public {
    uint256 reserveCount = spoke1.getReserveCount();
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(alice);
    spoke1.setUsingAsCollateral(reserveCount, true, alice);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(alice);
    spoke1.setUsingAsCollateral(reserveCount, false, alice);
  }

  function test_setUsingAsCollateral_revertsWith_ReserveFrozen() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    vm.prank(alice);
    spoke1.setUsingAsCollateral(daiReserveId, true, alice);

    assertTrue(_isUsingAsCollateral(spoke1, daiReserveId, alice), 'alice using as collateral');
    assertFalse(_isUsingAsCollateral(spoke1, daiReserveId, bob), 'bob not using as collateral');

    _updateReserveFrozenFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).flags.frozen(), 'reserve status frozen');

    // disallow when activating
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    vm.prank(bob);
    spoke1.setUsingAsCollateral(daiReserveId, true, bob);

    // allow when deactivating
    vm.prank(alice);
    spoke1.setUsingAsCollateral(daiReserveId, false, alice);

    assertFalse(
      _isUsingAsCollateral(spoke1, daiReserveId, alice),
      'alice deactivated using as collateral frozen reserve'
    );
  }

  function test_setUsingAsCollateral_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    _updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).flags.paused());

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(alice);
    spoke1.setUsingAsCollateral(daiReserveId, true, alice);
  }

  function test_setUsingAsCollateral_revertsWith_ReentrancyGuardReentrantCall() public {
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: 1e18,
      onBehalfOf: bob
    });

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob
    });

    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob
    });

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke1),
      ISpoke.setUsingAsCollateral.selector
    );

    // reentrant hub.refreshPremium call
    vm.mockFunction(
      address(_hub(spoke1, _daiReserveId(spoke1))),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.refreshPremium.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(bob);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), false, bob);
  }

  /// no action taken when collateral status is unchanged
  function test_setUsingAsCollateral_collateralStatusUnchanged() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    // slight update in collateral factor so user is subject to dynamic risk config refresh
    _updateCollateralFactor(
      spoke1,
      daiReserveId,
      _getCollateralFactor(spoke1, daiReserveId) + 1_00
    );
    // slight update collateral risk so user is subject to risk premium refresh
    _updateCollateralRisk(spoke1, daiReserveId, _getCollateralRisk(spoke1, daiReserveId) + 1_00);

    // Bob not using DAI as collateral
    assertFalse(_isUsingAsCollateral(spoke1, daiReserveId, bob), 'bob not using as collateral');

    // No action taken, because collateral status is already false
    DynamicConfig[] memory bobDynConfig = _getUserDynConfigKeys(spoke1, bob);
    uint256 bobRp = _getUserRpStored(spoke1, bob);

    vm.recordLogs();
    Utils.setUsingAsCollateral(spoke1, daiReserveId, bob, false, bob);
    _assertEventNotEmitted(ISpoke.SetUsingAsCollateral.selector);

    assertFalse(_isUsingAsCollateral(spoke1, daiReserveId, bob));
    assertEq(_getUserRpStored(spoke1, bob), bobRp);
    assertEq(_getUserDynConfigKeys(spoke1, bob), bobDynConfig);

    // Bob can change dai collateral status to true
    Utils.setUsingAsCollateral(spoke1, daiReserveId, bob, true, bob);
    assertTrue(_isUsingAsCollateral(spoke1, daiReserveId, bob), 'bob using as collateral');

    // slight update in collateral factor so user is subject to dynamic risk config refresh
    _updateCollateralFactor(
      spoke1,
      daiReserveId,
      _getCollateralFactor(spoke1, daiReserveId) + 1_00
    );
    // slight update collateral risk so user is subject to risk premium refresh
    _updateCollateralRisk(spoke1, daiReserveId, _getCollateralRisk(spoke1, daiReserveId) + 1_00);

    // No action taken, because collateral status is already true
    bobDynConfig = _getUserDynConfigKeys(spoke1, bob);
    bobRp = _getUserRpStored(spoke1, bob);

    vm.recordLogs();
    Utils.setUsingAsCollateral(spoke1, daiReserveId, bob, true, bob);
    _assertEventsNotEmitted(
      ISpoke.SetUsingAsCollateral.selector,
      ISpoke.RefreshSingleUserDynamicConfig.selector,
      ISpoke.RefreshAllUserDynamicConfig.selector
    );

    assertTrue(_isUsingAsCollateral(spoke1, daiReserveId, bob));
    assertEq(_getUserRpStored(spoke1, bob), bobRp);
    assertEq(_getUserDynConfigKeys(spoke1, bob), bobDynConfig);
  }

  function test_setUsingAsCollateral() public {
    bool usingAsCollateral = true;
    uint256 daiAmount = 100e18;

    uint256 daiReserveId = _daiReserveId(spoke1);

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, daiAmount);
    Utils.supply(spoke1, daiReserveId, bob, daiAmount, bob);

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral(daiReserveId, bob, bob, usingAsCollateral);
    spoke1.setUsingAsCollateral(daiReserveId, usingAsCollateral, bob);

    assertEq(
      _isUsingAsCollateral(spoke1, daiReserveId, bob),
      usingAsCollateral,
      'wrong usingAsCollateral'
    );
  }

  function test_setUsingAsCollateral_revertsWith_MaximumUserReservesExceeded() public {
    uint16 maxUserReservesLimit = (spoke1.getReserveCount() - 1).toUint16();
    _updateMaxUserReservesLimit(spoke1, maxUserReservesLimit);
    assertEq(spoke1.MAX_USER_RESERVES_LIMIT(), maxUserReservesLimit, 'Reserve limit adjusted');
    assertGt(spoke1.getReserveCount(), maxUserReservesLimit, 'More reserves than limit');

    for (uint256 i = 0; i < maxUserReservesLimit; ++i) {
      Utils.supplyCollateral(spoke1, i, bob, 1e18, bob);
    }
    ISpoke.UserAccountData memory accountData = spoke1.getUserAccountData(bob);
    assertEq(
      accountData.activeCollateralCount,
      maxUserReservesLimit,
      'Bob has reached the collateral limit'
    );

    vm.expectRevert(ISpoke.MaximumUserReservesExceeded.selector);
    vm.prank(bob);
    spoke1.setUsingAsCollateral(maxUserReservesLimit, true, bob);
  }

  /// @dev Test that enables collaterals up to the user reserves limit, disables one reserve, and then enables again
  function test_setUsingAsCollateral_to_limit_disable_enable_again() public {
    uint16 maxUserReservesLimit = (spoke1.getReserveCount() - 1).toUint16();
    _updateMaxUserReservesLimit(spoke1, maxUserReservesLimit);
    assertEq(spoke1.MAX_USER_RESERVES_LIMIT(), maxUserReservesLimit, 'Reserve limit adjusted');
    assertGt(spoke1.getReserveCount(), maxUserReservesLimit, 'More reserves than limit');

    for (uint256 i = 0; i < maxUserReservesLimit; ++i) {
      Utils.supplyCollateral(spoke1, i, bob, 1e18, bob);
    }

    ISpoke.UserAccountData memory accountData = spoke1.getUserAccountData(bob);
    assertEq(
      accountData.activeCollateralCount,
      maxUserReservesLimit,
      'Bob has reached the collateral limit'
    );

    Utils.setUsingAsCollateral(spoke1, 0, bob, false, bob);

    accountData = spoke1.getUserAccountData(bob);
    assertEq(
      accountData.activeCollateralCount,
      maxUserReservesLimit - 1,
      'Bob has disabled one collateral'
    );

    Utils.supplyCollateral(spoke1, maxUserReservesLimit, bob, 1e18, bob);

    accountData = spoke1.getUserAccountData(bob);
    assertEq(
      accountData.activeCollateralCount,
      maxUserReservesLimit,
      'Bob has reached the collateral limit'
    );
  }

  /// @dev Test showing that when the collateral limit is max, all reserves can be enabled as collateral.
  function test_setUsingAsCollateral_unlimited_whenLimitIsMax() public {
    assertEq(spoke1.MAX_USER_RESERVES_LIMIT(), Constants.MAX_ALLOWED_USER_RESERVES_LIMIT);

    uint256 collateralsToEnable = spoke1.getReserveCount();

    for (uint256 i = 0; i < collateralsToEnable; ++i) {
      Utils.supplyCollateral(spoke1, i, bob, 1e18, bob);
    }

    ISpoke.UserAccountData memory accountData = spoke1.getUserAccountData(bob);
    assertEq(accountData.activeCollateralCount, collateralsToEnable);
  }
}
