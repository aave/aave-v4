// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Spoke} from 'src/spoke/Spoke.sol';
import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';

/// @title PermissionedSpoke
/// @author Aave Labs
/// @notice Spoke where a gate replaces the default authorization on position actions, liquidations
/// and user risk premium updates.
abstract contract PermissionedSpoke is Spoke {
  /// @notice The gate deciding whether position actions and liquidations are allowed.
  address public immutable GATE;

  /// @dev Constructor.
  /// @param gate_ The address of the gate.
  constructor(address gate_) {
    require(gate_ != address(0), InvalidAddress());
    GATE = gate_;
  }

  /// @dev The gate fully decides whether the call is allowed, based on the caller, the position
  /// owner and the calldata. It can preserve the default authorization by calling back
  /// `isPositionManager` and allowing `liquidationCall`.
  function _isAllowed(
    address caller,
    address user,
    bytes calldata data
  ) internal view virtual override returns (bool) {
    return ISpokeGate(GATE).isCallAllowed({caller: caller, onBehalfOf: user, data: data});
  }

  function _domainNameAndVersion()
    internal
    pure
    virtual
    override
    returns (string memory, string memory)
  {
    return ('PermissionedSpoke', '1');
  }
}
