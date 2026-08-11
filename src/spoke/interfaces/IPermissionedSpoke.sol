// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IPermissionedSpoke
/// @author Aave Labs
/// @notice Interface for the permissioned functionality of a Spoke.
interface IPermissionedSpoke {
  /// @notice Emitted when the mandatory position manager is updated.
  /// @param mandatoryPositionManager The address of the mandatory position manager, or the zero address if removed.
  event UpdateMandatoryPositionManager(address indexed mandatoryPositionManager);

  /// @notice Updates the mandatory position manager.
  /// @dev When set, it replaces the default position manager authorization on position actions.
  /// @dev Setting the zero address removes it, restoring the default authorization.
  /// @param mandatoryPositionManager The address of the mandatory position manager.
  function updateMandatoryPositionManager(address mandatoryPositionManager) external;

  /// @notice Returns the address of the mandatory position manager, or the zero address if unset.
  function getMandatoryPositionManager() external view returns (address);
}
