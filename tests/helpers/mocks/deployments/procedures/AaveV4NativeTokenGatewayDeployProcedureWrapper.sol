// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4NativeTokenGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4NativeTokenGatewayDeployProcedure.sol';

contract AaveV4NativeTokenGatewayDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deployNativeTokenGateway(
    address nativeWrapper,
    address owner,
    bytes32 salt
  ) external returns (address) {
    return AaveV4NativeTokenGatewayDeployProcedure.deployNativeTokenGateway(nativeWrapper, owner, salt);
  }
}
