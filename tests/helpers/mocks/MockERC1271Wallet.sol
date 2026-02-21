// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IERC1271} from 'src/dependencies/openzeppelin/IERC1271.sol';

contract MockERC1271Wallet is IERC1271 {
  address public owner;

  mapping(bytes32 => bool) public isValidHash;

  error OnlyOwner();

  constructor(address owner_) {
    owner = owner_;
  }

  function approveHash(bytes32 _hash) external {
    if (msg.sender != owner) revert OnlyOwner();
    isValidHash[_hash] = true;
  }

  function isValidSignature(
    bytes32 _hash,
    bytes memory /*_signature*/
  ) public view returns (bytes4) {
    return isValidHash[_hash] ? this.isValidSignature.selector : bytes4(0);
  }
}
