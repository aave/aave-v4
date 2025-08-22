// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// trimmed https://github.com/Vectorized/solady/blob/ba711c9fa6a2dc7b2b7707f7fe136b5133379c03/src/utils/LibBit.sol

/// @notice Library for bit twiddling and boolean operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibBit.sol)
/// @author Inspired by (https://graphics.stanford.edu/~seander/bithacks.html)
library LibBit {
  /// @dev Returns the number of set bits in `x`.
  function popCount(uint256 x) internal pure returns (uint256 c) {
    /// @solidity memory-safe-assembly
    assembly {
      let max := not(0)
      let isMax := eq(x, max)
      x := sub(x, and(shr(1, x), div(max, 3)))
      x := add(and(x, div(max, 5)), and(shr(2, x), div(max, 5)))
      x := and(add(x, shr(4, x)), div(max, 17))
      c := or(shl(8, isMax), shr(248, mul(x, div(max, 255))))
    }
  }

  /// @dev Find first set.
  /// Returns the index of the least significant bit of `x`,
  /// counting from the least significant bit position.
  /// If `x` is zero, returns 256.
  /// Equivalent to `ctz` (count trailing zeros), which gives
  /// the number of zeros following the least significant one bit.
  function ffs(uint256 x) internal pure returns (uint256 r) {
    /// @solidity memory-safe-assembly
    assembly {
      // Isolate the least significant bit.
      x := and(x, add(not(x), 1))
      // For the upper 3 bits of the result, use a De Bruijn-like lookup.
      // Credit to adhusson: https://blog.adhusson.com/cheap-find-first-set-evm/
      // prettier-ignore
      r := shl(5, shr(252, shl(shl(2, shr(250, mul(x,
            0xb6db6db6ddddddddd34d34d349249249210842108c6318c639ce739cffffffff))),
            0x8040405543005266443200005020610674053026020000107506200176117077)))
      // For the lower 5 bits of the result, use a De Bruijn lookup.
      // prettier-ignore
      r := or(r, byte(and(div(0xd76453e0, shr(r, x)), 0x1f),
            0x001f0d1e100c1d070f090b19131c1706010e11080a1a141802121b1503160405))
    }
  }
}
