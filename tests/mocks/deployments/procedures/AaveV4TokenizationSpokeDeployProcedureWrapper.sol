// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4TokenizationSpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TokenizationSpokeDeployProcedure.sol';

contract AaveV4TokenizationSpokeDeployProcedureWrapper is AaveV4TokenizationSpokeDeployProcedure {
  bool public IS_TEST = true;

  function deployUpgradableTokenizationSpokeInstance(
    address hub,
    uint256 assetId,
    address spokeProxyAdminOwner,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) external returns (address tokenizationSpokeProxy, address tokenizationSpokeImplementation) {
    return
      _deployUpgradableTokenizationSpokeInstance(
        hub,
        assetId,
        spokeProxyAdminOwner,
        shareName,
        shareSymbol,
        salt
      );
  }
}
