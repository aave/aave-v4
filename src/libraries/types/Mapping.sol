// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

struct Mapping {
  uint248 _phantom;
}

using MappingLib for Mapping global;

library MappingLib {
  function get(Mapping storage base, uint256 key) internal view returns (uint256 ret) {
    assembly ('memory-safe') {
      mstore(0x00, key)
      mstore(0x20, base.slot)
      ret := sload(keccak256(0x00, 0x40))
    }
  }

  function set(Mapping storage base, uint256 key, uint256 value) internal {
    assembly ('memory-safe') {
      mstore(0x00, key)
      mstore(0x20, base.slot)
      sstore(keccak256(0x00, 0x40), value)
    }
  }
}
