// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';

contract MockNoncesKeyed is NoncesKeyed {
  bytes32 private constant NAMESPACE_SLOT =
    0x474d4a5585c1bae3dbeb574bb96408c7174aadd8ab635de4ab498e2723195f00;

  function useCheckedNonce(address owner, uint256 keyNonce) public {
    _useCheckedNonce(owner, keyNonce);
  }

  function setNonce(address owner, uint192 key, uint64 nonce) external {
    assembly ('memory-safe') {
      mstore(0x00, owner)
      mstore(0x20, NAMESPACE_SLOT)
      let slot1 := keccak256(0x00, 0x40)
      mstore(0x00, key)
      mstore(0x20, slot1)
      let slot2 := keccak256(0x00, 0x40)
      sstore(slot2, nonce)
    }
  }
}
