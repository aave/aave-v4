// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

type Mapping is uint248;

using MappingLib for Mapping global;

library MappingLib {
  function get(Mapping baseSlot, uint256 key) internal view returns (uint256 ret) {
    assembly ('memory-safe') {
      mstore(0x00, key)
      mstore(0x20, baseSlot)
      ret := sload(keccak256(0x00, 0x40))
    }
  }

  function set(Mapping baseSlot, uint256 key, uint256 value) internal {
    assembly ('memory-safe') {
      mstore(0x00, key)
      mstore(0x20, baseSlot)
      sstore(keccak256(0x00, 0x40), value)
    }
  }
}
