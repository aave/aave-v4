// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4EmergencyStewardRolesProcedure} from 'src/deployments/procedures/roles/AaveV4EmergencyStewardRolesProcedure.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

contract AaveV4EmergencyStewardRolesProcedureWrapper {
  bool public IS_TEST = true;

  function grantEmergencyStewardAllRoles(address accessManager, address admin) external {
    AaveV4EmergencyStewardRolesProcedure.grantEmergencyStewardAllRoles(accessManager, admin);
  }

  function grantEmergencyStewardRole(address accessManager, uint64 role, address admin) external {
    AaveV4EmergencyStewardRolesProcedure.grantEmergencyStewardRole(accessManager, role, admin);
  }

  function setupEmergencyStewardRoles(address accessManager, address emergencySteward) external {
    AaveV4EmergencyStewardRolesProcedure.setupEmergencyStewardAllRoles(
      accessManager,
      emergencySteward
    );
  }

  function setupEmergencyStewardRole(
    address accessManager,
    address emergencySteward,
    uint64 role,
    bytes4[] memory selectors
  ) external {
    AaveV4EmergencyStewardRolesProcedure.setupEmergencyStewardRole(
      accessManager,
      emergencySteward,
      role,
      selectors
    );
  }

  function getEmergencyStewardDomainAdminRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getEmergencyStewardDomainAdminRoleSelectors();
  }
}
