// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Spoke} from 'src/spoke/Spoke.sol';
import {PermissionedSpoke} from 'src/spoke/PermissionedSpoke.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';

/// @title PermissionedSpokeInstance
/// @author Aave Labs
/// @notice Implementation contract for the PermissionedSpoke.
contract PermissionedSpokeInstance is SpokeInstance, PermissionedSpoke {
  /// @dev Applies the gate authorization of the PermissionedSpoke.
  modifier onlyPositionManager(address onBehalfOf) override(Spoke, PermissionedSpoke) {
    _checkCallAllowed(msg.sender, onBehalfOf, msg.data);
    _;
  }

  /// @dev Constructor.
  /// @param oracle_ The address of the oracle.
  /// @param maxUserReservesLimit_ The maximum number of collateral and borrow reserves a user can have.
  /// @param gate_ The address of the gate.
  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_,
    address gate_
  ) SpokeInstance(oracle_, maxUserReservesLimit_) PermissionedSpoke(gate_) {}
}
