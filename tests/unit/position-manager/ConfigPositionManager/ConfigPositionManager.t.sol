// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/position-manager/ConfigPositionManager/ConfigPositionManager.Base.t.sol';

contract ConfigPositionManagerTest is ConfigPositionManagerBaseTest {
  using ConfigPermissionsMap for ConfigPermissions;
  function test_setGlobalPermission() public {
    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions = emptyPermissions
      .setCanSetUsingAsCollateral(true)
      .setCanUpdateUserRiskPremium(true)
      .setCanUpdateUserDynamicConfig(true);

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      emptyPermissions,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    permissions = positionManager.getConfigPermissions(address(spoke1), bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);
  }

  function test_setGlobalPermission_setThenRemove() public {
    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions = emptyPermissions
      .setCanSetUsingAsCollateral(true)
      .setCanUpdateUserRiskPremium(true)
      .setCanUpdateUserDynamicConfig(true);

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      emptyPermissions,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    permissions = positionManager.getConfigPermissions(address(spoke1), bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      newPermissions,
      emptyPermissions
    );
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, false);

    permissions = positionManager.getConfigPermissions(address(spoke1), bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);
  }

  function test_setGlobalPermission_removeAllPermissions() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions globalPermissions = ConfigPermissionsMap.setGlobalPermissions(true);
    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      globalPermissions,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, false);

    permissions = positionManager.getConfigPermissions(address(spoke1), bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);
  }

  function test_setGlobalPermission_removePreviousPermissions() public {
    vm.prank(alice);
    positionManager.setCanSetUsingAsCollateralPermission(address(spoke1), bob, true);
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);

    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions oldPermissions = emptyPermissions
      .setCanSetUsingAsCollateral(true)
      .setCanUpdateUserDynamicConfig(true);
    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      oldPermissions,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, false);

    permissions = positionManager.getConfigPermissions(address(spoke1), bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);
  }

  function test_setGlobalPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke2), bob, true);
  }

  function test_setCanSetUsingAsCollateralPermission() public {
    assertFalse(_canUpdateUsingAsCollateral(address(spoke1), bob, alice));
    ConfigPermissions newPermissions = emptyPermissions.setCanSetUsingAsCollateral(true);

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      emptyPermissions,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanSetUsingAsCollateralPermission(address(spoke1), bob, true);

    assertTrue(_canUpdateUsingAsCollateral(address(spoke1), bob, alice));
  }

  function test_setCanSetUsingAsCollateralPermission_remove() public {
    vm.prank(alice);
    positionManager.setCanSetUsingAsCollateralPermission(address(spoke1), bob, true);
    assertTrue(_canUpdateUsingAsCollateral(address(spoke1), bob, alice));

    ConfigPermissions oldPermissions = emptyPermissions.setCanSetUsingAsCollateral(true);
    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      oldPermissions,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanSetUsingAsCollateralPermission(address(spoke1), bob, false);

    assertFalse(_canUpdateUsingAsCollateral(address(spoke1), bob, alice));
  }

  function test_setCanSetUsingAsCollateralPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setCanSetUsingAsCollateralPermission(address(spoke2), bob, true);
  }

  function test_setCanUpdateUserRiskPremiumPermission() public {
    assertFalse(_canUpdateUserRiskPremium(address(spoke1), bob, alice));
    ConfigPermissions newPermissions = emptyPermissions.setCanUpdateUserRiskPremium(true);

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      emptyPermissions,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, true);

    assertTrue(_canUpdateUserRiskPremium(address(spoke1), bob, alice));
  }

  function test_setCanUpdateUserRiskPremiumPermission_remove() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, true);
    assertTrue(_canUpdateUserRiskPremium(address(spoke1), bob, alice));

    ConfigPermissions oldPermissions = emptyPermissions.setCanUpdateUserRiskPremium(true);
    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      oldPermissions,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, false);

    assertFalse(_canUpdateUserRiskPremium(address(spoke1), bob, alice));
  }

  function test_setCanUpdateUserRiskPremiumPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke2), bob, true);
  }

  function test_setCanUpdateUserDynamicConfigPermission() public {
    assertFalse(_canUpdateUserDynamicConfig(address(spoke1), bob, alice));
    ConfigPermissions newPermissions = emptyPermissions.setCanUpdateUserDynamicConfig(true);

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      emptyPermissions,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);

    assertTrue(_canUpdateUserDynamicConfig(address(spoke1), bob, alice));
  }

  function test_setCanUpdateUserDynamicConfigPermission_remove() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);
    assertTrue(_canUpdateUserDynamicConfig(address(spoke1), bob, alice));

    ConfigPermissions oldPermissions = emptyPermissions.setCanUpdateUserDynamicConfig(true);
    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      oldPermissions,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, false);

    assertFalse(_canUpdateUserDynamicConfig(address(spoke1), bob, alice));
  }

  function test_setCanUpdateUserDynamicConfigPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke2), bob, true);
  }

  function test_renounceGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions globalPermissions = ConfigPermissionsMap.setGlobalPermissions(true);
    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      globalPermissions,
      newPermissions
    );
    vm.prank(bob);
    positionManager.renounceGlobalPermission(address(spoke1), alice);

    permissions = positionManager.getConfigPermissions(address(spoke1), bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);
  }

  function test_renounceGlobalPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceGlobalPermission(address(spoke2), alice);
  }

  function test_renounceCanUpdateUsingAsCollateralPermission() public {
    vm.prank(alice);
    positionManager.setCanSetUsingAsCollateralPermission(address(spoke1), bob, true);

    assertTrue(_canUpdateUsingAsCollateral(address(spoke1), bob, alice));

    ConfigPermissions oldPermissions = emptyPermissions.setCanSetUsingAsCollateral(true);
    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      oldPermissions,
      newPermissions
    );
    vm.prank(bob);
    positionManager.renounceCanUpdateUsingAsCollateralPermission(address(spoke1), alice);

    assertFalse(_canUpdateUsingAsCollateral(address(spoke1), bob, alice));
  }

  function test_renounceCanUpdateUsingAsCollateralPermission_revertsWith_SpokeNotRegistered()
    public
  {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceCanUpdateUsingAsCollateralPermission(address(spoke2), alice);
  }

  function test_renounceCanUpdateUserRiskPremiumPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, true);

    assertTrue(_canUpdateUserRiskPremium(address(spoke1), bob, alice));

    ConfigPermissions oldPermissions = emptyPermissions.setCanUpdateUserRiskPremium(true);
    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      oldPermissions,
      newPermissions
    );
    vm.prank(bob);
    positionManager.renounceCanUpdateUserRiskPremiumPermission(address(spoke1), alice);

    assertFalse(_canUpdateUserRiskPremium(address(spoke1), bob, alice));
  }

  function test_renounceCanUpdateUserRiskPremiumPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceCanUpdateUserRiskPremiumPermission(address(spoke2), alice);
  }

  function test_renounceCanUpdateUserDynamicConfigPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);

    assertTrue(_canUpdateUserDynamicConfig(address(spoke1), bob, alice));

    ConfigPermissions oldPermissions = emptyPermissions.setCanUpdateUserDynamicConfig(true);
    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateConfigPermissions(
      address(spoke1),
      alice,
      bob,
      oldPermissions,
      newPermissions
    );
    vm.prank(bob);
    positionManager.renounceCanUpdateUserDynamicConfigPermission(address(spoke1), alice);

    assertFalse(_canUpdateUserDynamicConfig(address(spoke1), bob, alice));
  }

  function test_renounceCanUpdateUserDynamicConfigPermission_revertsWith_SpokeNotRegistered()
    public
  {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceCanUpdateUserDynamicConfigPermission(address(spoke2), alice);
  }

  function test_setUsingAsCollateralOnBehalfOf_fuzz_withPermission(
    uint256 reserveId,
    bool useAsCollateral
  ) public {
    reserveId = bound(reserveId, 1, spoke1.getReserveCount() - 1);

    vm.prank(alice);
    positionManager.setCanSetUsingAsCollateralPermission(address(spoke1), bob, true);

    vm.prank(alice);
    spoke1.setUsingAsCollateral(reserveId, !useAsCollateral, alice);

    (bool isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, !useAsCollateral);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral(reserveId, address(positionManager), alice, useAsCollateral);
    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.SetUsingAsCollateralOnBehalfOf(
      address(spoke1),
      bob,
      alice,
      reserveId,
      useAsCollateral
    );
    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(
      address(spoke1),
      reserveId,
      useAsCollateral,
      alice
    );

    (isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, useAsCollateral);
  }

  function test_setUsingAsCollateralOnBehalfOf_fuzz_withGlobalPermission(
    uint256 reserveId,
    bool useAsCollateral
  ) public {
    reserveId = bound(reserveId, 1, spoke1.getReserveCount() - 1);

    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    vm.prank(alice);
    spoke1.setUsingAsCollateral(reserveId, !useAsCollateral, alice);

    (bool isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, !useAsCollateral);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral(reserveId, address(positionManager), alice, useAsCollateral);
    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.SetUsingAsCollateralOnBehalfOf(
      address(spoke1),
      bob,
      alice,
      reserveId,
      useAsCollateral
    );
    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(
      address(spoke1),
      reserveId,
      useAsCollateral,
      alice
    );

    (isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, useAsCollateral);
  }

  function test_setUsingAsCollateralOnBehalfOf_revertsWith_CallerNotAllowed() public {
    vm.expectRevert(IConfigPositionManager.DelegateeNotAllowed.selector);
    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      true,
      alice
    );
  }

  function test_setUsingAsCollateralOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(address(spoke2), 1, true, alice);
  }

  function test_updateUserRiskPremiumOnBehalfOf_withPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 75e18, alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateUserRiskPremium(alice, _calculateExpectedUserRP(spoke1, alice));
    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateUserRiskPremiumOnBehalfOf(address(spoke1), bob, alice);
    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserRiskPremiumOnBehalfOf_withGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 75e18, alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateUserRiskPremium(alice, _calculateExpectedUserRP(spoke1, alice));
    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateUserRiskPremiumOnBehalfOf(address(spoke1), bob, alice);
    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserRiskPremiumOnBehalfOf_revertsWith_CallerNotAllowed() public {
    vm.expectRevert(IConfigPositionManager.DelegateeNotAllowed.selector);
    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserRiskPremiumOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(address(spoke2), alice);
  }

  function test_updateUserDynamicConfigOnBehalfOf_withPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);

    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateUserDynamicConfigOnBehalfOf(address(spoke1), bob, alice);
    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserDynamicConfigOnBehalfOf_withGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.expectEmit(address(positionManager));
    emit IConfigPositionManager.UpdateUserDynamicConfigOnBehalfOf(address(spoke1), bob, alice);
    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserDynamicConfigOnBehalfOf_revertsWith_CallerNotAllowed() public {
    vm.expectRevert(IConfigPositionManager.DelegateeNotAllowed.selector);
    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserDynamicConfigOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(address(spoke2), alice);
  }

  function test_multicall() public {
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSignature(
      'setGlobalPermission(address,address,bool)',
      address(spoke1),
      bob,
      true
    );
    calls[1] = abi.encodeWithSignature(
      'setGlobalPermission(address,address,bool)',
      address(spoke1),
      carol,
      true
    );

    vm.prank(alice);
    bytes[] memory res = positionManager.multicall(calls);

    assertEq(res[0].length, 0);
    assertEq(res[1].length, 0);

    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    permissions = positionManager.getConfigPermissions(address(spoke1), carol, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);
  }

  function test_setGlobalPermission_revertsWith_InvalidAddress_zeroDelegatee() public {
    vm.expectRevert(IPositionManagerBase.InvalidAddress.selector);
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), address(0), true);
  }

  function test_setCanSetUsingAsCollateralPermission_revertsWith_InvalidAddress_zeroDelegatee()
    public
  {
    vm.expectRevert(IPositionManagerBase.InvalidAddress.selector);
    vm.prank(alice);
    positionManager.setCanSetUsingAsCollateralPermission(address(spoke1), address(0), true);
  }

  function test_setCanUpdateUserRiskPremiumPermission_revertsWith_InvalidAddress_zeroDelegatee()
    public
  {
    vm.expectRevert(IPositionManagerBase.InvalidAddress.selector);
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), address(0), true);
  }

  function test_setCanUpdateUserDynamicConfigPermission_revertsWith_InvalidAddress_zeroDelegatee()
    public
  {
    vm.expectRevert(IPositionManagerBase.InvalidAddress.selector);
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), address(0), true);
  }
}
