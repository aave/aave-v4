// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4TokenizationSpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TokenizationSpokeDeployProcedure.sol';

contract AaveV4TokenizationSpokeDeployProcedureWrapper is AaveV4TokenizationSpokeDeployProcedure {
  bool public IS_TEST = true;

  function deployTokenizationSpokeInstance(
    address beacon,
    address hub,
    address underlying,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) external returns (address tokenizationSpokeProxy) {
    return _deployTokenizationSpokeInstance(beacon, hub, underlying, shareName, shareSymbol, salt);
  }
}
