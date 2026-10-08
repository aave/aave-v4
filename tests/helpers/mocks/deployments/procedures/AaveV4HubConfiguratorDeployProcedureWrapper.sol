// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4HubConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubConfiguratorDeployProcedure.sol';

contract AaveV4HubConfiguratorDeployProcedureWrapper is AaveV4HubConfiguratorDeployProcedure {
  bool public IS_TEST = true;

  function deployUpgradeableHubConfigurator(
    address proxyAdminOwner,
    address authority,
    bytes32 salt
  ) external returns (address, address) {
    return _deployUpgradeableHubConfigurator(proxyAdminOwner, authority, salt);
  }
}
