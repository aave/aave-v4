// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {ConfigPermissionsMap} from 'src/position-manager/libraries/ConfigPermissionsMap.sol';
import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {
  IConfigPositionManager,
  ConfigPermissions
} from 'src/position-manager/interfaces/IConfigPositionManager.sol';
import {PositionManagerIntentBase} from 'src/position-manager/PositionManagerIntentBase.sol';

/// @title ConfigPositionManager
/// @author Aave Labs
/// @notice Position manager to handle position configuration actions on behalf of users.
contract ConfigPositionManager is IConfigPositionManager, PositionManagerIntentBase {
  using ConfigPermissionsMap for ConfigPermissions;
  using EIP712Hash for *;

  /// @inheritdoc IConfigPositionManager
  bytes32 public constant SET_GLOBAL_PERMISSION_PERMIT_TYPEHASH =
    EIP712Hash.SET_GLOBAL_PERMISSION_PERMIT_TYPEHASH;

  /// @inheritdoc IConfigPositionManager
  bytes32 public constant SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH =
    EIP712Hash.SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH;

  /// @inheritdoc IConfigPositionManager
  bytes32 public constant SET_CAN_UPDATE_USER_RISK_PREMIUM_PERMISSION_PERMIT_TYPEHASH =
    EIP712Hash.SET_CAN_UPDATE_USER_RISK_PREMIUM_PERMISSION_PERMIT_TYPEHASH;

  /// @inheritdoc IConfigPositionManager
  bytes32 public constant SET_CAN_UPDATE_USER_DYNAMIC_CONFIG_PERMISSION_PERMIT_TYPEHASH =
    EIP712Hash.SET_CAN_UPDATE_USER_DYNAMIC_CONFIG_PERMISSION_PERMIT_TYPEHASH;

  /// @dev Map of configuration permissions based on the Spoke, delegator and delegatee.
  mapping(address spoke => mapping(address delegator => mapping(address delegatee => ConfigPermissions)))
    private _config;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) PositionManagerIntentBase(initialOwner_) {}

  /// @inheritdoc IConfigPositionManager
  function setGlobalPermission(
    address spoke,
    address delegatee,
    bool status
  ) external onlyRegisteredSpoke(spoke) {
    _setGlobalPermission({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee,
      status: status
    });
  }

  /// @inheritdoc IConfigPositionManager
  function setCanSetUsingAsCollateralPermission(
    address spoke,
    address delegatee,
    bool status
  ) external onlyRegisteredSpoke(spoke) {
    _setCanSetUsingAsCollateralPermission({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee,
      status: status
    });
  }

  /// @inheritdoc IConfigPositionManager
  function setCanUpdateUserRiskPremiumPermission(
    address spoke,
    address delegatee,
    bool status
  ) external onlyRegisteredSpoke(spoke) {
    _setCanUpdateUserRiskPremiumPermission({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee,
      status: status
    });
  }

  /// @inheritdoc IConfigPositionManager
  function setCanUpdateUserDynamicConfigPermission(
    address spoke,
    address delegatee,
    bool status
  ) external onlyRegisteredSpoke(spoke) {
    _setCanUpdateUserDynamicConfigPermission({
      spoke: spoke,
      delegator: msg.sender,
      delegatee: delegatee,
      status: status
    });
  }

  /// @inheritdoc IConfigPositionManager
  function setGlobalPermissionWithSig(
    SetGlobalPermissionPermit calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.delegator,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });
    _setGlobalPermission({
      spoke: params.spoke,
      delegator: params.delegator,
      delegatee: params.delegatee,
      status: params.status
    });
  }

  /// @inheritdoc IConfigPositionManager
  function setCanSetUsingAsCollateralPermissionWithSig(
    SetCanSetUsingAsCollateralPermissionPermit calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.delegator,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });
    _setCanSetUsingAsCollateralPermission({
      spoke: params.spoke,
      delegator: params.delegator,
      delegatee: params.delegatee,
      status: params.status
    });
  }

  /// @inheritdoc IConfigPositionManager
  function setCanUpdateUserRiskPremiumPermissionWithSig(
    SetCanUpdateUserRiskPremiumPermissionPermit calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.delegator,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });
    _setCanUpdateUserRiskPremiumPermission({
      spoke: params.spoke,
      delegator: params.delegator,
      delegatee: params.delegatee,
      status: params.status
    });
  }

  /// @inheritdoc IConfigPositionManager
  function setCanUpdateUserDynamicConfigPermissionWithSig(
    SetCanUpdateUserDynamicConfigPermissionPermit calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.delegator,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });
    _setCanUpdateUserDynamicConfigPermission({
      spoke: params.spoke,
      delegator: params.delegator,
      delegatee: params.delegatee,
      status: params.status
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
    ConfigPermissions newPermissions = ConfigPermissionsMap.setGlobalPermissions(false);
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

    emit SetUsingAsCollateralOnBehalfOf(
      spoke,
      msg.sender,
      onBehalfOf,
      reserveId,
      usingAsCollateral
    );
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

    emit UpdateUserRiskPremiumOnBehalfOf(spoke, msg.sender, onBehalfOf);
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

    emit UpdateUserDynamicConfigOnBehalfOf(spoke, msg.sender, onBehalfOf);
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

  /// @dev Sets the global permission for a delegatee on behalf of a delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  /// @param delegatee The address of the delegatee.
  /// @param status The new permission status.
  function _setGlobalPermission(
    address spoke,
    address delegator,
    address delegatee,
    bool status
  ) internal {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: delegatee
    });
    ConfigPermissions newPermissions = ConfigPermissionsMap.setGlobalPermissions(status);
    _updatePermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: delegatee,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @dev Sets the using as collateral permission for a delegatee on behalf of a delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  /// @param delegatee The address of the delegatee.
  /// @param status The new permission status.
  function _setCanSetUsingAsCollateralPermission(
    address spoke,
    address delegator,
    address delegatee,
    bool status
  ) internal {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: delegatee
    });
    ConfigPermissions newPermissions = oldPermissions.setCanSetUsingAsCollateral(status);
    _updatePermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: delegatee,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @dev Sets the user risk premium permission for a delegatee on behalf of a delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  /// @param delegatee The address of the delegatee.
  /// @param status The new permission status.
  function _setCanUpdateUserRiskPremiumPermission(
    address spoke,
    address delegator,
    address delegatee,
    bool status
  ) internal {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: delegatee
    });
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserRiskPremium(status);
    _updatePermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: delegatee,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @dev Sets the user dynamic config permission for a delegatee on behalf of a delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  /// @param delegatee The address of the delegatee.
  /// @param status The new permission status.
  function _setCanUpdateUserDynamicConfigPermission(
    address spoke,
    address delegator,
    address delegatee,
    bool status
  ) internal {
    ConfigPermissions oldPermissions = _getPermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: delegatee
    });
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserDynamicConfig(status);
    _updatePermissions({
      spoke: spoke,
      delegator: delegator,
      delegatee: delegatee,
      oldPermissions: oldPermissions,
      newPermissions: newPermissions
    });
  }

  /// @dev Does not update if the new permissions are equal to the old permissions.
  function _updatePermissions(
    address spoke,
    address delegator,
    address delegatee,
    ConfigPermissions oldPermissions,
    ConfigPermissions newPermissions
  ) internal {
    require(delegatee != address(0), InvalidAddress());
    if (oldPermissions.eq(newPermissions)) {
      return;
    }
    _config[spoke][delegator][delegatee] = newPermissions;
    emit UpdateConfigPermissions(spoke, delegator, delegatee, oldPermissions, newPermissions);
  }

  /// @dev Returns the config permissions for a delegatee on behalf of a delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  /// @param delegatee The address of the delegatee.
  /// @return The ConfigPermissions for the delegatee on behalf of the delegator.
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
