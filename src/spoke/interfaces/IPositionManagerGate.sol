// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {IIntentConsumer} from 'src/interfaces/IIntentConsumer.sol';
import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';

/// @title IPositionManagerGate
/// @author Aave Labs
/// @notice Gate implementing opt-in position-manager delegation for one or more Spokes.
interface IPositionManagerGate is ISpokeGate, IAccessManaged, IIntentConsumer {
  /// @notice Intent data to update a user's position-manager approvals for a Spoke.
  struct SetUserPositionManagers {
    address spoke;
    address onBehalfOf;
    PositionManagerUpdate[] updates;
    uint256 nonce;
    uint256 deadline;
  }

  /// @notice A position-manager approval update.
  struct PositionManagerUpdate {
    address positionManager;
    bool approve;
  }

  /// @notice Emitted when governance updates a position manager's active status for a Spoke.
  event UpdatePositionManager(address indexed spoke, address indexed positionManager, bool active);

  /// @notice Emitted when a user updates a position manager's approval for a Spoke.
  event SetUserPositionManager(
    address indexed spoke,
    address indexed user,
    address indexed positionManager,
    bool approve
  );

  error InvalidAddress();

  /// @notice Updates a position manager's active status for a Spoke.
  function updatePositionManager(address spoke, address positionManager, bool active) external;

  /// @notice Grants or revokes a position manager's approval for the caller on a Spoke.
  function setUserPositionManager(address spoke, address positionManager, bool approve) external;

  /// @notice Applies position-manager approval updates authorized by an EIP-712 signature.
  function setUserPositionManagersWithSig(
    SetUserPositionManagers calldata params,
    bytes calldata signature
  ) external;

  /// @notice Lets a position manager renounce a user's approval on a Spoke.
  function renouncePositionManagerRole(address spoke, address user) external;

  /// @notice Returns whether a position manager is active for a Spoke.
  function isPositionManagerActive(
    address spoke,
    address positionManager
  ) external view returns (bool);

  /// @notice Returns whether a position manager is active and approved by a user for a Spoke.
  function isPositionManager(
    address spoke,
    address user,
    address positionManager
  ) external view returns (bool);

  /// @notice Returns the type hash for the SetUserPositionManagers intent.
  function SET_USER_POSITION_MANAGERS_TYPEHASH() external view returns (bytes32);
}
