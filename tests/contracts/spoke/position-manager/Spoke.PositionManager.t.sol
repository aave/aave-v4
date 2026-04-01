// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokePositionManagerTest is Base {
  function test_setApprovalForPositionManager(bytes32) public {
    vm.setArbitraryStorage(address(spoke1));

    address user = vm.randomAddress();
    address positionManager = vm.randomAddress();
    bool approve = vm.randomBool();

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(user, positionManager, approve);

    vm.prank(user);
    spoke1.setUserPositionManager(positionManager, approve);
  }

  function test_renouncePositionManagerRole() public {
    vm.setArbitraryStorage(address(spoke1));

    address user = vm.randomAddress();
    address positionManager = vm.randomAddress();

    if (!spoke1.isPositionManager(user, positionManager)) {
      vm.expectEmit(address(spoke1));
      emit ISpoke.SetUserPositionManager(user, positionManager, false);
    }
    vm.prank(positionManager);
    spoke1.renouncePositionManagerRole(user);

    assertFalse(spoke1.isPositionManager(user, positionManager));
  }

  function test_renouncePositionManagerRole_noop_from_disabled() public {
    vm.setArbitraryStorage(address(spoke1));

    address user = vm.randomAddress();
    vm.prank(user);
    spoke1.setUserPositionManager(POSITION_MANAGER, false);

    vm.recordLogs();
    vm.prank(POSITION_MANAGER);
    spoke1.renouncePositionManagerRole(user);

    assertEq(vm.getRecordedLogs().length, 0);
    assertFalse(spoke1.isPositionManager(user, POSITION_MANAGER));
  }

  function test_onlyPositionManager_on_supply() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(POSITION_MANAGER);
    spoke1.supply(reserveId, amount, alice);

    _approvePositionManager(alice);
    _resetTokenAllowance(alice);

    ISpoke.UserPosition memory posBefore = spoke1.getUserPosition(reserveId, POSITION_MANAGER);

    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(POSITION_MANAGER), address(hub1), amount);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply({
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      user: alice,
      suppliedShares: hub1.previewAddByAssets(usdxAssetId, amount),
      suppliedAmount: amount
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserSuppliedAssets(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserSuppliedAssets(reserveId, alice), amount);

    _disablePositionManager();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });
  }

  function test_onlyPositionManager_on_withdraw() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });

    _approvePositionManager(alice);
    _resetTokenAllowance(alice);

    ISpoke.UserPosition memory posBefore = spoke1.getUserPosition(reserveId, POSITION_MANAGER);
    amount /= 2;

    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(hub1), address(POSITION_MANAGER), amount);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw({
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      user: alice,
      withdrawnShares: hub1.previewRemoveByAssets(usdxAssetId, amount),
      withdrawnAmount: amount
    });
    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserSuppliedAssets(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserSuppliedAssets(reserveId, alice), amount);

    _disablePositionManager();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });
  }

  function test_onlyPositionManager_on_borrow() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: (amount * 3) / 2,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });

    _approvePositionManager(alice);
    _resetTokenAllowance(alice);

    ISpoke.UserPosition memory posBefore = spoke1.getUserPosition(reserveId, POSITION_MANAGER);

    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(hub1), address(POSITION_MANAGER), amount);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrow({
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      user: alice,
      drawnShares: hub1.previewRestoreByAssets(usdxAssetId, amount),
      drawnAmount: amount
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserTotalDebt(reserveId, POSITION_MANAGER), 0);
    assertFalse(_isBorrowing(spoke1, reserveId, POSITION_MANAGER));
    assertEq(spoke1.getUserTotalDebt(reserveId, alice), amount);
    assertTrue(_isBorrowing(spoke1, reserveId, alice));

    _disablePositionManager();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });
  }

  function test_onlyPositionManager_on_repay() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: (amount * 3) / 2,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });

    _approvePositionManager(alice);
    _resetTokenAllowance(alice);

    ISpoke.UserPosition memory posBefore = spoke1.getUserPosition(reserveId, POSITION_MANAGER);
    uint256 repayAmount = amount / 3;

    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke1,
      alice,
      reserveId,
      repayAmount
    );

    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(POSITION_MANAGER), address(hub1), repayAmount);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      reserveId,
      POSITION_MANAGER,
      alice,
      hub1.previewRestoreByAssets(usdxAssetId, repayAmount),
      repayAmount,
      expectedPremiumDelta
    );
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: repayAmount,
      onBehalfOf: alice
    });

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserTotalDebt(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserTotalDebt(reserveId, alice), amount - repayAmount);
    assertFalse(_isBorrowing(spoke1, reserveId, POSITION_MANAGER));
    assertTrue(_isBorrowing(spoke1, reserveId, alice));

    SpokeActions.repay({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: UINT256_MAX,
      onBehalfOf: alice
    });
    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserTotalDebt(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserTotalDebt(reserveId, alice), 0);
    assertFalse(_isBorrowing(spoke1, reserveId, POSITION_MANAGER));
    assertFalse(_isBorrowing(spoke1, reserveId, alice));

    _disablePositionManager();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      amount: repayAmount,
      onBehalfOf: alice
    });
  }

  function test_onlyPositionManager_on_usingAsCollateral() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    assertFalse(_isUsingAsCollateral(spoke1, reserveId, alice));

    bool usingAsCollateral = true;

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.setUsingAsCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      usingAsCollateral: usingAsCollateral,
      onBehalfOf: alice
    });

    _approvePositionManager(alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral({
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      user: alice,
      usingAsCollateral: usingAsCollateral
    });
    SpokeActions.setUsingAsCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      usingAsCollateral: usingAsCollateral,
      onBehalfOf: alice
    });

    assertEq(_isUsingAsCollateral(spoke1, reserveId, alice), usingAsCollateral);

    _disablePositionManager();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.setUsingAsCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: POSITION_MANAGER,
      usingAsCollateral: usingAsCollateral,
      onBehalfOf: alice
    });
  }

  function test_onlyPositionManager_on_updateUserRiskPremium() public {
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), 1500e6);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: alice,
      amount: 0.5e18,
      onBehalfOf: alice
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: 1000e18,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _usdxReserveId(spoke1),
      caller: alice,
      amount: 1500e6,
      onBehalfOf: alice
    });

    uint256 riskPremiumBefore = _getUserRiskPremium(spoke1, alice);
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 100_00);
    assertGt(_getUserRiskPremium(spoke1, alice), riskPremiumBefore);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, POSITION_MANAGER)
    );
    vm.prank(POSITION_MANAGER);
    spoke1.updateUserRiskPremium(alice);

    _approvePositionManager(alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateUserRiskPremium(alice, _calculateExpectedUserRP(spoke1, alice));
    vm.prank(POSITION_MANAGER);
    spoke1.updateUserRiskPremium(alice);

    riskPremiumBefore = _getUserRiskPremium(spoke1, alice);
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 1000_00);
    assertGt(_getUserRiskPremium(spoke1, alice), riskPremiumBefore);
    _disablePositionManager();

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, POSITION_MANAGER)
    );
    vm.prank(POSITION_MANAGER);
    spoke1.updateUserRiskPremium(alice);
  }

  function test_onlyPositionManager_on_updateUserDynamicConfig() public {
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), 1500e6);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: alice,
      amount: 0.5e18,
      onBehalfOf: alice
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: 1000e18,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _usdxReserveId(spoke1),
      caller: alice,
      amount: 1500e6,
      onBehalfOf: alice
    });

    _updateCollateralFactor(spoke1, _wethReserveId(spoke1), 90_00);
    _updateCollateralFactor(spoke1, _daiReserveId(spoke1), 90_00);
    DynamicConfigEntry[] memory configs = _getUserDynConfigKeys(spoke1, alice);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, POSITION_MANAGER)
    );
    vm.prank(POSITION_MANAGER);
    spoke1.updateUserDynamicConfig(alice);

    _approvePositionManager(alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.prank(POSITION_MANAGER);
    spoke1.updateUserDynamicConfig(alice);

    assertNotEq(_getUserDynConfigKeys(spoke1, alice), configs);
    assertEq(_getSpokeDynConfigKeys(spoke1), _getUserDynConfigKeys(spoke1, alice));
    _disablePositionManager();

    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, POSITION_MANAGER)
    );
    vm.prank(POSITION_MANAGER);
    spoke1.updateUserDynamicConfig(alice);
  }

  function _approvePositionManager(address who) internal {
    assertFalse(spoke1.isPositionManager(who, POSITION_MANAGER));
    assertFalse(spoke1.isPositionManagerActive(POSITION_MANAGER));

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdatePositionManager(POSITION_MANAGER, true);
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager({positionManager: POSITION_MANAGER, active: true});

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(who, POSITION_MANAGER, true);
    vm.prank(who);
    spoke1.setUserPositionManager(POSITION_MANAGER, true);

    assertTrue(spoke1.isPositionManager(who, POSITION_MANAGER));
    assertTrue(spoke1.isPositionManagerActive(POSITION_MANAGER));
  }

  function _disablePositionManager() internal {
    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdatePositionManager(POSITION_MANAGER, false);
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager({positionManager: POSITION_MANAGER, active: false});

    assertFalse(spoke1.isPositionManagerActive(POSITION_MANAGER));
  }

  function _resetTokenAllowance(address who) internal {
    vm.prank(who);
    tokenList.usdx.approve(address(hub1), 0);
  }
}
