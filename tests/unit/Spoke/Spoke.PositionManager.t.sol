// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokePositionManagerTest is SpokeBase {
  function test_setApprovalForPositionManager(bytes32) public {
    vm.setArbitraryStorage(address(spoke1));

    address user = vm.randomAddress();
    address positionManager = vm.randomAddress();
    bool approve = vm.randomBool();

    // if position manager not active, then user should not be able to approve, else action should be idempotent
    if (!spoke1.isPositionManagerActive(positionManager) && approve) {
      vm.expectRevert(ISpoke.InactivePositionManager.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.SetUserPositionManager(user, positionManager, approve);
    }

    vm.prank(user);
    spoke1.setUserPositionManager(positionManager, approve);
  }

  function test_setApproval_revertsWith_InactivePositionManager() public {
    assertFalse(spoke1.isPositionManagerActive(POSITION_MANAGER));
    vm.expectRevert(ISpoke.InactivePositionManager.selector);
    spoke1.setUserPositionManager(POSITION_MANAGER, true);
  }

  function test_disableApproval_on_InactivePositionManager() public {
    _approvePositionManager(alice);
    assertTrue(spoke1.isPositionManager(alice, POSITION_MANAGER));
    assertTrue(spoke1.isPositionManagerActive(POSITION_MANAGER));

    _disablePositionManager();
    assertFalse(spoke1.isPositionManager(alice, POSITION_MANAGER)); // since posm is not active
    assertFalse(spoke1.isPositionManagerActive(POSITION_MANAGER));

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(alice, POSITION_MANAGER, false);
    vm.prank(alice);
    spoke1.setUserPositionManager(POSITION_MANAGER, false);

    assertFalse(spoke1.isPositionManager(alice, POSITION_MANAGER));
    assertFalse(spoke1.isPositionManagerActive(POSITION_MANAGER));
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
    emit ISpokeBase.Supply(
      reserveId,
      POSITION_MANAGER,
      alice,
      hub1.previewAddByAssets(usdxAssetId, amount),
      amount
    );
    Utils.supply(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserSuppliedAssets(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserSuppliedAssets(reserveId, alice), amount);

    _disablePositionManager();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.supply(spoke1, reserveId, POSITION_MANAGER, amount, alice);
  }

  function test_onlyPositionManager_on_withdraw() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    Utils.supply(spoke1, reserveId, alice, amount, alice);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.withdraw(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    _approvePositionManager(alice);
    _resetTokenAllowance(alice);

    ISpoke.UserPosition memory posBefore = spoke1.getUserPosition(reserveId, POSITION_MANAGER);
    amount /= 2;

    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(hub1), address(POSITION_MANAGER), amount);
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(
      reserveId,
      POSITION_MANAGER,
      alice,
      hub1.previewRemoveByAssets(usdxAssetId, amount),
      amount
    );
    Utils.withdraw(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserSuppliedAssets(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserSuppliedAssets(reserveId, alice), amount);

    _disablePositionManager();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.withdraw(spoke1, reserveId, POSITION_MANAGER, amount, alice);
  }

  function test_onlyPositionManager_on_borrow() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    Utils.supplyCollateral(spoke1, reserveId, alice, (amount * 3) / 2, alice);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.borrow(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    _approvePositionManager(alice);
    _resetTokenAllowance(alice);

    ISpoke.UserPosition memory posBefore = spoke1.getUserPosition(reserveId, POSITION_MANAGER);

    vm.expectEmit(address(tokenList.usdx));
    emit IERC20.Transfer(address(hub1), address(POSITION_MANAGER), amount);
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(
      reserveId,
      POSITION_MANAGER,
      alice,
      hub1.previewRestoreByAssets(usdxAssetId, amount),
      amount
    );
    Utils.borrow(spoke1, reserveId, POSITION_MANAGER, amount, alice);

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserTotalDebt(reserveId, POSITION_MANAGER), 0);
    assertFalse(_isBorrowing(spoke1, reserveId, POSITION_MANAGER));
    assertEq(spoke1.getUserTotalDebt(reserveId, alice), amount);
    assertTrue(_isBorrowing(spoke1, reserveId, alice));

    _disablePositionManager();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.borrow(spoke1, reserveId, POSITION_MANAGER, amount, alice);
  }

  function test_onlyPositionManager_on_repay() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    uint256 amount = 100e6;
    Utils.supplyCollateral(spoke1, reserveId, alice, (amount * 3) / 2, alice);
    Utils.borrow(spoke1, reserveId, alice, amount, alice);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.repay(spoke1, reserveId, POSITION_MANAGER, amount, alice);

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
    emit ISpokeBase.Repay(
      reserveId,
      POSITION_MANAGER,
      alice,
      hub1.previewRestoreByAssets(usdxAssetId, repayAmount),
      repayAmount,
      expectedPremiumDelta
    );
    Utils.repay(spoke1, reserveId, POSITION_MANAGER, repayAmount, alice);

    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserTotalDebt(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserTotalDebt(reserveId, alice), amount - repayAmount);
    assertFalse(_isBorrowing(spoke1, reserveId, POSITION_MANAGER));
    assertTrue(_isBorrowing(spoke1, reserveId, alice));

    Utils.repay(spoke1, reserveId, POSITION_MANAGER, type(uint256).max, alice);
    assertEq(spoke1.getUserPosition(reserveId, POSITION_MANAGER), posBefore);
    assertEq(spoke1.getUserTotalDebt(reserveId, POSITION_MANAGER), 0);
    assertEq(spoke1.getUserTotalDebt(reserveId, alice), 0);
    assertFalse(_isBorrowing(spoke1, reserveId, POSITION_MANAGER));
    assertFalse(_isBorrowing(spoke1, reserveId, alice));

    _disablePositionManager();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.repay(spoke1, reserveId, POSITION_MANAGER, repayAmount, alice);
  }

  function test_onlyPositionManager_on_usingAsCollateral() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    assertFalse(_isUsingAsCollateral(spoke1, reserveId, alice));

    bool usingAsCollateral = true;

    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.setUsingAsCollateral(spoke1, reserveId, POSITION_MANAGER, usingAsCollateral, alice);

    _approvePositionManager(alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral(reserveId, POSITION_MANAGER, alice, usingAsCollateral);
    Utils.setUsingAsCollateral(spoke1, reserveId, POSITION_MANAGER, usingAsCollateral, alice);

    assertEq(_isUsingAsCollateral(spoke1, reserveId, alice), usingAsCollateral);

    _disablePositionManager();
    vm.expectRevert(ISpoke.Unauthorized.selector);
    Utils.setUsingAsCollateral(spoke1, reserveId, POSITION_MANAGER, usingAsCollateral, alice);
  }

  function test_onlyPositionManager_on_updateUserRiskPremium() public {
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), 1500e6);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 0.5e18, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 1000e18, alice);
    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 1500e6, alice);

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
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 0.5e18, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 1000e18, alice);
    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 1500e6, alice);

    _updateCollateralFactor(spoke1, _wethReserveId(spoke1), 90_00);
    _updateCollateralFactor(spoke1, _daiReserveId(spoke1), 90_00);
    DynamicConfig[] memory configs = _getUserDynConfigKeys(spoke1, alice);

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
    spoke1.updatePositionManager(POSITION_MANAGER, true);

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
    spoke1.updatePositionManager(POSITION_MANAGER, false);

    assertFalse(spoke1.isPositionManagerActive(POSITION_MANAGER));
  }

  function _resetTokenAllowance(address who) internal {
    vm.prank(who);
    tokenList.usdx.approve(address(hub1), 0);
  }
}
