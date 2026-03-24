// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {GiverPositionManager} from 'src/position-manager/GiverPositionManager.sol';

contract AaveV4GiverPositionManagerDeployProcedure is AaveV4DeployProcedureBase {
  function _deployGiverPositionManager(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2Deploy({
        salt: salt,
        bytecode: abi.encodePacked(type(GiverPositionManager).creationCode, abi.encode(owner))
      });
  }
}
