// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
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

  /**
   * @dev This constant represents the minimum amount of assets in base currency that need to be leftover after a liquidation, if not clearing collateral on a position completely.
   * @notice The default value assumes that the basePrice is usd denominated by 26 decimals.
   */
  uint256 constant MIN_LEFTOVER_BASE = 1000e26;

  error MustNotLeaveDust();

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
      (liquidationBonus - minLiquidationBonus).mulDivDown(
        healthFactorLiquidationThreshold - healthFactor,
        healthFactorLiquidationThreshold - config.healthFactorForMaxBonus
      );
  }

  /**
   * @notice Calculates the actual amount of debt possible to repay in the liquidation.
   * @dev The amount of debt to repay is capped by the total debt of the user and the amount of debt.
   * @param params LiquidationCallLocalVars params struct.
   * @param debtToCover The amount of debt to cover.
   * @return The amount of debt to repay in the liquidation.
   */
  function calculateActualDebtToLiquidate(
    DataTypes.LiquidationCallLocalVars memory params,
    uint256 debtToCover
  ) internal pure returns (uint256) {
    uint256 maxLiquidatableDebt = debtToCover.min(params.totalBorrowerReserveDebt);
    uint256 actualDebtToLiquidate = maxLiquidatableDebt.min(params.debtToRestoreCloseFactor);

    if (actualDebtToLiquidate == params.totalBorrowerReserveDebt) {
      return actualDebtToLiquidate;
    }

    uint256 remainingDebtInBaseCurrency = (params.totalBorrowerReserveDebt - actualDebtToLiquidate)
      .mulDivDown(params.debtAssetPrice.toWad(), params.debtAssetUnit);

    // check for (non zero) debt dust remaining
    if (remainingDebtInBaseCurrency < MIN_LEFTOVER_BASE) {
      require(debtToCover >= params.totalBorrowerReserveDebt, MustNotLeaveDust());
      actualDebtToLiquidate = params.totalBorrowerReserveDebt;
    }

    return actualDebtToLiquidate;
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
    uint256 effectiveLiquidationPenalty = params.liquidationBonus.bpsToWad().percentMulDown(
      params.collateralFactor
    );

    // prevent underflow in denominator
    if (params.closeFactor < effectiveLiquidationPenalty) {
      return type(uint256).max;
    }

    // add 1 to denominator to round down, ensuring HF is always <= close factor
    return
      params.totalDebtInBaseCurrency.mulDivDown(
        params.debtAssetUnit * (params.closeFactor - params.healthFactor),
        (params.closeFactor - effectiveLiquidationPenalty + 1) * params.debtAssetPrice.toWad()
      );
  }

  /**
   * @notice Calculates the maximum amount of collateral that can be liquidated.
   * @param params LiquidationCallLocalVars params struct.
   * @return The maximum collateral amount that can be liquidated.
   * @return The corresponding debt amount to liquidate.
   * @return The protocol liquidation fee amount.
   * @return A boolean indicating if there is a deficit in the liquidation.
   */
  function calculateAvailableCollateralToLiquidate(
    DataTypes.LiquidationCallLocalVars memory params
  ) internal pure returns (uint256, uint256, uint256, bool) {
    DataTypes.CalculateAvailableCollateralToLiquidate memory vars;

    // convert existing collateral to base currency
    vars.borrowerCollateralBalanceInBaseCurrency = params.borrowerCollateralBalance.mulDivDown(
      params.collateralAssetPrice.toWad(),
      params.collateralAssetUnit
    );

    // find collateral in base currency that corresponds to the debt to cover
    vars.baseCollateral = (params.actualDebtToLiquidate * params.debtAssetPrice).wadDivUp(
      params.debtAssetUnit
    );

    // account for additional collateral required due to liquidation bonus
    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMulUp(params.liquidationBonus);

    if (vars.maxCollateralToLiquidate >= vars.borrowerCollateralBalanceInBaseCurrency) {
      vars.collateralAmount = params.borrowerCollateralBalance;
      vars.debtAmountNeeded = ((params.debtAssetUnit * vars.borrowerCollateralBalanceInBaseCurrency)
        .percentDivDown(params.liquidationBonus) / params.debtAssetPrice).fromWadDown();
      vars.collateralToLiquidateInBaseCurrency = vars.borrowerCollateralBalanceInBaseCurrency;
      vars.debtToLiquidateInBaseCurrency = vars.debtAmountNeeded.mulDivUp(
        params.debtAssetPrice.toWad(),
        params.debtAssetUnit
      );
    } else {
      vars.collateralAmount = vars.maxCollateralToLiquidate.mulDivUp(
        params.collateralAssetUnit,
        params.collateralAssetPrice.toWad()
      );
      vars.debtAmountNeeded = params.actualDebtToLiquidate;
      vars.collateralToLiquidateInBaseCurrency = vars.collateralAmount.mulDivDown(
        params.collateralAssetPrice.toWad(),
        params.collateralAssetUnit
      );
      vars.debtToLiquidateInBaseCurrency = vars.baseCollateral;
    }

    vars.hasDeficit =
      vars.debtToLiquidateInBaseCurrency < params.totalDebtInBaseCurrency &&
      vars.collateralToLiquidateInBaseCurrency == params.totalCollateralInBaseCurrency;

    if (params.liquidationFee != 0) {
      uint256 bonusCollateral = vars.collateralAmount -
        vars.collateralAmount.percentDivUp(params.liquidationBonus);
      uint256 liquidationFeeAmount = bonusCollateral.percentMulUp(params.liquidationFee);
      return (
        vars.collateralAmount - liquidationFeeAmount,
        vars.debtAmountNeeded,
        liquidationFeeAmount,
        vars.hasDeficit
      );
    } else {
      return (vars.collateralAmount, vars.debtAmountNeeded, 0, vars.hasDeficit);
    }
  }
}
