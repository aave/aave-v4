// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4SignatureGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4SignatureGatewayDeployProcedure.sol';

contract AaveV4SignatureGatewayDeployProcedureWrapper is AaveV4SignatureGatewayDeployProcedure {
  bool public IS_TEST = true;

  function deploySignatureGateway(address owner, bytes32 salt) external returns (address) {
    return _deploySignatureGateway(owner, salt);
  }
}
