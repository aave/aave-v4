// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ConfigPositionManager} from 'src/position-manager/ConfigPositionManager.sol';

contract AaveV4ConfigPositionManagerDeployProcedure is AaveV4DeployProcedureBase {
  function _deployConfigPositionManager(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2Deploy({
        salt: salt,
        bytecode: abi.encodePacked(type(ConfigPositionManager).creationCode, abi.encode(owner))
      });
  }
}
