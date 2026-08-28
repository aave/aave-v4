// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Spoke} from 'src/spoke/Spoke.sol';
import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';

/// @title PermissionedSpoke
/// @author Aave Labs
/// @notice Spoke where a gate replaces the default position manager authorization on position
/// actions.
abstract contract PermissionedSpoke is Spoke {
  /// @notice The gate deciding whether position actions are allowed.
  address public immutable GATE;

  /// @dev The gate fully decides whether the call is allowed, based on the caller, the position
  /// owner and the calldata. It can preserve the default authorization by calling back
  /// `isPositionManager`.
  modifier onlyPositionManager(address onBehalfOf) virtual override {
    _checkCallAllowed(msg.sender, onBehalfOf, msg.data);
    _;
  }

  /// @dev Constructor.
  /// @param gate_ The address of the gate.
  constructor(address gate_) {
    require(gate_ != address(0), InvalidAddress());
    GATE = gate_;
  }

  /// @dev Reverts if the gate disallows `caller` performing the call `data` on the position of `onBehalfOf`.
  function _checkCallAllowed(
    address caller,
    address onBehalfOf,
    bytes calldata data
  ) internal view {
    require(
      ISpokeGate(GATE).isCallAllowed({caller: caller, onBehalfOf: onBehalfOf, data: data}),
      Unauthorized()
    );
  }
}
