// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TreasurySpokeInstance} from 'src/spoke/instances/TreasurySpokeInstance.sol';

contract AaveV4TreasurySpokeDeployProcedure is AaveV4DeployProcedureBase {
  function _deployTreasurySpoke(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    address implementation = Create2Utils.create2Deploy(
      salt,
      type(TreasurySpokeInstance).creationCode
    );
    return
      Create2Utils.proxify(
        salt,
        implementation,
        owner,
        abi.encodeCall(TreasurySpokeInstance.initialize, (owner))
      );
  }
}
