// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';

contract MockNoncesKeyed is NoncesKeyed {
  function useCheckedNonce(address owner, uint256 keyNonce) public {
    _useCheckedNonce(owner, keyNonce);
  }
}
