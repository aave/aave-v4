// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {ISpoke, ISpokeBase} from 'src/spoke/interfaces/ISpoke.sol';

library LiquidationLogic {
  using SafeCast for *;
  using PositionStatusMap for ISpoke.PositionStatus;
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using MathUtils for *;

  struct LiquidateUserParams {
    uint256 collateralReserveId;
    uint256 debtReserveId;
    address oracle;
    address user;
    uint256 debtToCover;
    uint256 healthFactor;
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 accruedPremium;
    uint256 totalDebtInBaseCurrency;
    address liquidator;
    uint256 suppliedCollateralsCount;
    uint256 borrowedReservesCount;
  }

  struct ValidateLiquidationCallParams {
    address user;
    address liquidator;
    uint256 debtToCover;
    address collateralReserveHub;
    address debtReserveHub;
    bool collateralReservePaused;
    bool debtReservePaused;
    uint256 healthFactor;
    bool isUsingAsCollateral;
    uint256 collateralFactor;
    uint256 debtReserveBalance;
  }

  struct CalculateDebtToTargetHealthFactorParams {
    uint256 totalDebtInBaseCurrency;
    uint256 healthFactor;
    uint256 targetHealthFactor;
    uint256 liquidationBonus;
    uint256 collateralFactor;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
  }

  struct CalculateMaxDebtToLiquidateParams {
    uint256 debtReserveBalance;
    uint256 debtToCover;
    uint256 totalDebtInBaseCurrency;
    uint256 healthFactor;
    uint256 targetHealthFactor;
    uint256 liquidationBonus;
    uint256 collateralFactor;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
  }

  struct CalculateLiquidationAmountsParams {
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
    uint256 debtReserveBalance;
    uint256 collateralReserveBalance;
    uint256 debtToCover;
    uint256 totalDebtInBaseCurrency;
    uint256 healthFactor;
    uint256 targetHealthFactor;
    uint256 maxLiquidationBonus;
    uint256 collateralFactor;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
    uint256 collateralAssetPrice;
    uint256 collateralAssetUnit;
    uint256 liquidationFee;
  }

  struct LiquidateDebtParams {
    uint256 reserveId;
    uint256 debtToLiquidate;
    uint256 premiumDebt;
    uint256 accruedPremium;
    address liquidator;
  }

  struct LiquidateCollateralParams {
    uint256 collateralToLiquidate;
    uint256 collateralToLiquidator;
    address liquidator;
  }

  // see ISpoke.HEALTH_FACTOR_LIQUIDATION_THRESHOLD docs
  uint64 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

  // see ISpoke.DUST_DEBT_LIQUIDATION_THRESHOLD docs
  uint256 constant DUST_DEBT_LIQUIDATION_THRESHOLD = 1000e26;

  function liquidateUser(
    ISpoke.Reserve storage collateralReserve,
    ISpoke.Reserve storage debtReserve,
    ISpoke.UserPosition storage collateralPosition,
    ISpoke.UserPosition storage debtPosition,
    ISpoke.PositionStatus storage positionStatus,
    ISpoke.LiquidationConfig storage liquidationConfig,
    ISpoke.DynamicReserveConfig storage collateralDynConfig,
    LiquidateUserParams memory params
  ) external returns (bool) {
    IHubBase collateralHub = collateralReserve.hub;
    _validateLiquidationCall(
      ValidateLiquidationCallParams({
        user: params.user,
        liquidator: params.liquidator,
        debtToCover: params.debtToCover,
        collateralReserveHub: address(collateralHub),
        debtReserveHub: address(debtReserve.hub),
        collateralReservePaused: collateralReserve.paused,
        debtReservePaused: debtReserve.paused,
        healthFactor: params.healthFactor,
        isUsingAsCollateral: positionStatus.isUsingAsCollateral(params.collateralReserveId),
        collateralFactor: collateralDynConfig.collateralFactor,
        debtReserveBalance: params.drawnDebt + params.premiumDebt
      })
    );

    CalculateLiquidationAmountsParams
      memory calculateLiquidationAmountsParams = CalculateLiquidationAmountsParams({
        healthFactorForMaxBonus: liquidationConfig.healthFactorForMaxBonus,
        liquidationBonusFactor: liquidationConfig.liquidationBonusFactor,
        debtReserveBalance: params.drawnDebt + params.premiumDebt,
        collateralReserveBalance: collateralHub.previewRemoveByShares(
          collateralReserve.assetId,
          collateralPosition.suppliedShares
        ),
        debtToCover: params.debtToCover,
        totalDebtInBaseCurrency: params.totalDebtInBaseCurrency,
        healthFactor: params.healthFactor,
        targetHealthFactor: liquidationConfig.targetHealthFactor,
        maxLiquidationBonus: collateralDynConfig.maxLiquidationBonus,
        collateralFactor: collateralDynConfig.collateralFactor,
        debtAssetPrice: IAaveOracle(params.oracle).getReservePrice(params.debtReserveId),
        debtAssetUnit: uint256(10).uncheckedExp(debtReserve.decimals),
        collateralAssetPrice: IAaveOracle(params.oracle).getReservePrice(
          params.collateralReserveId
        ),
        collateralAssetUnit: uint256(10).uncheckedExp(collateralReserve.decimals),
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
        premiumDebt: params.premiumDebt,
        accruedPremium: params.accruedPremium,
        liquidator: params.liquidator
      })
    );

    emit ISpokeBase.LiquidationCall(
      params.collateralReserveId,
      params.debtReserveId,
      params.user,
      debtToLiquidate,
      collateralToLiquidate,
      params.liquidator
    );

    return
      _evaluateDeficit({
        isCollateralPositionEmpty: isCollateralPositionEmpty,
        isDebtPositionEmpty: isDebtPositionEmpty,
        suppliedCollateralsCount: params.suppliedCollateralsCount,
        borrowedReservesCount: params.borrowedReservesCount
      });
  }

  function _validateLiquidationCall(ValidateLiquidationCallParams memory params) internal pure {
    require(params.user != params.liquidator, ISpoke.SelfLiquidation());
    require(params.debtToCover > 0, ISpoke.InvalidDebtToCover());
    require(
      params.collateralReserveHub != address(0) && params.debtReserveHub != address(0),
      ISpoke.ReserveNotListed()
    );
    require(!params.collateralReservePaused && !params.debtReservePaused, ISpoke.ReservePaused());
    require(
      params.healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      ISpoke.HealthFactorNotBelowThreshold()
    );
    require(
      params.isUsingAsCollateral && params.collateralFactor > 0,
      ISpoke.CollateralCannotBeLiquidated()
    );
    require(params.debtReserveBalance > 0, ISpoke.SpecifiedCurrencyNotBorrowedByUser());
  }

  function _calculateLiquidationAmounts(
    CalculateLiquidationAmountsParams memory params
  ) internal pure returns (uint256, uint256, uint256) {
    uint256 liquidationBonus = calculateLiquidationBonus({
      healthFactorForMaxBonus: params.healthFactorForMaxBonus,
      liquidationBonusFactor: params.liquidationBonusFactor,
      healthFactor: params.healthFactor,
      maxLiquidationBonus: params.maxLiquidationBonus
    });

    uint256 debtToLiquidate = _calculateMaxDebtToLiquidate(
      CalculateMaxDebtToLiquidateParams({
        debtReserveBalance: params.debtReserveBalance,
        debtToCover: params.debtToCover,
        totalDebtInBaseCurrency: params.totalDebtInBaseCurrency,
        healthFactor: params.healthFactor,
        targetHealthFactor: params.targetHealthFactor,
        liquidationBonus: liquidationBonus,
        collateralFactor: params.collateralFactor,
        debtAssetPrice: params.debtAssetPrice,
        debtAssetUnit: params.debtAssetUnit
      })
    );

    uint256 debtToCollateral = debtToLiquidate.mulDivDown(
      params.debtAssetPrice * params.collateralAssetUnit,
      params.debtAssetUnit * params.collateralAssetPrice
    );
    uint256 collateralToLiquidate = debtToCollateral.percentMulDown(liquidationBonus);
    if (collateralToLiquidate > params.collateralReserveBalance) {
      collateralToLiquidate = params.collateralReserveBalance;
      debtToCollateral = collateralToLiquidate.percentDivUp(liquidationBonus);
      debtToLiquidate = debtToCollateral.mulDivUp(
        params.collateralAssetPrice * params.debtAssetUnit,
        params.debtAssetPrice * params.collateralAssetUnit
      );
    }

    uint256 collateralToLiquidator = collateralToLiquidate -
      (collateralToLiquidate - debtToCollateral).percentMulDown(params.liquidationFee);

    return (collateralToLiquidate, collateralToLiquidator, debtToLiquidate);
  }

  function calculateLiquidationBonus(
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonusFactor,
    uint256 healthFactor,
    uint256 maxLiquidationBonus
  ) internal pure returns (uint256) {
    if (healthFactor <= healthFactorForMaxBonus) {
      return maxLiquidationBonus;
    }

    uint256 minLiquidationBonus = (maxLiquidationBonus - PercentageMath.PERCENTAGE_FACTOR)
      .percentMulDown(liquidationBonusFactor) + PercentageMath.PERCENTAGE_FACTOR;

    // linear interpolation between min and max
    // denominator cannot be zero as healthFactorForMaxBonus is always < HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    return
      minLiquidationBonus +
      (maxLiquidationBonus - minLiquidationBonus).mulDivDown(
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD - healthFactor,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD - healthFactorForMaxBonus
      );
  }

  function _calculateMaxDebtToLiquidate(
    CalculateMaxDebtToLiquidateParams memory params
  ) internal pure returns (uint256) {
    uint256 maxDebtToLiquidate = params.debtReserveBalance;
    if (params.debtToCover < maxDebtToLiquidate) {
      maxDebtToLiquidate = params.debtToCover;
    }

    uint256 debtToTarget = _calculateDebtToTargetHealthFactor(
      CalculateDebtToTargetHealthFactorParams({
        totalDebtInBaseCurrency: params.totalDebtInBaseCurrency,
        healthFactor: params.healthFactor,
        targetHealthFactor: params.targetHealthFactor,
        liquidationBonus: params.liquidationBonus,
        collateralFactor: params.collateralFactor,
        debtAssetPrice: params.debtAssetPrice,
        debtAssetUnit: params.debtAssetUnit
      })
    );
    if (debtToTarget < maxDebtToLiquidate) {
      maxDebtToLiquidate = debtToTarget;
    }

    uint256 remainingDebtInBaseCurrency = (params.debtReserveBalance - maxDebtToLiquidate)
      .mulDivDown(params.debtAssetPrice.toWad(), params.debtAssetUnit);

    if (remainingDebtInBaseCurrency < DUST_DEBT_LIQUIDATION_THRESHOLD) {
      // target health factor is ignored to prevent leaving dust, only if the liquidator intends to fully cover the debt
      require(params.debtToCover >= params.debtReserveBalance, ISpoke.MustNotLeaveDust());
      maxDebtToLiquidate = params.debtReserveBalance;
    }

    return maxDebtToLiquidate;
  }

  function _calculateDebtToTargetHealthFactor(
    CalculateDebtToTargetHealthFactorParams memory params
  ) internal pure returns (uint256) {
    uint256 liquidationPenalty = params.liquidationBonus.bpsToWad().percentMulUp(
      params.collateralFactor
    );

    // denominator cannot be zero as liquidationBonus * collateralFactor is always < PercentageMath.PERCENTAGE_FACTOR
    // and targetHealthFactor is always >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    return
      params.totalDebtInBaseCurrency.mulDivUp(
        params.debtAssetUnit * (params.targetHealthFactor - params.healthFactor),
        (params.targetHealthFactor - liquidationPenalty) * params.debtAssetPrice.toWad()
      );
  }

  function _liquidateDebt(
    ISpoke.Reserve storage reserve,
    ISpoke.UserPosition storage position,
    ISpoke.PositionStatus storage positionStatus,
    LiquidateDebtParams memory params
  ) internal returns (bool) {
    {
      uint256 premiumDebtToLiquidate = params.premiumDebt.min(params.debtToLiquidate);
      uint256 drawnDebtToLiquidate = params.debtToLiquidate - premiumDebtToLiquidate;

      IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
        sharesDelta: -position.premiumShares.toInt256(),
        offsetDelta: -position.premiumOffset.toInt256(),
        realizedDelta: params.accruedPremium.toInt256() - premiumDebtToLiquidate.toInt256()
      });

      uint256 drawnSharesLiquidated = reserve.hub.restore(
        reserve.assetId,
        drawnDebtToLiquidate,
        premiumDebtToLiquidate,
        premiumDelta,
        params.liquidator
      );
      // debt accounting
      _settlePremiumDebt(position, premiumDelta.realizedDelta);
      position.drawnShares -= drawnSharesLiquidated.toUint128();
    }

    if (position.drawnShares == 0) {
      positionStatus.setBorrowing(params.reserveId, false);
      return true;
    }

    return false;
  }

  function _liquidateCollateral(
    ISpoke.Reserve storage reserve,
    ISpoke.UserPosition storage position,
    LiquidateCollateralParams memory params
  ) internal returns (bool) {
    IHubBase hub = reserve.hub;
    uint256 assetId = reserve.assetId;

    uint256 sharesToLiquidate = hub.previewRemoveByAssets(assetId, params.collateralToLiquidate);

    position.suppliedShares -= sharesToLiquidate.toUint128();

    uint256 sharesToLiquidator = hub.remove(
      assetId,
      params.collateralToLiquidator,
      params.liquidator
    );

    if (sharesToLiquidate > sharesToLiquidator) {
      hub.payFeeShares(assetId, sharesToLiquidate.uncheckedSub(sharesToLiquidator));
    }

    return position.suppliedShares == 0;
  }

  function _evaluateDeficit(
    bool isCollateralPositionEmpty,
    bool isDebtPositionEmpty,
    uint256 suppliedCollateralsCount,
    uint256 borrowedReservesCount
  ) internal pure returns (bool) {
    if (!isCollateralPositionEmpty || suppliedCollateralsCount > 1) {
      return false;
    }

    return !isDebtPositionEmpty || borrowedReservesCount > 1;
  }

  function _settlePremiumDebt(
    ISpoke.UserPosition storage debtPosition,
    int256 realizedDelta
  ) internal {
    debtPosition.premiumShares = 0;
    debtPosition.premiumOffset = 0;
    debtPosition.realizedPremium = debtPosition.realizedPremium.add(realizedDelta).toUint128();
  }
}
