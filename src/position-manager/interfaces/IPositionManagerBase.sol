// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {IRescuable} from 'src/interfaces/IRescuable.sol';

/// @title IPositionManagerBase
/// @author Aave Labs
/// @notice Base interface for position managers.
/// @dev This base interface is not mandatory for position managers, it only provides optional convenience methods.
interface IPositionManagerBase is IRescuable, IMulticall {
  /// @notice Emitted when the Spoke's registration status is updated.
  event RegisterSpoke(address indexed spoke, bool registered);

  /// @notice Thrown when the specified address is invalid.
  error InvalidAddress();

  /// @notice Thrown when the specified amount is invalid.
  error InvalidAmount();

  /// @notice Thrown when trying to call an unsupported action on this position manager.
  error UnsupportedAction();

  /// @notice Thrown when the specified Spoke is not registered.
  error SpokeNotRegistered();

  /// @notice Facilitates setting this position manager as user position manager on the specified registered Spoke
  /// with a typed signature from `onBehalfOf`.
  /// @dev The signature is consumed on the specified registered Spoke.
  /// @dev The given data is passed to the Spoke for the signature to be verified.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param spoke The address of the registered spoke.
  /// @param onBehalfOf The address of the user on whose behalf this position manager can act.
  /// @param approve True to approve the position manager, false to revoke approval.
  /// @param nonce The key-prefixed nonce for the signature.
  /// @param deadline The deadline for the intent.
  /// @param signature The EIP712-typed signed bytes for the intent.
  function setSelfAsUserPositionManagerWithSig(
    address spoke,
    address onBehalfOf,
    bool approve,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external;

  /// @notice Facilitates consuming a permit for the given reserve's underlying asset on the specified registered Spoke.
  /// @dev The given data is passed to the underlying asset for the signature to be verified.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @dev Spender is this position manager contract.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param onBehalfOf The address of the user on whose behalf the permit is being used.
  /// @param value The amount of the underlying asset to permit.
  /// @param deadline The deadline for the permit.
  function permitReserveUnderlying(
    address spoke,
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external;

  /// @notice Allows contract to renounce its position manager role for the specified user.
  /// @param spoke The address of the registered Spoke.
  /// @param user The address of the user to renounce the position manager role for.
  function renouncePositionManagerRole(address spoke, address user) external;

  /// @notice Registers or deregisters the Spoke.
  /// @param spoke The address of the Spoke.
  /// @param registered `true` to register, `false` to deregister.
  function registerSpoke(address spoke, bool registered) external;

  /// @notice Returns whether the specified Spoke is registered.
  /// @param spoke The address of the Spoke.
  /// @return `true` if the Spoke is registered, `false` otherwise.
  function isSpokeRegistered(address spoke) external view returns (bool);
}
