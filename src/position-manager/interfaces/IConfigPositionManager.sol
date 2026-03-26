// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IPositionManagerIntentBase} from 'src/position-manager/interfaces/IPositionManagerIntentBase.sol';

type ConfigPermissions is uint8;

/// @title IConfigPositionManager
/// @author Aave Labs
/// @notice Interface for position manager handling user configuration actions on behalf of an user.
interface IConfigPositionManager is IPositionManagerIntentBase {
  /// @notice Struct to hold the config permission values.
  /// @dev canSetUsingAsCollateral Whether the delegatee can set using as collateral on behalf of the user.
  /// @dev canUpdateUserRiskPremium Whether the delegatee can update user risk premium on behalf of the user.
  /// @dev canUpdateUserDynamicConfig Whether the delegatee can update user dynamic config on behalf of the user.
  struct ConfigPermissionValues {
    bool canSetUsingAsCollateral;
    bool canUpdateUserRiskPremium;
    bool canUpdateUserDynamicConfig;
  }

  /// @notice Structured parameters for global permission permit intent.
  /// @dev spoke The address of the Spoke.
  /// @dev delegator The address of the delegator.
  /// @dev delegatee The address of the delegatee.
  /// @dev status The new status of the permission.
  /// @dev nonce The key-prefixed nonce for the signature.
  /// @dev deadline The deadline for the intent.
  struct SetGlobalPermissionPermit {
    address spoke;
    address delegator;
    address delegatee;
    bool status;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Structured parameters for using as collateral permission permit intent.
  /// @dev spoke The address of the Spoke.
  /// @dev delegator The address of the delegator.
  /// @dev delegatee The address of the delegatee.
  /// @dev status The new status of the permission.
  /// @dev nonce The key-prefixed nonce for the signature.
  /// @dev deadline The deadline for the intent.
  struct SetCanSetUsingAsCollateralPermissionPermit {
    address spoke;
    address delegator;
    address delegatee;
    bool status;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Structured parameters for user risk premium permission permit intent.
  /// @dev spoke The address of the Spoke.
  /// @dev delegator The address of the delegator.
  /// @dev delegatee The address of the delegatee.
  /// @dev status The new status of the permission.
  /// @dev nonce The key-prefixed nonce for the signature.
  /// @dev deadline The deadline for the intent.
  struct SetCanUpdateUserRiskPremiumPermissionPermit {
    address spoke;
    address delegator;
    address delegatee;
    bool status;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Structured parameters for user dynamic config permission permit intent.
  /// @dev spoke The address of the Spoke.
  /// @dev delegator The address of the delegator.
  /// @dev delegatee The address of the delegatee.
  /// @dev status The new status of the permission.
  /// @dev nonce The key-prefixed nonce for the signature.
  /// @dev deadline The deadline for the intent.
  struct SetCanUpdateUserDynamicConfigPermissionPermit {
    address spoke;
    address delegator;
    address delegatee;
    bool status;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice Emitted when a global config permission is updated.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  /// @param delegatee The address of the delegatee.
  /// @param oldPermissions The old config permissions.
  /// @param newPermissions The new config permissions.
  event UpdateConfigPermissions(
    address indexed spoke,
    address indexed delegator,
    address indexed delegatee,
    ConfigPermissions oldPermissions,
    ConfigPermissions newPermissions
  );

  /// @notice Emitted when setting using as collateral on behalf of a user.
  /// @param spoke The address of the Spoke.
  /// @param caller The transaction initiator.
  /// @param onBehalfOf The owner of the position being modified.
  /// @param reserveId The identifier of the reserve.
  /// @param usingAsCollateral Whether the reserve is enabled or disabled as collateral.
  event SetUsingAsCollateralOnBehalfOf(
    address indexed spoke,
    address indexed caller,
    address indexed onBehalfOf,
    uint256 reserveId,
    bool usingAsCollateral
  );

  /// @notice Emitted when updating user risk premium on behalf of a user.
  /// @param spoke The address of the Spoke.
  /// @param caller The transaction initiator.
  /// @param onBehalfOf The owner of the position being modified.
  event UpdateUserRiskPremiumOnBehalfOf(
    address indexed spoke,
    address indexed caller,
    address indexed onBehalfOf
  );

  /// @notice Emitted when updating dynamic config on behalf of a user.
  /// @param spoke The address of the Spoke.
  /// @param caller The transaction initiator.
  /// @param onBehalfOf The owner of the position being modified.
  event UpdateUserDynamicConfigOnBehalfOf(
    address indexed spoke,
    address indexed caller,
    address indexed onBehalfOf
  );

  /// @notice Thrown when the delegatee of a function was not given permission by the user.
  error DelegateeNotAllowed();

  /// @notice Sets the global permission for a delegatee.
  /// @param spoke The address of the Spoke.
  /// @param delegatee The address of the delegatee.
  /// @param status The new permission status.
  function setGlobalPermission(address spoke, address delegatee, bool status) external;

  /// @notice Sets the using as collateral permission for a delegatee.
  /// @param spoke The address of the Spoke.
  /// @param delegatee The address of the delegatee.
  /// @param status The new permission status.
  function setCanSetUsingAsCollateralPermission(
    address spoke,
    address delegatee,
    bool status
  ) external;

