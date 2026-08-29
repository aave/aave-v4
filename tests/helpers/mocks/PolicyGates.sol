// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

interface IAllowlist {
  function isAllowed(address account) external view returns (bool);
}

/// @dev Gate replicating the default authorization.
contract PositionManagerPolicyGate is ISpokeGate {
  function isCallAllowed(
    address,
    address,
    bytes calldata
  ) external pure returns (CallPolicy) {
    return CallPolicy.USE_DEFAULT;
  }
}

/// @dev Gate allowing a fixed global manager to act on behalf of any user (e.g. an RWA manager).
contract GlobalManagerPolicyGate is ISpokeGate {
  address public immutable GLOBAL_MANAGER;

  constructor(address globalManager) {
    GLOBAL_MANAGER = globalManager;
  }

  function isCallAllowed(
    address caller,
    address,
    bytes calldata
  ) external view returns (CallPolicy) {
    if (caller == GLOBAL_MANAGER) return CallPolicy.ALLOW;
    return CallPolicy.USE_DEFAULT;
  }
}

/// @dev Gate restricting borrowing to allowlisted position owners.
contract BorrowAllowlistPolicyGate is ISpokeGate {
  IAllowlist public immutable ALLOWLIST;

  constructor(IAllowlist allowlist) {
    ALLOWLIST = allowlist;
  }

  function isCallAllowed(
    address,
    address onBehalfOf,
    bytes calldata data
  ) external view returns (CallPolicy) {
    if (bytes4(data) == ISpoke.borrow.selector && !ALLOWLIST.isAllowed(onBehalfOf)) {
      return CallPolicy.DENY;
    }
    return CallPolicy.USE_DEFAULT;
  }
}

contract MockAllowlist is IAllowlist {
  mapping(address account => bool) public isAllowed;

  function setAllowed(address account, bool value) external {
    isAllowed[account] = value;
  }
}
