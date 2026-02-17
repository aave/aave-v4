// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

library Create1Utils {
  error Create1DeploymentFailed();

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  function create1Deploy(bytes memory bytecode) internal returns (address addr) {
    assembly ('memory-safe') {
      addr := create(0, add(bytecode, 0x20), mload(bytecode))
    }
    require(addr != address(0), Create1DeploymentFailed());
  }

  function computeCreate1Address(address deployer, uint256 nonce) internal pure returns (address) {
    return vm.computeCreateAddress(deployer, nonce);
  }
}
