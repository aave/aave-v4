// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title EIP712Hash library
/// @author Aave Labs
/// @notice Helper methods to hash EIP712 typed data structs.
library EIP712Hash {
  bytes32 public constant SET_USER_POSITION_MANAGER_TYPEHASH =
    // keccak256('SetUserPositionManager(address positionManager,address user,bool approve,uint256 nonce,uint256 deadline)')
    0x758d23a3c07218b7ea0b4f7f63903c4e9d5cbde72d3bcfe3e9896639025a0214;

  function hash(
    ISpoke.SpokeSetUserPositionManager calldata params
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          SET_USER_POSITION_MANAGER_TYPEHASH,
          params.positionManager,
          params.user,
          params.approve,
          params.nonce,
          params.deadline
        )
      );
  }
}
