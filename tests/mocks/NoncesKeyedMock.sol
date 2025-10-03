// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';

contract NoncesKeyedMock is NoncesKeyed {
  function useCheckedNonce(address owner, uint256 keyNonce) public {
    _useCheckedNonce(owner, keyNonce);
  }
}
