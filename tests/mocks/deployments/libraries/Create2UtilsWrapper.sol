// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

contract Create2UtilsWrapper {
  function isContractDeployed(address addr) external view returns (bool) {
    return Create2Utils.isContractDeployed(addr);
  }

  function create2Deploy(bytes32 salt, bytes memory bytecode) external returns (address) {
    return Create2Utils.create2Deploy(salt, bytecode);
  }

  function proxify(
    bytes32 salt,
    address logic,
    address initialOwner,
    bytes memory data
  ) external returns (address) {
    return Create2Utils.proxify(salt, logic, initialOwner, data);
  }

  function computeCreate2Address(
    bytes32 salt,
    bytes32 initcodeHash
  ) external pure returns (address) {
    return Create2Utils.computeCreate2Address(salt, initcodeHash);
  }

  function computeCreate2Address(
    bytes32 salt,
    bytes memory bytecode
  ) external pure returns (address) {
    return Create2Utils.computeCreate2Address(salt, bytecode);
  }

  function addressFromLast20Bytes(bytes32 bytesValue) external pure returns (address) {
    return Create2Utils.addressFromLast20Bytes(bytesValue);
  }
}
