// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from '../types/DataTypes.sol';

/**
 * @title PositionStatus library
 * @author AaveLabs
 * @notice Implements the bitmap logic to handle the user configuration
 */
library PositionStatus {
  using PositionStatus for DataTypes.PositionStatus;



  error InvalidReserveIndex();

  //TODO: After we complete the data structures packing, this needs to be adjusted to the right size depending on the number of bits we will use to store the reserve index
  uint256 internal constant MAX_RESERVES_COUNT = 1024;
  uint256 internal constant BORROWING_MASK =
    0x5555555555555555555555555555555555555555555555555555555555555555;
  uint256 internal constant COLLATERAL_MASK =
    0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;

  /**
   * @notice Sets if the user is borrowing the reserve identified by reserveIndex
   * @param self The configuration object
   * @param reserveIndex The index of the reserve in the bitmap
   * @param borrowing True if the user is borrowing the reserve, false otherwise
   */
  function setBorrowing(
    DataTypes.PositionStatus storage self,
    uint256 reserveIndex,
    bool borrowing
  ) internal {
      require(reserveIndex < MAX_RESERVES_COUNT, InvalidReserveIndex());
      unchecked {
      uint256 bit = 1 << (reserveIndex << 1);
      if (borrowing) {
        self.map[reserveIndex >> 7] |= bit;
      } else {
        self.map[reserveIndex >> 7] &= ~bit;
      }
    }
  }

  /**
   * @notice Sets if the user is using as collateral the reserve identified by reserveIndex
   * @param self The configuration object
   * @param reserveIndex The index of the reserve in the bitmap
   * @param usingAsCollateral True if the user is using the reserve as collateral, false otherwise
   */
  function setUsingAsCollateral(
    DataTypes.PositionStatus storage self,
    uint256 reserveIndex,
    bool usingAsCollateral
  ) internal {
    unchecked {
      require(reserveIndex < MAX_RESERVES_COUNT, InvalidReserveIndex());
      uint256 bit = 1 << ((reserveIndex << 1) + 1);
      if (usingAsCollateral) {
        self.map[reserveIndex >> 7] |= bit;
      } else {
        self.map[reserveIndex >> 7] &= ~bit;
      }
    }
  }

  /**
   * @notice Returns if a user has been using the reserve for borrowing or as collateral
   * @param self The configuration object
   * @param reserveIndex The index of the reserve in the bitmap
   * @return True if the user has been using a reserve for borrowing or as collateral, false otherwise
   */
  function isUsingAsCollateralOrBorrowing(
    DataTypes.PositionStatus memory self,
    uint256 reserveIndex
  ) internal pure returns (bool) {
    unchecked {
      require(reserveIndex < MAX_RESERVES_COUNT, InvalidReserveIndex());
      return (_getMapSlot(self, reserveIndex) >> (reserveIndex << 1)) & 3 != 0;
    }
  }
  /**
   * @notice Validate a user has been using the reserve for borrowing
   * @param self The configuration object
   * @param reserveIndex The index of the reserve in the bitmap
   * @return True if the user has been using a reserve for borrowing, false otherwise
   */
  function isBorrowing(
    DataTypes.PositionStatus memory self,
    uint256 reserveIndex
  ) internal pure returns (bool) {
    unchecked {
      require(reserveIndex < MAX_RESERVES_COUNT, InvalidReserveIndex());
      return (_getMapSlot(self, reserveIndex) >> (reserveIndex << 1)) & 1 != 0;
    }
  }

  /**
   * @notice Validate a user has been using the reserve as collateral
   * @param self The configuration object
   * @param reserveIndex The index of the reserve in the bitmap
   * @return True if the user has been using a reserve as collateral, false otherwise
   */
  function isUsingAsCollateral(
    DataTypes.PositionStatus memory self,
    uint256 reserveIndex
  ) internal pure returns (bool) {
    unchecked {
      require(reserveIndex < MAX_RESERVES_COUNT, InvalidReserveIndex());
      return (_getMapSlot(self, reserveIndex) >> ((reserveIndex << 1) + 1)) & 1 != 0;
    }
  }

  /**
   * @notice Checks if a user has been supplying any reserve as collateral
   * @param self The configuration object
   * @return True if the user has been supplying as collateral any reserve, false otherwise
   *
  function isUsingAsCollateralAny(
    DataTypes.PositionStatus memory self
  ) internal pure returns (bool) {
    return _getMapSlot(self, reserveIndex) & COLLATERAL_MASK != 0;
  }
  */

  /**
   * @notice Checks if a user has been borrowing from any reserve
   * @param self The configuration object
   * @return True if the user has been borrowing any reserve, false otherwise
   *
  function isBorrowingAny(DataTypes.PositionStatus memory self) internal pure returns (bool) {
    return _getMapSlot(self, reserveIndex) & BORROWING_MASK != 0;
  }
  */

  /**
   * @notice Returns the uint256 containing the reserve state in the bitmap.
   * @param self The configuration object
   * @return the uint256 containing the state of the reserve
   */
  function _getMapSlot( DataTypes.PositionStatus memory self,uint256 reserveIndex) internal pure returns(uint256){
      return self.map[reserveIndex >> 7];
  }
}