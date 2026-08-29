// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Spoke} from 'src/spoke/Spoke.sol';
import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';

/// @title PermissionedSpoke
/// @author Aave Labs
/// @notice Spoke where a gate can override the default authorization on position actions,
/// liquidations and user risk premium updates.
abstract contract PermissionedSpoke is Spoke {
  /// @notice The gate deciding whether position actions and liquidations are allowed.
  address public immutable GATE;

  /// @dev Constructor.
  /// @param gate_ The address of the gate.
  constructor(address gate_) {
    require(gate_ != address(0), InvalidAddress());
    GATE = gate_;
  }

  /// @dev The gate can allow, deny or delegate the decision to the default Spoke authorization.
  function _isAllowed(
    address caller,
    address user,
    bytes calldata data
  ) internal view virtual override returns (bool) {
    ISpokeGate.CallPolicy policy = ISpokeGate(GATE).isCallAllowed({
      caller: caller,
      onBehalfOf: user,
      data: data
    });
    if (policy == ISpokeGate.CallPolicy.USE_DEFAULT) {
      return Spoke._isAllowed(caller, user, data);
    }
    return policy == ISpokeGate.CallPolicy.ALLOW;
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
