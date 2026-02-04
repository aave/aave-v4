// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {LibBit} from 'src/dependencies/solady/LibBit.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title PositionStatusMap Library
/// @author Aave Labs
/// @notice Implements the bitmap logic to handle the user configuration.
library PositionStatusMap {
  using PositionStatusMap for *;
  using LibBit for uint256;

  uint256 internal constant NOT_FOUND = type(uint256).max;

  uint256 internal constant BORROWING_MASK =
    0x5555555555555555555555555555555555555555555555555555555555555555;
  uint256 internal constant COLLATERAL_MASK =
    0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;

  /// @notice Sets if the user is borrowing the specified reserve.
  function setBorrowing(
    ISpoke.PositionStatus storage self,
    uint256 reserveId,
    bool borrowing
  ) internal {
    unchecked {
      uint256 bit = 1 << ((reserveId % 128) << 1);
      if (borrowing) {
        self.map[reserveId.bucketId()] |= bit;
      } else {
        self.map[reserveId.bucketId()] &= ~bit;
      }
    }
  }

  /// @notice Sets if the user is using as collateral the specified reserve.
  function setUsingAsCollateral(
    ISpoke.PositionStatus storage self,
    uint256 reserveId,
    bool usingAsCollateral
  ) internal {
    unchecked {
      uint256 bit = 1 << (((reserveId % 128) << 1) + 1);
      if (usingAsCollateral) {
        self.map[reserveId.bucketId()] |= bit;
      } else {
        self.map[reserveId.bucketId()] &= ~bit;
      }
    }
  }

  /// @notice Returns if a user is using the specified reserve for borrowing or as collateral.
  function isUsingAsCollateralOrBorrowing(
    ISpoke.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      return (self.getBucketWord(reserveId) >> ((reserveId % 128) << 1)) & 3 != 0;
    }
  }

  /// @notice Returns if a user is using the specified reserve for borrowing.
  function isBorrowing(
    ISpoke.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      return (self.getBucketWord(reserveId) >> ((reserveId % 128) << 1)) & 1 != 0;
    }
  }

  /// @notice Returns if a user is using the specified reserve as collateral.
  function isUsingAsCollateral(
    ISpoke.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      return (self.getBucketWord(reserveId) >> (((reserveId % 128) << 1) + 1)) & 1 != 0;
    }
  }

  /// @notice Counts the number of reserves enabled as collateral.
  /// @dev Disregards potential dirty bits set after `reserveCount`.
  /// @param reserveCount The current `reserveCount`, to avoid reading uninitialized buckets.
  function collateralCount(
    ISpoke.PositionStatus storage self,
    uint256 reserveCount
  ) internal view returns (uint256) {
    unchecked {
      uint256 bucket = reserveCount.bucketId();
      uint256 count = self.map[bucket].isolateCollateralUntil(reserveCount).popCount();
      while (bucket != 0) {
        count += self.map[--bucket].isolateCollateral().popCount();
      }
      return count;
    }
  }

  /// @notice Counts the number of reserves borrowed.
  /// @dev Disregards potential dirty bits set after `reserveCount`.
  /// @param reserveCount The current `reserveCount`, to avoid reading uninitialized buckets.
  function borrowCount(
    ISpoke.PositionStatus storage self,
    uint256 reserveCount
  ) internal view returns (uint256) {
    unchecked {
      uint256 bucket = reserveCount.bucketId();
      uint256 count = self.map[bucket].isolateBorrowingUntil(reserveCount).popCount();
      while (bucket != 0) {
        count += self.map[--bucket].isolateBorrowing().popCount();
      }
      return count;
    }
  }

  /// @notice Finds the previous borrowing or collateralized reserve strictly before `fromReserveId`.
  /// @dev The search starts at `fromReserveId` (exclusive) and scans backward across buckets.
  /// @dev Returns `NOT_FOUND` if no borrowing or collateralized reserve exists before the bound.
  /// @dev Ignores dirty bits beyond the configured `reserveCount` within the last bucket.
  /// @param fromReserveId The identifier of the reserve to start searching from.
  /// @return reserveId The reserve identifier for the next reserve that is borrowed or used as collateral.
  /// @return borrowing True if the next reserveId is borrowed.
  /// @return collateral True if the next reserveId is used as collateral.
  function next(
    ISpoke.PositionStatus storage self,
    uint256 fromReserveId
  ) internal view returns (uint256, bool, bool) {
    unchecked {
      uint256 bucket = fromReserveId.bucketId();
      uint256 map = self.map[bucket];
      uint256 setBitId = map.isolateUntil(fromReserveId).fls();
      while (setBitId == 256 && bucket != 0) {
        map = self.map[--bucket];
        setBitId = map.fls();
      }
      if (setBitId == 256) {
        return (NOT_FOUND, false, false);
      } else {
        uint256 word = map >> ((setBitId >> 1) << 1);
        return (setBitId.fromBitId(bucket), word & 1 != 0, word & 2 != 0);
      }
    }
  }

  /// @notice Finds the previous borrowed reserve strictly before `fromReserveId`.
  /// @dev The search starts at `fromReserveId` (exclusive) and scans backward across buckets.
  /// @dev Returns `NOT_FOUND` if no borrowed reserve exists before the bound.
  /// @dev Ignores dirty bits beyond the configured `reserveCount` within the last bucket.
  /// @param fromReserveId The exclusive upper bound to start from (this reserveId is not considered).
  /// @return The previous borrowed reserveId, or `NOT_FOUND` if none is found.
  function nextBorrowing(
    ISpoke.PositionStatus storage self,
    uint256 fromReserveId
  ) internal view returns (uint256) {
    unchecked {
      uint256 bucket = fromReserveId.bucketId();
      uint256 setBitId = self.map[bucket].isolateBorrowingUntil(fromReserveId).fls();
      while (setBitId == 256 && bucket != 0) {
        setBitId = self.map[--bucket].isolateBorrowing().fls();
      }
      return setBitId == 256 ? NOT_FOUND : setBitId.fromBitId(bucket);
    }
  }

  /// @notice Finds the previous collateral reserve strictly before `fromReserveId`.
  /// @dev The search starts at `fromReserveId` (exclusive) and scans backward across buckets.
  /// @dev Returns `NOT_FOUND` if no collateral reserve exists before the bound.
  /// @dev Ignores dirty bits beyond the configured `reserveCount` within the last bucket.
  /// @param fromReserveId The exclusive upper bound to start from (this reserveId is not considered).
  /// @return The previous collateral reserveId, or `NOT_FOUND` if none is found.
  function nextCollateral(
    ISpoke.PositionStatus storage self,
    uint256 fromReserveId
  ) internal view returns (uint256) {
    unchecked {
      uint256 bucket = fromReserveId.bucketId();
      uint256 setBitId = self.map[bucket].isolateCollateralUntil(fromReserveId).fls();
      while (setBitId == 256 && bucket != 0) {
        setBitId = self.map[--bucket].isolateCollateral().fls();
      }
      return setBitId == 256 ? NOT_FOUND : setBitId.fromBitId(bucket);
    }
  }

  /// @notice Returns the word containing the reserve state in the bitmap.
  function getBucketWord(
    ISpoke.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (uint256) {
    return self.map[reserveId.bucketId()];
  }

  /// @notice Converts a reserveId to its corresponding bucketId.
  function bucketId(uint256 reserveId) internal pure returns (uint256 wordId) {
    assembly ('memory-safe') {
      wordId := shr(7, reserveId)
    }
  }

  /// @notice Converts a bit index to its corresponding reserve index in the bitmap.
  /// @dev BitId 0, 1 correspond to reserveId 0; BitId 2, 3 correspond to reserveId 1; etc.
  function fromBitId(uint256 bitId, uint256 bucket) internal pure returns (uint256 reserveId) {
    assembly ('memory-safe') {
      reserveId := add(shr(1, bitId), shl(7, bucket))
    }
  }

  /// @notice Isolates the borrowing bits from word.
  function isolateBorrowing(uint256 word) internal pure returns (uint256 ret) {
    assembly ('memory-safe') {
      ret := and(word, BORROWING_MASK)
    }
  }

  /// @notice Returns masked `word` containing only borrowing bits from the first reserve up to `reserveCount`.
  function isolateBorrowingUntil(
    uint256 word,
    uint256 reserveCount
  ) internal pure returns (uint256 ret) {
    // ret = word & (BORROWING_MASK >> (256 - ((reserveCount % 128) << 1)));
    assembly ('memory-safe') {
      ret := and(word, shr(sub(256, shl(1, mod(reserveCount, 128))), BORROWING_MASK))
    }
  }

  /// @notice Returns masked `word` containing bits from the first reserve up to `reserveCount`.
  function isolateUntil(uint256 word, uint256 reserveCount) internal pure returns (uint256 ret) {
    // ret = word & (type(uint256).max >> (256 - ((reserveCount % 128) << 1)));
    assembly ('memory-safe') {
      ret := and(word, shr(sub(256, shl(1, mod(reserveCount, 128))), not(0)))
    }
  }

  /// @notice Isolates the collateral bits from word.
  function isolateCollateral(uint256 word) internal pure returns (uint256 ret) {
    assembly ('memory-safe') {
      ret := and(word, COLLATERAL_MASK)
    }
  }

  /// @notice Returns masked `word` containing only collateral bits from the first reserve up to `reserveCount`.
  function isolateCollateralUntil(
    uint256 word,
    uint256 reserveCount
  ) internal pure returns (uint256 ret) {
    // ret = word & (COLLATERAL_MASK >> (256 - ((reserveCount % 128) << 1)));
    assembly ('memory-safe') {
      ret := and(word, shr(sub(256, shl(1, mod(reserveCount, 128))), COLLATERAL_MASK))
    }
  }

  /// @notice Returns the collateral bitmap as bytes.
  /// @dev Each bucket (128 reserves) is compressed to 16 bytes (uint128), with two buckets packed per 32-byte word.
  /// @param reserveCount The current reserveCount to determine bucket boundaries.
  /// @return The compressed collateral bitmap (16 bytes per bucket).
  function getCollateralBitmap(
    ISpoke.PositionStatus storage self,
    uint256 reserveCount
  ) internal view returns (bytes memory) {
    unchecked {
      uint256 bucketCount = reserveCount == 0 ? 0 : (reserveCount - 1).bucketId() + 1;
      bytes memory result = new bytes(((bucketCount + 1) / 2) * 32);

      for (uint256 i; i < bucketCount; ) {
        uint128 compressed0 = self.map[i].compressCollateral();
        // Compress next bucket if it exists, otherwise 0
        uint128 compressed1 = (i + 1 < bucketCount) ? self.map[i + 1].compressCollateral() : 0;

        assembly ('memory-safe') {
          // Pack with compressed0 in lower 128 bits, compressed1 in upper 128 bits
          // This ensures reserve N is at bit N in the continuous bitmap
          let packed := or(compressed0, shl(128, compressed1))
          mstore(add(add(result, 32), shl(5, shr(1, i))), packed)
        }

        i += 2;
      }

      return result;
    }
  }

  /// @notice Compresses collateral bits from a word into a densely packed uint128.
  /// @dev Extracts odd bits (1,3,5,...,255) representing collateral flags for 128 reserves,
  ///      and packs them into consecutive bits (0,1,2,...,127) in a uint128.
  /// @param word The word to compress.
  /// @return packed The compressed uint128 containing only collateral bits.
  function compressCollateral(uint256 word) internal pure returns (uint128 packed) {
    assembly ('memory-safe') {
      // (word & COLLATERAL_MASK) >> 1 moves bits from positions 1,3,5,... to 0,2,4,...
      let x := shr(1, and(word, COLLATERAL_MASK))

      // Progressively merge bits from sparse even positions into dense consecutive positions

      // Merge (0,2)→(0,1), (4,6)→(4,5), (8,10)→(8,9), ...
      x := and(or(x, shr(1, x)), 0x3333333333333333333333333333333333333333333333333333333333333333)
      // Merge (0-3)→(0-3), (8-11)→(8-11), ...
      x := and(or(x, shr(2, x)), 0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F)
      // Merge (0-7)→(0-7), (16-23)→(16-23), ...
      x := and(or(x, shr(4, x)), 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF)
      // Merge (0-15)→(0-15), (32-47)→(32-47), ...
      x := and(or(x, shr(8, x)), 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF)
      // Merge (0-31)→(0-31), (64-95)→(64-95)
      x := and(
        or(x, shr(16, x)),
        0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF
      )
      // Merge (0-63)→(0-63), (128-191)→(128-191)
      x := and(
        or(x, shr(32, x)),
        0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF
      )

      // Move all 128 bits now in lower half
      packed := and(or(x, shr(64, x)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
    }
  }
}
