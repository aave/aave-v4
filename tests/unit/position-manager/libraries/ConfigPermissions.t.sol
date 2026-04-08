// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ConfigPermissions} from 'src/position-manager/libraries/ConfigPermissionsMap.sol';
import {IConfigPositionManager} from 'src/position-manager/interfaces/IConfigPositionManager.sol';
import {ConfigPermissionsWrapper} from 'tests/mocks/ConfigPermissionsWrapper.sol';

contract ConfigPermissionsTests is Test {
  uint8 internal constant CAN_SET_USING_AS_COLLATERAL_MASK = 0x1;
  uint8 internal constant CAN_UPDATE_USER_RISK_PREMIUM_MASK = 0x2;
  uint8 internal constant CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK = 0x4;
  uint8 internal constant GLOBAL_PERMISSIONS_MASK = 0x7;

  ConfigPermissionsWrapper internal w;

  function setUp() public {
    w = new ConfigPermissionsWrapper();
  }

  function test_constants() public view {
    assertEq(w.CAN_SET_USING_AS_COLLATERAL_MASK(), CAN_SET_USING_AS_COLLATERAL_MASK);
    assertEq(w.CAN_UPDATE_USER_RISK_PREMIUM_MASK(), CAN_UPDATE_USER_RISK_PREMIUM_MASK);
    assertEq(w.CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK(), CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK);
    assertEq(w.GLOBAL_PERMISSIONS_MASK(), GLOBAL_PERMISSIONS_MASK);
  }

  function test_setGlobalPermissions_fuzz(bool status) public view {
    ConfigPermissions updatedPerms = w.setGlobalPermissions(status);

    uint8 expected = status ? GLOBAL_PERMISSIONS_MASK : 0;
    assertEq(uint8(ConfigPermissions.unwrap(updatedPerms)), expected);
    assertEq(w.canSetUsingAsCollateral(updatedPerms), status);
    assertEq(w.canUpdateUserRiskPremium(updatedPerms), status);
    assertEq(w.canUpdateUserDynamicConfig(updatedPerms), status);
  }

  function test_setCanSetUsingAsCollateral_fuzz(uint8 rawPermissions, bool status) public view {
    ConfigPermissions perms = _sanitizePermissions(rawPermissions);
    ConfigPermissions updatedPerms = w.setCanSetUsingAsCollateral(perms, status);

    uint8 expected = _changeStatus(perms, CAN_SET_USING_AS_COLLATERAL_MASK, status);
    assertEq(uint8(ConfigPermissions.unwrap(updatedPerms)), expected);
    assertEq(w.canSetUsingAsCollateral(updatedPerms), status);
  }

  function test_setCanUpdateUserRiskPremium_fuzz(uint8 rawPermissions, bool status) public view {
    ConfigPermissions perms = _sanitizePermissions(rawPermissions);
    ConfigPermissions updatedPerms = w.setCanUpdateUserRiskPremium(perms, status);

    uint8 expected = _changeStatus(perms, CAN_UPDATE_USER_RISK_PREMIUM_MASK, status);
    assertEq(uint8(ConfigPermissions.unwrap(updatedPerms)), expected);
    assertEq(w.canUpdateUserRiskPremium(updatedPerms), status);
  }

  function test_setCanUpdateUserDynamicConfig_fuzz(uint8 rawPermissions, bool status) public view {
    ConfigPermissions perms = _sanitizePermissions(rawPermissions);
    ConfigPermissions updatedPerms = w.setCanUpdateUserDynamicConfig(perms, status);

    uint8 expected = _changeStatus(perms, CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK, status);
    assertEq(uint8(ConfigPermissions.unwrap(updatedPerms)), expected);
    assertEq(w.canUpdateUserDynamicConfig(updatedPerms), status);
  }

  function test_getConfigPermissionValues(uint8 rawPermissions) public view {
    ConfigPermissions perms = _sanitizePermissions(rawPermissions);
    IConfigPositionManager.ConfigPermissionValues memory values = w.getConfigPermissionValues(
      perms
    );

    assertEq(values.canSetUsingAsCollateral, w.canSetUsingAsCollateral(perms));
    assertEq(values.canUpdateUserRiskPremium, w.canUpdateUserRiskPremium(perms));
    assertEq(values.canUpdateUserDynamicConfig, w.canUpdateUserDynamicConfig(perms));
  }

  /// @dev Sanitizes the raw permissions by masking out any irrelevant bits.
  function _sanitizePermissions(uint8 rawPermissions) internal pure returns (ConfigPermissions) {
    uint8 sanitizedPermissions = rawPermissions & GLOBAL_PERMISSIONS_MASK;
    return ConfigPermissions.wrap(sanitizedPermissions);
  }

  function _changeStatus(
    ConfigPermissions perms,
    uint8 mask,
    bool status
  ) internal pure returns (uint8) {
    return
      status
        ? (uint8(ConfigPermissions.unwrap(perms)) | mask)
        : (uint8(ConfigPermissions.unwrap(perms)) & ~mask);
  }
}
