// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev Transient storage cheatcodes shipped in forge 1.9.0; drop once forge-std declares them in `Vm`.
interface VmTransient {
  function loadTransient(address target, bytes32 slot) external view returns (bytes32 data);
  function storeTransient(address target, bytes32 slot, bytes32 value) external;
}

VmTransient constant vmTransient = VmTransient(
  address(uint160(uint256(keccak256('hevm cheat code'))))
);
