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
    // keccak256('SetUserPositionManagers(address onBehalfOf,PositionManagerUpdate[] updates,uint256 nonce,uint256 deadline)PositionManagerUpdate(address positionManager,bool approve)')
    0xba01f7bf3d3674c63670ec4a78b0d56aac1ad6e8c84468920b9e61bfe0b9851a;

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
          params.onBehalfOf,
          keccak256(abi.encodePacked(updatesHashes)),
          params.nonce,
          params.deadline
        )
      );
  }

  function hash(
    ISpoke.PositionManagerUpdate calldata params
  ) internal pure returns (bytes32 digest) {
    // equivalent to: keccak256(abi.encode(POSITION_MANAGER_UPDATE, params.positionManager, params.approve))
    assembly {
      let fmp := mload(0x40)
      mstore(0, POSITION_MANAGER_UPDATE)
      mstore(0x20, shr(96, shl(96, calldataload(params)))) // params.positionManager
      mstore(0x40, iszero(iszero(calldataload(add(params, 0x20))))) // params.approve
      digest := keccak256(0, 0x60)
      mstore(0x40, fmp)
    }
  }
}
