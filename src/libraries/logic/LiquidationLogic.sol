// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

library LiquidationLogic {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using MathUtils for uint256;
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;

  function calculateVariableLiquidationBonus(
    DataTypes.LiquidationConfig storage config,
    uint256 healthFactor,
    uint256 liquidationBonus,
    uint256 healthFactorLiquidationThreshold
  ) internal view returns (uint256) {
    if (
      config.healthFactorForMaxBonus == 0 ||
      healthFactor <= config.healthFactorForMaxBonus ||
      config.liquidationBonusFactor == 0
    ) {
      return liquidationBonus;
    }
    uint256 minLiquidationBonus = (liquidationBonus - PercentageMath.PERCENTAGE_FACTOR)
      .percentMulDown(config.liquidationBonusFactor) + PercentageMath.PERCENTAGE_FACTOR;
    // if HF >= healthFactorLiquidationThreshold, liquidation bonus is min
    if (healthFactor >= healthFactorLiquidationThreshold) {
      return minLiquidationBonus;
    }

    // otherwise linearly interpolate between min and max
    return
      minLiquidationBonus +
      ((liquidationBonus - minLiquidationBonus) *
        (healthFactorLiquidationThreshold - healthFactor)) /
      (healthFactorLiquidationThreshold - config.healthFactorForMaxBonus);
  }

  /**
   * @notice Calculates the actual amount of debt possible to repay in the liquidation.
   * @dev The amount of debt to repay is capped by the total debt of the user and the amount of debt
   * @param debtToCover The amount of debt to cover.
   * @param params LiquidationCallLocalVars params struct.
   * @return The amount of debt to repay in the liquidation.
   */
  function calculateActualDebtToLiquidate(
    uint256 debtToCover,
    DataTypes.LiquidationCallLocalVars memory params
  ) internal pure returns (uint256) {
    uint256 maxLiquidatableDebt = params.totalDebt; // for current debt asset, in amount
    uint256 debtToRestoreCloseFactor = params.calculateDebtToRestoreCloseFactor();
    maxLiquidatableDebt = maxLiquidatableDebt.min(debtToRestoreCloseFactor);
    return debtToCover.min(maxLiquidatableDebt);
  }

  /**
   * @notice Calculates the amount of debt to liquidate to restore a user's health factor to the close factor.
   * @param params LiquidationCallLocalVars params struct.
   * @return The amount of debt asset to repay to restore health factor.
   */
  function calculateDebtToRestoreCloseFactor(
    DataTypes.LiquidationCallLocalVars memory params
  ) internal pure returns (uint256) {
    // represents the effective value loss from the collateral per unit of debt repaid
    // the greater the penalty, the more debt must be repaid to restore the user's health factor
    uint256 effectiveLiquidationPenalty = (params.liquidationBonus.toWad())
      .percentMulDown(params.collateralFactor)
      .fromBpsDown();

    // prevent underflow in denominator
    if (params.closeFactor < effectiveLiquidationPenalty) {
      return type(uint256).max;
    }

    // add 1 to denominator to round down, ensuring HF is always <= close factor
    return
      (((params.totalDebtInBaseCurrency * params.debtAssetUnit) *
        (params.closeFactor - params.healthFactor)) /
        ((params.closeFactor - effectiveLiquidationPenalty + 1) * params.debtAssetPrice))
        .fromWadDown();
  }

  /**
   * @notice Calculates the maximum amount of collateral that can be liquidated.
   * @param params LiquidationCallLocalVars params struct.
   * @return The maximum collateral amount that can be liquidated.
   * @return The corresponding debt amount to liquidate.
   * @return The protocol liquidation fee amount.
   */
  function calculateAvailableCollateralToLiquidate(
    DataTypes.LiquidationCallLocalVars memory params
  ) internal pure returns (uint256, uint256, uint256) {
    // convert existing collateral to base currency
    uint256 userCollateralBalanceInBaseCurrency = (params.userCollateralBalance *
      params.collateralAssetPrice).toWad() / params.collateralAssetUnit;

    // find collateral in base currency that corresponds to the debt to cover
    uint256 baseCollateral = (params.actualDebtToLiquidate * params.debtAssetPrice).toWad() /
      params.debtAssetUnit;

    // account for additional collateral required due to liquidation bonus
    uint256 maxCollateralToLiquidate = baseCollateral.percentMulDown(params.liquidationBonus);

    uint256 collateralAmount;
    uint256 debtAmountNeeded;
    if (maxCollateralToLiquidate >= userCollateralBalanceInBaseCurrency) {
      collateralAmount = params.userCollateralBalance;
      debtAmountNeeded = ((params.debtAssetUnit * userCollateralBalanceInBaseCurrency)
        .percentDivDown(params.liquidationBonus) / params.debtAssetPrice).fromWadDown();
    } else {
      // add 1 to round collateral amount up, ensuring HF is always <= close factor
      collateralAmount =
        ((maxCollateralToLiquidate * params.collateralAssetUnit) / params.collateralAssetPrice)
          .fromWadDown() +
        1;
      debtAmountNeeded = params.actualDebtToLiquidate;
    }

    if (params.liquidationFee != 0) {
      uint256 bonusCollateral = collateralAmount -
        collateralAmount.percentDivUp(params.liquidationBonus);
      uint256 liquidationFeeAmount = bonusCollateral.percentMulUp(params.liquidationFee);
      return (collateralAmount - liquidationFeeAmount, debtAmountNeeded, liquidationFeeAmount);
    } else {
      return (collateralAmount, debtAmountNeeded, 0);
    }
  }
}
