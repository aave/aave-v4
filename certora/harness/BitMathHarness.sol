// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibBit} from 'src/dependencies/solady/LibBit.sol';

/// @notice Exposes the original bit search for the independent equivalence proof.
contract BitMathHarness {
  function getFls(uint256 word) external pure returns (uint256) {
    return LibBit.fls(word);
  }
}
