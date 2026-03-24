// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

library ProxyHelper {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  bytes32 internal constant ERC1967_ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
  bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 internal constant INITIALIZABLE_STORAGE =
    0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

  function getProxyAdmin(address proxy) internal view returns (address) {
    bytes32 slotData = vm.load(proxy, ERC1967_ADMIN_SLOT);
    return address(uint160(uint256(slotData)));
  }

  function getImplementation(address proxy) internal view returns (address) {
    bytes32 slotData = vm.load(proxy, IMPLEMENTATION_SLOT);
    return address(uint160(uint256(slotData)));
  }

  function getProxyInitializedVersion(address proxy) internal view returns (uint64) {
    bytes32 slotData = vm.load(proxy, INITIALIZABLE_STORAGE);
    return uint64(uint256(slotData) & ((1 << 64) - 1));
  }
}
