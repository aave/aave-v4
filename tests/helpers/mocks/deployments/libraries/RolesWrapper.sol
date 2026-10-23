// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

contract RolesWrapper {
  function getHubRoleSelectors(uint64 roleId) external pure returns (bytes4[] memory) {
    return Roles.getHubRoleSelectors(roleId);
  }

  function getSpokeRoleSelectors(uint64 roleId) external pure returns (bytes4[] memory) {
    return Roles.getSpokeRoleSelectors(roleId);
  }
}
