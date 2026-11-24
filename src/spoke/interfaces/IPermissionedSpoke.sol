// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title IPermissionedSpoke
/// @author Aave Labs
/// @notice Full interface for the PermissionedSpoke.
interface IPermissionedSpoke is ISpoke {
  /// @notice Emitted when the immutable variables specific to the PermissionedSpoke are set.
  /// @param policyGate The policy gate of the Spoke.
  event SetPermissionedSpokeImmutables(address indexed policyGate);

  /// @notice Returns the policy gate of the Spoke.
  function POLICY_GATE() external view returns (address);
}
