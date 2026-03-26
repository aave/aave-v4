// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4NativeTokenGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4NativeTokenGatewayDeployProcedure.sol';

contract AaveV4NativeTokenGatewayDeployProcedureWrapper is AaveV4NativeTokenGatewayDeployProcedure {
  bool public IS_TEST = true;

  function deployNativeTokenGateway(
    address nativeWrapper,
    address owner,
    bytes32 salt
  ) external returns (address) {
    return _deployNativeTokenGateway(nativeWrapper, owner, salt);
  }
}
