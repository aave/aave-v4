// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2 as console} from 'forge-std/console2.sol';

import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {PercentageMathExtended} from 'src/libraries/math/PercentageMathExtended.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {WadRayMathExtended} from 'src/libraries/math/WadRayMathExtended.sol';

library LiquidationLogic {
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;
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

    // otherwise, linearly interpolate between min and max
    return
      minLiquidationBonus +
      ((liquidationBonus - minLiquidationBonus) *
        (healthFactorLiquidationThreshold - healthFactor)) /
      (healthFactorLiquidationThreshold - config.healthFactorBonusThreshold);
  }

  /// @return The amount of debt to repay in the liquidation, in amount
  function calculateActualDebtToLiquidate(
    uint256 debtToCover,
    DataTypes.LiquidationCallLocalVars memory params
  ) internal pure returns (uint256) {
    DataTypes.CalculateActualDebtToLiquidateLocalVars memory vars;
    vars.maxLiquidatableDebt = params.totalDebt; // for current debt asset, in amount
    vars.closeFactorDebt = params.calculateCloseFactorDebt();

    console.log('LL params.totalDebt %e %e', vars.maxLiquidatableDebt, params.totalDebt);

    vars.maxLiquidatableDebt = vars.maxLiquidatableDebt > vars.closeFactorDebt
      ? vars.closeFactorDebt
      : vars.maxLiquidatableDebt;

    console.log(
      'LL params.totalDebt %e %e %e',
      vars.maxLiquidatableDebt,
      params.totalDebt,
      vars.closeFactorDebt
    );

    return debtToCover > vars.maxLiquidatableDebt ? vars.maxLiquidatableDebt : debtToCover;
  }

  /// @notice Calculates the repayable amount of debt required to restore a user health factor to the close factor.
  /// @dev If the effective liquidation penalty exceeds or equals the close factor, liquidation cannot improve the user position.
  /// @dev Function defaults to returning uint max.
  /// @param params LiquidationCallLocalVars params struct.
  /// @return The amount of debt to repay.
  function calculateCloseFactorDebt(
    DataTypes.LiquidationCallLocalVars memory params
  ) internal pure returns (uint256) {
    // Multiply the liquidation bonus by the collateral factor.
    // This represents the effective value loss from the user's collateral per unit of debt repaid.
    // Acts like an “effective penalty” from the user’s point of view.
    uint256 effectiveLiquidationPenalty = (params.liquidationBonus.wadify())
      .percentMul(params.collateralFactor)
      .fromBps();

    // Return default max uint if:
    // - penalty exceeds or equals the close factor, ie liquidation cannot restore solvency efficiently (negative denominator)
    // - debt asset price is 0
    if (params.closeFactor <= effectiveLiquidationPenalty || params.debtAssetPrice == 0) {
      return type(uint256).max;
    }

    console.log('params.closeFactor', params.closeFactor);

    uint256 closeFactorDebt = ((params.totalDebtInBaseCurrency.wadMul(params.closeFactor) -
      params.totalCollateralInBaseCurrency.percentMul(params.avgCollateralFactor.dewadify())) *
      params.debtAssetUnit) /
      ((params.closeFactor - effectiveLiquidationPenalty) * params.debtAssetPrice) +
      1; // add 1 to ensure HF > close factor

    console.log(
      'num %e %e',
      params.totalDebtInBaseCurrency.wadMul(params.closeFactor),
      params.totalCollateralInBaseCurrency.percentMul(params.avgCollateralFactor.dewadify())
    );

    console.log('denom %e %e', params.closeFactor, effectiveLiquidationPenalty);
    console.log('LL closeFactorDebt %e', closeFactorDebt);

    return closeFactorDebt;
  }

  /**
   * @return The maximum collateral amount that is possible to liquidate given all the liquidation config.
   * @return The debt amount to repay with the liquidation.
   * @return The fee amount taken from the liquidation bonus amount to be paid to the protocol.
   */
  function calculateAvailableCollateralToLiquidate(
    DataTypes.LiquidationCallLocalVars memory params
  ) internal pure returns (uint256, uint256, uint256) {
    DataTypes.CalculateAvailableCollateralToLiquidateLocalVars memory vars;

    // find collateral amount that corresponds to the debt to cover
    vars.baseCollateral =
      (params.debtAssetPrice * params.actualDebtToLiquidate * params.collateralAssetUnit) /
      (params.collateralAssetPrice * params.debtAssetUnit);

    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(params.liquidationBonus);

    console.log(
      'LL %e %e',
      (params.debtAssetPrice * params.actualDebtToLiquidate * params.collateralAssetUnit),
      (params.collateralAssetPrice * params.debtAssetUnit)
    );

    if (vars.maxCollateralToLiquidate > params.userCollateralBalance) {
      // back calculate debt amount needed to cover the max allowed collateral
      vars.collateralAmount = params.userCollateralBalance;
      vars.debtAmountNeeded = ((params.collateralAssetPrice *
        vars.collateralAmount *
        params.debtAssetUnit) / (params.debtAssetPrice * params.collateralAssetUnit)).percentDiv(
          params.liquidationBonus
        );
    } else {
      vars.collateralAmount = vars.maxCollateralToLiquidate;
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
