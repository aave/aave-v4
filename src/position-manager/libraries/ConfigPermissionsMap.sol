// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.20;

import {
  ConfigPermissions,
  IConfigPositionManager
} from 'src/position-manager/interfaces/IConfigPositionManager.sol';

/// @title ConfigPermissions Library
/// @author Aave Labs
/// @notice Implements the bitmap logic to handle the ConfigPermissions configuration.
library ConfigPermissionsMap {
  using ConfigPermissionsMap for ConfigPermissions;

  /// @dev Mask for the `canSetUsingAsCollateral` permission.
  uint8 internal constant CAN_SET_USING_AS_COLLATERAL_MASK = 0x1;
  /// @dev Mask for the `canUpdateUserRiskPremium` permission.
  uint8 internal constant CAN_UPDATE_USER_RISK_PREMIUM_MASK = 0x2;
  /// @dev Mask for the `canUpdateUserDynamicConfig` permission.
  uint8 internal constant CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK = 0x4;
  /// @dev Mask for the global permissions.
  uint8 internal constant GLOBAL_PERMISSIONS_MASK = 0x7;

  /// @notice Creates a ConfigPermissions with all permissions set to the given status.
  /// @param status The status for all permissions.
  /// @return The created ConfigPermissions.
  function setGlobalPermissions(bool status) internal pure returns (ConfigPermissions) {
    return ConfigPermissions.wrap(status ? GLOBAL_PERMISSIONS_MASK : 0);
  }

  /// @notice Sets the new status for the `canSetUsingAsCollateral` permission.
  /// @param self The current ConfigPermissions.
  /// @param status The new status for the `canSetUsingAsCollateral` permission.
  /// @return The updated ConfigPermissions.
  function setCanSetUsingAsCollateral(
    ConfigPermissions self,
    bool status
  ) internal pure returns (ConfigPermissions) {
    return
      ConfigPermissions.wrap(
        _setStatus(ConfigPermissions.unwrap(self), CAN_SET_USING_AS_COLLATERAL_MASK, status)
      );
  }

  /// @notice Sets the new status for the `canUpdateUserRiskPremium` permission.
  /// @param self The current ConfigPermissions.
  /// @param status The new status for the `canUpdateUserRiskPremium` permission.
  /// @return The updated ConfigPermissions.
  function setCanUpdateUserRiskPremium(
    ConfigPermissions self,
    bool status
  ) internal pure returns (ConfigPermissions) {
    return
      ConfigPermissions.wrap(
        _setStatus(ConfigPermissions.unwrap(self), CAN_UPDATE_USER_RISK_PREMIUM_MASK, status)
      );
  }

  /// @notice Sets the new status for the `canUpdateUserDynamicConfig` permission.
  /// @param self The current ConfigPermissions.
  /// @param status The new status for the `canUpdateUserDynamicConfig` permission.
  /// @return The updated ConfigPermissions.
  function setCanUpdateUserDynamicConfig(
    ConfigPermissions self,
    bool status
  ) internal pure returns (ConfigPermissions) {
    return
      ConfigPermissions.wrap(
        _setStatus(ConfigPermissions.unwrap(self), CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK, status)
      );
  }

  /// @notice Returns the ConfigPermissionValues struct with the values of each permission.
  /// @param self The current ConfigPermissions.
  /// @return The ConfigPermissionValues struct with the values of each permission.
  function getConfigPermissionValues(
    ConfigPermissions self
  ) internal pure returns (IConfigPositionManager.ConfigPermissionValues memory) {
    return
      IConfigPositionManager.ConfigPermissionValues({
        canSetUsingAsCollateral: self.canSetUsingAsCollateral(),
        canUpdateUserRiskPremium: self.canUpdateUserRiskPremium(),
        canUpdateUserDynamicConfig: self.canUpdateUserDynamicConfig()
      });
  }

  /// @notice Returns whether the `canSetUsingAsCollateral` permission or global permissions are enabled.
  /// @param self The current ConfigPermissions.
  /// @return Whether the `canSetUsingAsCollateral` permission or global permissions are enabled.
  function canSetUsingAsCollateral(ConfigPermissions self) internal pure returns (bool) {
    return _getStatus(self, CAN_SET_USING_AS_COLLATERAL_MASK);
  }

  /// @notice Returns whether the `canUpdateUserRiskPremium` permission or global permissions are enabled.
  /// @param self The current ConfigPermissions.
  /// @return Whether the `canUpdateUserRiskPremium` permission or global permissions are enabled
  function canUpdateUserRiskPremium(ConfigPermissions self) internal pure returns (bool) {
    return _getStatus(self, CAN_UPDATE_USER_RISK_PREMIUM_MASK);
  }

  /// @notice Returns whether the `canUpdateUserDynamicConfig` permission or global permissions are enabled.
  /// @param self The current ConfigPermissions.
  /// @return Whether the `canUpdateUserDynamicConfig` permission or global permissions are enabled
  function canUpdateUserDynamicConfig(ConfigPermissions self) internal pure returns (bool) {
    return _getStatus(self, CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK);
  }

  /// @notice Compares two ConfigPermissions for equality.
  /// @param self The first ConfigPermissions.
  /// @param other The second ConfigPermissions.
  /// @return True if both ConfigPermissions are equal, false otherwise.
  function eq(ConfigPermissions self, ConfigPermissions other) internal pure returns (bool) {
    return ConfigPermissions.unwrap(self) == ConfigPermissions.unwrap(other);
  }

  /// @notice Sets the new status for the given permission.
  function _setStatus(uint8 self, uint8 mask, bool status) private pure returns (uint8) {
    return status ? self | mask : self & ~mask;
  }

  /// @notice Returns whether the given permission is enabled.
  function _getStatus(ConfigPermissions self, uint8 mask) private pure returns (bool) {
    return _getStatus(ConfigPermissions.unwrap(self), mask);
  }

  /// @notice Returns whether the given permission is enabled.
  function _getStatus(uint8 self, uint8 mask) private pure returns (bool) {
    return (self & mask) != 0;
  }
}
