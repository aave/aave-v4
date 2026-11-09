// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @dev Transient storage cheatcodes shipped in forge 1.9.0; drop once forge-std declares them in `Vm`.
interface VmTransient {
  function loadTransient(address target, bytes32 slot) external view returns (bytes32 data);
  function storeTransient(address target, bytes32 slot, bytes32 value) external;
}

VmTransient constant vmTransient = VmTransient(
  address(uint160(uint256(keccak256('hevm cheat code'))))
);

/// @dev ERC-7201 slot of OpenZeppelin's ReentrancyGuard, derived here rather than read from src.
bytes32 constant REENTRANCY_GUARD_SLOT = keccak256(
  abi.encode(uint256(keccak256('openzeppelin.storage.ReentrancyGuard')) - 1)
) & ~bytes32(uint256(0xff));

bytes32 constant REENTRANCY_GUARD_ENTERED = bytes32(uint256(1));
