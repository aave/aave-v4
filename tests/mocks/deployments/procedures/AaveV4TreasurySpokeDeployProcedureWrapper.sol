// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4TreasurySpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TreasurySpokeDeployProcedure.sol';

contract AaveV4TreasurySpokeDeployProcedureWrapper is AaveV4TreasurySpokeDeployProcedure {
  bool public IS_TEST = true;

  function deployTreasurySpoke(address owner, bytes32 salt) external returns (address) {
    return _deployTreasurySpoke(owner, salt);
  }
}
