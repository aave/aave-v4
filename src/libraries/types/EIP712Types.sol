// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

library EIP712Types {
  struct SetUserPositionManager {
    address positionManager;
    address user;
    bool approve;
    uint256 nonce;
    uint256 deadline;
  }

  struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
  }
}
