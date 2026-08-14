// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SpokeInstanceBase} from 'src/spoke/instances/SpokeInstanceBase.sol';
import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';

/// @title PermissionedSpokeInstance
/// @author Aave Labs
/// @notice Spoke implementation where a gate replaces the default position manager authorization
/// on position actions.
contract PermissionedSpokeInstance is SpokeInstanceBase {
  /// @notice The gate deciding whether position actions are allowed.
  address public immutable GATE;

  /// @dev Constructor.
  /// @param oracle_ The address of the oracle.
  /// @param maxUserReservesLimit_ The maximum number of collateral and borrow reserves a user can have.
  /// @param gate_ The address of the gate.
  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_,
    address gate_
  ) SpokeInstanceBase(oracle_, maxUserReservesLimit_) {
    require(gate_ != address(0), InvalidAddress());
    GATE = gate_;
  }

  /// @dev The gate fully decides whether the call is allowed, based on the caller, the position
  /// owner and the calldata. It can preserve the default authorization by calling back
  /// `isPositionManager`.
  function _isAuthorizedPositionManagerCall(
    address caller,
    address user,
    bytes calldata data
  ) internal view override returns (bool) {
    return ISpokeGate(GATE).isCallAllowed({caller: caller, onBehalfOf: user, data: data});
  }
}
