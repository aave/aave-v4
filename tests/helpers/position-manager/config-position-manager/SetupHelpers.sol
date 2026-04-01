// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpokeHelpers} from 'tests/helpers/spoke/SpokeHelpers.sol';
import {IConfigPositionManager} from 'src/position-manager/interfaces/IConfigPositionManager.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title SetupHelpers
/// @notice Data builders and query helpers for ConfigPositionManager tests.
abstract contract SetupHelpers is SpokeHelpers {
  function _setGlobalPermissionPermitData(
    IConfigPositionManager positionManager,
    ISpoke spoke,
    address delegatee,
    address delegator,
    bool status,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetGlobalPermissionPermit memory) {
    return
      IConfigPositionManager.SetGlobalPermissionPermit({
        spoke: address(spoke),
        delegator: delegator,
        delegatee: delegatee,
        status: status,
        nonce: positionManager.nonces(delegator, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _setCanSetUsingAsCollateralPermissionPermitData(
    IConfigPositionManager positionManager,
    ISpoke spoke,
    address delegatee,
    address delegator,
    bool status,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit memory) {
    return
      IConfigPositionManager.SetCanSetUsingAsCollateralPermissionPermit({
        spoke: address(spoke),
        delegator: delegator,
        delegatee: delegatee,
        status: status,
        nonce: positionManager.nonces(delegator, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _setCanUpdateUserRiskPremiumPermissionPermitData(
    IConfigPositionManager positionManager,
    ISpoke spoke,
    address delegatee,
    address delegator,
    bool status,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit memory) {
    return
      IConfigPositionManager.SetCanUpdateUserRiskPremiumPermissionPermit({
        spoke: address(spoke),
        delegator: delegator,
        delegatee: delegatee,
        status: status,
        nonce: positionManager.nonces(delegator, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _setCanUpdateUserDynamicConfigPermissionPermitData(
    IConfigPositionManager positionManager,
    ISpoke spoke,
    address delegatee,
    address delegator,
    bool status,
    uint256 deadline
  ) internal returns (IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit memory) {
    return
      IConfigPositionManager.SetCanUpdateUserDynamicConfigPermissionPermit({
        spoke: address(spoke),
        delegator: delegator,
        delegatee: delegatee,
        status: status,
        nonce: positionManager.nonces(delegator, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _canUpdateUsingAsCollateral(
    IConfigPositionManager positionManager,
    address spoke,
    address delegator,
    address delegatee
  ) internal view returns (bool) {
    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(spoke, delegator, delegatee);
    return permissions.canSetUsingAsCollateral;
  }

  function _canUpdateUserRiskPremium(
    IConfigPositionManager positionManager,
    address spoke,
    address delegator,
    address delegatee
  ) internal view returns (bool) {
    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(spoke, delegator, delegatee);
    return permissions.canUpdateUserRiskPremium;
  }

  function _canUpdateUserDynamicConfig(
    IConfigPositionManager positionManager,
    address spoke,
    address delegator,
    address delegatee
  ) internal view returns (bool) {
    IConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(spoke, delegator, delegatee);
    return permissions.canUpdateUserDynamicConfig;
  }
}
