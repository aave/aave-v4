// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AddressesProviderDeployProcedure} from 'src/deployments/procedures/deploy/addresses-provider/AddressesProviderDeployProcedure.sol';

contract AddressesProviderDeployProcedureWrapper is AddressesProviderDeployProcedure {
  bool public IS_TEST = true;

  function deployAddressesProvider(
    address owner,
    bytes32 salt
  ) external returns (address, address) {
    return _deployAddressesProvider(owner, salt);
  }
}
