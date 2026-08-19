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
    uint256 debtReserveId;
    address oracle;
    address user;
    ISpoke.LiquidationConfig liquidationConfig;
    uint256 debtToCover;
    uint256 maxCollateralToReceive;
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
    uint256 maxCollateralToReceive;
    uint256 healthFactor;
    uint256 activeCollateralCount;
    uint256 borrowCount;
    address liquidator;
  }

  struct ValidateDiscreteLiquidationCallParams {
    address user;
    address liquidator;
    ReserveFlags collateralReserveFlags;
    ReserveFlags debtReserveFlags;
    uint256 suppliedShares;
    uint256 drawnShares;
    uint256 debtToCover;
    uint256 maxCollateralToReceive;
    uint256 collateralFactor;
    bool isUsingAsCollateral;
    uint256 healthFactor;
  }

  struct CalculateDiscreteLiquidationAmountsParams {
    IHubBase collateralReserveHub;
    uint256 collateralReserveAssetId;
    uint256 collateralAssetDecimals;
    uint256 collateralAssetPrice;
    uint256 suppliedShares;
    uint256 drawnShares;
    uint256 premiumDebtRay;
    uint256 drawnIndex;
    uint256 debtAssetDecimals;
    uint256 debtAssetPrice;
    uint256 debtToCover;
    uint256 maxCollateralToReceive;
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
    uint256 maxLiquidationBonus;
    uint256 healthFactor;
    uint256 liquidationFee;
  }

  /// @notice Liquidates a user position with discrete sizing.
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
      maxCollateralToReceive: params.maxCollateralToReceive,
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

  /// @dev Executes the discrete liquidation.
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

    _validateDiscreteLiquidationCall(
      ValidateDiscreteLiquidationCallParams({
        user: params.user,
        liquidator: params.liquidator,
        collateralReserveFlags: params.collateralReserveFlags,
        debtReserveFlags: params.debtReserveFlags,
        suppliedShares: suppliedShares,
        drawnShares: debtComponents.drawnShares,
        debtToCover: params.debtToCover,
        maxCollateralToReceive: params.maxCollateralToReceive,
        collateralFactor: params.collateralDynConfig.collateralFactor,
        isUsingAsCollateral: userPositionStatus.isUsingAsCollateral(params.collateralReserveId),
        healthFactor: params.healthFactor
      })
    );

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = _calculateLiquidationAmounts(
      CalculateDiscreteLiquidationAmountsParams({
        collateralReserveHub: params.collateralHub,
        collateralReserveAssetId: params.collateralAssetId,
        collateralAssetDecimals: params.collateralAssetDecimals,
        collateralAssetPrice: IAaveOracle(params.oracle).getReservePrice(
          params.collateralReserveId
        ),
        suppliedShares: suppliedShares,
        drawnShares: debtComponents.drawnShares,
        premiumDebtRay: debtComponents.premiumDebtRay,
        drawnIndex: debtComponents.drawnIndex,
        debtAssetDecimals: params.debtAssetDecimals,
        debtAssetPrice: IAaveOracle(params.oracle).getReservePrice(params.debtReserveId),
        debtToCover: params.debtToCover,
        maxCollateralToReceive: params.maxCollateralToReceive,
        healthFactorForMaxBonus: params.liquidationConfig.healthFactorForMaxBonus,
        liquidationBonusFactor: params.liquidationConfig.liquidationBonusFactor,
        maxLiquidationBonus: params.collateralDynConfig.maxLiquidationBonus,
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

    emit IDiscreteLiquidationSpoke.DiscreteLiquidationCall({
      collateralReserveId: params.collateralReserveId,
      debtReserveId: params.debtReserveId,
      user: params.user,
      liquidator: params.liquidator,
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

  /// @notice Validates the discrete liquidation call.
  /// @param params The validate discrete liquidation call params.
  function _validateDiscreteLiquidationCall(
    ValidateDiscreteLiquidationCallParams memory params
  ) internal pure {
    require(params.user != params.liquidator, ISpoke.SelfLiquidation());
    require(params.debtToCover > 0, ISpoke.InvalidDebtToCover());
    require(
      params.maxCollateralToReceive > 0,
      IDiscreteLiquidationSpoke.InvalidMaxCollateralToReceive()
    );
    require(
      !params.collateralReserveFlags.paused() && !params.debtReserveFlags.paused(),
      ISpoke.ReservePaused()
    );
    require(params.suppliedShares > 0, ISpoke.ReserveNotSupplied());
    // user has active debt if and only if user has drawn shares (premium debt is always repaid first,
    // and can only be created when drawn shares exist)
    require(params.drawnShares > 0, ISpoke.ReserveNotBorrowed());
    require(
      params.healthFactor < LiquidationLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      ISpoke.HealthFactorNotBelowThreshold()
    );
    require(
      params.collateralFactor > 0 && params.isUsingAsCollateral,
      ISpoke.ReserveNotEnabledAsCollateral()
    );
  }

  /// @notice Calculates the discrete liquidation amounts.
  /// @dev Repays up to `debtToCover`, capped at the full user debt, with premium debt liquidated first.
  /// @dev The seized collateral is computed with the canonical bonus formula, then capped at
  /// `maxCollateralToReceive` and at the user's collateral balance. Any computed seizure beyond the
  /// caps is not taken, while the repayment stands.
  function _calculateLiquidationAmounts(
    CalculateDiscreteLiquidationAmountsParams memory params
  ) internal view returns (LiquidationLogic.LiquidationAmounts memory) {
    uint256 liquidationBonus = LiquidationLogic.calculateLiquidationBonus({
      healthFactorForMaxBonus: params.healthFactorForMaxBonus,
      liquidationBonusFactor: params.liquidationBonusFactor,
      healthFactor: params.healthFactor,
      maxLiquidationBonus: params.maxLiquidationBonus
    });

    uint256 premiumDebtRayToLiquidate = params.premiumDebtRay;
    uint256 drawnSharesToLiquidate;
    if (params.debtToCover < premiumDebtRayToLiquidate.fromRayUp()) {
      premiumDebtRayToLiquidate = params.debtToCover.toRay();
    } else {
      drawnSharesToLiquidate = Math
        .mulDiv(
          params.debtToCover - premiumDebtRayToLiquidate.fromRayUp(),
          WadRayMath.RAY,
          params.drawnIndex,
          Math.Rounding.Floor
        )
        .min(params.drawnShares);
    }

    uint256 collateralSharesToLiquidate = LiquidationLogic
      ._calculateCollateralToLiquidate(
        LiquidationLogic.CalculateCollateralToLiquidateParams({
          collateralReserveHub: params.collateralReserveHub,
          collateralReserveAssetId: params.collateralReserveAssetId,
          collateralAssetUnit: MathUtils.uncheckedExp(10, params.collateralAssetDecimals),
          collateralAssetPrice: params.collateralAssetPrice,
          drawnSharesToLiquidate: drawnSharesToLiquidate,
          premiumDebtRayToLiquidate: premiumDebtRayToLiquidate,
          drawnIndex: params.drawnIndex,
          debtAssetUnit: MathUtils.uncheckedExp(10, params.debtAssetDecimals),
          debtAssetPrice: params.debtAssetPrice,
          liquidationBonus: liquidationBonus
        })
      )
      .min(
        params.collateralReserveHub.previewAddByAssets(
          params.collateralReserveAssetId,
          params.maxCollateralToReceive
        )
      )
      .min(params.suppliedShares);

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
}
