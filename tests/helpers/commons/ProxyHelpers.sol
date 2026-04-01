// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

/// @title ProxyHelpers
/// @notice Proxy introspection helpers for the Aave V4 test suite.
abstract contract ProxyHelpers {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  bytes32 internal constant ERC1967_ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
  bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 internal constant INITIALIZABLE_SLOT =
    0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

  function _getProxyAdminAddress(address proxy) internal view returns (address) {
    bytes32 slotData = vm.load(proxy, ERC1967_ADMIN_SLOT);
    return address(uint160(uint256(slotData)));
  }

  function _getImplementationAddress(address proxy) internal view returns (address) {
    bytes32 slotData = vm.load(proxy, IMPLEMENTATION_SLOT);
    return address(uint160(uint256(slotData)));
  }

  function _getProxyInitializedVersion(address proxy) internal view returns (uint64) {
    bytes32 slotData = vm.load(proxy, INITIALIZABLE_SLOT);
    return uint64(uint256(slotData) & ((1 << 64) - 1));
  }
}
