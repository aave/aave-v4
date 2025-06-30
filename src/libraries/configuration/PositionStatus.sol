// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibBit} from 'src/dependencies/solady/LibBit.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title PositionStatus
 * @author Aave Labs
 * @notice Implements the bitmap logic to handle the user configuration.
 */
library PositionStatus {
  using PositionStatus for DataTypes.PositionStatus;

  error InvalidReserveId();
  error InvalidReserveCount();

  //TODO: After we complete the data structures packing, this needs to be adjusted to the right size depending on the number of bits we will use to store the reserve index
  uint256 public constant MAX_RESERVES_COUNT = 1024;
  uint256 internal constant BORROWING_MASK =
    0x5555555555555555555555555555555555555555555555555555555555555555;
  uint256 internal constant COLLATERAL_MASK =
    0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;

  /**
   * @dev Sets if the user is borrowing the reserve identified by reserveId.
   * @param self The configuration object.
   * @param reserveId The index of the reserve in the bitmap.
   * @param borrowing True if the user is borrowing the reserve, false otherwise.
   */
  function setBorrowing(
    DataTypes.PositionStatus storage self,
    uint256 reserveId,
    bool borrowing
  ) internal {
    require(reserveId < MAX_RESERVES_COUNT, InvalidReserveId());
    unchecked {
      uint256 bit = 1 << ((reserveId % 128) << 1);
      if (borrowing) {
        self.map[reserveId >> 7] |= bit;
      } else {
        self.map[reserveId >> 7] &= ~bit;
      }
    }
  }

  /**
   * @dev Sets if the user is using as collateral the reserve identified by reserveId.
   * @param self The configuration object.
   * @param reserveId The index of the reserve in the bitmap.
   * @param usingAsCollateral True if the user is using the reserve as collateral, false otherwise.
   */
  function setUsingAsCollateral(
    DataTypes.PositionStatus storage self,
    uint256 reserveId,
    bool usingAsCollateral
  ) internal {
    unchecked {
      require(reserveId < MAX_RESERVES_COUNT, InvalidReserveId());
      uint256 bit = 1 << (((reserveId % 128) << 1) + 1);
      if (usingAsCollateral) {
        self.map[reserveId >> 7] |= bit;
      } else {
        self.map[reserveId >> 7] &= ~bit;
      }
    }
  }

  /**
   * @dev Returns if a user is using the reserve for borrowing or as collateral.
   * @param self The configuration object.
   * @param reserveId The index of the reserve in the bitmap.
   * @return True if the user is using a reserve for borrowing or as collateral, false otherwise.
   */
  function isUsingAsCollateralOrBorrowing(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      require(reserveId < MAX_RESERVES_COUNT, InvalidReserveId());
      return (self.getMapSlot(reserveId) >> (reserveId % 128 << 1)) & 3 != 0;
    }
  }

  /**
   * @dev Returns if a user is using the reserve for borrowing.
   * @param self The configuration object.
   * @param reserveId The index of the reserve in the bitmap.
   * @return True if the user is using a reserve for borrowing, false otherwise.
   */
  function isBorrowing(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      require(reserveId < MAX_RESERVES_COUNT, InvalidReserveId());
      return (self.getMapSlot(reserveId) >> ((reserveId % 128) << 1)) & 1 != 0;
    }
  }

  /**
   * @dev Returns if a user is using the reserve as collateral.
   * @param self The configuration object.
   * @param reserveId The index of the reserve in the bitmap.
   * @return True if the user is using a reserve as collateral, false otherwise.
   */
  function isUsingAsCollateral(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      require(reserveId < MAX_RESERVES_COUNT, InvalidReserveId());
      return (self.getMapSlot(reserveId) >> (((reserveId % 128) << 1) + 1)) & 1 != 0;
    }
  }

  /**
   * @dev Counts the number reserves enabled as collateral.
   * @dev Takes all bits in the last bucket after `reserveCount` as well.
   * @param self The configuration object.
   * @param reserveCount The current reserveCount, to avoid reading uninitialized buckets.
   */
  function collateralCount(
    DataTypes.PositionStatus storage self,
    uint256 reserveCount
  ) internal view returns (uint256) {
    require(reserveCount <= MAX_RESERVES_COUNT, InvalidReserveCount()); // assertion: should never hit
    unchecked {
      uint256 count;
      uint256 bucket = 1 + (reserveCount >> 7);
      while (bucket-- != 0) {
        count += LibBit.popCount(self.map[bucket] & COLLATERAL_MASK);
      }
      return count;
    }
  }

  /**
   * @dev Returns the slot containing the reserve state in the bitmap.
   * @param self The configuration object.
   * @return The slot containing the state of the reserve.
   */
  function getMapSlot(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (uint256) {
    return self.map[reserveId >> 7];
  }
}
