// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISpokeGate} from 'src/spoke/interfaces/ISpokeGate.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

interface IAllowlist {
  function isAllowed(address account) external view returns (bool);
}

/// @dev Gate replicating the default position-manager authorization.
contract PositionManagerPolicyGate is ISpokeGate {
  ISpoke public immutable SPOKE;

  constructor(ISpoke spoke) {
    SPOKE = spoke;
  }

  function isCallAllowed(
    address caller,
    address onBehalfOf,
    bytes calldata
  ) external view returns (bool) {
    return SPOKE.isPositionManager(onBehalfOf, caller);
  }
}

/// @dev Gate allowing a fixed global manager to act on behalf of any user (e.g. an RWA manager).
contract GlobalManagerPolicyGate is ISpokeGate {
  ISpoke public immutable SPOKE;
  address public immutable GLOBAL_MANAGER;

  constructor(ISpoke spoke, address globalManager) {
    SPOKE = spoke;
    GLOBAL_MANAGER = globalManager;
  }

  function isCallAllowed(
    address caller,
    address onBehalfOf,
    bytes calldata
  ) external view returns (bool) {
    if (caller == GLOBAL_MANAGER) return true;
    return SPOKE.isPositionManager(onBehalfOf, caller);
  }
}

/// @dev Gate restricting borrowing to allowlisted position owners.
contract BorrowAllowlistPolicyGate is ISpokeGate {
  ISpoke public immutable SPOKE;
  IAllowlist public immutable ALLOWLIST;

  constructor(ISpoke spoke, IAllowlist allowlist) {
    SPOKE = spoke;
    ALLOWLIST = allowlist;
  }

  function isCallAllowed(
    address caller,
    address onBehalfOf,
    bytes calldata data
  ) external view returns (bool) {
    if (bytes4(data) == ISpoke.borrow.selector && !ALLOWLIST.isAllowed(onBehalfOf)) return false;
    return SPOKE.isPositionManager(onBehalfOf, caller);
  }
}

contract MockAllowlist is IAllowlist {
  mapping(address account => bool) public isAllowed;

  function setAllowed(address account, bool value) external {
    isAllowed[account] = value;
  }
}