  /// @notice Sets the user risk premium permission for a delegatee.
  /// @param spoke The address of the Spoke.
  /// @param delegatee The address of the delegatee.
  /// @param status The new permission status.
  function setCanUpdateUserRiskPremiumPermission(
    address spoke,
    address delegatee,
    bool status
  ) external;

  /// @notice Sets the user dynamic config permission for a delegatee.
  /// @param spoke The address of the Spoke.
  /// @param delegatee The address of the delegatee.
  /// @param status The new permission status.
  function setCanUpdateUserDynamicConfigPermission(
    address spoke,
    address delegatee,
    bool status
  ) external;

  /// @notice Sets the global permission for a delegatee using an EIP712-typed intent.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured SetGlobalPermissionPermit parameters.
  /// @param signature The EIP712-compliant signature bytes.
  function setGlobalPermissionWithSig(
    SetGlobalPermissionPermit calldata params,
    bytes calldata signature
  ) external;

  /// @notice Sets the using as collateral permission for a delegatee using an EIP712-typed intent.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured SetCanSetUsingAsCollateralPermissionPermit parameters.
  /// @param signature The EIP712-compliant signature bytes.
  function setCanSetUsingAsCollateralPermissionWithSig(
    SetCanSetUsingAsCollateralPermissionPermit calldata params,
    bytes calldata signature
  ) external;

  /// @notice Sets the user risk premium permission for a delegatee using an EIP712-typed intent.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured SetCanUpdateUserRiskPremiumPermissionPermit parameters.
  /// @param signature The EIP712-compliant signature bytes.
  function setCanUpdateUserRiskPremiumPermissionWithSig(
    SetCanUpdateUserRiskPremiumPermissionPermit calldata params,
    bytes calldata signature
  ) external;

  /// @notice Sets the user dynamic config permission for a delegatee using an EIP712-typed intent.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured SetCanUpdateUserDynamicConfigPermissionPermit parameters.
  /// @param signature The EIP712-compliant signature bytes.
  function setCanUpdateUserDynamicConfigPermissionWithSig(
    SetCanUpdateUserDynamicConfigPermissionPermit calldata params,
    bytes calldata signature
  ) external;

  /// @notice Renounces the global permission given by the delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  function renounceGlobalPermission(address spoke, address delegator) external;

  /// @notice Renounces the using as collateral permission given by the delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  function renounceCanUpdateUsingAsCollateralPermission(address spoke, address delegator) external;

  /// @notice Renounces the user risk premium permission given by the delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  function renounceCanUpdateUserRiskPremiumPermission(address spoke, address delegator) external;

  /// @notice Renounces the user dynamic config permission given by the delegator.
  /// @param spoke The address of the Spoke.
  /// @param delegator The address of the delegator.
  function renounceCanUpdateUserDynamicConfigPermission(address spoke, address delegator) external;

  /// @notice Sets the using as collateral status on behalf of a user for a specified reserve.
  /// @dev The `msg.sender` must be the delegatee to perform this action on behalf of the user.
  /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The id of the reserve.
  /// @param usingAsCollateral The new using as collateral status.
  /// @param onBehalfOf The address of the user.
  function setUsingAsCollateralOnBehalfOf(
    address spoke,
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external;

  /// @notice Updates the user risk premium on behalf of a user.
  /// @dev The `msg.sender` must be the delegatee to perform this action on behalf of the user.
  /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
  /// @param spoke The address of the Spoke.
  /// @param onBehalfOf The address of the user.
  function updateUserRiskPremiumOnBehalfOf(address spoke, address onBehalfOf) external;

  /// @notice Updates the user dynamic config on behalf of a user.
  /// @dev The `msg.sender` must be the delegatee to perform this action on behalf of the user.
  /// @dev Contract must be an active and approved user position manager of `onBehalfOf`.
  /// @param spoke The address of the Spoke.
  /// @param onBehalfOf The address of the user.
  function updateUserDynamicConfigOnBehalfOf(address spoke, address onBehalfOf) external;

  /// @notice Returns the config permissions for a delegatee on behalf of a user.
  /// @param spoke The address of the Spoke.
  /// @param delegatee The address of the delegatee.
  /// @param onBehalfOf The address of the user.
  /// @return The ConfigPermissionValues for the delegatee on behalf of the user.
  function getConfigPermissions(
    address spoke,
    address delegatee,
    address onBehalfOf
  ) external view returns (ConfigPermissionValues memory);

  /// @notice Returns the type hash for the SetGlobalPermissionPermit intent.
  function SET_GLOBAL_PERMISSION_PERMIT_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the SetCanSetUsingAsCollateralPermissionPermit intent.
  function SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH()
    external
    view
    returns (bytes32);

  /// @notice Returns the type hash for the SetCanUpdateUserRiskPremiumPermissionPermit intent.
  function SET_CAN_UPDATE_USER_RISK_PREMIUM_PERMISSION_PERMIT_TYPEHASH()
    external
    view
    returns (bytes32);

  /// @notice Returns the type hash for the SetCanUpdateUserDynamicConfigPermissionPermit intent.
  function SET_CAN_UPDATE_USER_DYNAMIC_CONFIG_PERMISSION_PERMIT_TYPEHASH()
    external
    view
    returns (bytes32);
}
