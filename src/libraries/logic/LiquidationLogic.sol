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
    vars.debtToRestoreCloseFactor = params.calculateDebtToRestoreCloseFactor();

    vars.maxLiquidatableDebt = vars.maxLiquidatableDebt > vars.debtToRestoreCloseFactor
      ? vars.debtToRestoreCloseFactor
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
    // represents the effective value loss from the collateral per unit of debt repaid
    // the greater the penalty, the more debt must be repaid to restore the user's health factor
    uint256 effectiveLiquidationPenalty = (params.liquidationBonus.wadify())
      .percentMul(params.collateralFactor)
      .fromBps();

    console.log(
      'LL: LB %e | CF %e',
      params.liquidationBonus,
      params.collateralFactor,
      params.healthFactor
    );

    // Return default max uint if:
    // - penalty exceeds or equals the close factor, ie liquidation cannot restore solvency efficiently (negative denominator)
    if (params.closeFactor < effectiveLiquidationPenalty) {
      return type(uint256).max;
    }

    // convert total debt across all assets into amount of current debt asset
    uint256 totalDebtAmount = (params.totalDebtInBaseCurrency.dewadify() * params.debtAssetUnit) /
      params.debtAssetPrice;

    // effectiveLiquidationPenalty = (params.liquidationBonus.percentMul(params.collateralFactor) - 1)
    //   .wadify()
    //   .fromBps();

    // console.log(
    //   'effectiveLiquidationPenalty',
    //   effectiveLiquidationPenalty,
    //   (params.liquidationBonus.percentMul(params.collateralFactor)).wadify().fromBps()
    // );

    // add 1 to denominator to round down, ensuring HF is always <= close factor
    uint256 debtToRestoreCloseFactor = totalDebtAmount.wadMulDown(
      ((params.closeFactor - params.healthFactor)).wadDivDown(
        (params.closeFactor - effectiveLiquidationPenalty + 1)
      )
    );

    // uint prev = (params.totalDebtInBaseCurrency.wadMulUp(params.closeFactor - params.healthFactor) *
    //   params.debtAssetUnit) /
    //   (((params.closeFactor - effectiveLiquidationPenalty) * params.debtAssetPrice)) +
    //   1;

    // console.log('LL after cmp prev %e new %e', prev, closeFactorDebt);

    return debtToRestoreCloseFactor;
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
    vars.userCollateralBalanceinBaseCurrency =
      (params.userCollateralBalance * params.collateralAssetPrice).wadify() /
      params.collateralAssetUnit;

    // find collateral in base currency that corresponds to the debt to cover
    vars.baseCollateral =
      (params.actualDebtToLiquidate * params.debtAssetPrice).wadify() /
      params.debtAssetUnit;

    // account for additional collateral required due to liquidation bonus
    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(params.liquidationBonus);

    console.log(
      'LL userCollateralBalanceinBaseCurrency %e | baseCollateral %e | maxCollateralToLiquidate %e',
      vars.userCollateralBalanceinBaseCurrency,
      vars.baseCollateral,
      vars.maxCollateralToLiquidate
    );

    if (vars.maxCollateralToLiquidate > vars.userCollateralBalanceinBaseCurrency) {
      console.log('maxCollateralToLiquidate > userCollateralBalance');
      vars.collateralAmount = params.userCollateralBalance;
      // back calculate debt amount needed to cover the max allowed collateral
      vars.debtAmountNeeded = ((params.debtAssetUnit *
        vars.userCollateralBalanceinBaseCurrency.dewadify()) / (params.debtAssetPrice)).percentDiv(
          params.liquidationBonus
        );
    } else {
      console.log('maxCollateralToLiquidate <= userCollateralBalance');
      // add 1 to reduce remaining collateral to ensure HF is always <= close factor
      vars.collateralAmount =
        ((vars.maxCollateralToLiquidate * params.collateralAssetUnit) / params.collateralAssetPrice)
          .dewadify() +
        1;
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

      console.log('LL bonus coll %e', vars.bonusCollateral);

      vars.liquidationProtocolFeeAmount = vars.bonusCollateral.percentMul(
        params.liquidationProtocolFeePercentage
      );

      console.log(
        'LL protocol fee %e lpfp: %e',
        vars.liquidationProtocolFeeAmount,
        params.liquidationProtocolFeePercentage
      );

      console.log(
        'LL coll amt %e | debt amt %e',
        vars.collateralAmount - vars.liquidationProtocolFeeAmount,
        vars.debtAmountNeeded
      );
      return (
        vars.collateralAmount - vars.liquidationProtocolFeeAmount,
        vars.debtAmountNeeded,
        vars.liquidationProtocolFeeAmount
      );
    } else {
      console.log('LL coll amt %e | debt amt %e', vars.collateralAmount, vars.debtAmountNeeded);
      return (vars.collateralAmount, vars.debtAmountNeeded, 0);
    }
  }

  // function calculateAvailableCollateralToLiquidate(
  //   DataTypes.LiquidationCallLocalVars memory params
  // ) internal pure returns (uint256, uint256, uint256) {
  //   DataTypes.CalculateAvailableCollateralToLiquidateLocalVars memory vars;

  //   // find collateral amount that corresponds to the debt to cover
  //   vars.baseCollateral =
  //     (params.debtAssetPrice * params.actualDebtToLiquidate * params.collateralAssetUnit) /
  //     (params.collateralAssetPrice * params.debtAssetUnit);

  //   vars.maxCollateralToLiquidate = vars.baseCollateral.percentMul(params.liquidationBonus);

  //   if (vars.maxCollateralToLiquidate > params.userCollateralBalance) {
  //     // back calculate debt amount needed to cover the max allowed collateral
  //     vars.collateralAmount = params.userCollateralBalance;
  //     vars.debtAmountNeeded = ((params.collateralAssetPrice *
  //       vars.collateralAmount *
  //       params.debtAssetUnit) / (params.debtAssetPrice * params.collateralAssetUnit)).percentDiv(
  //         params.liquidationBonus
  //       );
  //   } else {
  //     vars.collateralAmount = vars.maxCollateralToLiquidate;
  //     vars.debtAmountNeeded = params.actualDebtToLiquidate;
  //   }

  //   if (params.liquidationProtocolFeePercentage != 0) {
  //     vars.bonusCollateral =
  //       vars.collateralAmount -
  //       vars.collateralAmount.percentDiv(params.liquidationBonus);

  //     vars.liquidationProtocolFeeAmount = vars.bonusCollateral.percentMul(
  //       params.liquidationProtocolFeePercentage
  //     );

  //     return (
  //       vars.collateralAmount - vars.liquidationProtocolFeeAmount,
  //       vars.debtAmountNeeded,
  //       vars.liquidationProtocolFeeAmount
  //     );
  //   } else {
  //     return (vars.collateralAmount, vars.debtAmountNeeded, 0);
  //   }
  // }
}
