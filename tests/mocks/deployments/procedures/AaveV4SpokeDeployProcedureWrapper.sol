// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';

contract AaveV4SpokeDeployProcedureWrapper is AaveV4SpokeDeployProcedure {
  bool public IS_TEST = true;

  function deployUpgradeableSpokeInstance(
    address spokeProxyAdminOwner,
    address authority,
    address oracle,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) external returns (address spokeProxy, address spokeImplementation) {
    return
      _deployUpgradeableSpokeInstance(
        spokeProxyAdminOwner,
        authority,
        oracle,
        spokeBytecode,
        maxUserReservesLimit,
        salt
      );
  }
}
