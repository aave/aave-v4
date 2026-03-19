// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {ConfigPositionManagerHelpers} from 'tests/helpers/position-manager/config-position-manager/ConfigPositionManagerHelpers.sol';

contract ConfigPositionManagerBaseTest is Base, ConfigPositionManagerHelpers {
  using ConfigPermissionsMap for ConfigPermissions;

  ConfigPositionManager public positionManager;
  ConfigPermissions emptyPermissions;

  function setUp() public virtual override {
    super.setUp();

    positionManager = new ConfigPositionManager(address(ADMIN));

    emptyPermissions = ConfigPermissions.wrap(0);

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
  }

  function _setGlobalPermissionPermitData(
    address delegatee,
    address delegator,
    bool permission,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetGlobalPermissionPermit memory) {
    return
      _setGlobalPermissionPermitData(
        positionManager,
        spoke1,
        delegatee,
        delegator,
        permission,
        deadline
      );
  }

  function _setCanSetUsingAsCollateralPermissionPermitData(
    address delegatee,
    address delegator,
    bool permission,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit memory) {
    return
      _setCanSetUsingAsCollateralPermissionPermitData(
        positionManager,
        spoke1,
        delegatee,
        delegator,
        permission,
        deadline
      );
  }

  function _setCanUpdateUserRiskPremiumPermissionPermitData(
    address delegatee,
    address delegator,
    bool permission,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit memory) {
    return
      _setCanUpdateUserRiskPremiumPermissionPermitData(
        positionManager,
        spoke1,
        delegatee,
        delegator,
        permission,
        deadline
      );
  }

  function _setCanUpdateUserDynamicConfigPermissionPermitData(
    address delegatee,
    address delegator,
    bool permission,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit memory) {
    return
      _setCanUpdateUserDynamicConfigPermissionPermitData(
        positionManager,
        spoke1,
        delegatee,
        delegator,
        permission,
        deadline
      );
  }

  function _canUpdateUsingAsCollateral(
    address spoke,
    address delegator,
    address delegatee
  ) internal view returns (bool) {
    return _canUpdateUsingAsCollateral(positionManager, spoke, delegator, delegatee);
  }

  function _canUpdateUserRiskPremium(
    address spoke,
    address delegator,
    address delegatee
  ) internal view returns (bool) {
    return _canUpdateUserRiskPremium(positionManager, spoke, delegator, delegatee);
  }

  function _canUpdateUserDynamicConfig(
    address spoke,
    address delegator,
    address delegatee
  ) internal view returns (bool) {
    return _canUpdateUserDynamicConfig(positionManager, spoke, delegator, delegatee);
  }
}
