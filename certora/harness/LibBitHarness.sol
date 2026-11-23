import {LibBit} from '../../src/dependencies/solady/LibBit.sol';

pragma solidity ^0.8.0;

contract LibBitHarness {
  function popCount(uint256 x) external pure returns (uint256 c) {
    return LibBit.popCount(x);
  }

  function fls(uint256 x) external pure returns (uint256 r) {
    return LibBit.fls(x);
  }

  function isBitTrue(uint256 x, uint16 pos) public pure returns (bool) {
    return ((x >> pos) & 1) == 1;
  }

  function changeOneBit(uint256 x, uint16 pos) external pure returns (uint256 c) {
    if (isBitTrue(x, pos)) {
      return x & ~(1 << pos);
    } else {
      return x | (1 << pos);
    }
  }
}
