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
import {IDiscreteLiquidationSpoke} from 'src/spoke/interfaces/IDiscreteLiquidationSpoke.sol';

/// @title DiscreteLiquidationLogic library
/// @author Aave Labs
/// @notice Implements the logic for discrete liquidations, sized by a collateral cap instead of a
/// target health factor and without dust validation.
library DiscreteLiquidationLogic {
  using MathUtils for *;
  using WadRayMath for uint256;
  using SpokeUtils for *;
  using UserPositionUtils for ISpoke.UserPosition;
  using ReserveFlagsMap for ReserveFlags;
  using PositionStatusMap for ISpoke.PositionStatus;

  struct LiquidateUserParams {
    uint256 collateralReserveId;
    uint256[] debtReserveIds;
    uint256[] debtAmounts;
    address oracle;
    address user;
    ISpoke.LiquidationConfig liquidationConfig;
    uint256 maxCollateralToReceive;
    ISpoke.UserAccountData userAccountData;
    address liquidator;
  }

  struct ValidateDiscreteLiquidationCallParams {
    address user;
    address liquidator;
    uint256 debtReserveCount;
    uint256 debtAmountCount;
    ReserveFlags collateralReserveFlags;
    uint256 suppliedShares;
    uint256 maxCollateralToReceive;
    uint256 collateralFactor;
    bool isUsingAsCollateral;
    uint256 healthFactor;
  }

  struct LiquidationState {
    IHubBase collateralHub;
    uint256 collateralAssetId;
    uint256 collateralAssetUnit;
    uint256 collateralAssetPrice;
    uint256 liquidationBonus;
    uint256 remainingShares;
    uint256 collateralSharesToLiquidate;
    uint256 clearedDebtPositions;
  }

  /// @notice Liquidates a user position with discrete sizing.
  /// @dev The health factor is validated once at entry, not per debt reserve: with multiple debt
  /// reserves, an intermediate repayment can restore the health factor above the threshold while the
  /// seizure cap is not yet reached, and repayment must be able to continue so the seizure can be
  /// completed. Over-liquidation is bounded by `maxCollateralToReceive` and by the liquidation
  /// manager restriction on the caller.
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
    ISpoke.DynamicReserveConfig storage collateralDynConfig = dynamicConfig[
      params.collateralReserveId
    ][collateralUserPosition.dynamicConfigKey];

    uint256 suppliedShares = collateralUserPosition.suppliedShares;

    _validateDiscreteLiquidationCall(
      ValidateDiscreteLiquidationCallParams({
        user: params.user,
        liquidator: params.liquidator,
        debtReserveCount: params.debtReserveIds.length,
        debtAmountCount: params.debtAmounts.length,
        collateralReserveFlags: collateralReserve.flags,
        suppliedShares: suppliedShares,
        maxCollateralToReceive: params.maxCollateralToReceive,
        collateralFactor: collateralDynConfig.collateralFactor,
        isUsingAsCollateral: positionStatus[params.user].isUsingAsCollateral(
          params.collateralReserveId
        ),
        healthFactor: params.userAccountData.healthFactor
      })
    );

    LiquidationState memory state;
    state.collateralHub = collateralReserve.hub;
    state.collateralAssetId = collateralReserve.assetId;
    state.collateralAssetUnit = MathUtils.uncheckedExp(10, collateralReserve.decimals);
    state.collateralAssetPrice = IAaveOracle(params.oracle).getReservePrice(
      params.collateralReserveId
    );
    state.liquidationBonus = LiquidationLogic.calculateLiquidationBonus({
      healthFactorForMaxBonus: params.liquidationConfig.healthFactorForMaxBonus,
      liquidationBonusFactor: params.liquidationConfig.liquidationBonusFactor,
      healthFactor: params.userAccountData.healthFactor,
      maxLiquidationBonus: collateralDynConfig.maxLiquidationBonus
    });
    state.remainingShares = state
      .collateralHub
      .previewAddByAssets(state.collateralAssetId, params.maxCollateralToReceive)
      .min(suppliedShares);

    for (uint256 i = 0; i < params.debtReserveIds.length; ++i) {
      _liquidateDebtReserve({
        reserves: reserves,
        userPositions: userPositions,
        positionStatus: positionStatus,
        params: params,
        state: state,
        index: i
      });
      // stop early once the seizure cap is reached; later debt reserves are left untouched
      if (state.remainingShares == 0) break;
    }

    uint256 collateralSharesToLiquidator = state.collateralSharesToLiquidate -
      state.collateralSharesToLiquidate.mulDivUp(
        uint256(collateralDynConfig.liquidationFee) *
          (state.liquidationBonus - PercentageMath.PERCENTAGE_FACTOR),
        state.liquidationBonus * PercentageMath.PERCENTAGE_FACTOR
      );

    LiquidationLogic.LiquidateCollateralResult memory liquidateCollateralResult = LiquidationLogic
      ._liquidateCollateral(
        collateralUserPosition,
        userPositions[params.liquidator][params.collateralReserveId],
        LiquidationLogic.LiquidateCollateralParams({
          hub: state.collateralHub,
          assetId: state.collateralAssetId,
          sharesToLiquidate: state.collateralSharesToLiquidate,
          sharesToLiquidator: collateralSharesToLiquidator,
          liquidator: params.liquidator,
          receiveShares: false
        })
      );

    emit IDiscreteLiquidationSpoke.DiscreteLiquidationCall({
      collateralReserveId: params.collateralReserveId,
      user: params.user,
      liquidator: params.liquidator,
      collateralAmountRemoved: liquidateCollateralResult.amountRemoved,
      collateralSharesLiquidated: state.collateralSharesToLiquidate,
      collateralSharesToLiquidator: collateralSharesToLiquidator
    });

    return
      liquidateCollateralResult.isCollateralPositionEmpty &&
      params.userAccountData.activeCollateralCount == 1 &&
      params.userAccountData.borrowCount > state.clearedDebtPositions;
  }

  /// @dev Repays a single debt reserve and accrues its seizure into the liquidation state.
  /// @dev Repays up to the given amount, capped at the user's full debt in the reserve, with premium
  /// debt liquidated first. The seizure is priced with the canonical bonus formula and capped at the
  /// remaining seizable shares; when the cap binds, the repayment is resized to exactly consume the
  /// remaining seizable shares, mirroring the canonical full-collateral sizing.
  function _liquidateDebtReserve(
    mapping(uint256 reserveId => ISpoke.Reserve) storage reserves,
    mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition)) storage userPositions,
    mapping(address user => ISpoke.PositionStatus) storage positionStatus,
    LiquidateUserParams memory params,
    LiquidationState memory state,
    uint256 index
  ) internal {
    uint256 debtReserveId = params.debtReserveIds[index];
    uint256 debtToCover = params.debtAmounts[index];
    ISpoke.Reserve storage debtReserve = reserves.get(debtReserveId);
    ISpoke.UserPosition storage debtUserPosition = userPositions[params.user][debtReserveId];

    require(debtToCover > 0, ISpoke.InvalidDebtToCover());
    require(!debtReserve.flags.paused(), ISpoke.ReservePaused());

    UserPositionUtils.DebtComponents memory debtComponents = debtUserPosition.getDebtComponents(
      debtReserve.hub,
      debtReserve.assetId
    );
    // user has active debt if and only if user has drawn shares (premium debt is always repaid first,
    // and can only be created when drawn shares exist)
    require(debtComponents.drawnShares > 0, ISpoke.ReserveNotBorrowed());

    uint256 debtAssetUnit = MathUtils.uncheckedExp(10, debtReserve.decimals);
    uint256 debtAssetPrice = IAaveOracle(params.oracle).getReservePrice(debtReserveId);

    uint256 premiumDebtRayToLiquidate = debtComponents.premiumDebtRay;
    uint256 drawnSharesToLiquidate;
    if (debtToCover < premiumDebtRayToLiquidate.fromRayUp()) {
      premiumDebtRayToLiquidate = debtToCover.toRay();
    } else {
      drawnSharesToLiquidate = Math
        .mulDiv(
          debtToCover - premiumDebtRayToLiquidate.fromRayUp(),
          WadRayMath.RAY,
          debtComponents.drawnIndex,
          Math.Rounding.Floor
        )
        .min(debtComponents.drawnShares);
    }

    uint256 collateralShares = LiquidationLogic._calculateCollateralToLiquidate(
      LiquidationLogic.CalculateCollateralToLiquidateParams({
        collateralReserveHub: state.collateralHub,
        collateralReserveAssetId: state.collateralAssetId,
        collateralAssetUnit: state.collateralAssetUnit,
        collateralAssetPrice: state.collateralAssetPrice,
        drawnSharesToLiquidate: drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: premiumDebtRayToLiquidate,
        drawnIndex: debtComponents.drawnIndex,
        debtAssetUnit: debtAssetUnit,
        debtAssetPrice: debtAssetPrice,
        liquidationBonus: state.liquidationBonus
      })
    );

    if (collateralShares > state.remainingShares) {
      // the seizure cap binds: resize the repayment to exactly consume the remaining seizable
      // shares, using the inverse of the canonical bonus pricing, without exceeding the repayment
      // computed above
      collateralShares = state.remainingShares;
      uint256 debtRayToLiquidate = Math.mulDiv(
        state.collateralHub.previewAddByShares(state.collateralAssetId, collateralShares),
        state.collateralAssetPrice *
          debtAssetUnit *
          PercentageMath.PERCENTAGE_FACTOR *
          WadRayMath.RAY,
        debtAssetPrice * state.collateralAssetUnit * state.liquidationBonus,
        Math.Rounding.Ceil
      );

      if (debtRayToLiquidate <= premiumDebtRayToLiquidate) {
        // `premiumDebtRayToLiquidate` may exceed `debtRayToLiquidate` as a result of rounding up to asset units, ensuring full utilization of assets
        premiumDebtRayToLiquidate = debtRayToLiquidate.roundRayUp().min(premiumDebtRayToLiquidate);
        drawnSharesToLiquidate = 0;
      } else {
        // `drawnSharesToLiquidate` may exceed the repayment computed above due to rounding, in which
        // case the repayment stands and its seizure remains capped at the remaining seizable shares
        drawnSharesToLiquidate = (debtRayToLiquidate - premiumDebtRayToLiquidate)
          .divUp(debtComponents.drawnIndex)
          .min(drawnSharesToLiquidate);
      }
    }
    state.remainingShares -= collateralShares;
    state.collateralSharesToLiquidate += collateralShares;

    LiquidationLogic.LiquidateDebtResult memory liquidateDebtResult = LiquidationLogic
      ._liquidateDebt(
        debtUserPosition,
        positionStatus[params.user],
        LiquidationLogic.LiquidateDebtParams({
          hub: debtReserve.hub,
          assetId: debtReserve.assetId,
          underlying: debtReserve.underlying,
          reserveId: debtReserveId,
          drawnSharesToLiquidate: drawnSharesToLiquidate,
          premiumDebtRayToLiquidate: premiumDebtRayToLiquidate,
          drawnIndex: debtComponents.drawnIndex,
          liquidator: params.liquidator
        })
      );
    if (liquidateDebtResult.isDebtPositionEmpty) {
      state.clearedDebtPositions = state.clearedDebtPositions.uncheckedAdd(1);
    }

    emit IDiscreteLiquidationSpoke.DiscreteLiquidationRepay({
      debtReserveId: debtReserveId,
      user: params.user,
      debtAmountRestored: liquidateDebtResult.amountRestored,
      drawnSharesLiquidated: drawnSharesToLiquidate,
      premiumDelta: liquidateDebtResult.premiumDelta
    });
  }

  /// @notice Validates the discrete liquidation call.
  /// @dev Per debt reserve validation happens in `_liquidateDebtReserve`.
  /// @param params The validate discrete liquidation call params.
  function _validateDiscreteLiquidationCall(
    ValidateDiscreteLiquidationCallParams memory params
  ) internal pure {
    require(params.user != params.liquidator, ISpoke.SelfLiquidation());
    require(
      params.debtReserveCount > 0 && params.debtReserveCount == params.debtAmountCount,
      IDiscreteLiquidationSpoke.InvalidLiquidationCallArguments()
    );
    require(
      params.maxCollateralToReceive > 0,
      IDiscreteLiquidationSpoke.InvalidMaxCollateralToReceive()
    );
    require(!params.collateralReserveFlags.paused(), ISpoke.ReservePaused());
    require(params.suppliedShares > 0, ISpoke.ReserveNotSupplied());
    require(
      params.healthFactor < LiquidationLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      ISpoke.HealthFactorNotBelowThreshold()
    );
    require(
      params.collateralFactor > 0 && params.isUsingAsCollateral,
      ISpoke.ReserveNotEnabledAsCollateral()
    );
  }
}
