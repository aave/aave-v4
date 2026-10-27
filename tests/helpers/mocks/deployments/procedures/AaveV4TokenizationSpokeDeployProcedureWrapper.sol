// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4TokenizationSpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TokenizationSpokeDeployProcedure.sol';

contract AaveV4TokenizationSpokeDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deployUpgradeableTokenizationSpokeInstance(
    address hub,
    address underlying,
    address proxyAdminOwner,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) external returns (address tokenizationSpokeProxy, address tokenizationSpokeImplementation) {
    return
      AaveV4TokenizationSpokeDeployProcedure.deployUpgradeableTokenizationSpokeInstance(
        hub,
        underlying,
        proxyAdminOwner,
        shareName,
        shareSymbol,
        salt
      );
  }
}
