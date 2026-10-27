// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4SignatureGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4SignatureGatewayDeployProcedure.sol';

contract AaveV4SignatureGatewayDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deploySignatureGateway(address owner, bytes32 salt) external returns (address) {
    return AaveV4SignatureGatewayDeployProcedure.deploySignatureGateway(owner, salt);
  }
}
