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

// TODO: rename asset price to reserve price

library LiquidationLogic {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using MathUtils for *;
  using SafeCast for *;
  using PositionStatus for DataTypes.PositionStatus;

  struct ValidateLiquidationCallParams {
    uint256 debtToCover;
    address collateralReserveHub;
    address debtReserveHub;
    bool collateralReservePaused;
    bool debtReservePaused;
    uint256 healthFactor;
    bool isUsingAsCollateral;
    uint256 collateralFactor;
    uint256 totalDebt;
  }

  struct CalculateDebtToRestoreCloseFactorParams {
    uint256 totalDebtInBaseCurrency;
    uint256 healthFactor;
    uint256 closeFactor;
    uint256 variableLiquidationBonus;
    uint256 collateralFactor;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
  }

  struct CalculateMaxDebtToLiquidateParams {
    uint256 totalReserveDebt;
    uint256 debtToCover;
    uint256 totalDebtInBaseCurrency;
    uint256 healthFactor;
    uint256 closeFactor;
    uint256 variableLiquidationBonus;
    uint256 collateralFactor;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
  }

  struct CalculateLiquidationAmountsParams {
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
    uint256 totalReserveDebt;
    uint256 totalReserveCollateral;
    uint256 debtToCover;
    uint256 totalDebtInBaseCurrency;
    uint256 healthFactor;
    uint256 closeFactor;
    uint256 liquidationBonus;
    uint256 collateralFactor;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
    uint256 collateralAssetPrice;
    uint256 collateralAssetUnit;
    uint256 liquidationFee;
  }

  struct AssessDeficitParams {
    bool isCollateralPositionEmpty;
    bool isDebtPositionEmpty;
    uint256 suppliedAssetsCount;
    uint256 borrowedAssetsCount;
  }

  struct LiquidateDebtParams {
    uint256 reserveId;
    uint256 debtToLiquidate;
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 accruedPremium;
    address liquidator;
  }

  struct LiquidateCollateralParams {
    uint256 reserveCollateral;
    uint256 collateralToLiquidate;
    uint256 collateralToLiquidator;
    address liquidator;
  }

  /**
   * @dev This constant represents the minimum amount of assets in base currency that need to be leftover after a liquidation, if not clearing collateral on a position completely.
   * @notice The default value assumes that the basePrice is usd denominated by 26 decimals.
   */
  uint256 constant MIN_LEFTOVER_BASE = 1000e26;

  error HealthFactorNotBelowThreshold();
  error MustNotLeaveDust();
  error InvalidDebtToCover();

  function calculateVariableLiquidationBonus(
    DataTypes.CalculateVariableLiquidationBonusParams memory params
  ) internal pure returns (uint256) {
    if (params.healthFactor <= params.healthFactorForMaxBonus) {
      return params.liquidationBonus;
    }

    uint256 minLiquidationBonus = (params.liquidationBonus - PercentageMath.PERCENTAGE_FACTOR)
      .percentMulDown(params.liquidationBonusFactor) + PercentageMath.PERCENTAGE_FACTOR;

    // otherwise linearly interpolate between min and max
    return
      minLiquidationBonus +
      (params.liquidationBonus - minLiquidationBonus).mulDivDown(
        Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD - params.healthFactor,
        Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD - params.healthFactorForMaxBonus
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

  function _validateLiquidationCall(ValidateLiquidationCallParams memory params) internal pure {
    require(params.debtToCover > 0, InvalidDebtToCover());
    require(
      params.collateralReserveHub != address(0) && params.debtReserveHub != address(0),
      ISpoke.ReserveNotListed()
    );
    require(!params.collateralReservePaused && !params.debtReservePaused, ISpoke.ReservePaused());
    require(
      params.healthFactor < Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      HealthFactorNotBelowThreshold()
    );
    require(
      params.isUsingAsCollateral && params.collateralFactor != 0,
      ISpoke.CollateralCannotBeLiquidated()
    );
    require(params.totalDebt > 0, ISpoke.SpecifiedCurrencyNotBorrowedByUser());
  }

  function _calculateDebtToRestoreCloseFactor(
    CalculateDebtToRestoreCloseFactorParams memory params
  ) internal pure returns (uint256) {
    uint256 liquidationPenalty = params.variableLiquidationBonus.bpsToWad().percentMulUp(
      params.collateralFactor
    );

    return
      params.totalDebtInBaseCurrency.mulDivUp(
        params.debtAssetUnit * (params.closeFactor - params.healthFactor),
        (params.closeFactor - liquidationPenalty) * params.debtAssetPrice.toWad()
      );
  }

  function _calculateMaxDebtToLiquidate(
    CalculateMaxDebtToLiquidateParams memory params
  ) internal pure returns (uint256) {
    uint256 maxDebtToLiquidate = params.totalReserveDebt;
    if (params.debtToCover < maxDebtToLiquidate) {
      maxDebtToLiquidate = params.debtToCover;
    }

    uint256 debtToRestoreCloseFactor = _calculateDebtToRestoreCloseFactor(
      CalculateDebtToRestoreCloseFactorParams({
        totalDebtInBaseCurrency: params.totalDebtInBaseCurrency,
        healthFactor: params.healthFactor,
        closeFactor: params.closeFactor,
        variableLiquidationBonus: params.variableLiquidationBonus,
        collateralFactor: params.collateralFactor,
        debtAssetPrice: params.debtAssetPrice,
        debtAssetUnit: params.debtAssetUnit
      })
    );
    if (debtToRestoreCloseFactor < maxDebtToLiquidate) {
      maxDebtToLiquidate = debtToRestoreCloseFactor;
    }

    uint256 remainingDebtInBaseCurrency = (params.totalReserveDebt - maxDebtToLiquidate).mulDivDown(
      params.debtAssetPrice.toWad(),
      params.debtAssetUnit
    );

    if (remainingDebtInBaseCurrency < MIN_LEFTOVER_BASE) {
      require(params.debtToCover >= params.totalReserveDebt, MustNotLeaveDust());
      maxDebtToLiquidate = params.totalReserveDebt;
    }

    return maxDebtToLiquidate;
  }

  function _calculateLiquidationAmounts(
    CalculateLiquidationAmountsParams memory params
  ) internal pure returns (uint256, uint256, uint256) {
    uint256 variableLiquidationBonus = calculateVariableLiquidationBonus(
      DataTypes.CalculateVariableLiquidationBonusParams({
        healthFactorForMaxBonus: params.healthFactorForMaxBonus,
        liquidationBonusFactor: params.liquidationBonusFactor,
        healthFactor: params.healthFactor,
        liquidationBonus: params.liquidationBonus
      })
    );

    uint256 debtToLiquidate = _calculateMaxDebtToLiquidate(
      CalculateMaxDebtToLiquidateParams({
        totalReserveDebt: params.totalReserveDebt,
        debtToCover: params.debtToCover,
        totalDebtInBaseCurrency: params.totalDebtInBaseCurrency,
        healthFactor: params.healthFactor,
        closeFactor: params.closeFactor,
        variableLiquidationBonus: variableLiquidationBonus,
        collateralFactor: params.collateralFactor,
        debtAssetPrice: params.debtAssetPrice,
        debtAssetUnit: params.debtAssetUnit
      })
    );

    uint256 debtToCollateral = debtToLiquidate.mulDivDown(
      params.debtAssetPrice * params.collateralAssetUnit,
      params.debtAssetUnit * params.collateralAssetPrice
    );
    uint256 collateralToLiquidate = debtToCollateral.percentMulDown(variableLiquidationBonus);
    if (collateralToLiquidate > params.totalReserveCollateral) {
      collateralToLiquidate = params.totalReserveCollateral;
      debtToCollateral = collateralToLiquidate.percentDivUp(variableLiquidationBonus);
      debtToLiquidate = debtToCollateral.mulDivUp(
        params.collateralAssetPrice * params.debtAssetUnit,
        params.debtAssetPrice * params.collateralAssetUnit
      );
    }

    uint256 collateralToLiquidator = collateralToLiquidate -
      (collateralToLiquidate - debtToCollateral).percentMulUp(params.liquidationFee);

    return (collateralToLiquidate, collateralToLiquidator, debtToLiquidate);
  }

  function _assessDeficit(AssessDeficitParams memory params) internal pure returns (bool) {
    if (!params.isCollateralPositionEmpty || params.suppliedAssetsCount > 1) {
      return false;
    }

    return !params.isDebtPositionEmpty || params.borrowedAssetsCount > 1;
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

  function _liquidateCollateral(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage position,
    LiquidateCollateralParams memory params
  ) internal returns (bool) {
    bool isPositionEmpty;

    IHub hub = reserve.hub;
    uint256 assetId = reserve.assetId;

    uint256 sharesToLiquidate = hub.previewRemoveByAssets(assetId, params.collateralToLiquidate);

    uint256 sharesToLiquidator = hub.previewRemoveByAssets(assetId, params.collateralToLiquidator);

    if (params.collateralToLiquidate < params.reserveCollateral) {
      if (sharesToLiquidate > 0) {
        sharesToLiquidate -= 1;
      }
      if (sharesToLiquidator > 0) {
        sharesToLiquidator -= 1;
      }
    } else {
      isPositionEmpty = true;
    }

    position.suppliedShares -= sharesToLiquidate.toUint128();

    hub.remove(assetId, hub.previewRemoveByShares(assetId, sharesToLiquidator), params.liquidator);

    if (sharesToLiquidate > sharesToLiquidator) {
      hub.payFee(assetId, sharesToLiquidate - sharesToLiquidator);
    }

    return isPositionEmpty;
  }

  function _liquidateDebt(
    DataTypes.Reserve storage reserve,
    DataTypes.UserPosition storage position,
    DataTypes.PositionStatus storage positionStatus,
    LiquidateDebtParams memory params
  ) internal returns (bool) {
    {
      (uint256 drawnDebtToLiquidate, uint256 premiumDebtToLiquidate) = _calculateRestoreAmount(
        params.drawnDebt,
        params.premiumDebt,
        params.debtToLiquidate
      );

      DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
        sharesDelta: -position.premiumShares.toInt256(),
        offsetDelta: -position.premiumOffset.toInt256(),
        realizedDelta: params.accruedPremium.toInt256() - premiumDebtToLiquidate.toInt256()
      });

      IHub hub = reserve.hub;
      uint256 assetId = reserve.assetId;

      uint256 drawnSharesToLiquidate = hub.previewRestoreByAssets(assetId, drawnDebtToLiquidate) +
        1;
      drawnDebtToLiquidate = hub.previewRestoreByShares(assetId, drawnSharesToLiquidate);
      if (drawnDebtToLiquidate > params.drawnDebt) {
        drawnSharesToLiquidate -= 1;
        drawnDebtToLiquidate = params.drawnDebt;
      }

      hub.restore(
        assetId,
        drawnDebtToLiquidate,
        premiumDebtToLiquidate,
        premiumDelta,
        params.liquidator
      );
      // debt accounting
      _settlePremiumDebt(position, premiumDelta);
      position.drawnShares -= drawnSharesToLiquidate.toUint128();
    }

    if (position.drawnShares == 0) {
      positionStatus.setBorrowing(params.reserveId, false);
      return true;
    }

    return false;
  }

  function _liquidateUser(
    DataTypes.Reserve storage collateralReserve,
    DataTypes.Reserve storage debtReserve,
    DataTypes.UserPosition storage collateralPosition,
    DataTypes.UserPosition storage debtPosition,
    DataTypes.PositionStatus storage positionStatus,
    DataTypes.LiquidationConfig storage liquidationConfig,
    DataTypes.DynamicReserveConfig storage collateralDynConfig,
    DataTypes.LiquidateUserParams memory params
  ) external returns (bool) {
    IHub collateralHub = collateralReserve.hub;
    _validateLiquidationCall(
      ValidateLiquidationCallParams({
        debtToCover: params.debtToCover,
        collateralReserveHub: address(collateralHub),
        debtReserveHub: address(debtReserve.hub),
        collateralReservePaused: collateralReserve.paused,
        debtReservePaused: debtReserve.paused,
        healthFactor: params.healthFactor,
        isUsingAsCollateral: positionStatus.isUsingAsCollateral(params.collateralReserveId),
        collateralFactor: collateralDynConfig.collateralFactor,
        totalDebt: params.drawnDebt + params.premiumDebt
      })
    );

    CalculateLiquidationAmountsParams
      memory calculateLiquidationAmountsParams = CalculateLiquidationAmountsParams({
        healthFactorForMaxBonus: liquidationConfig.healthFactorForMaxBonus,
        liquidationBonusFactor: liquidationConfig.liquidationBonusFactor,
        totalReserveDebt: params.drawnDebt + params.premiumDebt,
        totalReserveCollateral: collateralHub.previewRemoveByShares(
          collateralReserve.assetId,
          collateralPosition.suppliedShares
        ),
        debtToCover: params.debtToCover,
        totalDebtInBaseCurrency: params.totalDebtInBaseCurrency,
        healthFactor: params.healthFactor,
        closeFactor: liquidationConfig.closeFactor,
        liquidationBonus: collateralDynConfig.liquidationBonus,
        collateralFactor: collateralDynConfig.collateralFactor,
        debtAssetPrice: IAaveOracle(params.oracle).getReservePrice(params.debtReserveId),
        debtAssetUnit: 10 ** debtReserve.decimals,
        collateralAssetPrice: IAaveOracle(params.oracle).getReservePrice(
          params.collateralReserveId
        ),
        collateralAssetUnit: 10 ** collateralReserve.decimals,
        liquidationFee: collateralDynConfig.liquidationFee
      });

    (
      uint256 collateralToLiquidate,
      uint256 collateralToLiquidator,
      uint256 debtToLiquidate
    ) = _calculateLiquidationAmounts(calculateLiquidationAmountsParams);

    bool isCollateralPositionEmpty = _liquidateCollateral(
      collateralReserve,
      collateralPosition,
      LiquidateCollateralParams({
        reserveCollateral: calculateLiquidationAmountsParams.totalReserveCollateral,
        collateralToLiquidate: collateralToLiquidate,
        collateralToLiquidator: collateralToLiquidator,
        liquidator: params.liquidator
      })
    );

    bool isDebtPositionEmpty = _liquidateDebt(
      debtReserve,
      debtPosition,
      positionStatus,
      LiquidateDebtParams({
        reserveId: params.debtReserveId,
        debtToLiquidate: debtToLiquidate,
        drawnDebt: params.drawnDebt,
        premiumDebt: params.premiumDebt,
        accruedPremium: params.accruedPremium,
        liquidator: params.liquidator
      })
    );

    emit ISpokeBase.LiquidationCall(
      params.collateralReserveId,
      params.debtReserveId,
      params.user,
      params.debtToCover,
      collateralToLiquidate,
      params.liquidator
    );

    return
      _assessDeficit(
        AssessDeficitParams({
          isCollateralPositionEmpty: isCollateralPositionEmpty,
          isDebtPositionEmpty: isDebtPositionEmpty,
          suppliedAssetsCount: params.suppliedAssetsCount,
          borrowedAssetsCount: params.borrowedAssetsCount
        })
      );
  }
}
