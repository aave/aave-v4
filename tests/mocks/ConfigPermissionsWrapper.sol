// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
  ConfigPermissions,
  ConfigPermissionsMap
} from 'src/position-manager/libraries/ConfigPermissionsMap.sol';
import {IConfigPositionManager} from 'src/position-manager/interfaces/IConfigPositionManager.sol';

contract ConfigPermissionsWrapper {
  using ConfigPermissionsMap for ConfigPermissions;

  function setGlobalPermissions(bool status) external pure returns (ConfigPermissions) {
    return ConfigPermissionsMap.setGlobalPermissions(status);
  }

  function setCanSetUsingAsCollateral(
    ConfigPermissions self,
    bool status
  ) external pure returns (ConfigPermissions) {
    return self.setCanSetUsingAsCollateral(status);
  }

  function setCanUpdateUserRiskPremium(
    ConfigPermissions self,
    bool status
  ) external pure returns (ConfigPermissions) {
    return self.setCanUpdateUserRiskPremium(status);
  }

  function setCanUpdateUserDynamicConfig(
    ConfigPermissions self,
    bool status
  ) external pure returns (ConfigPermissions) {
    return self.setCanUpdateUserDynamicConfig(status);
  }

  function canSetUsingAsCollateral(ConfigPermissions self) external pure returns (bool) {
    return self.canSetUsingAsCollateral();
  }

  function canUpdateUserRiskPremium(ConfigPermissions self) external pure returns (bool) {
    return self.canUpdateUserRiskPremium();
  }

  function canUpdateUserDynamicConfig(ConfigPermissions self) external pure returns (bool) {
    return self.canUpdateUserDynamicConfig();
  }

  function getConfigPermissionValues(
    ConfigPermissions self
  ) external pure returns (IConfigPositionManager.ConfigPermissionValues memory) {
    return self.getConfigPermissionValues();
  }

  function CAN_SET_USING_AS_COLLATERAL_MASK() external pure returns (uint8) {
    return ConfigPermissionsMap.CAN_SET_USING_AS_COLLATERAL_MASK;
  }

  function CAN_UPDATE_USER_RISK_PREMIUM_MASK() external pure returns (uint8) {
    return ConfigPermissionsMap.CAN_UPDATE_USER_RISK_PREMIUM_MASK;
  }

  function CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK() external pure returns (uint8) {
    return ConfigPermissionsMap.CAN_UPDATE_USER_DYNAMIC_CONFIG_MASK;
  }

  function GLOBAL_PERMISSIONS_MASK() external pure returns (uint8) {
    return ConfigPermissionsMap.GLOBAL_PERMISSIONS_MASK;
  }
}
