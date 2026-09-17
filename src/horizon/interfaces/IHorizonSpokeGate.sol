// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';

/// @title IHorizonSpokeGate
/// @author Aave Labs
/// @notice Interface for the Horizon gate, where reserve managers can act on the position of any
/// user for a given reserve.
interface IHorizonSpokeGate is ISpokeGate {
  /// @notice Emitted when a manager is authorized or revoked for a reserve.
  /// @param reserveId The identifier of the reserve.
  /// @param manager The address of the manager.
  /// @param active True if the manager is authorized for the reserve.
  event UpdateReserveManager(uint256 indexed reserveId, address indexed manager, bool active);

  /// @notice Authorizes or revokes a manager for the given reserve.
  /// @param reserveId The identifier of the reserve.
  /// @param manager The address of the manager.
  /// @param active True to authorize the manager for the reserve.
  function updateReserveManager(uint256 reserveId, address manager, bool active) external;

  /// @notice Returns whether `manager` can act on the position of any user for the given reserve.
  /// @param reserveId The identifier of the reserve.
  /// @param manager The address of the manager.
  /// @return True if the manager is authorized for the reserve.
  function isReserveManager(uint256 reserveId, address manager) external view returns (bool);
}
