// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Errors} from './helpers/Errors.sol';
import {DataTypes} from './types/DataTypes.sol';

/**
 * @title SupplyReserveConfiguration library
 * @author Aave Labs
 * @notice Implements the bitmap logic to handle the supply reserve configuration
 */
library SupplyReserveConfiguration {
  uint256 internal constant LIQUIDATION_THRESHOLD_MASK =     0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
  uint256 internal constant LIQUIDATION_BONUS_MASK =         0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
  uint256 internal constant RESERVE_FACTOR_MASK =            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFF; // prettier-ignore
  uint256 internal constant ACTIVE_MASK =                    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant BORROWABLE_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant FROZEN_MASK =                    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant PAUSED_MASK =                    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant DRAW_CAP_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant SUPPLY_CAP_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
  uint256 internal constant LIQUIDITY_PREMIUM_MASK =         0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore

  /// @dev For the Liquidation Threshold, the start bit is 0 (up to 15), hence no bitshifting is needed
  uint256 internal constant LIQUIDATION_BONUS_START_BIT_POSITION = 16;
  uint256 internal constant RESERVE_FACTOR_START_BIT_POSITION = 32;
  uint256 internal constant IS_ACTIVE_START_BIT_POSITION = 48;
  uint256 internal constant IS_BORROWABLE_START_BIT_POSITION = 49;
  uint256 internal constant IS_FROZEN_START_BIT_POSITION = 50;
  uint256 internal constant IS_PAUSED_START_BIT_POSITION = 51;
  uint256 internal constant DRAW_CAP_START_BIT_POSITION = 52;
  uint256 internal constant SUPPLY_CAP_START_BIT_POSITION = 88;
  uint256 internal constant LIQUIDITY_PREMIUM_START_BIT_POSITION = 124;

  uint256 internal constant MAX_VALID_LIQUIDATION_THRESHOLD = 65535;
  uint256 internal constant MAX_VALID_LIQUIDATION_BONUS = 65535;
  uint256 internal constant MAX_VALID_RESERVE_FACTOR = 65535;
  uint256 internal constant MAX_VALID_LIQUIDITY_PREMIUM = 10000;
  uint256 internal constant MAX_VALID_DRAW_CAP = 68719476735;
  uint256 internal constant MAX_VALID_SUPPLY_CAP = 68719476735;

  uint16 public constant MAX_RESERVES_COUNT = 128;

  /**
   * @notice Sets the liquidation threshold of the reserve
   * @param self The reserve configuration
   * @param threshold The new liquidation threshold
   */
  function setLiquidationThreshold(
    DataTypes.SupplyReserveConfig memory self,
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
    DataTypes.SupplyReserveConfig memory self
  ) internal pure returns (uint256) {
    return self.data & ~LIQUIDATION_THRESHOLD_MASK;
  }

  /**
   * @notice Sets the liquidation bonus of the reserve
   * @param self The reserve configuration
   * @param bonus The new liquidation bonus
   */
  function setLiquidationBonus(
    DataTypes.SupplyReserveConfig memory self,
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
    DataTypes.SupplyReserveConfig memory self
  ) internal pure returns (uint256) {
    return (self.data & ~LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION;
  }

  /**
   * @notice Sets the active state of the reserve
   * @param self The reserve configuration
   * @param active The active state
   */
  function setActive(DataTypes.SupplyReserveConfig memory self, bool active) internal pure {
    self.data =
      (self.data & ACTIVE_MASK) |
      (uint256(active ? 1 : 0) << IS_ACTIVE_START_BIT_POSITION);
  }

  /**
   * @notice Gets the active state of the reserve
   * @param self The reserve configuration
   * @return The active state
   */
  function getActive(DataTypes.SupplyReserveConfig memory self) internal pure returns (bool) {
    return (self.data & ~ACTIVE_MASK) != 0;
  }

  /**
   * @notice Sets the frozen state of the reserve
   * @param self The reserve configuration
   * @param frozen The frozen state
   */
  function setFrozen(DataTypes.SupplyReserveConfig memory self, bool frozen) internal pure {
    self.data =
      (self.data & FROZEN_MASK) |
      (uint256(frozen ? 1 : 0) << IS_FROZEN_START_BIT_POSITION);
  }

  /**
   * @notice Gets the frozen state of the reserve
   * @param self The reserve configuration
   * @return The frozen state
   */
  function getFrozen(DataTypes.SupplyReserveConfig memory self) internal pure returns (bool) {
    return (self.data & ~FROZEN_MASK) != 0;
  }

  /**
   * @notice Sets the paused state of the reserve
   * @param self The reserve configuration
   * @param paused The paused state
   */
  function setPaused(DataTypes.SupplyReserveConfig memory self, bool paused) internal pure {
    self.data =
      (self.data & PAUSED_MASK) |
      (uint256(paused ? 1 : 0) << IS_PAUSED_START_BIT_POSITION);
  }

  /**
   * @notice Gets the paused state of the reserve
   * @param self The reserve configuration
   * @return The paused state
   */
  function getPaused(DataTypes.SupplyReserveConfig memory self) internal pure returns (bool) {
    return (self.data & ~PAUSED_MASK) != 0;
  }

  /**
   * @notice Enables or disables borrowing on the reserve
   * @param self The reserve configuration
   * @param enabled True if the borrowing needs to be enabled, false otherwise
   */
  function setBorrowingEnabled(
    DataTypes.SupplyReserveConfig memory self,
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
    DataTypes.SupplyReserveConfig memory self
  ) internal pure returns (bool) {
    return (self.data & ~BORROWABLE_MASK) != 0;
  }

  /**
   * @notice Sets the reserve factor of the reserve
   * @param self The reserve configuration
   * @param reserveFactor The reserve factor
   */
  function setReserveFactor(
    DataTypes.SupplyReserveConfig memory self,
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
    DataTypes.SupplyReserveConfig memory self
  ) internal pure returns (uint256) {
    return (self.data & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION;
  }

  /**
   * @notice Sets the draw cap of the reserve
   * @param self The reserve configuration
   * @param drawCap The draw cap
   */
  function setDrawCap(DataTypes.SupplyReserveConfig memory self, uint256 drawCap) internal pure {
    require(drawCap <= MAX_VALID_DRAW_CAP, Errors.INVALID_DRAW_CAP);

    self.data = (self.data & DRAW_CAP_MASK) | (drawCap << DRAW_CAP_START_BIT_POSITION);
  }

  /**
   * @notice Gets the draw cap of the reserve
   * @param self The reserve configuration
   * @return The draw cap
   */
  function getDrawCap(DataTypes.SupplyReserveConfig memory self) internal pure returns (uint256) {
    return (self.data & ~DRAW_CAP_MASK) >> DRAW_CAP_START_BIT_POSITION;
  }

  /**
   * @notice Sets the supply cap of the reserve
   * @param self The reserve configuration
   * @param supplyCap The supply cap
   */
  function setSupplyCap(
    DataTypes.SupplyReserveConfig memory self,
    uint256 supplyCap
  ) internal pure {
    require(supplyCap <= MAX_VALID_SUPPLY_CAP, Errors.INVALID_SUPPLY_CAP);

    self.data = (self.data & SUPPLY_CAP_MASK) | (supplyCap << SUPPLY_CAP_START_BIT_POSITION);
  }

  /**
   * @notice Gets the supply cap of the reserve
   * @param self The reserve configuration
   * @return The supply cap
   */
  function getSupplyCap(DataTypes.SupplyReserveConfig memory self) internal pure returns (uint256) {
    return (self.data & ~SUPPLY_CAP_MASK) >> SUPPLY_CAP_START_BIT_POSITION;
  }

  /**
   * @notice Sets the liquidity premium of the reserve
   * @param self The reserve configuration
   * @param liquidityPremium The liquidity premium
   */
  function setLiquidityPremium(
    DataTypes.SupplyReserveConfig memory self,
    uint256 liquidityPremium
  ) internal pure {
    require(liquidityPremium <= MAX_VALID_LIQUIDITY_PREMIUM, Errors.INVALID_LIQ_PREMIUM);

    self.data =
      (self.data & LIQUIDITY_PREMIUM_MASK) |
      (liquidityPremium << LIQUIDITY_PREMIUM_START_BIT_POSITION);
  }

  /**
   * @notice Gets the liquidity premium of the reserve
   * @param self The reserve configuration
   * @return The liquidity premium
   */
  function getLiquidityPremium(
    DataTypes.SupplyReserveConfig memory self
  ) internal pure returns (uint256) {
    return (self.data & ~LIQUIDITY_PREMIUM_MASK) >> LIQUIDITY_PREMIUM_START_BIT_POSITION;
  }

  /**
   * @notice Gets the configuration flags of the reserve
   * @param self The reserve configuration
   * @return The state flag representing active
   * @return The state flag representing borrowing enabled
   * @return The state flag representing frozen
   * @return The state flag representing paused
   */
  function getFlags(
    DataTypes.SupplyReserveConfig memory self
  ) internal pure returns (bool, bool, bool, bool) {
    uint256 dataLocal = self.data;

    return (
      (dataLocal & ~ACTIVE_MASK) != 0,
      (dataLocal & ~BORROWABLE_MASK) != 0,
      (dataLocal & ~FROZEN_MASK) != 0,
      (dataLocal & ~PAUSED_MASK) != 0
    );
  }

  /**
   * @notice Gets the configuration parameters of the reserve from storage
   * @param self The reserve configuration
   * @return The state param representing liquidation threshold
   * @return The state param representing liquidation bonus
   * @return The state param representing reserve factor
   */
  function getParams(
    DataTypes.SupplyReserveConfig memory self
  ) internal pure returns (uint256, uint256, uint256) {
    uint256 dataLocal = self.data;

    return (
      dataLocal & ~LIQUIDATION_THRESHOLD_MASK,
      (dataLocal & ~LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION,
      (dataLocal & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION
    );
  }

  /**
   * @notice Gets the caps parameters of the reserve from storage
   * @param self The reserve configuration
   * @return The state param representing draw cap
   * @return The state param representing supply cap.
   */
  function getCaps(
    DataTypes.SupplyReserveConfig memory self
  ) internal pure returns (uint256, uint256) {
    uint256 dataLocal = self.data;

    return (
      (dataLocal & ~DRAW_CAP_MASK) >> DRAW_CAP_START_BIT_POSITION,
      (dataLocal & ~SUPPLY_CAP_MASK) >> SUPPLY_CAP_START_BIT_POSITION
    );
  }

  function setConfigFromParams(
    DataTypes.SupplyReserveConfig memory self,
    DataTypes.SupplyReserveConfigurationParams memory params
  ) internal pure {
    setLiquidationThreshold(self, params.lt);
    setLiquidationBonus(self, params.lb);
    setReserveFactor(self, params.rf);
    setActive(self, params.active);
    setBorrowingEnabled(self, params.borrowable);
    setFrozen(self, params.frozen);
    setPaused(self, params.paused);
    setDrawCap(self, params.drawCap);
    setSupplyCap(self, params.supplyCap);
    setLiquidityPremium(self, params.liquidityPremium);
  }
}
