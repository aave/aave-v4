// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';

contract AaveV4AccessManagerEnumerableDeployProcedure is AaveV4DeployProcedureBase {
  function _deployAccessManagerEnumerable(address admin, bytes32 salt) internal returns (address) {
    require(admin != address(0), 'invalid admin');
    return
      Create2Utils.create2Deploy(
        salt,
        abi.encodePacked(type(AccessManagerEnumerable).creationCode, abi.encode(admin))
      );
  }
}
