// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title EIP712Hash library
/// @author Aave Labs
/// @notice Helper methods to hash EIP712 typed data structs.
library EIP712Hash {
  using EIP712Hash for *;

  bytes32 public constant SET_USER_POSITION_MANAGERS_TYPEHASH =
    // keccak256('SetUserPositionManagers(address user,PositionManagerUpdate[] updates,uint256 nonce,uint256 deadline)PositionManagerUpdate(address positionManager,bool approve)')
    0xa9a500485f4e7c738838a1c065fe46501b5a92142c290f6a51aa56f61810c5b0;

  bytes32 public constant POSITION_MANAGER_UPDATE =
    // keccak256('PositionManagerUpdate(address positionManager,bool approve)')
    0x187dbd227227274b90655fb4011fc21dd749e8966fc040bd91e0b92609202565;

  function hash(ISpoke.SetUserPositionManagers calldata params) internal pure returns (bytes32) {
    bytes32[] memory updatesHashes = new bytes32[](params.updates.length);
    for (uint256 i = 0; i < updatesHashes.length; ++i) {
      updatesHashes[i] = params.updates[i].hash();
    }
    return
      keccak256(
        abi.encode(
          SET_USER_POSITION_MANAGERS_TYPEHASH,
          params.user,
          keccak256(abi.encodePacked(updatesHashes)),
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(ISpoke.PositionManagerUpdate calldata params) internal pure returns (bytes32) {
    return keccak256(abi.encode(POSITION_MANAGER_UPDATE, params.positionManager, params.approve));
  }
}
