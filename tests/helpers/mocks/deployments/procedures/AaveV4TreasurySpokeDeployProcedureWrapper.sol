// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4TreasurySpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TreasurySpokeDeployProcedure.sol';

contract AaveV4TreasurySpokeDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deployTreasurySpoke(address owner, bytes32 salt) external returns (address) {
    return AaveV4TreasurySpokeDeployProcedure.deployTreasurySpoke(owner, salt);
  }
}
