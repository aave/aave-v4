// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Errors} from './helpers/Errors.sol';
import {DataTypes} from './types/DataTypes.sol';

/**
 * @title ReserveBorrowModuleConfiguration library
 * @author Aave Labs
 * @notice Implements the bitmap logic to handle the borrow module reserve configuration
 */
library ReserveBorrowModuleConfiguration {
  uint256 internal constant LIQUIDATION_THRESHOLD_MASK =     0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
  uint256 internal constant LIQUIDATION_BONUS_MASK =         0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
  uint256 internal constant RESERVE_FACTOR_MASK =            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFF; // prettier-ignore
  uint256 internal constant BORROWABLE_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFF; // prettier-ignore

  /// @dev For the Liquidation Threshold, the start bit is 0 (up to 15), hence no bitshifting is needed
  uint256 internal constant LIQUIDATION_BONUS_START_BIT_POSITION = 16;
  uint256 internal constant RESERVE_FACTOR_START_BIT_POSITION = 32;
  uint256 internal constant IS_BORROWABLE_START_BIT_POSITION = 48;

  uint256 internal constant MAX_VALID_LIQUIDATION_THRESHOLD = 65535;
  uint256 internal constant MAX_VALID_LIQUIDATION_BONUS = 65535;
  uint256 internal constant MAX_VALID_RESERVE_FACTOR = 65535;

  /**
   * @notice Sets the liquidation threshold of the reserve
   * @param self The reserve configuration
   * @param threshold The new liquidation threshold
   */
  function setLiquidationThreshold(
    DataTypes.ReserveBorrowModuleConfig memory self,
    uint256 threshold
  ) internal pure {
    require(threshold <= MAX_VALID_LIQUIDATION_THRESHOLD, Errors.INVALID_LIQ_THRESHOLD);

    self.data = (self.data & LIQUIDATION_THRESHOLD_MASK) | threshold;
  }

  /**
   * @notice Gets the liquidation threshold of the reserve
   * @param self The reserve configuration
   * @return The liquidation threshold
   */
  function getLiquidationThreshold(
    DataTypes.ReserveBorrowModuleConfig memory self
  ) internal pure returns (uint256) {
    return self.data & ~LIQUIDATION_THRESHOLD_MASK;
  }

  /**
   * @notice Sets the liquidation bonus of the reserve
   * @param self The reserve configuration
   * @param bonus The new liquidation bonus
   */
  function setLiquidationBonus(
    DataTypes.ReserveBorrowModuleConfig memory self,
    uint256 bonus
  ) internal pure {
    require(bonus <= MAX_VALID_LIQUIDATION_BONUS, Errors.INVALID_LIQ_BONUS);

    self.data =
      (self.data & LIQUIDATION_BONUS_MASK) |
      (bonus << LIQUIDATION_BONUS_START_BIT_POSITION);
  }

  /**
   * @notice Gets the liquidation bonus of the reserve
   * @param self The reserve configuration
   * @return The liquidation bonus
   */
  function getLiquidationBonus(
    DataTypes.ReserveBorrowModuleConfig memory self
  ) internal pure returns (uint256) {
    return (self.data & ~LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION;
  }

  /**
   * @notice Sets the reserve factor of the reserve
   * @param self The reserve configuration
   * @param reserveFactor The reserve factor
   */
  function setReserveFactor(
    DataTypes.ReserveBorrowModuleConfig memory self,
    uint256 reserveFactor
  ) internal pure {
    require(reserveFactor <= MAX_VALID_RESERVE_FACTOR, Errors.INVALID_RESERVE_FACTOR);

    self.data =
      (self.data & RESERVE_FACTOR_MASK) |
      (reserveFactor << RESERVE_FACTOR_START_BIT_POSITION);
  }

  /**
   * @notice Gets the reserve factor of the reserve
   * @param self The reserve configuration
   * @return The reserve factor
   */
  function getReserveFactor(
    DataTypes.ReserveBorrowModuleConfig memory self
  ) internal pure returns (uint256) {
    return (self.data & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION;
  }

  /**
   * @notice Enables or disables borrowing on the reserve
   * @param self The reserve configuration
   * @param enabled True if the borrowing needs to be enabled, false otherwise
   */
  function setBorrowingEnabled(
    DataTypes.ReserveBorrowModuleConfig memory self,
    bool enabled
  ) internal pure {
    self.data =
      (self.data & BORROWABLE_MASK) |
      (uint256(enabled ? 1 : 0) << IS_BORROWABLE_START_BIT_POSITION);
  }

  /**
   * @notice Gets the borrowing state of the reserve
   * @param self The reserve configuration
   * @return The borrowing state
   */
  function getBorrowingEnabled(
    DataTypes.ReserveBorrowModuleConfig memory self
  ) internal pure returns (bool) {
    return (self.data & ~BORROWABLE_MASK) != 0;
  }

  /**
   * @notice Gets the configuration parameters of the reserve from storage
   * @param self The reserve configuration
   * @return The state param representing liquidation threshold
   * @return The state param representing liquidation bonus
   * @return The state param representing reserve factor
   */
  function getParams(
    DataTypes.ReserveBorrowModuleConfig memory self
  ) internal pure returns (uint256, uint256, uint256) {
    uint256 dataLocal = self.data;

    return (
      dataLocal & ~LIQUIDATION_THRESHOLD_MASK,
      (dataLocal & ~LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION,
      (dataLocal & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION
    );
  }

  function setConfigFromParams(
    DataTypes.ReserveBorrowModuleConfig memory self,
    DataTypes.ReserveBorrowModuleConfigurationParams memory params
  ) internal pure {
    setLiquidationThreshold(self, params.lt);
    setLiquidationBonus(self, params.lb);
    setReserveFactor(self, params.rf);
    setBorrowingEnabled(self, params.borrowable);
  }
}
