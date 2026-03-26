// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4TestOrchestration} from 'tests/deployments/orchestration/AaveV4TestOrchestration.sol';

contract AaveV4TestOrchestrationWrapper {
  function deploySpokeImplementation(
    address oracle,
    uint16 maxUserReservesLimit
  ) external returns (address) {
    return address(AaveV4TestOrchestration.deploySpokeImplementation(oracle, maxUserReservesLimit));
  }

  function deployHub(address authority, address proxyAdminOwner) external returns (address) {
    return address(AaveV4TestOrchestration.deployHub(authority, proxyAdminOwner));
  }
}
