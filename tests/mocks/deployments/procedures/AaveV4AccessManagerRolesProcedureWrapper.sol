// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';

contract AaveV4AccessManagerRolesProcedureWrapper {
  bool public IS_TEST = true;

  function replaceDefaultAdminRole(
    address accessManager,
    address adminToAdd,
    address adminToRemove
  ) external {
    AaveV4AccessManagerRolesProcedure.replaceDefaultAdminRole(
      accessManager,
      adminToAdd,
      adminToRemove
    );
  }

  function grantAccessManagerAdminRole(address accessManager, address admin) external {
    AaveV4AccessManagerRolesProcedure.grantAccessManagerAdminRole(accessManager, admin);
  }

  function labelAllRoles(address accessManager) external {
    AaveV4AccessManagerRolesProcedure.labelAllRoles(accessManager);
  }
}
