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
import {ReserveFlags} from 'src/spoke/libraries/ReserveFlagsMap.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title BabylonLiquidationLogic library
/// @author Aave Labs
/// @notice Implements the Babylon liquidation logic: the canonical sizing extended with a cap on
/// the total collateral removed and bypasses of dust protection and target health factor sizing.
library BabylonLiquidationLogic {
  using MathUtils for *;
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using SpokeUtils for *;
  using UserPositionUtils for ISpoke.UserPosition;
  using PositionStatusMap for ISpoke.PositionStatus;

  /// @notice Caller-supplied overrides to the canonical liquidation sizing.
  /// @dev maxCollateralToRemove The maximum total amount of collateral to remove from the user, expressed in asset units. `type(uint256).max` for no cap.
  /// @dev dustThreshold The liquidation dust threshold (in value terms). Zero disables dust protection.
  /// @dev bypassTargetHealthFactor True to size the repaid debt to the full reserve debt instead of the target health factor.
  struct LiquidationOverrides {
    uint256 maxCollateralToRemove;
    uint256 dustThreshold;
    bool bypassTargetHealthFactor;
  }

  struct LiquidateUserParams {
    uint256 collateralReserveId;
    uint256 debtReserveId;
    address oracle;
    address user;
    ISpoke.LiquidationConfig liquidationConfig;
    uint256 debtToCover;
    LiquidationOverrides overrides;
    ISpoke.UserAccountData userAccountData;
    address liquidator;
    bool receiveShares;
  }

  struct ExecuteLiquidationParams {
    IHubBase collateralHub;
    uint256 collateralAssetId;
    uint256 collateralAssetDecimals;
    uint256 collateralReserveId;
    ReserveFlags collateralReserveFlags;
    ISpoke.DynamicReserveConfig collateralDynConfig;
    IHubBase debtHub;
    uint256 debtAssetId;
    uint256 debtAssetDecimals;
    address debtUnderlying;
    uint256 debtReserveId;
    ReserveFlags debtReserveFlags;
    ISpoke.LiquidationConfig liquidationConfig;
    address oracle;
    address user;
    uint256 debtToCover;
    LiquidationOverrides overrides;
    uint256 healthFactor;
    uint256 totalDebtValueRay;
    uint256 activeCollateralCount;
    uint256 borrowCount;
    address liquidator;
    bool receiveShares;
  }

  struct CalculateDebtToLiquidateParams {
    uint256 drawnShares;
    uint256 premiumDebtRay;
    uint256 drawnIndex;
    uint256 totalDebtValueRay;
    uint256 debtAssetDecimals;
    uint256 debtAssetUnit;
    uint256 debtAssetPrice;
    uint256 debtToCover;
    uint256 collateralFactor;
    uint256 liquidationBonus;
    uint256 healthFactor;
    uint256 targetHealthFactor;
    LiquidationOverrides overrides;
  }

  struct CalculateLiquidationAmountsParams {
    IHubBase collateralReserveHub;
    uint256 collateralReserveAssetId;
    uint256 suppliedShares;
    uint256 collateralAssetDecimals;
    uint256 collateralAssetPrice;
    uint256 drawnShares;
    uint256 premiumDebtRay;
    uint256 drawnIndex;
    uint256 totalDebtValueRay;
    uint256 debtAssetDecimals;
    uint256 debtAssetPrice;
    uint256 debtToCover;
    LiquidationOverrides overrides;
    uint256 collateralFactor;
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
    uint256 maxLiquidationBonus;
    uint256 targetHealthFactor;
    uint256 healthFactor;
    uint256 liquidationFee;
  }

  /// @notice Liquidates a user position, applying the given liquidation overrides.
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
    ISpoke.Reserve storage debtReserve = reserves.get(params.debtReserveId);

    ISpoke.UserPosition storage collateralUserPosition = userPositions[params.user][
      params.collateralReserveId
    ];
    ISpoke.DynamicReserveConfig storage collateralDynConfig = dynamicConfig[
      params.collateralReserveId
    ][collateralUserPosition.dynamicConfigKey];

    ExecuteLiquidationParams memory executeLiquidationParams = ExecuteLiquidationParams({
      collateralHub: collateralReserve.hub,
      collateralAssetId: collateralReserve.assetId,
      collateralAssetDecimals: collateralReserve.decimals,
      collateralReserveId: params.collateralReserveId,
      collateralReserveFlags: collateralReserve.flags,
      collateralDynConfig: collateralDynConfig,
      debtHub: debtReserve.hub,
      debtAssetId: debtReserve.assetId,
      debtAssetDecimals: debtReserve.decimals,
      debtUnderlying: debtReserve.underlying,
      debtReserveId: params.debtReserveId,
      debtReserveFlags: debtReserve.flags,
      liquidationConfig: params.liquidationConfig,
      oracle: params.oracle,
      user: params.user,
      debtToCover: params.debtToCover,
      overrides: params.overrides,
      healthFactor: params.userAccountData.healthFactor,
      totalDebtValueRay: params.userAccountData.totalDebtValueRay,
      activeCollateralCount: params.userAccountData.activeCollateralCount,
      borrowCount: params.userAccountData.borrowCount,
      liquidator: params.liquidator,
      receiveShares: params.receiveShares
    });

    ISpoke.UserPosition storage debtUserPosition = userPositions[params.user][params.debtReserveId];
    ISpoke.UserPosition storage collateralLiquidatorPosition = userPositions[params.liquidator][
      params.collateralReserveId
    ];
    ISpoke.PositionStatus storage userPositionStatus = positionStatus[params.user];

    return
      _executeLiquidation({
        collateralUserPosition: collateralUserPosition,
        debtUserPosition: debtUserPosition,
        collateralLiquidatorPosition: collateralLiquidatorPosition,
        userPositionStatus: userPositionStatus,
        params: executeLiquidationParams
      });
  }

  /// @dev Executes the liquidation. Mirrors the canonical execution, with sizing applying the
  /// liquidation overrides.
  /// @param collateralUserPosition User's collateral position.
  /// @param debtUserPosition User's debt position.
  /// @param collateralLiquidatorPosition Liquidator's collateral position.
  /// @param userPositionStatus User's position status.
  /// @param params The execute liquidation params.
  /// @return True if the liquidation results in deficit.
  function _executeLiquidation(
    ISpoke.UserPosition storage collateralUserPosition,
    ISpoke.UserPosition storage debtUserPosition,
    ISpoke.UserPosition storage collateralLiquidatorPosition,
    ISpoke.PositionStatus storage userPositionStatus,
    ExecuteLiquidationParams memory params
  ) internal returns (bool) {
    uint256 suppliedShares = collateralUserPosition.suppliedShares;
    UserPositionUtils.DebtComponents memory debtComponents = debtUserPosition.getDebtComponents(
      params.debtHub,
      params.debtAssetId
    );

    require(
      params.overrides.maxCollateralToRemove > 0,
      IBabylonSpoke.InvalidMaxCollateralToRemove()
    );
    LiquidationLogic._validateLiquidationCall(
      LiquidationLogic.ValidateLiquidationCallParams({
        user: params.user,
        liquidator: params.liquidator,
        collateralReserveFlags: params.collateralReserveFlags,
        debtReserveFlags: params.debtReserveFlags,
        suppliedShares: suppliedShares,
        drawnShares: debtComponents.drawnShares,
        debtToCover: params.debtToCover,
        collateralFactor: params.collateralDynConfig.collateralFactor,
        isUsingAsCollateral: userPositionStatus.isUsingAsCollateral(params.collateralReserveId),
        healthFactor: params.healthFactor,
        receiveShares: params.receiveShares
      })
    );

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = _calculateLiquidationAmounts(
      CalculateLiquidationAmountsParams({
        collateralReserveHub: params.collateralHub,
        collateralReserveAssetId: params.collateralAssetId,
        suppliedShares: suppliedShares,
        collateralAssetDecimals: params.collateralAssetDecimals,
        collateralAssetPrice: IAaveOracle(params.oracle).getReservePrice(
          params.collateralReserveId
        ),
        drawnShares: debtComponents.drawnShares,
        premiumDebtRay: debtComponents.premiumDebtRay,
        drawnIndex: debtComponents.drawnIndex,
        totalDebtValueRay: params.totalDebtValueRay,
        debtAssetDecimals: params.debtAssetDecimals,
        debtAssetPrice: IAaveOracle(params.oracle).getReservePrice(params.debtReserveId),
        debtToCover: params.debtToCover,
        overrides: params.overrides,
        collateralFactor: params.collateralDynConfig.collateralFactor,
        healthFactorForMaxBonus: params.liquidationConfig.healthFactorForMaxBonus,
        liquidationBonusFactor: params.liquidationConfig.liquidationBonusFactor,
        maxLiquidationBonus: params.collateralDynConfig.maxLiquidationBonus,
        targetHealthFactor: params.liquidationConfig.targetHealthFactor,
        healthFactor: params.healthFactor,
        liquidationFee: params.collateralDynConfig.liquidationFee
      })
    );

    LiquidationLogic.LiquidateCollateralResult memory liquidateCollateralResult = LiquidationLogic
      ._liquidateCollateral(
        collateralUserPosition,
        collateralLiquidatorPosition,
        LiquidationLogic.LiquidateCollateralParams({
          hub: params.collateralHub,
          assetId: params.collateralAssetId,
          sharesToLiquidate: liquidationAmounts.collateralSharesToLiquidate,
          sharesToLiquidator: liquidationAmounts.collateralSharesToLiquidator,
          liquidator: params.liquidator,
          receiveShares: params.receiveShares
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

    emit ISpoke.LiquidationCall({
      collateralReserveId: params.collateralReserveId,
      debtReserveId: params.debtReserveId,
      user: params.user,
      liquidator: params.liquidator,
      receiveShares: params.receiveShares,
      debtAmountRestored: liquidateDebtResult.amountRestored,
      drawnSharesLiquidated: liquidationAmounts.drawnSharesToLiquidate,
      premiumDelta: liquidateDebtResult.premiumDelta,
      collateralAmountRemoved: liquidateCollateralResult.amountRemoved,
      collateralSharesLiquidated: liquidationAmounts.collateralSharesToLiquidate,
      collateralSharesToLiquidator: liquidationAmounts.collateralSharesToLiquidator
    });

    return
      LiquidationLogic._evaluateDeficit({
        isCollateralPositionEmpty: liquidateCollateralResult.isCollateralPositionEmpty,
        isDebtPositionEmpty: liquidateDebtResult.isDebtPositionEmpty,
        activeCollateralCount: params.activeCollateralCount,
        borrowCount: params.borrowCount
      });
  }

  /// @notice Calculates the liquidation amounts, applying the liquidation overrides.
  /// @dev Mirrors the canonical calculation, with the collateral available for seizure bounded by
  /// `min(suppliedShares, maxCollateralSharesToRemove)`. When the cap binds below the user's
  /// collateral balance, the remaining collateral and debt must respect the dust threshold.
  function _calculateLiquidationAmounts(
    CalculateLiquidationAmountsParams memory params
  ) internal view returns (LiquidationLogic.LiquidationAmounts memory) {
    uint256 collateralAssetUnit = MathUtils.uncheckedExp(10, params.collateralAssetDecimals);
    uint256 debtAssetUnit = MathUtils.uncheckedExp(10, params.debtAssetDecimals);

    uint256 liquidationBonus = LiquidationLogic.calculateLiquidationBonus({
      healthFactorForMaxBonus: params.healthFactorForMaxBonus,
      liquidationBonusFactor: params.liquidationBonusFactor,
      healthFactor: params.healthFactor,
      maxLiquidationBonus: params.maxLiquidationBonus
    });

    uint256 availableCollateralShares = params.suppliedShares.min(
      params.overrides.maxCollateralToRemove == type(uint256).max
        ? type(uint256).max
        : params.collateralReserveHub.previewAddByAssets(
          params.collateralReserveAssetId,
          params.overrides.maxCollateralToRemove
        )
    );

    // To prevent accumulation of dust, one of the following conditions is enforced:
    // 1. liquidate all debt
    // 2. liquidate all collateral
    // 3. leave at least `overrides.dustThreshold` of collateral and debt (in value terms)
    // The threshold is zero when dust protection is bypassed, so conditions are trivially met.
    (uint256 drawnSharesToLiquidate, uint256 premiumDebtRayToLiquidate) = _calculateDebtToLiquidate(
      CalculateDebtToLiquidateParams({
        drawnShares: params.drawnShares,
        premiumDebtRay: params.premiumDebtRay,
        drawnIndex: params.drawnIndex,
        totalDebtValueRay: params.totalDebtValueRay,
        debtAssetDecimals: params.debtAssetDecimals,
        debtAssetUnit: debtAssetUnit,
        debtAssetPrice: params.debtAssetPrice,
        debtToCover: params.debtToCover,
        collateralFactor: params.collateralFactor,
        liquidationBonus: liquidationBonus,
        healthFactor: params.healthFactor,
        targetHealthFactor: params.targetHealthFactor,
        overrides: params.overrides
      })
    );

    uint256 collateralSharesToLiquidate = LiquidationLogic._calculateCollateralToLiquidate(
      LiquidationLogic.CalculateCollateralToLiquidateParams({
        collateralReserveHub: params.collateralReserveHub,
        collateralReserveAssetId: params.collateralReserveAssetId,
        collateralAssetUnit: collateralAssetUnit,
        collateralAssetPrice: params.collateralAssetPrice,
        drawnSharesToLiquidate: drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: premiumDebtRayToLiquidate,
        drawnIndex: params.drawnIndex,
        debtAssetUnit: debtAssetUnit,
        debtAssetPrice: params.debtAssetPrice,
        liquidationBonus: liquidationBonus
      })
    );

    bool leavesCollateralDust;
    if (collateralSharesToLiquidate < params.suppliedShares) {
      uint256 collateralRemaining = params.collateralReserveHub.previewRemoveByShares(
        params.collateralReserveAssetId,
        params.suppliedShares.uncheckedSub(collateralSharesToLiquidate)
      );
      leavesCollateralDust =
        collateralRemaining.toValue({
          decimals: params.collateralAssetDecimals,
          price: params.collateralAssetPrice
        }) < params.overrides.dustThreshold;
    }

    // debt is fully liquidated if and only if all drawn shares are liquidated
    if (
      collateralSharesToLiquidate > availableCollateralShares ||
      (leavesCollateralDust && drawnSharesToLiquidate < params.drawnShares)
    ) {
      collateralSharesToLiquidate = availableCollateralShares;

      // - `debtRayToLiquidate` is decreased if `collateralSharesToLiquidate > availableCollateralShares` (if so, debt dust could remain).
      // - `debtRayToLiquidate` is increased if `(leavesCollateralDust && drawnSharesToLiquidate < params.drawnShares)`,
      // ensuring the available collateral is fully liquidated (potentially bypassing the target health factor).
      uint256 debtRayToLiquidate = Math.mulDiv(
        params.collateralReserveHub.previewAddByShares(
          params.collateralReserveAssetId,
          collateralSharesToLiquidate
        ),
        params.collateralAssetPrice *
          debtAssetUnit *
          PercentageMath.PERCENTAGE_FACTOR *
          WadRayMath.RAY,
        params.debtAssetPrice * collateralAssetUnit * liquidationBonus,
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

        // `drawnSharesToLiquidate` may exceed `params.drawnShares` due to rounding.
        if (drawnSharesToLiquidate > params.drawnShares) {
          drawnSharesToLiquidate = params.drawnShares;

          // `collateralSharesToLiquidate` may exceed `availableCollateralShares` due to rounding.
          // If this happens, simply cap `collateralSharesToLiquidate` to `availableCollateralShares` since
          // debt to liquidate would be the same (it is already calculated based on `availableCollateralShares`).
          collateralSharesToLiquidate = LiquidationLogic
            ._calculateCollateralToLiquidate(
              LiquidationLogic.CalculateCollateralToLiquidateParams({
                collateralReserveHub: params.collateralReserveHub,
                collateralReserveAssetId: params.collateralReserveAssetId,
                collateralAssetUnit: collateralAssetUnit,
                collateralAssetPrice: params.collateralAssetPrice,
                drawnSharesToLiquidate: drawnSharesToLiquidate,
                premiumDebtRayToLiquidate: premiumDebtRayToLiquidate,
                drawnIndex: params.drawnIndex,
                debtAssetUnit: debtAssetUnit,
                debtAssetPrice: params.debtAssetPrice,
                liquidationBonus: liquidationBonus
              })
            )
            .min(availableCollateralShares);
        }
      }
    }

    // when the cap binds below the user's collateral balance, the collateral reserve cannot be
    // fully liquidated: the remaining collateral and debt must respect the dust threshold
    if (
      params.overrides.dustThreshold > 0 &&
      availableCollateralShares < params.suppliedShares &&
      drawnSharesToLiquidate < params.drawnShares
    ) {
      _validateRemainingDust({
        params: params,
        collateralSharesToLiquidate: collateralSharesToLiquidate,
        drawnSharesToLiquidate: drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: premiumDebtRayToLiquidate
      });
    }

    // revert if the liquidator does not intend to cover the necessary debt to prevent dust from remaining
    require(
      params.debtToCover >=
        drawnSharesToLiquidate.rayMulUp(params.drawnIndex) + premiumDebtRayToLiquidate.fromRayUp(),
      ISpoke.MustNotLeaveDust()
    );

    uint256 collateralSharesToLiquidator = collateralSharesToLiquidate -
      collateralSharesToLiquidate.mulDivUp(
        params.liquidationFee * (liquidationBonus - PercentageMath.PERCENTAGE_FACTOR),
        liquidationBonus * PercentageMath.PERCENTAGE_FACTOR
      );

    return
      LiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: collateralSharesToLiquidate,
        collateralSharesToLiquidator: collateralSharesToLiquidator,
        drawnSharesToLiquidate: drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: premiumDebtRayToLiquidate
      });
  }

  /// @notice Calculates the amount of drawn shares and premium debt that should be liquidated.
  /// @dev Mirrors the canonical calculation, sizing to the full reserve debt when target health
  /// factor sizing is bypassed and using the given dust threshold.
  /// @return The amount of drawn shares to liquidate. Does not exceed `params.drawnShares`.
  /// @return The amount of premium debt to liquidate. Does not exceed `params.premiumDebtRay`.
  function _calculateDebtToLiquidate(
    CalculateDebtToLiquidateParams memory params
  ) internal pure returns (uint256, uint256) {
    // when target health factor sizing is bypassed, size to the full debt of the reserve,
    // equivalent to an infinite target health factor
    uint256 debtRayToTarget = params.overrides.bypassTargetHealthFactor
      ? params.drawnShares * params.drawnIndex + params.premiumDebtRay
      : LiquidationLogic._calculateDebtToTargetHealthFactor(
        LiquidationLogic.CalculateDebtToTargetHealthFactorParams({
          totalDebtValueRay: params.totalDebtValueRay,
          debtAssetUnit: params.debtAssetUnit,
          debtAssetPrice: params.debtAssetPrice,
          collateralFactor: params.collateralFactor,
          liquidationBonus: params.liquidationBonus,
          healthFactor: params.healthFactor,
          targetHealthFactor: params.targetHealthFactor
        })
      );

    // `premiumDebtRayToLiquidate` may exceed `debtRayToTarget` as a result of rounding up to asset units, ensuring full utilization of assets
    uint256 premiumDebtRayToLiquidate = debtRayToTarget.roundRayUp().min(params.premiumDebtRay);
    // strict inequality is mandatory given rounding
    if (params.debtToCover < premiumDebtRayToLiquidate.fromRayUp()) {
      premiumDebtRayToLiquidate = params.debtToCover.toRay();
    }

    uint256 drawnSharesToLiquidate;
    if (
      premiumDebtRayToLiquidate == params.premiumDebtRay &&
      premiumDebtRayToLiquidate < debtRayToTarget
    ) {
      uint256 drawnSharesToTarget = (debtRayToTarget - premiumDebtRayToLiquidate).divUp(
        params.drawnIndex
      );
      uint256 drawnSharesToCover = Math.mulDiv(
        params.debtToCover - premiumDebtRayToLiquidate.fromRayUp(),
        WadRayMath.RAY,
        params.drawnIndex,
        Math.Rounding.Floor
      );

      drawnSharesToLiquidate = drawnSharesToTarget.min(drawnSharesToCover).min(params.drawnShares);
    }

    uint256 debtRayRemaining = (params.drawnShares - drawnSharesToLiquidate) * params.drawnIndex +
      params.premiumDebtRay -
      premiumDebtRayToLiquidate;

    // debt is fully liquidated if and only if all drawn shares are liquidated (premium debt is always liquidated first)
    bool leavesDebtDust = (drawnSharesToLiquidate < params.drawnShares) &&
      debtRayRemaining.toValue({decimals: params.debtAssetDecimals, price: params.debtAssetPrice}) <
        params.overrides.dustThreshold.toRay();

    if (leavesDebtDust) {
      // target health factor is bypassed to prevent leaving dust
      drawnSharesToLiquidate = params.drawnShares;
      premiumDebtRayToLiquidate = params.premiumDebtRay;
    }

    return (drawnSharesToLiquidate, premiumDebtRayToLiquidate);
  }

  /// @dev Reverts unless the remaining collateral and debt balances both respect the dust threshold.
  function _validateRemainingDust(
    CalculateLiquidationAmountsParams memory params,
    uint256 collateralSharesToLiquidate,
    uint256 drawnSharesToLiquidate,
    uint256 premiumDebtRayToLiquidate
  ) internal view {
    uint256 collateralValueRemaining = params
      .collateralReserveHub
      .previewRemoveByShares(
        params.collateralReserveAssetId,
        params.suppliedShares.uncheckedSub(collateralSharesToLiquidate)
      )
      .toValue({decimals: params.collateralAssetDecimals, price: params.collateralAssetPrice});
    uint256 debtValueRayRemaining = ((params.drawnShares - drawnSharesToLiquidate) *
      params.drawnIndex +
      params.premiumDebtRay -
      premiumDebtRayToLiquidate).toValue({
        decimals: params.debtAssetDecimals,
        price: params.debtAssetPrice
      });
    require(
      collateralValueRemaining >= params.overrides.dustThreshold &&
        debtValueRayRemaining >= params.overrides.dustThreshold.toRay(),
      ISpoke.MustNotLeaveDust()
    );
  }
}
