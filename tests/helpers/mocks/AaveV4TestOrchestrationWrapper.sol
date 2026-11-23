// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4TestOrchestration} from 'tests/deployments/orchestration/AaveV4TestOrchestration.sol';

contract AaveV4TestOrchestrationWrapper {
  function deployHub(address authority, address proxyAdminOwner) external returns (address) {
    return address(AaveV4TestOrchestration.deployHub(authority, proxyAdminOwner));
  }
}
