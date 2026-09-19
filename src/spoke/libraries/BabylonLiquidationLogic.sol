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
  using PositionStatusMap for ISpoke.PositionStatus;

  struct LiquidateUserParams {
    uint256 collateralReserveId;
    uint256 debtReserveId;
    address oracle;
    address user;
    ISpoke.LiquidationConfig liquidationConfig;
    uint256 debtToCover;
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
    uint256 maxCollateralToRemove;
    uint256 healthFactor;
    uint256 activeCollateralCount;
    uint256 borrowCount;
    address liquidator;
  }

  struct LiquidationResult {
    bool isUserInDeficit;
    uint256 liquidationBonus;
    uint256 collateralAmountRemoved;
  }

  struct CalculateLiquidationAmountsParams {
    IHubBase collateralReserveHub;
    uint256 collateralReserveAssetId;
    uint256 collateralAssetUnit;
    uint256 collateralAssetPrice;
    uint256 drawnShares;
    uint256 premiumDebtRay;
    uint256 drawnIndex;
    uint256 debtAssetUnit;
    uint256 debtAssetPrice;
    uint256 liquidationBonus;
    uint256 debtToCover;
    uint256 maxRemovableShares;
  }

  struct LiquidationAmounts {
    uint256 collateralSharesToLiquidate;
    uint256 drawnSharesToLiquidate;
    uint256 premiumDebtRayToLiquidate;
  }

  /// @notice Liquidates a user position with cap-bounded sizing.
  /// @dev The liquidation fee is not charged: the liquidator receives the full removed collateral.
  /// @param reserves The mapping of reserves per reserve id.
  /// @param userPositions The mapping of user positions per user per reserve.
  /// @param positionStatus The mapping of position status per user.
  /// @param dynamicConfig The mapping of dynamic config per reserve per dynamic config key.
  /// @param params The liquidate user params.
  /// @return The liquidation result.
  function liquidateUser(
    mapping(uint256 reserveId => ISpoke.Reserve) storage reserves,
    mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition)) storage userPositions,
    mapping(address user => ISpoke.PositionStatus) storage positionStatus,
    mapping(uint256 reserveId => mapping(uint32 dynamicConfigKey => ISpoke.DynamicReserveConfig)) storage dynamicConfig,
    LiquidateUserParams memory params
  ) external returns (LiquidationResult memory) {
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
      maxCollateralToRemove: params.maxCollateralToRemove,
      healthFactor: params.userAccountData.healthFactor,
      activeCollateralCount: params.userAccountData.activeCollateralCount,
      borrowCount: params.userAccountData.borrowCount,
      liquidator: params.liquidator
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

  /// @dev Repays the debt reserve and removes the priced collateral, bounded by the removal cap.
  /// @dev The repayment runs even when no collateral can be removed, so debt is liquidatable when the collateral to receive rounds to zero.
  /// @param collateralUserPosition User's collateral position.
  /// @param debtUserPosition User's debt position.
  /// @param collateralLiquidatorPosition Liquidator's collateral position.
  /// @param userPositionStatus User's position status.
  /// @param params The execute liquidation params.
  /// @return The liquidation result.
  function _executeLiquidation(
    ISpoke.UserPosition storage collateralUserPosition,
    ISpoke.UserPosition storage debtUserPosition,
    ISpoke.UserPosition storage collateralLiquidatorPosition,
    ISpoke.PositionStatus storage userPositionStatus,
    ExecuteLiquidationParams memory params
  ) internal returns (LiquidationResult memory) {
    UserPositionUtils.DebtComponents memory debtComponents = debtUserPosition.getDebtComponents(
      params.debtHub,
      params.debtAssetId
    );

    LiquidationLogic._validateLiquidationCall(
      LiquidationLogic.ValidateLiquidationCallParams({
        user: params.user,
        liquidator: params.liquidator,
        collateralReserveFlags: params.collateralReserveFlags,
        debtReserveFlags: params.debtReserveFlags,
        suppliedShares: collateralUserPosition.suppliedShares,
        drawnShares: debtComponents.drawnShares,
        debtToCover: params.debtToCover,
        collateralFactor: params.collateralDynConfig.collateralFactor,
        isUsingAsCollateral: userPositionStatus.isUsingAsCollateral(params.collateralReserveId),
        healthFactor: params.healthFactor,
        receiveShares: false
      })
    );

    uint256 liquidationBonus = LiquidationLogic.calculateLiquidationBonus({
      healthFactorForMaxBonus: params.liquidationConfig.healthFactorForMaxBonus,
      liquidationBonusFactor: params.liquidationConfig.liquidationBonusFactor,
      healthFactor: params.healthFactor,
      maxLiquidationBonus: params.collateralDynConfig.maxLiquidationBonus
    });

    LiquidationAmounts memory liquidationAmounts = _calculateLiquidationAmounts(
      CalculateLiquidationAmountsParams({
        collateralReserveHub: params.collateralHub,
        collateralReserveAssetId: params.collateralAssetId,
        collateralAssetUnit: MathUtils.uncheckedExp(10, params.collateralAssetDecimals),
        collateralAssetPrice: IAaveOracle(params.oracle).getReservePrice(
          params.collateralReserveId
        ),
        drawnShares: debtComponents.drawnShares,
        premiumDebtRay: debtComponents.premiumDebtRay,
        drawnIndex: debtComponents.drawnIndex,
        debtAssetUnit: MathUtils.uncheckedExp(10, params.debtAssetDecimals),
        debtAssetPrice: IAaveOracle(params.oracle).getReservePrice(params.debtReserveId),
        liquidationBonus: liquidationBonus,
        debtToCover: params.debtToCover,
        // rounded down so the removed collateral cannot exceed the cap
        maxRemovableShares: params
          .collateralHub
          .previewAddByAssets(params.collateralAssetId, params.maxCollateralToRemove)
          .min(collateralUserPosition.suppliedShares)
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
      collateralReserveId: params.collateralReserveId,
      debtReserveId: params.debtReserveId,
      user: params.user,
      liquidator: params.liquidator,
      debtAmountRestored: liquidateDebtResult.amountRestored,
      drawnSharesLiquidated: liquidationAmounts.drawnSharesToLiquidate,
      premiumDelta: liquidateDebtResult.premiumDelta,
      collateralAmountRemoved: liquidateCollateralResult.amountRemoved,
      collateralSharesLiquidated: liquidationAmounts.collateralSharesToLiquidate
    });

    return
      LiquidationResult({
        isUserInDeficit: LiquidationLogic._evaluateDeficit({
          isCollateralPositionEmpty: liquidateCollateralResult.isCollateralPositionEmpty,
          isDebtPositionEmpty: liquidateDebtResult.isDebtPositionEmpty,
          activeCollateralCount: params.activeCollateralCount,
          borrowCount: params.borrowCount
        }),
        liquidationBonus: liquidationBonus,
        collateralAmountRemoved: liquidateCollateralResult.amountRemoved
      });
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
}
