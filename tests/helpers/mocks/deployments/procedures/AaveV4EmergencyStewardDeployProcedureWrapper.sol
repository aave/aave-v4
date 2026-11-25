// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4EmergencyStewardDeployProcedure} from 'src/deployments/procedures/deploy/emergency/AaveV4EmergencyStewardDeployProcedure.sol';

contract AaveV4EmergencyStewardDeployProcedureWrapper is AaveV4EmergencyStewardDeployProcedure {
  bool public IS_TEST = true;

  function deployEmergencySteward(
    address authority,
    address spokeConfigurator,
    bytes32 salt
  ) external returns (address) {
    return _deployEmergencySteward(authority, spokeConfigurator, salt);
  }
}
