// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4SpokeConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeConfiguratorDeployProcedure.sol';

contract AaveV4SpokeConfiguratorDeployProcedureWrapper is AaveV4SpokeConfiguratorDeployProcedure {
  bool public IS_TEST = true;

  function deployUpgradeableSpokeConfigurator(
    address proxyAdminOwner,
    address authority,
    bytes32 salt
  ) external returns (address, address) {
    return _deployUpgradeableSpokeConfigurator(proxyAdminOwner, authority, salt);
  }
}
