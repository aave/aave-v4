// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {LibBit} from 'src/dependencies/solady/LibBit.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title PositionStatus
 * @author Aave Labs
 * @notice Implements the bitmap logic to handle the user configuration.
 */
library PositionStatus {
  using PositionStatus for *;
  using LibBit for uint256;

  uint256 internal constant NOT_FOUND = type(uint256).max;

  uint256 internal constant BORROWING_MASK =
    0x5555555555555555555555555555555555555555555555555555555555555555;
  uint256 internal constant COLLATERAL_MASK =
    0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;

  /**
   * @dev Sets if the user is borrowing the reserve identified by reserveId.
   * @param self The configuration struct.
   * @param reserveId The index of the reserve in the bitmap.
   * @param borrowing True if the user is borrowing the reserve, false otherwise.
   */
  function setBorrowing(
    DataTypes.PositionStatus storage self,
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

  /**
   * @dev Sets if the user is using as collateral the reserve identified by reserveId.
   * @param self The configuration struct.
   * @param reserveId The index of the reserve in the bitmap.
   * @param usingAsCollateral True if the user is using the reserve as collateral, false otherwise.
   */
  function setUsingAsCollateral(
    DataTypes.PositionStatus storage self,
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

  /**
   * @dev Returns if a user is using the reserve for borrowing or as collateral.
   * @param self The configuration struct.
   * @param reserveId The index of the reserve in the bitmap.
   * @return True if the user is using a reserve for borrowing or as collateral, false otherwise.
   */
  function isUsingAsCollateralOrBorrowing(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      return (self.map[reserveId.bucketId()] >> ((reserveId % 128) << 1)) & 3 != 0;
    }
  }

  /**
   * @dev Returns if a user is using the reserve for borrowing.
   * @param self The configuration struct.
   * @param reserveId The index of the reserve in the bitmap.
   * @return True if the user is using a reserve for borrowing, false otherwise.
   */
  function isBorrowing(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      return (self.getBucketWord(reserveId) >> ((reserveId % 128) << 1)) & 1 != 0;
    }
  }

  /**
   * @dev Returns if a user is using the reserve as collateral.
   * @param self The configuration struct.
   * @param reserveId The index of the reserve in the bitmap.
   * @return True if the user is using a reserve as collateral, false otherwise.
   */
  function isUsingAsCollateral(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      return (self.getBucketWord(reserveId) >> (((reserveId % 128) << 1) + 1)) & 1 != 0;
    }
  }

  /**
   * @dev Counts the number of reserves enabled as collateral.
   * @dev Disregards potential dirty bits set after `reserveCount`.
   * @param self The configuration struct.
   * @param reserveCount The current reserveCount, to avoid reading uninitialized buckets.
   */
  function collateralCount(
    DataTypes.PositionStatus storage self,
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

  /**
   * @dev Finds the previous borrowing or collateralized reserve strictly before `fromReserveId`.
   * @dev The search starts at `fromReserveId` (exclusive) and scans backward across buckets.
   * @dev Returns `NOT_FOUND` if no borrowing or collateralized reserve exists before the bound.
   * @dev Ignores dirty bits beyond the configured `reserveCount` within the current bucket.
   * @param self The configuration object.
   * @param fromReserveId The reserveId to start searching from.
   * @return reserveId The next reserveId that is borrowing or using as collateral.
   * @return borrowing True if the next reserveId is borrowing, false otherwise.
   * @return collateral True if the next reserveId is using as collateral, false otherwise.
   */
  function next(
    DataTypes.PositionStatus storage self,
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

  /**
   * @dev Finds the previous borrowing reserve strictly before `fromReserveId`.
   * @dev The search starts at `fromReserveId` (exclusive) and scans backward across buckets.
   * @dev Returns `NOT_FOUND` if no borrowing reserve exists before the bound.
   * @dev Ignores dirty bits beyond the configured `reserveCount` within the current bucket.
   * @param self The position status storing reserves bitmap.
   * @param fromReserveId The exclusive upper bound to start from (this reserveId is not considered).
   * @return reserveId The previous borrowing reserveId, or `NOT_FOUND` if none is found.
   */
  function nextBorrowing(
    DataTypes.PositionStatus storage self,
    uint256 fromReserveId
  ) internal view returns (uint256 reserveId) {
    unchecked {
      uint256 bucket = fromReserveId.bucketId();
      uint256 setBitId = self.map[bucket].isolateBorrowingUntil(fromReserveId).fls();
      while (setBitId == 256 && bucket != 0) {
        setBitId = self.map[--bucket].isolateBorrowing().fls();
      }
      return setBitId == 256 ? NOT_FOUND : setBitId.fromBitId(bucket);
    }
  }

  /**
   * @dev Finds the previous collateralized reserve strictly before `fromReserveId`.
   * @dev The search starts at `fromReserveId` (exclusive) and scans backward across buckets.
   * @dev Returns `NOT_FOUND` if no collateralized reserve exists before the bound.
   * @dev Ignores dirty bits beyond the configured `reserveCount` within the current bucket.
   * @param self The position status storing reserves bitmap.
   * @param fromReserveId The exclusive upper bound to start from (this reserveId is not considered).
   * @return reserveId The previous collateralized reserveId, or `NOT_FOUND` if none is found.
   */
  function nextCollateral(
    DataTypes.PositionStatus storage self,
    uint256 fromReserveId
  ) internal view returns (uint256 reserveId) {
    unchecked {
      uint256 bucket = fromReserveId.bucketId();
      uint256 setBitId = self.map[bucket].isolateCollateralUntil(fromReserveId).fls();
      while (setBitId == 256 && bucket != 0) {
        setBitId = self.map[--bucket].isolateCollateral().fls();
      }
      return setBitId == 256 ? NOT_FOUND : setBitId.fromBitId(bucket);
    }
  }

  /**
   * @dev Returns the word containing the reserve state in the bitmap.
   * @param self The configuration struct.
   * @return The word containing the state of the reserve.
   */
  function getBucketWord(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (uint256) {
    return self.map[reserveId.bucketId()];
  }

  /**
   * @dev Converts a reserveId to it's corresponding bucketId.
   */
  function bucketId(uint256 reserveId) internal pure returns (uint256 wordId) {
    assembly ('memory-safe') {
      wordId := shr(7, reserveId)
    }
  }

  /**
   * @dev Converts a bitId (bit index) to it's corresponding reserveId.
   * @dev BitId 0, 1 correspond to reserveId 0; BitId 2, 3 correspond to reserveId 1; etc.
   */
  function fromBitId(uint256 bitId, uint256 bucket) internal pure returns (uint256 reserveId) {
    assembly ('memory-safe') {
      reserveId := add(shr(1, bitId), shl(7, bucket))
    }
  }

  /**
   * @dev Isolates the borrowing bits from word.
   */
  function isolateBorrowing(uint256 word) internal pure returns (uint256 ret) {
    assembly ('memory-safe') {
      ret := and(word, BORROWING_MASK)
    }
  }

  /**
   * @dev Isolates borrowing bits up to the given `reserveCount`, clearing all later reserves.
   * @param word The 256-bit value encoding reserves configuration.
   * @param reserveCount The number of reserves (2 bits each) to include.
   * @return ret The portion of word containing borrowing bits from the first reserve up to `reserveCount`.
   */
  function isolateBorrowingUntil(
    uint256 word,
    uint256 reserveCount
  ) internal pure returns (uint256 ret) {
    // ret = word & (BORROWING_MASK >> (256 - ((reserveCount % 128) << 1)));
    assembly ('memory-safe') {
      ret := and(word, shr(sub(256, shl(1, mod(reserveCount, 128))), BORROWING_MASK))
    }
  }

  /**
   * @dev Isolates bits up to the given `reserveCount`, clearing all later reserves.
   * @param word The 256-bit value encoding reserves configuration.
   * @param reserveCount The number of reserves (2 bits each) to include.
   * @return ret The portion of word containing bits from the first reserve up to `reserveCount`.
   */
  function isolateUntil(uint256 word, uint256 reserveCount) internal pure returns (uint256 ret) {
    // ret = word & (type(uint256).max >> (256 - ((reserveCount % 128) << 1)));
    assembly ('memory-safe') {
      ret := and(word, shr(sub(256, shl(1, mod(reserveCount, 128))), not(0)))
    }
  }

  /**
   * @dev Isolates the collateral bits from word.
   */
  function isolateCollateral(uint256 word) internal pure returns (uint256 ret) {
    assembly ('memory-safe') {
      ret := and(word, COLLATERAL_MASK)
    }
  }

  /**
   * @dev Isolates collateral bits up to the given `reserveCount`, clearing all later reserves.
   * @param word The 256-bit value encoding reserves configuration.
   * @param reserveCount The number of reserves (2 bits each) to include.
   * @return ret The portion of word containing collateral bits from the first reserve up to `reserveCount`.
   */
  function isolateCollateralUntil(
    uint256 word,
    uint256 reserveCount
  ) internal pure returns (uint256 ret) {
    // ret = word & (COLLATERAL_MASK >> (256 - ((reserveCount % 128) << 1)));
    assembly ('memory-safe') {
      ret := and(word, shr(sub(256, shl(1, mod(reserveCount, 128))), COLLATERAL_MASK))
    }
  }
}
