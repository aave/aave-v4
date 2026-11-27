// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/position-manager/PermissionedPositionManager/PermissionedPositionManager.Base.t.sol';

contract PermissionedPositionManagerTest is PermissionedPositionManagerBaseTest {
  function test_initialize() public {
    assertEq(positionManager.SPOKE(), address(spoke1));
    assertEq(positionManager.owner(), ADMIN);
    assertEq(positionManager.rescueGuardian(), ADMIN);
    assertEq(
      _getProxyInitializedVersion(address(positionManager)),
      positionManager.POSITION_MANAGER_REVISION()
    );

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    positionManager.initialize(alice);
  }

  function test_implementation_initialize_revertsWith_InvalidInitialization() public {
    PermissionedPositionManager implementation = _deployImplementation();

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    implementation.initialize(alice);
  }

  function test_constructor_revertsWith_InvalidAddress() public {
    vm.expectRevert(IPermissionedPositionManager.InvalidAddress.selector);
    new PermissionedPositionManager(address(0));
  }

  function test_setPermissionedAction_fuzz(uint256 actionSeed, bool permissioned) public {
    IPermissionedPositionManager.Action action = IPermissionedPositionManager.Action(
      bound(actionSeed, 0, uint8(type(IPermissionedPositionManager.Action).max))
    );

    vm.expectEmit(address(positionManager));
    emit IPermissionedPositionManager.SetPermissionedAction(action, permissioned);
    vm.prank(ADMIN);
    positionManager.setPermissionedAction(action, permissioned);

    for (uint8 i; i <= uint8(type(IPermissionedPositionManager.Action).max); ++i) {
      IPermissionedPositionManager.Action other = IPermissionedPositionManager.Action(i);
      assertEq(positionManager.isActionPermissioned(other), other == action && permissioned);
    }
  }

  function test_setPermissionedAction_unset() public {
    _setPermissioned(IPermissionedPositionManager.Action.Borrow);
    _setPermissioned(IPermissionedPositionManager.Action.Repay);

    vm.prank(ADMIN);
    positionManager.setPermissionedAction(IPermissionedPositionManager.Action.Borrow, false);

    assertFalse(positionManager.isActionPermissioned(IPermissionedPositionManager.Action.Borrow));
    assertTrue(positionManager.isActionPermissioned(IPermissionedPositionManager.Action.Repay));
  }

  function test_setPermissionedAction_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    positionManager.setPermissionedAction(IPermissionedPositionManager.Action.Supply, true);
  }

  function test_setApprovedCaller_fuzz(address caller, bool approved) public {
    vm.expectEmit(address(positionManager));
    emit IPermissionedPositionManager.SetApprovedCaller(caller, approved);
    vm.prank(ADMIN);
    positionManager.setApprovedCaller(caller, approved);

    assertEq(positionManager.isApprovedCaller(caller), approved);
  }

  function test_setApprovedCaller_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    positionManager.setApprovedCaller(alice, true);
  }

  function test_supply() public {
    uint256 amount = 100e18;
    uint256 shares = hub1.previewAddByAssets(daiAssetId, amount);
    uint256 balanceBefore = tokenList.dai.balanceOf(alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(daiReserveId, address(positionManager), alice, shares, amount);
    vm.prank(alice);
    (uint256 suppliedShares, uint256 suppliedAmount) = positionManager.supply(
      daiReserveId,
      amount,
      alice
    );

    assertEq(suppliedShares, shares);
    assertEq(suppliedAmount, amount);
    assertEq(tokenList.dai.balanceOf(alice), balanceBefore - amount);
    assertEq(spoke1.getUserSuppliedAssets(daiReserveId, alice), amount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
  }

  function test_withdraw() public {
    vm.prank(alice);
    positionManager.supply(daiReserveId, 100e18, alice);
    uint256 balanceBefore = tokenList.dai.balanceOf(alice);

    vm.prank(alice);
    (, uint256 withdrawnAmount) = positionManager.withdraw(daiReserveId, UINT256_MAX, alice);

    assertEq(withdrawnAmount, 100e18);
    assertEq(tokenList.dai.balanceOf(alice), balanceBefore + withdrawnAmount);
    assertEq(spoke1.getUserSuppliedAssets(daiReserveId, alice), 0);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
  }

  function test_borrow() public {
    vm.startPrank(alice);
    positionManager.supply(daiReserveId, 100e18, alice);
    positionManager.setUsingAsCollateral(daiReserveId, true, alice);
    uint256 balanceBefore = tokenList.usdx.balanceOf(alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrow(
      usdxReserveId,
      address(positionManager),
      alice,
      hub1.previewDrawByAssets(usdxAssetId, 10e6),
      10e6
    );
    (, uint256 borrowedAmount) = positionManager.borrow(usdxReserveId, 10e6, alice);
    vm.stopPrank();

    assertEq(borrowedAmount, 10e6);
    assertEq(tokenList.usdx.balanceOf(alice), balanceBefore + borrowedAmount);
    assertEq(spoke1.getUserTotalDebt(usdxReserveId, alice), 10e6);
    assertEq(tokenList.usdx.balanceOf(address(positionManager)), 0);
  }

  function test_repay_partial() public {
    _openBorrowPosition(alice, 100e18, 10e6);
    uint256 balanceBefore = tokenList.usdx.balanceOf(alice);

    vm.prank(alice);
    (, uint256 repaidAmount) = positionManager.repay(usdxReserveId, 4e6, alice);

    assertEq(repaidAmount, 4e6);
    assertEq(tokenList.usdx.balanceOf(alice), balanceBefore - 4e6);
    assertEq(spoke1.getUserTotalDebt(usdxReserveId, alice), 6e6);
  }

  function test_repay_max_capped_to_debt() public {
    _openBorrowPosition(alice, 100e18, 10e6);
    skip(365 days);
    uint256 debt = spoke1.getUserTotalDebt(usdxReserveId, alice);
    uint256 balanceBefore = tokenList.usdx.balanceOf(alice);

    vm.prank(alice);
    (, uint256 repaidAmount) = positionManager.repay(usdxReserveId, UINT256_MAX, alice);

    assertEq(repaidAmount, debt);
    assertEq(tokenList.usdx.balanceOf(alice), balanceBefore - debt);
    assertEq(spoke1.getUserTotalDebt(usdxReserveId, alice), 0);
    assertEq(tokenList.usdx.balanceOf(address(positionManager)), 0);
  }

  function test_setUsingAsCollateral() public {
    vm.prank(alice);
    positionManager.supply(daiReserveId, 100e18, alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral(daiReserveId, address(positionManager), alice, true);
    vm.prank(alice);
    positionManager.setUsingAsCollateral(daiReserveId, true, alice);

    assertTrue(_isUsingAsCollateral(spoke1, daiReserveId, alice));
  }

  function test_updateUserRiskPremium() public {
    _openBorrowPosition(alice, 100e18, 10e6);

    vm.expectCall(address(spoke1), abi.encodeCall(ISpoke.updateUserRiskPremium, (alice)));
    vm.prank(alice);
    positionManager.updateUserRiskPremium(alice);
  }

  function test_updateUserDynamicConfig() public {
    _openBorrowPosition(alice, 100e18, 10e6);

    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.prank(alice);
    positionManager.updateUserDynamicConfig(alice);
  }

  function test_userAction_revertsWith_Unauthorized_fuzz(uint256 actionSeed) public {
    vm.expectRevert(IPermissionedPositionManager.Unauthorized.selector);
    _callAction(_boundUserAction(actionSeed), bob, alice);
  }

  function test_userAction_revertsWith_CallerNotApproved_fuzz(uint256 actionSeed) public {
    IPermissionedPositionManager.Action action = _boundUserAction(actionSeed);
    _setPermissioned(action);

    vm.expectRevert(IPermissionedPositionManager.CallerNotApproved.selector);
    _callAction(action, alice, alice);
  }

  function test_permissioned_supply_approvedCaller() public {
    _setPermissioned(IPermissionedPositionManager.Action.Supply);
    _approveCaller(alice);

    vm.prank(alice);
    positionManager.supply(daiReserveId, 1e18, alice);

    assertEq(spoke1.getUserSuppliedAssets(daiReserveId, alice), 1e18);
  }

  function test_permissioned_only_restricts_its_action() public {
    _setPermissioned(IPermissionedPositionManager.Action.Borrow);

    vm.startPrank(alice);
    positionManager.supply(daiReserveId, 100e18, alice);
    positionManager.setUsingAsCollateral(daiReserveId, true, alice);
    vm.expectRevert(IPermissionedPositionManager.CallerNotApproved.selector);
    positionManager.borrow(usdxReserveId, 1e6, alice);
    vm.stopPrank();
  }

  function test_liquidationCall() public {
    _openBorrowPosition(alice, 10_000e18, 5_000e6);
    _mockReservePriceByPercent(spoke1, daiReserveId, 60_00, SPOKE_ADMIN);
    assertLt(_getUserHealthFactor(spoke1, alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    uint256 debtToCover = 100e6;
    deal(address(tokenList.usdx), liquidator, debtToCover);
    vm.prank(liquidator);
    tokenList.usdx.approve(address(positionManager), debtToCover);
    uint256 debtBefore = spoke1.getUserTotalDebt(usdxReserveId, alice);

    vm.prank(liquidator);
    positionManager.liquidationCall(daiReserveId, usdxReserveId, alice, debtToCover);

    uint256 repaid = debtToCover - tokenList.usdx.balanceOf(liquidator);
    assertGt(repaid, 0);
    assertApproxEqAbs(spoke1.getUserTotalDebt(usdxReserveId, alice), debtBefore - repaid, 1);
    assertGt(tokenList.dai.balanceOf(liquidator), 0);
    assertEq(spoke1.getUserSuppliedAssets(daiReserveId, address(positionManager)), 0);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.usdx.balanceOf(address(positionManager)), 0);
  }

  function test_liquidationCall_permissioned_approvedCaller() public {
    _setPermissioned(IPermissionedPositionManager.Action.LiquidationCall);
    _approveCaller(liquidator);
    test_liquidationCall();
  }

  function test_liquidationCall_revertsWith_CallerNotApproved() public {
    _setPermissioned(IPermissionedPositionManager.Action.LiquidationCall);
    // the position owner being approved does not matter for liquidations
    _approveCaller(alice);

    vm.expectRevert(IPermissionedPositionManager.CallerNotApproved.selector);
    _callAction(IPermissionedPositionManager.Action.LiquidationCall, liquidator, alice);
  }

  function test_liquidationCall_revertsWith_SelfLiquidation() public {
    vm.expectRevert(ISpoke.SelfLiquidation.selector);
    _callAction(IPermissionedPositionManager.Action.LiquidationCall, alice, alice);
  }

  function test_multicall() public {
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(IPermissionedPositionManager.supply, (daiReserveId, 100e18, alice));
    calls[1] = abi.encodeCall(
      IPermissionedPositionManager.setUsingAsCollateral,
      (daiReserveId, true, alice)
    );

    vm.prank(alice);
    positionManager.multicall(calls);

    assertEq(spoke1.getUserSuppliedAssets(daiReserveId, alice), 100e18);
    assertTrue(_isUsingAsCollateral(spoke1, daiReserveId, alice));
  }

  function test_rescueToken() public {
    deal(address(tokenList.dai), address(positionManager), 1e18);

    vm.prank(ADMIN);
    positionManager.rescueToken(address(tokenList.dai), ADMIN, 1e18);

    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
  }

  function test_rescueToken_revertsWith_OnlyRescueGuardian() public {
    vm.expectRevert(IRescuable.OnlyRescueGuardian.selector);
    vm.prank(alice);
    positionManager.rescueToken(address(tokenList.dai), alice, 1);
  }
}
