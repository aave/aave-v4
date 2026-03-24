// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {HubConfigurator} from 'src/hub/HubConfigurator.sol';

contract AaveV4HubConfiguratorDeployProcedure is AaveV4DeployProcedureBase {
  function _deployHubConfigurator(address authority, bytes32 salt) internal returns (address) {
    require(authority != address(0), 'invalid authority');
    return
      Create2Utils.create2Deploy(
        salt,
        abi.encodePacked(type(HubConfigurator).creationCode, abi.encode(authority))
      );
  }
}
