// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {WadRayMathExtended} from 'src/libraries/math/WadRayMathExtended.sol';

library LiquidationLogic {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using WadRayMathExtended for uint256;
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;

  function calculateVariableLiquidationBonus(
    DataTypes.LiquidationConfig storage config,
    uint256 healthFactor,
    uint256 liquidationBonus,
    uint256 healthFactorLiquidationThreshold
  ) internal view returns (uint256) {
    if (
      config.healthFactorBonusThreshold == 0 || healthFactor <= config.healthFactorBonusThreshold
    ) {
      return liquidationBonus;
    }
    uint256 minLiquidationBonus = (liquidationBonus - PercentageMath.PERCENTAGE_FACTOR).percentMul(
      config.liquidationBonusFactor
    ) + PercentageMath.PERCENTAGE_FACTOR;
    // if HF >= healthFactorLiquidationThreshold, liquidation bonus is min
    if (healthFactor >= healthFactorLiquidationThreshold) {
      return minLiquidationBonus;
    }

    // otherwise linearly interpolate between min and max
    return
      minLiquidationBonus +
      ((liquidationBonus - minLiquidationBonus) *
        (healthFactorLiquidationThreshold - healthFactor)) /
      (healthFactorLiquidationThreshold - config.healthFactorBonusThreshold);
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

    maxLiquidatableDebt = maxLiquidatableDebt > debtToRestoreCloseFactor
      ? debtToRestoreCloseFactor
      : maxLiquidatableDebt;

    return debtToCover > maxLiquidatableDebt ? maxLiquidatableDebt : debtToCover;
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
    uint256 effectiveLiquidationPenalty = (params.liquidationBonus.wadify())
      .percentMul(params.collateralFactor)
      .fromBps();

    // prevent underflow in denominator
    if (params.closeFactor < effectiveLiquidationPenalty) {
      return type(uint256).max;
    }

    // add 1 to denominator to round down, ensuring HF is always <= close factor
    uint256 debtToRestoreCloseFactor = (
      (params.totalDebtInBaseCurrency * params.debtAssetUnit)
        .wadMulDown(params.closeFactor - params.healthFactor)
        .wadDivDown(params.closeFactor - effectiveLiquidationPenalty + 1)
    ).dewadify() / params.debtAssetPrice;

    return debtToRestoreCloseFactor;
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
    DataTypes.CalculateAvailableCollateralToLiquidateLocalVars memory vars;

    // convert existing collateral to base currency
    vars.userCollateralBalanceInBaseCurrency =
      (params.userCollateralBalance * params.collateralAssetPrice).wadify() /
      params.collateralAssetUnit;

    // find collateral in base currency that corresponds to the debt to cover
    vars.baseCollateral =
      (params.actualDebtToLiquidate * params.debtAssetPrice).wadify() /
      params.debtAssetUnit;

    // account for additional collateral required due to liquidation bonus
    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(params.liquidationBonus);

    if (vars.maxCollateralToLiquidate > vars.userCollateralBalanceInBaseCurrency) {
      vars.collateralAmount = params.userCollateralBalance;
      vars.debtAmountNeeded = ((params.debtAssetUnit * vars.userCollateralBalanceInBaseCurrency)
        .percentDiv(params.liquidationBonus) / params.debtAssetPrice).dewadify();
    } else {
      // add 1 to round collateral amount up, ensuring HF is always <= close factor
      vars.collateralAmount =
        ((vars.maxCollateralToLiquidate * params.collateralAssetUnit) / params.collateralAssetPrice)
          .dewadify() +
        1;
      vars.debtAmountNeeded = params.actualDebtToLiquidate;
    }

    if (params.liquidationProtocolFeePercentage != 0) {
      vars.bonusCollateral =
        vars.collateralAmount -
        vars.collateralAmount.percentDiv(params.liquidationBonus);

      vars.liquidationProtocolFeeAmount = vars.bonusCollateral.percentMul(
        params.liquidationProtocolFeePercentage
      );

      return (
        vars.collateralAmount - vars.liquidationProtocolFeeAmount,
        vars.debtAmountNeeded,
        vars.liquidationProtocolFeeAmount
      );
    } else {
      return (vars.collateralAmount, vars.debtAmountNeeded, 0);
    }
  }
}
