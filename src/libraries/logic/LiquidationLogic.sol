// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IHub} from 'src/interfaces/IHub.sol';
import {ISpoke, ISpokeBase} from 'src/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/interfaces/IAaveOracle.sol';
import {Constants} from 'src/libraries/helpers/Constants.sol';
import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';

library LiquidationLogic {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using MathUtils for *;
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;
  using LiquidationLogic for DataTypes.LiquidationConfig;
  using SafeCast for *;
  using PositionStatus for DataTypes.PositionStatus;

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

  function executeLiquidationCall(
    DataTypes.Reserve storage collateralReserve,
    DataTypes.Reserve storage debtReserve,
    DataTypes.UserPosition storage collateralPosition,
    DataTypes.UserPosition storage debtPosition,
    DataTypes.DynamicReserveConfig storage collateralDynConfig,
    DataTypes.PositionStatus storage positionStatus,
    DataTypes.LiquidationConfig storage liquidationConfig,
    DataTypes.LiquidationCallParams memory params
  ) external returns (bool) {
    DataTypes.ExecuteLiquidationLocalVars memory vars;

    vars.collateralReserveHub = collateralReserve.hub;
    vars.collateralAssetId = collateralReserve.assetId;
    vars.debtReserveHub = debtReserve.hub;
    vars.debtAssetId = debtReserve.assetId;

    (vars.drawnDebt, vars.premiumDebt, vars.accruedPremium) = _getUserDebt(
      vars.debtReserveHub,
      vars.debtAssetId,
      debtPosition
    );

    (
      vars.collateralToLiquidate,
      vars.liquidationFeeAmount,
      vars.drawnDebtToLiquidate,
      vars.premiumDebtToLiquidate,
      vars.hasDeficit
    ) = _calculateLiquidationParameters(
      collateralReserve,
      debtReserve,
      collateralDynConfig,
      liquidationConfig,
      positionStatus,
      collateralPosition,
      DataTypes.CalculateLiquidationParametersParams({
        oracle: params.oracle,
        collateralReserveId: params.collateralReserveId,
        debtReserveId: params.debtReserveId,
        debtToCover: params.debtToCover,
        drawnReserveDebt: vars.drawnDebt,
        premiumReserveDebt: vars.premiumDebt,
        healthFactor: params.healthFactor,
        totalCollateralInBaseCurrency: params.totalCollateralInBaseCurrency,
        totalDebtInBaseCurrency: params.totalDebtInBaseCurrency
      })
    );

    // expected total withdrawn shares includes liquidation fee
    vars.withdrawnShares = vars.collateralReserveHub.previewRemoveByAssets(
      vars.collateralAssetId,
      vars.liquidationFeeAmount + vars.collateralToLiquidate
    );

    // perform collateral accounting first so that restore donations can not affect collateral shares calcs
    // in case the same reserve is being repaid and liquidated
    collateralPosition.suppliedShares -= vars.withdrawnShares.toUint128();

    // remove collateral, send liquidated collateral directly to liquidator
    vars.liquidatedSuppliedShares = vars.collateralReserveHub.remove(
      vars.collateralAssetId,
      vars.collateralToLiquidate,
      params.liquidator
    );

    // repay debt
    {
      vars.premiumDelta = DataTypes.PremiumDelta({
        sharesDelta: -debtPosition.premiumShares.toInt256(),
        offsetDelta: -debtPosition.premiumOffset.toInt256(),
        realizedDelta: vars.accruedPremium.toInt256() - vars.premiumDebtToLiquidate.toInt256()
      });
      vars.restoredShares = vars.debtReserveHub.restore(
        vars.debtAssetId,
        vars.drawnDebtToLiquidate,
        vars.premiumDebtToLiquidate,
        vars.premiumDelta,
        params.liquidator
      );
      // debt accounting
      _settlePremiumDebt(debtPosition, vars.premiumDelta);
      debtPosition.drawnShares -= vars.restoredShares.toUint128();
    }

    if (debtPosition.drawnShares == 0) {
      positionStatus.setBorrowing(params.debtReserveId, false);
    }

    if (vars.withdrawnShares > vars.liquidatedSuppliedShares) {
      vars.collateralReserveHub.payFee(
        vars.collateralAssetId,
        vars.withdrawnShares - vars.liquidatedSuppliedShares
      );
    }

    emit ISpokeBase.LiquidationCall(
      params.collateralReserveId,
      params.debtReserveId,
      params.user,
      vars.drawnDebtToLiquidate + vars.premiumDebtToLiquidate,
      vars.collateralToLiquidate,
      params.liquidator
    );

    return vars.hasDeficit;
  }

  /**
   * @dev Calculates the liquidation parameters for a user being liquidated.
   * @param collateralReserve The collateral reserve being liquidated.
   * @param debtReserve The debt reserve being repaid during liquidation.
   * @param collateralDynConfig The dynamic config of the collateral reserve.
   * @param liquidationConfig The liquidation config of the spoke.
   * @param positionStatus The position status of the user.
   * @param collateralPosition The collateral position of the user.
   * @param params The parameters for the liquidation call.
   */
  function _calculateLiquidationParameters(
    DataTypes.Reserve storage collateralReserve,
    DataTypes.Reserve storage debtReserve,
    DataTypes.DynamicReserveConfig storage collateralDynConfig,
    DataTypes.LiquidationConfig storage liquidationConfig,
    DataTypes.PositionStatus storage positionStatus,
    DataTypes.UserPosition storage collateralPosition,
    DataTypes.CalculateLiquidationParametersParams memory params
  ) internal view returns (uint256, uint256, uint256, uint256, bool) {
    DataTypes.LiquidationCallLocalVars memory vars;
    vars.collateralReserveId = params.collateralReserveId;
    vars.debtReserveId = params.debtReserveId;
    vars.borrowerCollateralBalance = collateralReserve.hub.previewRemoveByShares(
      collateralReserve.assetId,
      collateralPosition.suppliedShares
    );
    vars.totalBorrowerReserveDebt = params.drawnReserveDebt + params.premiumReserveDebt;
    vars.collateralFactor = collateralDynConfig.collateralFactor;

    vars.healthFactor = params.healthFactor;
    vars.totalCollateralInBaseCurrency = params.totalCollateralInBaseCurrency;
    vars.totalDebtInBaseCurrency = params.totalDebtInBaseCurrency;

    _validateLiquidationCall(
      collateralReserve,
      debtReserve,
      positionStatus,
      params.collateralReserveId,
      params.debtToCover,
      vars.totalBorrowerReserveDebt,
      vars.healthFactor,
      vars.collateralFactor
    );

    vars.debtAssetPrice = IAaveOracle(params.oracle).getReservePrice(params.debtReserveId);
    vars.debtAssetUnit = 10 ** debtReserve.decimals;
    vars.liquidationBonus = liquidationConfig.calculateVariableLiquidationBonus(
      vars.healthFactor,
      collateralDynConfig.liquidationBonus,
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    vars.closeFactor = liquidationConfig.closeFactor;
    vars.collateralAssetPrice = IAaveOracle(params.oracle).getReservePrice(
      params.collateralReserveId
    );
    vars.collateralAssetUnit = 10 ** collateralReserve.decimals;
    vars.liquidationFee = collateralDynConfig.liquidationFee;
    vars.debtToRestoreCloseFactor = vars.calculateDebtToRestoreCloseFactor();
    vars.actualDebtToLiquidate = vars.calculateActualDebtToLiquidate(params.debtToCover);
    (
      vars.actualCollateralToLiquidate,
      vars.actualDebtToLiquidate,
      vars.liquidationFeeAmount,
      vars.hasDeficit
    ) = vars.calculateAvailableCollateralToLiquidate();

    (vars.drawnDebtToLiquidate, vars.premiumDebtToLiquidate) = _calculateRestoreAmount(
      params.drawnReserveDebt,
      params.premiumReserveDebt,
      vars.actualDebtToLiquidate
    );

    return (
      vars.actualCollateralToLiquidate,
      vars.liquidationFeeAmount,
      vars.drawnDebtToLiquidate,
      vars.premiumDebtToLiquidate,
      vars.hasDeficit
    );
  }

  function _getUserDebt(
    IHub hub,
    uint256 assetId,
    DataTypes.UserPosition storage userPosition
  ) internal view returns (uint256, uint256, uint256) {
    uint256 accruedPremium = hub.previewRestoreByShares(assetId, userPosition.premiumShares) -
      userPosition.premiumOffset;
    return (
      hub.previewRestoreByShares(assetId, userPosition.drawnShares),
      userPosition.realizedPremium + accruedPremium,
      accruedPremium
    );
  }

  // @dev allows donation on drawn debt
  function _calculateRestoreAmount(
    uint256 drawnDebt,
    uint256 premiumDebt,
    uint256 amount
  ) internal pure returns (uint256, uint256) {
    if (amount >= drawnDebt + premiumDebt) {
      return (drawnDebt, premiumDebt);
    }
    if (amount <= premiumDebt) {
      return (0, amount);
    }
    return (amount - premiumDebt, premiumDebt);
  }

  function _validateLiquidationCall(
    DataTypes.Reserve storage collateralReserve,
    DataTypes.Reserve storage debtReserve,
    DataTypes.PositionStatus storage positionStatus,
    uint256 collateralReserveId,
    uint256 debtToCover,
    uint256 totalDebt,
    uint256 healthFactor,
    uint256 collateralFactor
  ) internal view {
    require(debtToCover > 0, ISpoke.InvalidDebtToCover());
    require(
      address(collateralReserve.hub) != address(0) && address(debtReserve.hub) != address(0),
      ISpoke.ReserveNotListed()
    );
    require(!collateralReserve.paused && !debtReserve.paused, ISpoke.ReservePaused());
    require(
      healthFactor < Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      ISpoke.HealthFactorNotBelowThreshold()
    );
    bool isCollateralEnabled = positionStatus.isUsingAsCollateral(collateralReserveId) &&
      collateralFactor != 0;
    require(isCollateralEnabled, ISpoke.CollateralCannotBeLiquidated());
    require(totalDebt > 0, ISpoke.SpecifiedCurrencyNotBorrowedByUser());
  }

  function _settlePremiumDebt(
    DataTypes.UserPosition storage debtPosition,
    DataTypes.PremiumDelta memory premiumDelta
  ) internal {
    debtPosition.premiumShares = 0;
    debtPosition.premiumOffset = 0;
    debtPosition.realizedPremium = debtPosition
      .realizedPremium
      .add(premiumDelta.realizedDelta)
      .toUint128();
  }
}
