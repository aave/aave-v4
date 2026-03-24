// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {IHubInstance} from 'src/deployments/utils/interfaces/IHubInstance.sol';

contract AaveV4HubDeployProcedure is AaveV4DeployProcedureBase {
  function _deployUpgradeableHubInstance(
    address hubProxyAdminOwner,
    address authority,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (address hubProxy, address hubImplementation) {
    require(hubProxyAdminOwner != address(0), 'invalid hub proxy admin owner');
    require(authority != address(0), 'invalid authority');
    hubImplementation = Create2Utils.create2Deploy({salt: salt, bytecode: hubBytecode});
    hubProxy = Create2Utils.proxify({
      salt: salt,
      logic: hubImplementation,
      initialOwner: hubProxyAdminOwner,
      data: abi.encodeCall(IHubInstance.initialize, (authority))
    });
    return (hubProxy, hubImplementation);
  }
}
