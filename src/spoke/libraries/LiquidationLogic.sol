// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {ISpoke, ISpokeBase} from 'src/spoke/interfaces/ISpoke.sol';

/// @title LiquidationLogic library
/// @author Aave Labs
/// @notice Implements the logic for liquidations.
library LiquidationLogic {
  using SafeCast for *;
  using PositionStatusMap for ISpoke.PositionStatus;
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using MathUtils for *;
  using LiquidationLogic for *;

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
    uint256 totalDebtValue;
    address liquidator;
    uint256 activeCollateralCount;
    uint256 borrowedCount;
    bool receiveShares;
  }

  struct ValidateLiquidationCallParams {
    address user;
    address liquidator;
    uint256 debtToCover;
    address collateralReserveHub;
    address debtReserveHub;
    bool collateralReservePaused;
    bool debtReservePaused;
    bool collateralReserveFrozen;
    uint256 healthFactor;
    bool isUsingAsCollateral;
    uint256 collateralFactor;
    uint256 collateralReserveBalance;
    uint256 debtReserveBalance;
    bool receiveShares;
  }

  struct CalculateDebtToTargetHealthFactorParams {
    uint256 totalDebtValue;
    uint256 healthFactor;
    uint256 targetHealthFactor;
    uint256 liquidationBonus;
    uint256 collateralFactor;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
  }

  struct CalculateDebtToLiquidateParams {
    uint256 debtReserveBalance;
    uint256 debtToCover;
    uint256 totalDebtValue;
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
    uint256 targetHealthFactor;
    uint256 debtReserveBalance;
    uint256 collateralReserveBalance;
    uint256 debtToCover;
    uint256 totalDebtValue;
    uint256 healthFactor;
    uint256 maxLiquidationBonus;
    uint256 collateralFactor;
    uint256 liquidationFee;
    uint256 debtAssetPrice;
    uint256 debtAssetDecimals;
    uint256 collateralAssetPrice;
    uint256 collateralAssetDecimals;
  }

  struct LiquidateDebtParams {
    uint256 debtReserveId;
    uint256 debtToLiquidate;
    uint256 premiumDebt;
    uint256 accruedPremium;
    address liquidator;
    address user;
  }

  struct LiquidateCollateralParams {
    uint256 collateralReserveId;
    uint256 collateralToLiquidate;
    uint256 collateralToLiquidator;
    address liquidator;
    address user;
    bool receiveShares;
  }

  // see ISpoke.HEALTH_FACTOR_LIQUIDATION_THRESHOLD docs
  uint64 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

  // see ISpoke.DUST_LIQUIDATION_THRESHOLD docs
  uint256 public constant DUST_LIQUIDATION_THRESHOLD = 1000e26;

  /// @notice Liquidates a user position.
  /// @param collateralReserve The collateral reserve to seize during liquidation.
  /// @param debtReserve The debt reserve to repay during liquidation.
  /// @param positions The user positions mapping in storage.
  /// @param positionStatus The user's position status.
  /// @param liquidationConfig The liquidation config.
  /// @param collateralDynConfig The collateral dynamic config.
  /// @param params The liquidate user params.
  /// @return True if the liquidation results in deficit.
  function liquidateUser(
    ISpoke.Reserve storage collateralReserve,
    ISpoke.Reserve storage debtReserve,
    mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition)) storage positions,
    ISpoke.PositionStatus storage positionStatus,
    ISpoke.LiquidationConfig storage liquidationConfig,
    ISpoke.DynamicReserveConfig storage collateralDynConfig,
    LiquidateUserParams memory params
  ) external returns (bool) {
    uint256 collateralReserveBalance = collateralReserve.hub.previewRemoveByShares(
      collateralReserve.assetId,
      positions[params.user][params.collateralReserveId].suppliedShares
    );
    _validateLiquidationCall(
      ValidateLiquidationCallParams({
        user: params.user,
        liquidator: params.liquidator,
        debtToCover: params.debtToCover,
        collateralReserveHub: address(collateralReserve.hub),
        debtReserveHub: address(debtReserve.hub),
        collateralReservePaused: collateralReserve.paused,
        collateralReserveFrozen: collateralReserve.frozen,
        debtReservePaused: debtReserve.paused,
        healthFactor: params.healthFactor,
        isUsingAsCollateral: positionStatus.isUsingAsCollateral(params.collateralReserveId),
        collateralFactor: collateralDynConfig.collateralFactor,
        collateralReserveBalance: collateralReserveBalance,
        debtReserveBalance: params.drawnDebt + params.premiumDebt,
        receiveShares: params.receiveShares
      })
    );

    (
      uint256 collateralToLiquidate,
      uint256 collateralToLiquidator,
      uint256 debtToLiquidate
    ) = _calculateLiquidationAmounts(
        CalculateLiquidationAmountsParams({
          healthFactorForMaxBonus: liquidationConfig.healthFactorForMaxBonus,
          liquidationBonusFactor: liquidationConfig.liquidationBonusFactor,
          targetHealthFactor: liquidationConfig.targetHealthFactor,
          debtReserveBalance: params.drawnDebt + params.premiumDebt,
          collateralReserveBalance: collateralReserveBalance,
          debtToCover: params.debtToCover,
          totalDebtValue: params.totalDebtValue,
          healthFactor: params.healthFactor,
          maxLiquidationBonus: collateralDynConfig.maxLiquidationBonus,
          collateralFactor: collateralDynConfig.collateralFactor,
          liquidationFee: collateralDynConfig.liquidationFee,
          debtAssetPrice: IAaveOracle(params.oracle).getReservePrice(params.debtReserveId),
          debtAssetDecimals: debtReserve.decimals,
          collateralAssetPrice: IAaveOracle(params.oracle).getReservePrice(
            params.collateralReserveId
          ),
          collateralAssetDecimals: collateralReserve.decimals
        })
      );

    bool isCollateralPositionEmpty = _liquidateCollateral(
      collateralReserve,
      positions,
      LiquidateCollateralParams({
        collateralReserveId: params.collateralReserveId,
        collateralToLiquidate: collateralToLiquidate,
        collateralToLiquidator: collateralToLiquidator,
        liquidator: params.liquidator,
        user: params.user,
        receiveShares: params.receiveShares
      })
    );

    bool isDebtPositionEmpty = _liquidateDebt(
      debtReserve,
      positions[params.user][params.debtReserveId],
      positionStatus,
      LiquidateDebtParams({
        debtReserveId: params.debtReserveId,
        debtToLiquidate: debtToLiquidate,
        premiumDebt: params.premiumDebt,
        accruedPremium: params.accruedPremium,
        liquidator: params.liquidator,
        user: params.user
      })
    );

    emit ISpokeBase.LiquidationCall(
      params.collateralReserveId,
      params.debtReserveId,
      params.user,
      debtToLiquidate,
      collateralToLiquidate,
      params.liquidator,
      params.receiveShares
    );

    return
      _evaluateDeficit({
        isCollateralPositionEmpty: isCollateralPositionEmpty,
        isDebtPositionEmpty: isDebtPositionEmpty,
        activeCollateralCount: params.activeCollateralCount,
        borrowedCount: params.borrowedCount
      });
  }

  /// @notice Calculates the liquidation bonus at a given health factor.
  /// @dev Liquidation Bonus is expressed as a BPS value greater than `PercentageMath.PERCENTAGE_FACTOR`.
  /// @param healthFactorForMaxBonus The health factor for max bonus.
  /// @param liquidationBonusFactor The liquidation bonus factor.
  /// @param healthFactor The health factor.
  /// @param maxLiquidationBonus The max liquidation bonus.
  /// @return The liquidation bonus.
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

  /// @notice Settles the premium debt by realizing change in premium and resetting premium shares and offset.
  function settlePremiumDebt(
    ISpoke.UserPosition storage debtPosition,
    int256 realizedDelta
  ) internal {
    debtPosition.premiumShares = 0;
    debtPosition.premiumOffset = 0;
    debtPosition.realizedPremium = debtPosition.realizedPremium.add(realizedDelta).toUint128();
  }

  /// @dev Invoked by `liquidateUser` method.
  /// @return True if the collateral position is empty, false otherwise.
  function _liquidateCollateral(
    ISpoke.Reserve storage collateralReserve,
    mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition)) storage positions,
    LiquidateCollateralParams memory params
  ) internal returns (bool) {
    ISpoke.UserPosition storage collateralPosition = positions[params.user][
      params.collateralReserveId
    ];
    IHubBase hub = collateralReserve.hub;
    uint256 assetId = collateralReserve.assetId;

    uint256 sharesToLiquidate = hub.previewRemoveByAssets(assetId, params.collateralToLiquidate);
    uint128 suppliedShares = collateralPosition.suppliedShares - sharesToLiquidate.toUint128();
    collateralPosition.suppliedShares = suppliedShares;

    uint256 sharesToLiquidator;
    if (params.receiveShares) {
      sharesToLiquidator = hub.previewRemoveByAssets(assetId, params.collateralToLiquidator);
      positions[params.liquidator][params.collateralReserveId].suppliedShares += sharesToLiquidator
        .toUint128();
    } else {
      sharesToLiquidator = hub.remove(assetId, params.collateralToLiquidator, params.liquidator);
    }

    if (sharesToLiquidate > sharesToLiquidator) {
      hub.payFeeShares(assetId, sharesToLiquidate.uncheckedSub(sharesToLiquidator));
    }

    return suppliedShares == 0;
  }

  /// @dev Invoked by `liquidateUser` method.
  /// @return True if the debt position becomes zero after restoring.
  function _liquidateDebt(
    ISpoke.Reserve storage debtReserve,
    ISpoke.UserPosition storage debtPosition,
    ISpoke.PositionStatus storage positionStatus,
    LiquidateDebtParams memory params
  ) internal returns (bool) {
    {
      uint256 premiumDebtToLiquidate = params.premiumDebt.min(params.debtToLiquidate);
      uint256 drawnDebtToLiquidate = params.debtToLiquidate - premiumDebtToLiquidate;

      IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
        sharesDelta: -debtPosition.premiumShares.toInt256(),
        offsetDelta: -debtPosition.premiumOffset.toInt256(),
        realizedDelta: params.accruedPremium.toInt256() - premiumDebtToLiquidate.toInt256()
      });

      uint256 drawnSharesLiquidated = debtReserve.hub.restore(
        debtReserve.assetId,
        drawnDebtToLiquidate,
        premiumDebtToLiquidate,
        premiumDelta,
        params.liquidator
      );
      debtPosition.settlePremiumDebt(premiumDelta.realizedDelta);
      debtPosition.drawnShares -= drawnSharesLiquidated.toUint128();
    }

    if (debtPosition.drawnShares == 0) {
      positionStatus.setBorrowing(params.debtReserveId, false);
      return true;
    }

    return false;
  }

  /// @notice Validates the liquidation call.
  /// @param params The validate liquidation call params.
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
    require(params.collateralReserveBalance > 0, ISpoke.ReserveNotSupplied());
    require(params.debtReserveBalance > 0, ISpoke.ReserveNotBorrowed());
    require(!params.receiveShares || !params.collateralReserveFrozen, ISpoke.CannotReceiveShares());
  }

  /// @notice Calculates the liquidation amounts.
  /// @dev Invoked by `liquidateUser` method.
  /// @return The collateral to liquidate.
  /// @return The collateral to transfer to liquidator.
  /// @return The debt to liquidate.
  function _calculateLiquidationAmounts(
    CalculateLiquidationAmountsParams memory params
  ) internal pure returns (uint256, uint256, uint256) {
    uint256 debtAssetUnit = MathUtils.uncheckedExp(10, params.debtAssetDecimals);
    uint256 collateralAssetUnit = MathUtils.uncheckedExp(10, params.collateralAssetDecimals);

    uint256 liquidationBonus = calculateLiquidationBonus({
      healthFactorForMaxBonus: params.healthFactorForMaxBonus,
      liquidationBonusFactor: params.liquidationBonusFactor,
      healthFactor: params.healthFactor,
      maxLiquidationBonus: params.maxLiquidationBonus
    });

    // To prevent accumulation of dust, one of the following conditions is enforced:
    // 1. liquidate all debt
    // 2. liquidate all collateral
    // 3. leave at least `DUST_LIQUIDATION_THRESHOLD` of collateral and debt (in value terms)
    uint256 debtToLiquidate = _calculateDebtToLiquidate(
      CalculateDebtToLiquidateParams({
        debtReserveBalance: params.debtReserveBalance,
        debtToCover: params.debtToCover,
        totalDebtValue: params.totalDebtValue,
        healthFactor: params.healthFactor,
        targetHealthFactor: params.targetHealthFactor,
        liquidationBonus: liquidationBonus,
        collateralFactor: params.collateralFactor,
        debtAssetPrice: params.debtAssetPrice,
        debtAssetUnit: debtAssetUnit
      })
    );

    uint256 collateralToLiquidate = debtToLiquidate.mulDivDown(
      params.debtAssetPrice * collateralAssetUnit * liquidationBonus,
      debtAssetUnit * params.collateralAssetPrice * PercentageMath.PERCENTAGE_FACTOR
    );

    bool leavesCollateralDust = collateralToLiquidate < params.collateralReserveBalance &&
      (params.collateralReserveBalance - collateralToLiquidate).mulDivDown(
        params.collateralAssetPrice.toWad(),
        collateralAssetUnit
      ) <
      DUST_LIQUIDATION_THRESHOLD;

    if (
      collateralToLiquidate > params.collateralReserveBalance ||
      (leavesCollateralDust && debtToLiquidate < params.debtReserveBalance)
    ) {
      collateralToLiquidate = params.collateralReserveBalance;

      // - `debtToLiquidate` is decreased if `collateralToLiquidate > params.collateralReserveBalance` (if so, debt dust could remain).
      // - `debtToLiquidate` is increased if `(leavesCollateralDust && debtToLiquidate < params.debtReserveBalance)`, ensuring collateral reserve
      //   is fully liquidated (potentially bypassing the target health factor). Can only increase by at most `DUST_LIQUIDATION_THRESHOLD` (in
      //   value terms). Since debt dust condition was enforced, it is guaranteed that `debtToLiquidate` will never exceed `params.debtReserveBalance`.
      debtToLiquidate = collateralToLiquidate.mulDivUp(
        params.collateralAssetPrice * debtAssetUnit * PercentageMath.PERCENTAGE_FACTOR,
        params.debtAssetPrice * collateralAssetUnit * liquidationBonus
      );
    }

    // revert if the liquidator does not cover the necessary debt to prevent dust from remaining
    require(params.debtToCover >= debtToLiquidate, ISpoke.MustNotLeaveDust());

    uint256 collateralToLiquidator = collateralToLiquidate -
      collateralToLiquidate.mulDivDown(
        params.liquidationFee * (liquidationBonus - PercentageMath.PERCENTAGE_FACTOR),
        liquidationBonus * PercentageMath.PERCENTAGE_FACTOR
      );

    return (collateralToLiquidate, collateralToLiquidator, debtToLiquidate);
  }

  /// @notice Calculates the debt that should be liquidated.
  /// @dev Generally, it returns the minimum of `debtToCover`, `debtReserveBalance` and `debtToTarget`.
  /// If debt dust would be left behind, it returns `debtReserveBalance` to ensure the debt is fully cleared and no dust is left.
  function _calculateDebtToLiquidate(
    CalculateDebtToLiquidateParams memory params
  ) internal pure returns (uint256) {
    uint256 debtToLiquidate = params.debtReserveBalance;
    if (params.debtToCover < debtToLiquidate) {
      debtToLiquidate = params.debtToCover;
    }

    uint256 debtToTarget = _calculateDebtToTargetHealthFactor(
      CalculateDebtToTargetHealthFactorParams({
        totalDebtValue: params.totalDebtValue,
        healthFactor: params.healthFactor,
        targetHealthFactor: params.targetHealthFactor,
        liquidationBonus: params.liquidationBonus,
        collateralFactor: params.collateralFactor,
        debtAssetPrice: params.debtAssetPrice,
        debtAssetUnit: params.debtAssetUnit
      })
    );
    if (debtToTarget < debtToLiquidate) {
      debtToLiquidate = debtToTarget;
    }

    bool leavesDebtDust = debtToLiquidate < params.debtReserveBalance &&
      (params.debtReserveBalance - debtToLiquidate).mulDivDown(
        params.debtAssetPrice.toWad(),
        params.debtAssetUnit
      ) <
      DUST_LIQUIDATION_THRESHOLD;

    if (leavesDebtDust) {
      // target health factor is bypassed to prevent leaving dust
      debtToLiquidate = params.debtReserveBalance;
    }

    return debtToLiquidate;
  }

  /// @notice Calculates the amount of debt needed to be liquidated to restore a position to the target health factor.
  function _calculateDebtToTargetHealthFactor(
    CalculateDebtToTargetHealthFactorParams memory params
  ) internal pure returns (uint256) {
    uint256 liquidationPenalty = params.liquidationBonus.bpsToWad().percentMulUp(
      params.collateralFactor
    );

    // denominator cannot be zero as `liquidationPenalty` is always < PercentageMath.PERCENTAGE_FACTOR
    // `liquidationBonus.percentMulUp(collateralFactor) < PercentageMath.PERCENTAGE_FACTOR` is enforced in `_validateDynamicReserveConfig`
    // and targetHealthFactor is always >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    return
      params.totalDebtValue.mulDivUp(
        params.debtAssetUnit * (params.targetHealthFactor - params.healthFactor),
        (params.targetHealthFactor - liquidationPenalty) * params.debtAssetPrice.toWad()
      );
  }

  /// @notice Returns if the liquidation results in deficit.
  function _evaluateDeficit(
    bool isCollateralPositionEmpty,
    bool isDebtPositionEmpty,
    uint256 activeCollateralCount,
    uint256 borrowedCount
  ) internal pure returns (bool) {
    if (!isCollateralPositionEmpty || activeCollateralCount > 1) {
      return false;
    }
    return !isDebtPositionEmpty || borrowedCount > 1;
  }
}
