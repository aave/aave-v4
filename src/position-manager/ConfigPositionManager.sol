// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ConfigPermissionsMap} from 'src/position-manager/libraries/ConfigPermissionsMap.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {
  IConfigPositionManager,
  ConfigPermissions
} from 'src/position-manager/interfaces/IConfigPositionManager.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

/// @title ConfigPositionManager
/// @author Aave Labs
/// @notice Position manager to handle position configuration actions on behalf of users.
contract ConfigPositionManager is IConfigPositionManager, PositionManagerBase {
  using ConfigPermissionsMap for ConfigPermissions;

  /// @dev Map of configuration permissions based on the Spoke, delegator and delegatee.
  mapping(address spoke => mapping(address delegator => mapping(address delegatee => ConfigPermissions)))
    private _config;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) PositionManagerBase(initialOwner_) {}

  /// @inheritdoc IConfigPositionManager
  function setGlobalPermission(
    address spoke,
    address delegatee,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee
    });
    ConfigPermissions newPermissions = ConfigPermissionsMap.setFullPermissions(permission);
    _updatePermissions({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @inheritdoc IConfigPositionManager
  function setCanUpdateUsingAsCollateralPermission(
    address spoke,
    address delegatee,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee
    });
    ConfigPermissions newPermissions = oldPermissions.setCanSetUsingAsCollateral(permission);
    _updatePermissions({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @inheritdoc IConfigPositionManager
  function setCanUpdateUserRiskPremiumPermission(
    address spoke,
    address delegatee,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee
    });
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserRiskPremium(permission);
    _updatePermissions({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @inheritdoc IConfigPositionManager
  function setCanUpdateUserDynamicConfigPermission(
    address spoke,
    address delegatee,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee
    });
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserDynamicConfig(permission);
    _updatePermissions({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @inheritdoc IConfigPositionManager
  function renounceGlobalPermission(
    address spoke,
    address delegator
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: msg.sender
    });
    ConfigPermissions newPermissions = ConfigPermissionsMap.setFullPermissions(false);
    _updatePermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: msg.sender,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @inheritdoc IConfigPositionManager
  function renounceCanUpdateUsingAsCollateralPermission(
    address spoke,
    address delegator
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: msg.sender
    });
    ConfigPermissions newPermissions = oldPermissions.setCanSetUsingAsCollateral(false);
    _updatePermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: msg.sender,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @inheritdoc IConfigPositionManager
  function renounceCanUpdateUserRiskPremiumPermission(
    address spoke,
    address delegator
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: msg.sender
    });
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserRiskPremium(false);
    _updatePermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: msg.sender,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @inheritdoc IConfigPositionManager
  function renounceCanUpdateUserDynamicConfigPermission(
    address spoke,
    address delegator
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: msg.sender
    });
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserDynamicConfig(false);
    _updatePermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: msg.sender,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @inheritdoc IConfigPositionManager
  function setUsingAsCollateralOnBehalfOf(
    address spoke,
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) {
    require(
      _getPermissions({spoke: spoke, delegator: onBehalfOf, delegatee: msg.sender})
        .canSetUsingAsCollateral(),
      DelegateeNotAllowed()
    );

    ISpoke(spoke).setUsingAsCollateral(reserveId, usingAsCollateral, onBehalfOf);
  }

  /// @inheritdoc IConfigPositionManager
  function updateUserRiskPremiumOnBehalfOf(
    address spoke,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) {
    require(
      _getPermissions({spoke: spoke, delegator: onBehalfOf, delegatee: msg.sender})
        .canUpdateUserRiskPremium(),
      DelegateeNotAllowed()
    );

    ISpoke(spoke).updateUserRiskPremium(onBehalfOf);
  }

  /// @inheritdoc IConfigPositionManager
  function updateUserDynamicConfigOnBehalfOf(
    address spoke,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) {
    require(
      _getPermissions({spoke: spoke, delegator: onBehalfOf, delegatee: msg.sender})
        .canUpdateUserDynamicConfig(),
      DelegateeNotAllowed()
    );

    ISpoke(spoke).updateUserDynamicConfig(onBehalfOf);
  }

  /// @inheritdoc IConfigPositionManager
  function getConfigPermissions(
    address spoke,
    address delegatee,
    address onBehalfOf
  ) external view returns (ConfigPermissionValues memory) {
    return
      _getPermissions({spoke: spoke, delegator: onBehalfOf, delegatee: delegatee})
        .getConfigPermissionValues();
  }

  /// @dev Does not update if the new permissions are equal to the old permissions.
  function _updatePermissions(
    address spoke,
    address delegator,
    address delegatee,
    ConfigPermissions oldPermissions,
    ConfigPermissions newPermissions
  ) internal {
    if (oldPermissions.eq(newPermissions)) {
      return;
    }
    _config[spoke][delegator][delegatee] = newPermissions;
    emit ConfigPermissionsUpdated(spoke, delegator, delegatee, newPermissions);
  }

  function _getPermissions(
    address spoke,
    address delegator,
    address delegatee
  ) internal view returns (ConfigPermissions) {
    return _config[spoke][delegator][delegatee];
  }

  function _multicallEnabled() internal pure override returns (bool) {
    return true;
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('ConfigPositionManager', '1');
  }
}
