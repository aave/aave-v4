// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4TokenizationSpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TokenizationSpokeDeployProcedure.sol';

contract AaveV4TokenizationSpokeDeployProcedureWrapper is AaveV4TokenizationSpokeDeployProcedure {
  bool public IS_TEST = true;

  function deployTokenizationSpokeImplementation(bytes32 salt) external returns (address) {
    return _deployTokenizationSpokeImplementation(salt);
  }

  function deployTokenizationSpokeProxy(
    address implementation,
    address hub,
    address underlying,
    address proxyAdminOwner,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) external returns (address) {
    return
      _deployTokenizationSpokeProxy(
        implementation,
        hub,
        underlying,
        proxyAdminOwner,
        shareName,
        shareSymbol,
        salt
      );
  }
}
