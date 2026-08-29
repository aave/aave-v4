// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.20;

import {Math} from 'src/dependencies/openzeppelin/Math.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SpokeUtils} from 'src/spoke/libraries/SpokeUtils.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {UserPositionUtils} from 'src/spoke/libraries/UserPositionUtils.sol';
import {ReserveFlags, ReserveFlagsMap} from 'src/spoke/libraries/ReserveFlagsMap.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';

/// @title BabylonLiquidationLogic library
/// @author Aave Labs
/// @notice Implements the Babylon liquidation logic, sized by a collateral cap instead of a
/// target health factor and without dust validation.
library BabylonLiquidationLogic {
  using MathUtils for *;
  using WadRayMath for uint256;
  using SpokeUtils for *;
  using UserPositionUtils for ISpoke.UserPosition;
  using ReserveFlagsMap for ReserveFlags;
  using PositionStatusMap for ISpoke.PositionStatus;

  struct LiquidateUserParams {
    uint256 collateralReserveId;
    uint256[] debtReserveIds;
    uint256[] debtToCoverAmounts;
    uint256 reserveCount;
    address oracle;
    address user;
    ISpoke.LiquidationConfig liquidationConfig;
    uint256 maxCollateralToRemove;
    ISpoke.UserAccountData userAccountData;
    address liquidator;
  }

  struct ExecuteLiquidationParams {
    IHubBase collateralHub;
    uint256 collateralAssetId;
    uint256 collateralAssetDecimals;
    uint256 collateralReserveId;
    ReserveFlags collateralReserveFlags;
    ISpoke.DynamicReserveConfig collateralDynConfig;
    uint256[] debtReserveIds;
    uint256[] debtToCoverAmounts;
    ISpoke.LiquidationConfig liquidationConfig;
    address oracle;
    address user;
    uint256 maxCollateralToRemove;
    uint256 healthFactor;
    uint256 reserveCount;
    address liquidator;
  }

  struct ValidateLiquidationCallParams {
    address user;
    address liquidator;
    uint256[] debtReserveIds;
    uint256[] debtToCoverAmounts;
    uint256 collateralReserveId;
    ReserveFlags collateralReserveFlags;
    uint256 suppliedShares;
    uint256 collateralFactor;
    uint256 healthFactor;
  }

  struct LiquidateDebtReservesParams {
    IHubBase collateralHub;
    uint256 collateralAssetId;
    uint256 collateralAssetUnit;
    uint256 collateralAssetPrice;
    uint256 liquidationBonus;
    uint256[] debtReserveIds;
    uint256[] debtToCoverAmounts;
    address oracle;
    address user;
    address liquidator;
    uint256 maxCollateralToRemove;
    uint256 suppliedShares;
  }

  struct LiquidateDebtReserveParams {
    IHubBase collateralHub;
    uint256 collateralAssetId;
    uint256 collateralAssetUnit;
    uint256 collateralAssetPrice;
    uint256 liquidationBonus;
    IHubBase debtHub;
    uint256 debtAssetId;
    address debtUnderlying;
    uint256 debtAssetUnit;
    uint256 debtReserveId;
    uint256 debtToCover;
    address oracle;
    address user;
    address liquidator;
    uint256 maxRemovableShares;
  }

  struct CalculateLiquidationAmountsParams {
    IHubBase collateralReserveHub;
    uint256 collateralReserveAssetId;
    uint256 collateralAssetUnit;
    uint256 collateralAssetPrice;
    uint256 liquidationBonus;
    uint256 drawnShares;
    uint256 premiumDebtRay;
    uint256 drawnIndex;
    uint256 debtAssetUnit;
    uint256 debtAssetPrice;
    uint256 debtToCover;
    uint256 maxRemovableShares;
  }

  struct LiquidationAmounts {
    uint256 collateralSharesToLiquidate;
    uint256 drawnSharesToLiquidate;
    uint256 premiumDebtRayToLiquidate;
  }

  /// @notice Liquidates a user position with cap-bounded sizing.
  /// @dev The health factor is validated once at entry, not per debt reserve: with multiple debt
  /// reserves, an intermediate repayment can restore the health factor above the threshold while the
  /// removal cap is not yet reached, and repayment must be able to continue so the collateral
  /// removal can be completed. Over-liquidation is bounded by `maxCollateralToRemove` and by the liquidation
  /// manager restriction on the caller.
  /// @dev The liquidation fee is not charged: the liquidator receives the full removed collateral. The
  /// collateral reserve is expected to be configured with a zero liquidation fee.
  /// @dev A debt reserve the user no longer borrows is skipped, so repayments cannot be blocked
  /// by front-running liquidations.
  /// @param reserves The mapping of reserves per reserve id.
  /// @param userPositions The mapping of user positions per user per reserve.
  /// @param positionStatus The mapping of position status per user.
  /// @param dynamicConfig The mapping of dynamic config per reserve per dynamic config key.
  /// @param params The liquidate user params.
  /// @return True if the liquidation results in deficit.
  function liquidateUser(
    mapping(uint256 reserveId => ISpoke.Reserve) storage reserves,
    mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition)) storage userPositions,
    mapping(address user => ISpoke.PositionStatus) storage positionStatus,
    mapping(uint256 reserveId => mapping(uint32 dynamicConfigKey => ISpoke.DynamicReserveConfig)) storage dynamicConfig,
    LiquidateUserParams memory params
  ) external returns (bool) {
    ISpoke.Reserve storage collateralReserve = reserves.get(params.collateralReserveId);
    ISpoke.UserPosition storage collateralUserPosition = userPositions[params.user][
      params.collateralReserveId
    ];

    return
      _executeLiquidation({
        reserves: reserves,
        userPositions: userPositions,
        collateralUserPosition: collateralUserPosition,
        userPositionStatus: positionStatus[params.user],
        params: ExecuteLiquidationParams({
          collateralHub: collateralReserve.hub,
          collateralAssetId: collateralReserve.assetId,
          collateralAssetDecimals: collateralReserve.decimals,
          collateralReserveId: params.collateralReserveId,
          collateralReserveFlags: collateralReserve.flags,
          collateralDynConfig: dynamicConfig[params.collateralReserveId][
            collateralUserPosition.dynamicConfigKey
          ],
          debtReserveIds: params.debtReserveIds,
          debtToCoverAmounts: params.debtToCoverAmounts,
          liquidationConfig: params.liquidationConfig,
          oracle: params.oracle,
          user: params.user,
          maxCollateralToRemove: params.maxCollateralToRemove,
          healthFactor: params.userAccountData.healthFactor,
          reserveCount: params.reserveCount,
          liquidator: params.liquidator
        })
      });
  }

  /// @dev Executes the liquidation.
  /// @param reserves The mapping of reserves per reserve id.
  /// @param userPositions The mapping of user positions per user per reserve.
  /// @param collateralUserPosition User's collateral position.
  /// @param userPositionStatus User's position status.
  /// @param params The execute liquidation params.
  /// @return True if the liquidation results in deficit.
  function _executeLiquidation(
    mapping(uint256 reserveId => ISpoke.Reserve) storage reserves,
    mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition)) storage userPositions,
    ISpoke.UserPosition storage collateralUserPosition,
    ISpoke.PositionStatus storage userPositionStatus,
    ExecuteLiquidationParams memory params
  ) internal returns (bool) {
    _validateLiquidationCall(
      reserves,
      userPositionStatus,
      ValidateLiquidationCallParams({
        user: params.user,
        liquidator: params.liquidator,
        debtReserveIds: params.debtReserveIds,
        debtToCoverAmounts: params.debtToCoverAmounts,
        collateralReserveId: params.collateralReserveId,
        collateralReserveFlags: params.collateralReserveFlags,
        suppliedShares: collateralUserPosition.suppliedShares,
        collateralFactor: params.collateralDynConfig.collateralFactor,
        healthFactor: params.healthFactor
      })
    );

    // the collateral pricing is constant across the debt reserves repaid: the bonus is derived
    // from the entry health factor and the collateral price is read once
    LiquidateDebtReservesParams memory liquidateDebtReservesParams = LiquidateDebtReservesParams({
      collateralHub: params.collateralHub,
      collateralAssetId: params.collateralAssetId,
      collateralAssetUnit: MathUtils.uncheckedExp(10, params.collateralAssetDecimals),
      collateralAssetPrice: IAaveOracle(params.oracle).getReservePrice(params.collateralReserveId),
      liquidationBonus: LiquidationLogic.calculateLiquidationBonus({
        healthFactorForMaxBonus: params.liquidationConfig.healthFactorForMaxBonus,
        liquidationBonusFactor: params.liquidationConfig.liquidationBonusFactor,
        healthFactor: params.healthFactor,
        maxLiquidationBonus: params.collateralDynConfig.maxLiquidationBonus
      }),
      debtReserveIds: params.debtReserveIds,
      debtToCoverAmounts: params.debtToCoverAmounts,
      oracle: params.oracle,
      user: params.user,
      liquidator: params.liquidator,
      maxCollateralToRemove: params.maxCollateralToRemove,
      suppliedShares: collateralUserPosition.suppliedShares
    });

    (uint256 collateralSharesRemoved, uint256 collateralAmountRemoved) = _liquidateDebtReserves({
      reserves: reserves,
      userPositions: userPositions,
      collateralUserPosition: collateralUserPosition,
      collateralLiquidatorPosition: userPositions[params.liquidator][params.collateralReserveId],
      userPositionStatus: userPositionStatus,
      params: liquidateDebtReservesParams
    });

    emit IBabylonSpoke.BabylonLiquidationCallSummary({
      user: params.user,
      liquidator: params.liquidator,
      collateralAmountRemoved: collateralAmountRemoved,
      collateralSharesLiquidated: collateralSharesRemoved
    });

    return
      collateralUserPosition.suppliedShares == 0 &&
      userPositionStatus.nextBorrowing(params.reserveCount) != PositionStatusMap.NOT_FOUND;
  }

  /// @dev Repays the listed debt reserves in order, each removing its priced collateral, bounded
  /// by `params.maxCollateralToRemove` in total. The remaining cap is tracked in asset terms and
  /// converted into removable shares before each repayment.
  /// @dev No further repayments once the removal cap is fully consumed.
  /// @param reserves The mapping of reserves per reserve id.
  /// @param userPositions The mapping of user positions per user per reserve.
  /// @param collateralUserPosition User's collateral position.
  /// @param collateralLiquidatorPosition Liquidator's collateral position.
  /// @param userPositionStatus The position status of the user being liquidated.
  /// @param params The liquidate debt reserves params.
  /// @return The total amount of collateral shares removed.
  /// @return The total amount of collateral removed, expressed in asset units. Does not exceed
  /// `params.maxCollateralToRemove`.
  function _liquidateDebtReserves(
    mapping(uint256 reserveId => ISpoke.Reserve) storage reserves,
    mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition)) storage userPositions,
    ISpoke.UserPosition storage collateralUserPosition,
    ISpoke.UserPosition storage collateralLiquidatorPosition,
    ISpoke.PositionStatus storage userPositionStatus,
    LiquidateDebtReservesParams memory params
  ) internal returns (uint256, uint256) {
    uint256 totalCollateralSharesRemoved;
    uint256 totalCollateralAmountRemoved;
    for (uint256 i = 0; i < params.debtReserveIds.length; ++i) {
      // rounded down so the removed collateral cannot exceed the remaining cap
      uint256 maxRemovableShares = params
        .collateralHub
        .previewAddByAssets(
          params.collateralAssetId,
          params.maxCollateralToRemove - totalCollateralAmountRemoved
        )
        .min(params.suppliedShares - totalCollateralSharesRemoved);
      // no further repayments once the removal cap is consumed; the first repayment always runs,
      // so debt can be liquidated even when the corresponding collateral amount to receive is zero
      if (maxRemovableShares == 0 && i > 0) break;

      ISpoke.Reserve storage debtReserve = reserves.get(params.debtReserveIds[i]);

      LiquidateDebtReserveParams memory liquidateDebtReserveParams = LiquidateDebtReserveParams({
        collateralHub: params.collateralHub,
        collateralAssetId: params.collateralAssetId,
        collateralAssetUnit: params.collateralAssetUnit,
        collateralAssetPrice: params.collateralAssetPrice,
        liquidationBonus: params.liquidationBonus,
        debtHub: debtReserve.hub,
        debtAssetId: debtReserve.assetId,
        debtUnderlying: debtReserve.underlying,
        debtAssetUnit: MathUtils.uncheckedExp(10, debtReserve.decimals),
        debtReserveId: params.debtReserveIds[i],
        debtToCover: params.debtToCoverAmounts[i],
        oracle: params.oracle,
        user: params.user,
        liquidator: params.liquidator,
        maxRemovableShares: maxRemovableShares
      });
      (uint256 collateralSharesRemoved, uint256 collateralAmountRemoved) = _liquidateDebtReserve(
        userPositions[params.user][params.debtReserveIds[i]],
        collateralUserPosition,
        collateralLiquidatorPosition,
        userPositionStatus,
        liquidateDebtReserveParams
      );
      totalCollateralSharesRemoved += collateralSharesRemoved;
      totalCollateralAmountRemoved += collateralAmountRemoved;
    }

    return (totalCollateralSharesRemoved, totalCollateralAmountRemoved);
  }

  /// @dev Repays a single debt reserve and removes the corresponding collateral.
  /// @dev A debt reserve the user no longer borrows is skipped: liquidations front-running this
  /// call cannot make it revert.
  /// @param debtUserPosition User's debt position.
  /// @param collateralUserPosition User's collateral position.
  /// @param collateralLiquidatorPosition Liquidator's collateral position.
  /// @param userPositionStatus The position status of the user being liquidated.
  /// @param params The liquidate debt reserve params.
  /// @return The amount of collateral shares removed. Does not exceed `params.maxRemovableShares`.
  /// @return The amount of collateral removed, expressed in asset units.
  function _liquidateDebtReserve(
    ISpoke.UserPosition storage debtUserPosition,
    ISpoke.UserPosition storage collateralUserPosition,
    ISpoke.UserPosition storage collateralLiquidatorPosition,
    ISpoke.PositionStatus storage userPositionStatus,
    LiquidateDebtReserveParams memory params
  ) internal returns (uint256, uint256) {
    UserPositionUtils.DebtComponents memory debtComponents = debtUserPosition.getDebtComponents(
      params.debtHub,
      params.debtAssetId
    );
    if (debtComponents.drawnShares == 0) {
      return (0, 0);
    }

    LiquidationAmounts memory liquidationAmounts = _calculateLiquidationAmounts(
      CalculateLiquidationAmountsParams({
        collateralReserveHub: params.collateralHub,
        collateralReserveAssetId: params.collateralAssetId,
        collateralAssetUnit: params.collateralAssetUnit,
        collateralAssetPrice: params.collateralAssetPrice,
        liquidationBonus: params.liquidationBonus,
        drawnShares: debtComponents.drawnShares,
        premiumDebtRay: debtComponents.premiumDebtRay,
        drawnIndex: debtComponents.drawnIndex,
        debtAssetUnit: params.debtAssetUnit,
        debtAssetPrice: IAaveOracle(params.oracle).getReservePrice(params.debtReserveId),
        debtToCover: params.debtToCover,
        maxRemovableShares: params.maxRemovableShares
      })
    );

    // the liquidation fee is not charged: the liquidator receives the full removed collateral
    LiquidationLogic.LiquidateCollateralResult memory liquidateCollateralResult = LiquidationLogic
      ._liquidateCollateral(
        collateralUserPosition,
        collateralLiquidatorPosition,
        LiquidationLogic.LiquidateCollateralParams({
          hub: params.collateralHub,
          assetId: params.collateralAssetId,
          sharesToLiquidate: liquidationAmounts.collateralSharesToLiquidate,
          sharesToLiquidator: liquidationAmounts.collateralSharesToLiquidate,
          liquidator: params.liquidator,
          receiveShares: false
        })
      );

    LiquidationLogic.LiquidateDebtResult memory liquidateDebtResult = LiquidationLogic
      ._liquidateDebt(
        debtUserPosition,
        userPositionStatus,
        LiquidationLogic.LiquidateDebtParams({
          hub: params.debtHub,
          assetId: params.debtAssetId,
          underlying: params.debtUnderlying,
          reserveId: params.debtReserveId,
          drawnSharesToLiquidate: liquidationAmounts.drawnSharesToLiquidate,
          premiumDebtRayToLiquidate: liquidationAmounts.premiumDebtRayToLiquidate,
          drawnIndex: debtComponents.drawnIndex,
          liquidator: params.liquidator
        })
      );

    emit IBabylonSpoke.BabylonLiquidationCall({
      debtReserveId: params.debtReserveId,
      user: params.user,
      liquidator: params.liquidator,
      debtAmountRestored: liquidateDebtResult.amountRestored,
      drawnSharesLiquidated: liquidationAmounts.drawnSharesToLiquidate,
      premiumDelta: liquidateDebtResult.premiumDelta,
      collateralAmountRemoved: liquidateCollateralResult.amountRemoved,
      collateralSharesLiquidated: liquidationAmounts.collateralSharesToLiquidate
    });

    return (
      liquidationAmounts.collateralSharesToLiquidate,
      liquidateCollateralResult.amountRemoved
    );
  }

  /// @notice Calculates the liquidation amounts.
  /// @dev Sizes the repayment up to `params.debtToCover`, capped at the user's full debt in the
  /// reserve, with premium debt liquidated first. The removed collateral is priced with the canonical bonus
  /// formula and capped at `params.maxRemovableShares`; when the priced removal exceeds the cap, the repayment is
  /// resized to exactly consume it, mirroring the canonical full-collateral sizing.
  /// @param params The calculate liquidation amounts params.
  /// @return The liquidation amounts.
  function _calculateLiquidationAmounts(
    CalculateLiquidationAmountsParams memory params
  ) internal view returns (LiquidationAmounts memory) {
    // premium debt is liquidated first, up to `debtToCover`
    uint256 premiumDebtRayToLiquidate = params.premiumDebtRay;
    // strict inequality is mandatory given rounding
    if (params.debtToCover < premiumDebtRayToLiquidate.fromRayUp()) {
      premiumDebtRayToLiquidate = params.debtToCover.toRay();
    }

    // the remaining cover repays drawn debt only once the premium debt is fully liquidated
    uint256 drawnSharesToLiquidate;
    if (premiumDebtRayToLiquidate == params.premiumDebtRay) {
      drawnSharesToLiquidate = Math
        .mulDiv(
          params.debtToCover - premiumDebtRayToLiquidate.fromRayUp(),
          WadRayMath.RAY,
          params.drawnIndex,
          Math.Rounding.Floor
        )
        .min(params.drawnShares);
    }

    uint256 collateralSharesToLiquidate = LiquidationLogic._calculateCollateralToLiquidate(
      LiquidationLogic.CalculateCollateralToLiquidateParams({
        collateralReserveHub: params.collateralReserveHub,
        collateralReserveAssetId: params.collateralReserveAssetId,
        collateralAssetUnit: params.collateralAssetUnit,
        collateralAssetPrice: params.collateralAssetPrice,
        drawnSharesToLiquidate: drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: premiumDebtRayToLiquidate,
        drawnIndex: params.drawnIndex,
        debtAssetUnit: params.debtAssetUnit,
        debtAssetPrice: params.debtAssetPrice,
        liquidationBonus: params.liquidationBonus
      })
    );

    if (collateralSharesToLiquidate > params.maxRemovableShares) {
      // the priced removal exceeds the cap: resize the repayment to exactly consume the remaining
      // shares, using the inverse of the canonical bonus pricing. The resized repayment never
      // exceeds the repayment computed above, so it stays within `debtToCover` and the user's debt
      collateralSharesToLiquidate = params.maxRemovableShares;
      uint256 debtRayToLiquidate = Math.mulDiv(
        params.collateralReserveHub.previewAddByShares(
          params.collateralReserveAssetId,
          collateralSharesToLiquidate
        ),
        params.collateralAssetPrice *
          params.debtAssetUnit *
          PercentageMath.PERCENTAGE_FACTOR *
          WadRayMath.RAY,
        params.debtAssetPrice * params.collateralAssetUnit * params.liquidationBonus,
        Math.Rounding.Ceil
      );

      if (debtRayToLiquidate <= params.premiumDebtRay) {
        // `premiumDebtRayToLiquidate` may exceed `debtRayToLiquidate` as a result of rounding up to asset units, ensuring full utilization of assets
        premiumDebtRayToLiquidate = debtRayToLiquidate.roundRayUp().min(params.premiumDebtRay);
        drawnSharesToLiquidate = 0;
      } else {
        premiumDebtRayToLiquidate = params.premiumDebtRay;
        drawnSharesToLiquidate = (debtRayToLiquidate - premiumDebtRayToLiquidate).divUp(
          params.drawnIndex
        );
      }
    }

    return
      LiquidationAmounts({
        collateralSharesToLiquidate: collateralSharesToLiquidate,
        drawnSharesToLiquidate: drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: premiumDebtRayToLiquidate
      });
  }

  /// @notice Validates the liquidation call.
  /// @dev All debt reserves are validated upfront: repayment amounts must be non-zero, debt
  /// reserves must be unique and must not be paused.
  /// @param reserves The mapping of reserves per reserve id.
  /// @param userPositionStatus The position status of the user being liquidated.
  /// @param params The validate liquidation call params.
  function _validateLiquidationCall(
    mapping(uint256 reserveId => ISpoke.Reserve) storage reserves,
    ISpoke.PositionStatus storage userPositionStatus,
    ValidateLiquidationCallParams memory params
  ) internal view {
    require(params.user != params.liquidator, ISpoke.SelfLiquidation());
    require(
      params.debtReserveIds.length > 0 &&
        params.debtReserveIds.length == params.debtToCoverAmounts.length,
      IBabylonSpoke.InvalidLiquidationCallArguments()
    );
    require(!params.collateralReserveFlags.paused(), ISpoke.ReservePaused());
    require(params.suppliedShares > 0, ISpoke.ReserveNotSupplied());
    require(
      params.healthFactor < LiquidationLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      ISpoke.HealthFactorNotBelowThreshold()
    );
    require(
      params.collateralFactor > 0 &&
        userPositionStatus.isUsingAsCollateral(params.collateralReserveId),
      ISpoke.ReserveNotEnabledAsCollateral()
    );

    for (uint256 i = 0; i < params.debtReserveIds.length; ++i) {
      uint256 debtReserveId = params.debtReserveIds[i];
      require(params.debtToCoverAmounts[i] > 0, ISpoke.InvalidDebtToCover());
      require(!reserves.get(debtReserveId).flags.paused(), ISpoke.ReservePaused());
      // quadratic duplicate scan; the list is bounded by the user's borrowed reserves
      for (uint256 j = 0; j < i; ++j) {
        require(
          params.debtReserveIds[j] != debtReserveId,
          IBabylonSpoke.InvalidLiquidationCallArguments()
        );
      }
    }
  }
}
