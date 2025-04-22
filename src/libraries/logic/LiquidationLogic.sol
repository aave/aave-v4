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
    vars.closeFactorDebt = params.calculateDebtToRestoreCloseFactor();

    vars.maxLiquidatableDebt = vars.maxLiquidatableDebt > vars.closeFactorDebt
      ? vars.closeFactorDebt
      : vars.maxLiquidatableDebt;

    return debtToCover > vars.maxLiquidatableDebt ? vars.maxLiquidatableDebt : debtToCover;
  }

  /// @notice Calculates the repayable amount of debt required to restore a user health factor to the close factor.
  /// @dev If the effective liquidation penalty exceeds or equals the close factor, liquidation cannot improve the user position.
  /// @dev Function defaults to returning uint max.
  /// @param params LiquidationCallLocalVars params struct.
  /// @return The amount of debt to repay.
  function calculateDebtToRestoreCloseFactor(
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
    if (params.closeFactor <= effectiveLiquidationPenalty) {
      return type(uint256).max;
    }

    // console.log(
    //   'LL totalDebtInBaseCurrency %e closeFactor %e healthFactor %e',
    //   params.totalDebtInBaseCurrency,
    //   params.closeFactor,
    //   params.healthFactor
    // );

    // console.log(
    //   'LL collateralFactor %e liquidationBonus %e effectiveLiquidationPenalty %e',
    //   params.collateralFactor,
    //   params.liquidationBonus,
    //   effectiveLiquidationPenalty
    // );

    // console.log(
    //   'LL num %e, den %e',
    //   params.totalDebtInBaseCurrency.wadMulUp(params.closeFactor - params.healthFactor),
    //   (params.closeFactor - effectiveLiquidationPenalty)
    // );

    // console.log(
    //   'LL debt to liq %e %e',
    //   (params.totalDebtInBaseCurrency.wadMulUp(params.closeFactor - params.healthFactor) *
    //     params.debtAssetUnit) /
    //     ((params.closeFactor - effectiveLiquidationPenalty) * params.debtAssetPrice),
    //   ((
    //     (params.totalDebtInBaseCurrency.wadMulUp(params.closeFactor - params.healthFactor) *
    //       params.debtAssetUnit).wadify()
    //   ) / ((params.closeFactor - effectiveLiquidationPenalty) * params.debtAssetPrice)).dewadify()
    // );

    // console.log(
    //   'debt amt %e',
    //   params.totalDebt.wadMulUp(params.closeFactor - params.healthFactor + 1e5).wadDiv(
    //     params.closeFactor - effectiveLiquidationPenalty
    //   )
    // );

    // return
    //   (params.totalDebtInBaseCurrency.wadMulUp(params.closeFactor - params.healthFactor) *
    //     params.debtAssetUnit) /
    //   ((params.closeFactor - effectiveLiquidationPenalty) * params.debtAssetPrice);

    return
      params.totalDebt.wadMulUp(params.closeFactor - params.healthFactor).wadDivUp(
        params.closeFactor - effectiveLiquidationPenalty
      );
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

    // convert collateral to base currency
    params.userCollateralBalanceinBaseCurrency =
      (params.userCollateralBalance * params.collateralAssetPrice).wadify() /
      params.collateralAssetUnit;

    // find collateral amount that corresponds to the debt to cover in base currency
    vars.baseCollateral =
      (params.actualDebtToLiquidate * params.debtAssetPrice).wadify() /
      params.debtAssetUnit;

    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(params.liquidationBonus);

    if (vars.maxCollateralToLiquidate > params.userCollateralBalanceinBaseCurrency) {
      console.log('maxCollateralToLiquidate > userCollateralBalance');
      // back calculate debt amount needed to cover the max allowed collateral
      vars.collateralAmount = params.userCollateralBalance;
      vars.debtAmountNeeded = ((params.collateralAssetPrice *
        vars.collateralAmount *
        params.debtAssetUnit) / (params.debtAssetPrice * params.collateralAssetUnit)).percentDiv(
          params.liquidationBonus
        );
    } else {
      console.log('maxCollateralToLiquidate <= userCollateralBalance');
      vars.collateralAmount = ((vars.maxCollateralToLiquidate * params.collateralAssetUnit) /
        params.collateralAssetPrice).dewadify();
      vars.debtAmountNeeded = params.actualDebtToLiquidate;
    }

    console.log(
      'LL availColl: coll %e debtamt needed %e',
      vars.collateralAmount,
      vars.debtAmountNeeded
    );

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
