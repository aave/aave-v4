// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract SpokeLiquidationCallBaseTest is LiquidationLogicBaseTest {
  using SafeCast for *;
  using PercentageMath for *;
  using WadRayMath for *;
  using KeyValueList for KeyValueList.List;
  using MathUtils for uint256;

  uint256 internal constant MAX_AMOUNT_IN_BASE_CURRENCY = 1_000_000_000e26; // 1 billion USD
  uint256 internal constant MIN_AMOUNT_IN_BASE_CURRENCY = 1e26; // 1 USD

  struct CheckedLiquidationCallParams {
    ISpoke spoke;
    uint256 collateralReserveId;
    uint256 debtReserveId;
    address user;
    uint256 debtToCover;
    address liquidator;
    bool isSolvent;
    bool receiveShares;
  }

  struct BalanceInfo {
    uint256 collateralErc20Balance;
    uint256 suppliedInSpoke;
    uint256 addedInHub;
    uint256 debtErc20Balance;
    uint256 borrowedFromSpoke;
    uint256 drawnFromHub;
  }

  struct AccountsInfo {
    ISpoke.UserAccountData userAccountData;
    BalanceInfo userBalanceInfo;
    BalanceInfo collateralHubBalanceInfo;
    BalanceInfo debtHubBalanceInfo;
    BalanceInfo liquidatorBalanceInfo;
    BalanceInfo collateralFeeReceiverBalanceInfo;
    BalanceInfo debtFeeReceiverBalanceInfo;
    BalanceInfo spokeBalanceInfo;
    bool hasPositiveRiskPremium;
  }

  struct LiquidationMetadata {
    uint256 debtToTarget;
    uint256 collateralToLiquidate;
    uint256 collateralToLiquidator;
    uint256 collateralSharesToLiquidate;
    uint256 collateralSharesToLiquidator;
    uint256 debtToLiquidate;
    uint256 liquidationBonus;
    uint256 expectedUserRiskPremium;
    uint256 expectedUserAvgCollateralFactor;
    bool isCollateralAffectingUserHf;
    bool hasDeficit;
  }
  struct ExpectEventsAndCallsParams {
    uint256 userDrawnDebt;
    uint256 userPremiumDebt;
    uint256 premiumDebtToRestore;
    uint256 baseAmountToRestore;
    int256 realizedDelta;
    IHubBase.PremiumDelta premiumDelta;
    ISpoke.UserPosition userReservePosition;
    ISpoke.UserPosition userDebtPosition;
    IHub collateralHub;
    IHub debtHub;
    uint256 debtAssetId;
    uint256 collateralAssetId;
  }

  /// @notice Bound liquidation config to full range of possible values
  function _bound(
    ISpoke.LiquidationConfig memory liqConfig
  ) internal pure virtual returns (ISpoke.LiquidationConfig memory) {
    liqConfig.targetHealthFactor = bound(
      liqConfig.targetHealthFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      MAX_CLOSE_FACTOR
    ).toUint120();

    liqConfig.healthFactorForMaxBonus = bound(
      liqConfig.healthFactorForMaxBonus,
      0,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    ).toUint64();

    liqConfig.liquidationBonusFactor = bound(
      liqConfig.liquidationBonusFactor,
      0,
      PercentageMath.PERCENTAGE_FACTOR
    ).toUint16();

    return liqConfig;
  }

  function _bound(
    ISpoke.DynamicReserveConfig memory dynConfig
  ) internal pure virtual returns (ISpoke.DynamicReserveConfig memory) {
    dynConfig.maxLiquidationBonus = bound(
      dynConfig.maxLiquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    ).toUint32();
    dynConfig.collateralFactor = bound(
      dynConfig.collateralFactor,
      1,
      (PercentageMath.PERCENTAGE_FACTOR - 1).percentDivDown(dynConfig.maxLiquidationBonus)
    ).toUint16();
    return dynConfig;
  }

  function _boundAssume(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    address liquidator
  ) internal virtual returns (uint256, uint256, address) {
    collateralReserveId = bound(collateralReserveId, 0, spoke.getReserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke.getReserveCount() - 1);
    vm.assume(user != liquidator);
    assumeUnusedAddress(user);
    return (collateralReserveId, debtReserveId, user);
  }

  function _boundDebtToCoverNoDustRevert(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    address liquidator
  ) internal virtual returns (uint256) {
    debtToCover = bound(
      debtToCover,
      _convertValueToAmount(spoke, debtReserveId, 1e26),
      MAX_SUPPLY_AMOUNT
    );

    LiquidationLogic.CalculateLiquidationAmountsParams
      memory params = _getCalculateLiquidationAmountsParams(
        spoke,
        collateralReserveId,
        debtReserveId,
        user,
        debtToCover
      );
    try liquidationLogicWrapper.calculateLiquidationAmounts(params) returns (
      LiquidationLogic.LiquidationAmounts memory
    ) {} catch {
      ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
      uint256 liquidationBonus = spoke.getLiquidationBonus(
        collateralReserveId,
        user,
        userAccountData.healthFactor
      );
      debtToCover = bound(
        debtToCover,
        params.debtReserveBalance.min(
          _convertAssetAmount(
            spoke,
            collateralReserveId,
            params.collateralReserveBalance.percentDivUp(liquidationBonus),
            debtReserveId
          )
        ),
        MAX_SUPPLY_AMOUNT
      );
    }
    deal(spoke, debtReserveId, liquidator, debtToCover.percentMulUp(101_00));
    Utils.approve(spoke, debtReserveId, liquidator, debtToCover.percentMulUp(101_00));

    return debtToCover;
  }

  function _bound(
    ISpoke spoke,
    uint256[] memory reserveIds,
    uint256 reserveIdToExclude,
    uint256 maxLength
  ) internal view returns (bytes memory) {
    uint256[] memory boundedReserveIds = new uint256[](_min(reserveIds.length, maxLength));

    for (uint256 i = 0; i < boundedReserveIds.length; i++) {
      boundedReserveIds[i] = bound(reserveIds[i], 0, spoke.getReserveCount() - 1);
      if (boundedReserveIds[i] == reserveIdToExclude) {
        boundedReserveIds[i] = bound(boundedReserveIds[i] + 1, 0, spoke.getReserveCount() - 1);
      }
    }
    return abi.encode(boundedReserveIds);
  }

  function _getCalculateDebtToLiquidateParams(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) internal virtual returns (LiquidationLogic.CalculateDebtToLiquidateParams memory) {
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    return
      LiquidationLogic.CalculateDebtToLiquidateParams({
        debtReserveBalance: spoke.getUserTotalDebt(debtReserveId, user),
        debtToCover: debtToCover,
        totalDebtValue: userAccountData.totalDebtValue,
        healthFactor: userAccountData.healthFactor,
        targetHealthFactor: spoke.getLiquidationConfig().targetHealthFactor,
        liquidationBonus: spoke.getLiquidationBonus(
          collateralReserveId,
          user,
          userAccountData.healthFactor
        ),
        collateralFactor: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).dynamicConfigKey
          )
          .collateralFactor,
        debtAssetPrice: IPriceOracle(spoke.ORACLE()).getReservePrice(debtReserveId),
        debtAssetUnit: 10 ** spoke.getReserve(debtReserveId).decimals
      });
  }

  function _getCalculateDebtToTargetHealthFactorParams(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user
  ) internal virtual returns (LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory) {
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    return
      LiquidationLogic.CalculateDebtToTargetHealthFactorParams({
        totalDebtValue: userAccountData.totalDebtValue,
        healthFactor: userAccountData.healthFactor,
        targetHealthFactor: spoke.getLiquidationConfig().targetHealthFactor,
        liquidationBonus: spoke.getLiquidationBonus(
          collateralReserveId,
          user,
          userAccountData.healthFactor
        ),
        collateralFactor: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).dynamicConfigKey
          )
          .collateralFactor,
        debtAssetPrice: IPriceOracle(spoke.ORACLE()).getReservePrice(debtReserveId),
        debtAssetUnit: 10 ** spoke.getReserve(debtReserveId).decimals
      });
  }

  function _getCalculateLiquidationAmountsParams(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) internal virtual returns (LiquidationLogic.CalculateLiquidationAmountsParams memory) {
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    return
      LiquidationLogic.CalculateLiquidationAmountsParams({
        healthFactorForMaxBonus: spoke.getLiquidationConfig().healthFactorForMaxBonus,
        liquidationBonusFactor: spoke.getLiquidationConfig().liquidationBonusFactor,
        debtReserveBalance: spoke.getUserTotalDebt(debtReserveId, user),
        collateralReserveBalance: spoke.getUserSuppliedAssets(collateralReserveId, user),
        debtToCover: debtToCover,
        totalDebtValue: userAccountData.totalDebtValue,
        healthFactor: userAccountData.healthFactor,
        targetHealthFactor: spoke.getLiquidationConfig().targetHealthFactor,
        maxLiquidationBonus: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).dynamicConfigKey
          )
          .maxLiquidationBonus,
        collateralFactor: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).dynamicConfigKey
          )
          .collateralFactor,
        debtAssetPrice: IPriceOracle(spoke.ORACLE()).getReservePrice(debtReserveId),
        debtAssetDecimals: spoke.getReserve(debtReserveId).decimals,
        collateralAssetPrice: IPriceOracle(spoke.ORACLE()).getReservePrice(collateralReserveId),
        collateralAssetDecimals: spoke.getReserve(collateralReserveId).decimals,
        liquidationFee: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).dynamicConfigKey
          )
          .liquidationFee
      });
  }

  function _makeUserLiquidatable(
    ISpoke spoke,
    address user,
    uint256 debtReserveId,
    uint256 newHealthFactor
  ) internal virtual {
    // add liquidity
    _openSupplyPosition(
      spoke,
      debtReserveId,
      _getRequiredDebtAmountForHf(spoke, user, debtReserveId, newHealthFactor)
    );
    // borrow to be at target health factor
    _borrowToBeAtHf(spoke, user, debtReserveId, newHealthFactor);
  }

  function _calculateExpectedUserRiskPremiumAndAvgCollateralFactor(
    CheckedLiquidationCallParams memory params,
    ISpoke.UserAccountData memory userAccountDataBefore,
    uint256 collateralToLiquidate,
    uint256 debtToLiquidate
  ) internal virtual returns (uint256, uint256) {
    KeyValueList.List memory list = KeyValueList.init(userAccountDataBefore.activeCollateralCount);

    uint256 totalCollateralValue = 0;
    uint256 newAvgCollateralFactor = 0;

    uint256 index = 0;
    for (uint256 reserveId = 0; reserveId < params.spoke.getReserveCount(); reserveId++) {
      if (!_isUsingAsCollateral(params.spoke, reserveId, params.user)) {
        continue;
      }

      uint256 collateralFactor = _getCollateralFactor(params.spoke, reserveId, params.user);
      if (collateralFactor == 0) {
        continue;
      }

      uint256 userSuppliedAmount = params.spoke.getUserSuppliedAssets(reserveId, params.user);
      if (params.collateralReserveId == reserveId) {
        userSuppliedAmount -= collateralToLiquidate;
      }
      if (userSuppliedAmount == 0) {
        continue;
      }

      // from now, userSuppliedAmount is in value terms (to avoid stack too deep)
      userSuppliedAmount = _convertAmountToValue(params.spoke, reserveId, userSuppliedAmount);
      list.add(index++, _getCollateralRisk(params.spoke, reserveId), userSuppliedAmount);
      totalCollateralValue += userSuppliedAmount;
      newAvgCollateralFactor += collateralFactor * userSuppliedAmount;
    }

    if (totalCollateralValue != 0) {
      newAvgCollateralFactor = newAvgCollateralFactor
        .wadDivDown(totalCollateralValue)
        .fromBpsDown();
    }
    list.sortByKey();

    uint256 debtToLiquidateValue = _convertAmountToValue(
      params.spoke,
      params.debtReserveId,
      debtToLiquidate
    );
    uint256 totalDebtToCover = userAccountDataBefore.totalDebtValue - debtToLiquidateValue;
    uint256 remainingDebtToCover = totalDebtToCover;

    uint256 newRiskPremium = 0;
    for (uint256 i = 0; i < list.length() && remainingDebtToCover > 0; i++) {
      (uint256 collateralRisk, uint256 collateralValue) = list.get(i);
      newRiskPremium += collateralRisk * _min(collateralValue, remainingDebtToCover);
      remainingDebtToCover -= _min(collateralValue, remainingDebtToCover);
    }

    newRiskPremium /= _max(1, _min(totalDebtToCover, totalCollateralValue));

    return (newRiskPremium, newAvgCollateralFactor);
  }

  function _calculateExactRestoreAmount(
    IHub hub,
    uint256 drawn,
    uint256 premium,
    uint256 restoreAmount,
    uint256 assetId
  ) internal view returns (uint256, uint256) {
    if (restoreAmount <= premium) {
      return (0, restoreAmount);
    }
    uint256 drawnRestored = _min(drawn, restoreAmount - premium);
    // round drawn debt to nearest whole share
    drawnRestored = hub.previewRestoreByShares(
      assetId,
      hub.previewRestoreByAssets(assetId, drawnRestored)
    );
    return (drawnRestored, premium);
  }

  function _expectEventsAndCalls(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory /*accountsInfoBefore*/,
    LiquidationMetadata memory liquidationMetadata
  ) internal virtual {
    ExpectEventsAndCallsParams memory vars;

    vars.userDebtPosition = params.spoke.getUserPosition(params.debtReserveId, params.user);
    vars.collateralHub = _hub(params.spoke, params.collateralReserveId);
    vars.debtHub = _hub(params.spoke, params.debtReserveId);
    vars.debtAssetId = _spokeAssetId(params.spoke, params.debtReserveId);
    vars.collateralAssetId = _spokeAssetId(params.spoke, params.collateralReserveId);

    (vars.userDrawnDebt, vars.userPremiumDebt) = params.spoke.getUserDebt(
      params.debtReserveId,
      params.user
    );

    (vars.baseAmountToRestore, vars.premiumDebtToRestore) = _calculateRestoreAmounts(
      params.spoke,
      params.debtReserveId,
      params.user,
      liquidationMetadata.debtToLiquidate
    );
    vars.premiumDelta = _getExpectedPremiumDelta(
      params.spoke,
      params.user,
      params.debtReserveId,
      liquidationMetadata.debtToLiquidate
    );

    vm.expectEmit(address(params.spoke));
    emit ISpokeBase.LiquidationCall({
      collateralReserveId: params.collateralReserveId,
      debtReserveId: params.debtReserveId,
      user: params.user,
      liquidator: params.liquidator,
      receiveShares: params.receiveShares,
      debtToLiquidate: liquidationMetadata.debtToLiquidate,
      drawnSharesToLiquidate: vars
        .debtHub
        .previewRestoreByAssets(vars.debtAssetId, vars.baseAmountToRestore)
        .toUint120(),
      premiumDelta: vars.premiumDelta,
      collateralToLiquidate: liquidationMetadata.collateralToLiquidate,
      collateralSharesToLiquidate: liquidationMetadata.collateralSharesToLiquidate,
      collateralSharesToLiquidator: liquidationMetadata.collateralSharesToLiquidator
    });

    if (!params.receiveShares && liquidationMetadata.collateralToLiquidator > 0) {
      vm.expectCall(
        address(vars.collateralHub),
        abi.encodeCall(
          IHubBase.remove,
          (vars.collateralAssetId, liquidationMetadata.collateralToLiquidator, params.liquidator)
        ),
        1
      );
    }

    vm.expectCall(
      address(vars.debtHub),
      abi.encodeCall(
        IHubBase.restore,
        (vars.debtAssetId, vars.baseAmountToRestore, vars.premiumDelta)
      ),
      1
    );

    // PayFee call is partially checked, as conversion from assets to shares might differ due to restore donation
    if (liquidationMetadata.collateralToLiquidate > liquidationMetadata.collateralToLiquidator) {
      vm.expectCall(
        address(_hub(params.spoke, params.collateralReserveId)),
        abi.encodeWithSelector(IHubBase.payFeeShares.selector)
      );
    }

    {
      for (uint256 i = params.spoke.getReserveCount(); i != 0; ) {
        i--;
        uint256 reserveId = i;
        if (_isBorrowing(params.spoke, reserveId, params.user)) {
          vars.userReservePosition = params.spoke.getUserPosition(reserveId, params.user);
          uint256 assetId = _spokeAssetId(params.spoke, reserveId);

          if (reserveId == params.debtReserveId) {
            vars.userReservePosition.drawnShares -= _hub(params.spoke, reserveId)
              .previewRestoreByAssets(assetId, vars.baseAmountToRestore)
              .toUint120();
            vars.userReservePosition.premiumShares = 0;
            vars.userReservePosition.premiumOffsetRay = 0;
            vars.userReservePosition.realizedPremiumRay = (vars
              .userReservePosition
              .realizedPremiumRay +
              vars.premiumDelta.accruedPremiumRay -
              vars.premiumDelta.restoredPremiumRay).toUint200();

            if (vars.userReservePosition.drawnShares == 0) {
              continue;
            }
          }

          IHub targetHub = _hub(params.spoke, reserveId);
          uint256 userReserveDrawnDebt = targetHub.previewRestoreByShares(
            assetId,
            vars.userReservePosition.drawnShares
          );

          if (liquidationMetadata.hasDeficit) {
            uint256 accruedPremiumRay = _calculateAccruedPremiumRay(
              params.spoke,
              reserveId,
              vars.userReservePosition.premiumShares,
              vars.userReservePosition.premiumOffsetRay
            );

            vm.expectCall(
              address(targetHub),
              abi.encodeCall(
                IHubBase.reportDeficit,
                (
                  assetId,
                  userReserveDrawnDebt,
                  IHubBase.PremiumDelta({
                    sharesDelta: -vars.userReservePosition.premiumShares.toInt256(),
                    offsetDeltaRay: -vars.userReservePosition.premiumOffsetRay.toInt256(),
                    accruedPremiumRay: accruedPremiumRay,
                    restoredPremiumRay: vars.userReservePosition.realizedPremiumRay +
                      accruedPremiumRay
                  })
                )
              ),
              1
            );
            vm.expectEmit(address(params.spoke));
            emit ISpoke.ReportDeficit({
              reserveId: reserveId,
              user: params.user,
              drawnShares: targetHub
                .previewRestoreByAssets(assetId, userReserveDrawnDebt)
                .toUint120(),
              premiumDelta: IHubBase.PremiumDelta({
                sharesDelta: -vars.userReservePosition.premiumShares.toInt256(),
                offsetDeltaRay: -vars.userReservePosition.premiumOffsetRay.toInt256(),
                accruedPremiumRay: accruedPremiumRay,
                restoredPremiumRay: vars.userReservePosition.realizedPremiumRay + accruedPremiumRay
              })
            });
          }
        }
      }
    }
  }

  function _getBalanceInfo(
    ISpoke spoke,
    address addr,
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal virtual returns (BalanceInfo memory) {
    return
      BalanceInfo({
        collateralErc20Balance: getAssetUnderlyingByReserveId(spoke, collateralReserveId).balanceOf(
          addr
        ),
        suppliedInSpoke: spoke.getUserSuppliedAssets(collateralReserveId, addr),
        addedInHub: _hub(spoke, collateralReserveId).getSpokeAddedAssets(
          _spokeAssetId(spoke, collateralReserveId),
          addr
        ),
        debtErc20Balance: getAssetUnderlyingByReserveId(spoke, debtReserveId).balanceOf(addr),
        borrowedFromSpoke: spoke.getUserTotalDebt(debtReserveId, addr),
        drawnFromHub: _hub(spoke, debtReserveId).getSpokeTotalOwed(
          _spokeAssetId(spoke, debtReserveId),
          addr
        )
      });
  }

  function _getAccountsInfo(
    CheckedLiquidationCallParams memory params
  ) internal virtual returns (AccountsInfo memory) {
    return
      AccountsInfo({
        userAccountData: params.spoke.getUserAccountData(params.user),
        userBalanceInfo: _getBalanceInfo(
          params.spoke,
          params.user,
          params.collateralReserveId,
          params.debtReserveId
        ),
        collateralHubBalanceInfo: _getBalanceInfo(
          params.spoke,
          address(_hub(params.spoke, params.collateralReserveId)),
          params.collateralReserveId,
          params.debtReserveId
        ),
        debtHubBalanceInfo: _getBalanceInfo(
          params.spoke,
          address(_hub(params.spoke, params.debtReserveId)),
          params.collateralReserveId,
          params.debtReserveId
        ),
        liquidatorBalanceInfo: _getBalanceInfo(
          params.spoke,
          params.liquidator,
          params.collateralReserveId,
          params.debtReserveId
        ),
        collateralFeeReceiverBalanceInfo: _getBalanceInfo(
          params.spoke,
          _getFeeReceiver(params.spoke, params.collateralReserveId),
          params.collateralReserveId,
          params.debtReserveId
        ),
        debtFeeReceiverBalanceInfo: _getBalanceInfo(
          params.spoke,
          _getFeeReceiver(params.spoke, params.debtReserveId),
          params.collateralReserveId,
          params.debtReserveId
        ),
        spokeBalanceInfo: _getBalanceInfo(
          params.spoke,
          address(params.spoke),
          params.collateralReserveId,
          params.debtReserveId
        ),
        hasPositiveRiskPremium: _hasPositiveRiskPremium(params.spoke, params.user)
      });
  }

  function _getLiquidationMetadata(
    CheckedLiquidationCallParams memory params,
    ISpoke.UserAccountData memory userAccountDataBefore
  ) internal virtual returns (LiquidationMetadata memory) {
    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getCalculateDebtToTargetHealthFactorParams(
        params.spoke,
        params.collateralReserveId,
        params.debtReserveId,
        params.user
      )
    );
    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(
        _getCalculateLiquidationAmountsParams(
          params.spoke,
          params.collateralReserveId,
          params.debtReserveId,
          params.user,
          params.debtToCover
        )
      );

    uint256 collateralSharesToLiquidate = _hub(params.spoke, params.collateralReserveId)
      .previewRemoveByAssets(
        _spokeAssetId(params.spoke, params.collateralReserveId),
        liquidationAmounts.collateralToLiquidate
      );

    uint256 collateralSharesToLiquidator;
    if (params.receiveShares && liquidationAmounts.collateralToLiquidator > 0) {
      collateralSharesToLiquidator = _hub(params.spoke, params.collateralReserveId)
        .previewAddByAssets(
          _spokeAssetId(params.spoke, params.collateralReserveId),
          liquidationAmounts.collateralToLiquidator
        );
    } else {
      collateralSharesToLiquidator = _hub(params.spoke, params.collateralReserveId)
        .previewRemoveByAssets(
          _spokeAssetId(params.spoke, params.collateralReserveId),
          liquidationAmounts.collateralToLiquidator
        );
    }

    uint256 liquidationBonus = params.spoke.getLiquidationBonus(
      params.collateralReserveId,
      params.user,
      userAccountDataBefore.healthFactor
    );

    (
      uint256 expectedUserRiskPremium,
      uint256 expectedUserAvgCollateralFactor
    ) = _calculateExpectedUserRiskPremiumAndAvgCollateralFactor(
        params,
        userAccountDataBefore,
        liquidationAmounts.collateralToLiquidate,
        liquidationAmounts.debtToLiquidate
      );

    uint256 debtToLiquidateValue = _convertAmountToValue(
      params.spoke,
      params.debtReserveId,
      liquidationAmounts.debtToLiquidate
    );

    // health factor is decreasing due to liquidation bonus / collateral factor if:
    //   (totalCollateralValue - debtToLiquidateValue * LB) * newCF / (totalDebtValue - debtToLiquidateValue) < totalCollateralValue * oldCF / totalDebtValue
    //   this is equivalent to: LB * totalDebtValue * debtToLiquidateValue * newCF > totalCollateralValue * (totalDebtValue * (newCF - oldCF) + debtToLiquidateValue * oldCF)
    bool isCollateralAffectingUserHf = (liquidationBonus *
      userAccountDataBefore.totalDebtValue.wadMulUp(debtToLiquidateValue) *
      expectedUserAvgCollateralFactor).toInt256() >
      PercentageMath.PERCENTAGE_FACTOR.toInt256() *
        (userAccountDataBefore
          .totalCollateralValue
          .wadMulDown(userAccountDataBefore.totalDebtValue)
          .toInt256() *
          (expectedUserAvgCollateralFactor.toInt256() -
            userAccountDataBefore.avgCollateralFactor.toInt256()) +
          (userAccountDataBefore.totalCollateralValue.wadMulDown(debtToLiquidateValue) *
            userAccountDataBefore.avgCollateralFactor).toInt256());

    bool hasDeficit = (userAccountDataBefore.activeCollateralCount == 1) &&
      (!params.isSolvent || isCollateralAffectingUserHf) &&
      (liquidationAmounts.collateralToLiquidate ==
        params.spoke.getUserSuppliedAssets(params.collateralReserveId, params.user));

    return
      LiquidationMetadata({
        debtToTarget: debtToTarget,
        collateralToLiquidate: liquidationAmounts.collateralToLiquidate,
        collateralToLiquidator: liquidationAmounts.collateralToLiquidator,
        collateralSharesToLiquidate: collateralSharesToLiquidate,
        collateralSharesToLiquidator: collateralSharesToLiquidator,
        debtToLiquidate: liquidationAmounts.debtToLiquidate,
        liquidationBonus: liquidationBonus,
        expectedUserRiskPremium: expectedUserRiskPremium,
        expectedUserAvgCollateralFactor: expectedUserAvgCollateralFactor,
        isCollateralAffectingUserHf: isCollateralAffectingUserHf,
        hasDeficit: hasDeficit
      });
  }

  function _checkPositionStatus(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    LiquidationMetadata memory liquidationMetadata
  ) internal virtual {
    assertEq(
      _isUsingAsCollateral(params.spoke, params.collateralReserveId, params.user),
      true,
      'user position status: using as collateral'
    );
    assertEq(
      _isBorrowing(params.spoke, params.debtReserveId, params.user) ||
        liquidationMetadata.hasDeficit,
      liquidationMetadata.debtToLiquidate < accountsInfoBefore.userBalanceInfo.borrowedFromSpoke,
      'user position status: borrowing'
    );
  }

  function _checkHealthFactor(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata
  ) internal virtual {
    if (
      accountsInfoAfter.userAccountData.totalDebtValue == 0 ||
      (params.isSolvent && !liquidationMetadata.isCollateralAffectingUserHf)
    ) {
      assertGe(
        accountsInfoAfter.userAccountData.healthFactor,
        accountsInfoBefore.userAccountData.healthFactor,
        'health factor should increase after liquidation'
      );
    } else {
      assertLe(
        accountsInfoAfter.userAccountData.healthFactor,
        accountsInfoBefore.userAccountData.healthFactor,
        'health factor should decrease after liquidation'
      );
    }

    if (accountsInfoAfter.userAccountData.totalDebtValue == 0) {
      assertEq(
        accountsInfoAfter.userAccountData.healthFactor,
        UINT256_MAX,
        'health factor should be max if all debt is liquidated'
      );
    } else if (liquidationMetadata.debtToLiquidate == liquidationMetadata.debtToTarget) {
      assertApproxEqRel(
        accountsInfoAfter.userAccountData.healthFactor,
        _getTargetHealthFactor(params.spoke),
        _approxRelFromBps(1),
        'health factor should be approx equal to target health factor'
      );
    } else if (liquidationMetadata.debtToLiquidate > liquidationMetadata.debtToTarget) {
      // dust adjusted
      assertGe(
        accountsInfoAfter.userAccountData.healthFactor,
        _getTargetHealthFactor(params.spoke),
        'health factor should be greater than or equal to target health factor'
      );
    } else {
      assertLe(
        accountsInfoAfter.userAccountData.healthFactor,
        _getTargetHealthFactor(params.spoke),
        'health factor should be less than or equal to target health factor'
      );
    }
  }

  function _checkErc20Balances(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata
  ) internal view {
    // Hubs/liquidator balances check
    if (params.receiveShares) {
      _checkErc20BalancesReceiveShares(
        params,
        accountsInfoBefore,
        accountsInfoAfter,
        liquidationMetadata
      );
    } else {
      _checkErc20BalancesReceiveAssets(
        params,
        accountsInfoBefore,
        accountsInfoAfter,
        liquidationMetadata
      );
    }

    // User
    assertEq(
      accountsInfoAfter.userBalanceInfo.collateralErc20Balance,
      accountsInfoBefore.userBalanceInfo.collateralErc20Balance,
      'user: collateral erc20 balance'
    );
    assertEq(
      accountsInfoAfter.userBalanceInfo.debtErc20Balance,
      accountsInfoBefore.userBalanceInfo.debtErc20Balance,
      'user: debt erc20 balance'
    );

    // Fee Receivers
    assertEq(
      accountsInfoAfter.collateralFeeReceiverBalanceInfo.collateralErc20Balance,
      accountsInfoBefore.collateralFeeReceiverBalanceInfo.collateralErc20Balance,
      'collateral fee receiver: collateral erc20 balance'
    );
    assertEq(
      accountsInfoAfter.collateralFeeReceiverBalanceInfo.debtErc20Balance,
      accountsInfoBefore.collateralFeeReceiverBalanceInfo.debtErc20Balance,
      'collateral fee receiver: debt erc20 balance'
    );
    assertEq(
      accountsInfoAfter.debtFeeReceiverBalanceInfo.collateralErc20Balance,
      accountsInfoBefore.debtFeeReceiverBalanceInfo.collateralErc20Balance,
      'debt fee receiver: collateral erc20 balance'
    );
    assertEq(
      accountsInfoAfter.debtFeeReceiverBalanceInfo.debtErc20Balance,
      accountsInfoBefore.debtFeeReceiverBalanceInfo.debtErc20Balance,
      'debt fee receiver: debt erc20 balance'
    );

    // Spoke
    assertEq(
      accountsInfoAfter.spokeBalanceInfo.collateralErc20Balance,
      accountsInfoBefore.spokeBalanceInfo.collateralErc20Balance,
      'spoke: collateral erc20 balance'
    );
    assertEq(
      accountsInfoAfter.spokeBalanceInfo.debtErc20Balance,
      accountsInfoBefore.spokeBalanceInfo.debtErc20Balance,
      'spoke: debt erc20 balance'
    );
  }

  function _checkErc20BalancesReceiveShares(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata
  ) internal view {
    // Hubs
    address collateralHub = address(_hub(params.spoke, params.collateralReserveId));
    address debtHub = address(_hub(params.spoke, params.debtReserveId));
    if (collateralHub == debtHub && params.collateralReserveId == params.debtReserveId) {
      assertEq(
        accountsInfoAfter.collateralHubBalanceInfo.collateralErc20Balance,
        accountsInfoBefore.collateralHubBalanceInfo.collateralErc20Balance +
          liquidationMetadata.debtToLiquidate,
        'collateral hub: collateral erc20 balance'
      );
    } else {
      assertEq(
        accountsInfoAfter.collateralHubBalanceInfo.collateralErc20Balance,
        accountsInfoBefore.collateralHubBalanceInfo.collateralErc20Balance,
        'collateral hub: collateral erc20 balance'
      );
      if (collateralHub != debtHub) {
        assertEq(
          accountsInfoAfter.debtHubBalanceInfo.collateralErc20Balance,
          accountsInfoBefore.debtHubBalanceInfo.collateralErc20Balance,
          'debt hub: collateral erc20 balance'
        );
      }
      assertEq(
        accountsInfoAfter.debtHubBalanceInfo.debtErc20Balance,
        accountsInfoBefore.debtHubBalanceInfo.debtErc20Balance +
          liquidationMetadata.debtToLiquidate,
        'debt hub: debt erc20 balance'
      );
      if (collateralHub != debtHub) {
        assertEq(
          accountsInfoAfter.collateralHubBalanceInfo.debtErc20Balance,
          accountsInfoBefore.collateralHubBalanceInfo.debtErc20Balance,
          'collateral hub: debt erc20 balance'
        );
      }
    }

    // Liquidator
    if (
      getAssetUnderlyingByReserveId(params.spoke, params.collateralReserveId) ==
      getAssetUnderlyingByReserveId(params.spoke, params.debtReserveId)
    ) {
      assertEq(
        accountsInfoAfter.liquidatorBalanceInfo.collateralErc20Balance,
        accountsInfoBefore.liquidatorBalanceInfo.collateralErc20Balance -
          liquidationMetadata.debtToLiquidate,
        'liquidator: collateral erc20 balance'
      );
    } else {
      assertEq(
        accountsInfoAfter.liquidatorBalanceInfo.collateralErc20Balance,
        accountsInfoBefore.liquidatorBalanceInfo.collateralErc20Balance,
        'liquidator: collateral erc20 balance'
      );
      assertEq(
        accountsInfoAfter.liquidatorBalanceInfo.debtErc20Balance,
        accountsInfoBefore.liquidatorBalanceInfo.debtErc20Balance -
          liquidationMetadata.debtToLiquidate,
        'liquidator: debt erc20 balance'
      );
    }
  }

  function _checkErc20BalancesReceiveAssets(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata
  ) internal view {
    // Hubs
    address collateralHub = address(_hub(params.spoke, params.collateralReserveId));
    address debtHub = address(_hub(params.spoke, params.debtReserveId));
    if (collateralHub == debtHub && params.collateralReserveId == params.debtReserveId) {
      assertEq(
        accountsInfoAfter.collateralHubBalanceInfo.collateralErc20Balance,
        accountsInfoBefore.collateralHubBalanceInfo.collateralErc20Balance -
          liquidationMetadata.collateralToLiquidator +
          liquidationMetadata.debtToLiquidate,
        'collateral hub: collateral erc20 balance'
      );
    } else {
      assertEq(
        accountsInfoAfter.collateralHubBalanceInfo.collateralErc20Balance,
        accountsInfoBefore.collateralHubBalanceInfo.collateralErc20Balance -
          liquidationMetadata.collateralToLiquidator,
        'collateral hub: collateral erc20 balance'
      );
      if (collateralHub != debtHub) {
        assertEq(
          accountsInfoAfter.debtHubBalanceInfo.collateralErc20Balance,
          accountsInfoBefore.debtHubBalanceInfo.collateralErc20Balance,
          'debt hub: collateral erc20 balance'
        );
      }

      assertEq(
        accountsInfoAfter.debtHubBalanceInfo.debtErc20Balance,
        accountsInfoBefore.debtHubBalanceInfo.debtErc20Balance +
          liquidationMetadata.debtToLiquidate,
        'debt hub: debt erc20 balance'
      );
      if (collateralHub != debtHub) {
        assertEq(
          accountsInfoAfter.collateralHubBalanceInfo.debtErc20Balance,
          accountsInfoBefore.collateralHubBalanceInfo.debtErc20Balance,
          'collateral hub: debt erc20 balance'
        );
      }
    }

    // Liquidator
    if (
      getAssetUnderlyingByReserveId(params.spoke, params.collateralReserveId) ==
      getAssetUnderlyingByReserveId(params.spoke, params.debtReserveId)
    ) {
      assertEq(
        accountsInfoAfter.liquidatorBalanceInfo.collateralErc20Balance,
        accountsInfoBefore.liquidatorBalanceInfo.collateralErc20Balance +
          liquidationMetadata.collateralToLiquidator -
          liquidationMetadata.debtToLiquidate,
        'liquidator: collateral erc20 balance'
      );
    } else {
      assertEq(
        accountsInfoAfter.liquidatorBalanceInfo.collateralErc20Balance,
        accountsInfoBefore.liquidatorBalanceInfo.collateralErc20Balance +
          liquidationMetadata.collateralToLiquidator,
        'liquidator: collateral erc20 balance'
      );
      assertEq(
        accountsInfoAfter.liquidatorBalanceInfo.debtErc20Balance,
        accountsInfoBefore.liquidatorBalanceInfo.debtErc20Balance -
          liquidationMetadata.debtToLiquidate,
        'liquidator: debt erc20 balance'
      );
    }
  }

  function _checkSpokeBalances(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata
  ) internal pure {
    // User
    assertApproxEqRel(
      accountsInfoAfter.userBalanceInfo.suppliedInSpoke,
      accountsInfoBefore.userBalanceInfo.suppliedInSpoke -
        liquidationMetadata.collateralToLiquidate,
      _approxRelFromBps(1),
      'user: collateral supplied'
    );
    assertApproxEqRel(
      accountsInfoAfter.userBalanceInfo.borrowedFromSpoke,
      (liquidationMetadata.hasDeficit)
        ? 0
        : accountsInfoBefore.userBalanceInfo.borrowedFromSpoke -
          liquidationMetadata.debtToLiquidate,
      _approxRelFromBps(1),
      'user: debt borrowed'
    );

    // Hubs
    assertEq(
      accountsInfoAfter.collateralHubBalanceInfo.suppliedInSpoke,
      accountsInfoBefore.collateralHubBalanceInfo.suppliedInSpoke,
      'collateral hub: collateral supplied'
    );
    assertEq(
      accountsInfoAfter.collateralHubBalanceInfo.borrowedFromSpoke,
      accountsInfoBefore.collateralHubBalanceInfo.borrowedFromSpoke,
      'collateral hub: debt borrowed'
    );
    assertEq(
      accountsInfoAfter.debtHubBalanceInfo.suppliedInSpoke,
      accountsInfoBefore.debtHubBalanceInfo.suppliedInSpoke,
      'debt hub: collateral supplied'
    );
    assertEq(
      accountsInfoAfter.debtHubBalanceInfo.borrowedFromSpoke,
      accountsInfoBefore.debtHubBalanceInfo.borrowedFromSpoke,
      'debt hub: debt borrowed'
    );

    // Liquidator
    if (!params.receiveShares) {
      assertEq(
        accountsInfoAfter.liquidatorBalanceInfo.suppliedInSpoke,
        accountsInfoBefore.liquidatorBalanceInfo.suppliedInSpoke,
        'liquidator: collateral supplied'
      );
    } else {
      // collateral rounded down on receiveShares, can differ by 2 wei in asset terms
      assertApproxEqAbs(
        accountsInfoAfter.liquidatorBalanceInfo.suppliedInSpoke,
        accountsInfoBefore.liquidatorBalanceInfo.suppliedInSpoke +
          liquidationMetadata.collateralToLiquidator,
        2,
        'liquidator: collateral supplied (receiveShares)'
      );
    }
    assertEq(
      accountsInfoAfter.liquidatorBalanceInfo.borrowedFromSpoke,
      accountsInfoBefore.liquidatorBalanceInfo.borrowedFromSpoke,
      'liquidator: debt borrowed'
    );

    // Fee Receivers
    assertEq(
      accountsInfoAfter.collateralFeeReceiverBalanceInfo.suppliedInSpoke,
      accountsInfoBefore.collateralFeeReceiverBalanceInfo.suppliedInSpoke,
      'collateral fee receiver: collateral supplied'
    );

    assertEq(
      accountsInfoAfter.collateralFeeReceiverBalanceInfo.borrowedFromSpoke,
      accountsInfoBefore.collateralFeeReceiverBalanceInfo.borrowedFromSpoke,
      'collateral fee receiver: debt borrowed'
    );
    assertEq(
      accountsInfoAfter.debtFeeReceiverBalanceInfo.suppliedInSpoke,
      accountsInfoBefore.debtFeeReceiverBalanceInfo.suppliedInSpoke,
      'debt fee receiver: collateral supplied'
    );
    assertEq(
      accountsInfoAfter.debtFeeReceiverBalanceInfo.borrowedFromSpoke,
      accountsInfoBefore.debtFeeReceiverBalanceInfo.borrowedFromSpoke,
      'debt fee receiver: debt borrowed'
    );

    // Spoke
    assertEq(
      accountsInfoAfter.spokeBalanceInfo.suppliedInSpoke,
      accountsInfoBefore.spokeBalanceInfo.suppliedInSpoke,
      'spoke: collateral supplied'
    );
    assertEq(
      accountsInfoAfter.spokeBalanceInfo.borrowedFromSpoke,
      accountsInfoBefore.spokeBalanceInfo.borrowedFromSpoke,
      'spoke: debt borrowed'
    );
  }

  function _checkHubBalances(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata
  ) internal view {
    // User
    assertEq(
      accountsInfoAfter.userBalanceInfo.addedInHub,
      accountsInfoBefore.userBalanceInfo.addedInHub,
      'user: added'
    );
    assertEq(
      accountsInfoAfter.userBalanceInfo.drawnFromHub,
      accountsInfoBefore.userBalanceInfo.drawnFromHub,
      'user: drawn'
    );

    // Hubs
    assertEq(
      accountsInfoAfter.collateralHubBalanceInfo.addedInHub,
      accountsInfoBefore.collateralHubBalanceInfo.addedInHub,
      'collateral hub: added'
    );
    assertEq(
      accountsInfoAfter.collateralHubBalanceInfo.drawnFromHub,
      accountsInfoBefore.collateralHubBalanceInfo.drawnFromHub,
      'collateral hub: drawn'
    );
    assertEq(
      accountsInfoAfter.debtHubBalanceInfo.addedInHub,
      accountsInfoBefore.debtHubBalanceInfo.addedInHub,
      'debt hub: added'
    );
    assertEq(
      accountsInfoAfter.debtHubBalanceInfo.drawnFromHub,
      accountsInfoBefore.debtHubBalanceInfo.drawnFromHub,
      'debt hub: drawn'
    );

    // Liquidator
    assertEq(
      accountsInfoAfter.liquidatorBalanceInfo.addedInHub,
      accountsInfoBefore.liquidatorBalanceInfo.addedInHub,
      'liquidator: added'
    );
    assertEq(
      accountsInfoAfter.liquidatorBalanceInfo.drawnFromHub,
      accountsInfoBefore.liquidatorBalanceInfo.drawnFromHub,
      'liquidator: drawn'
    );

    // Fee Receivers
    assertEq(
      accountsInfoAfter.collateralFeeReceiverBalanceInfo.drawnFromHub,
      accountsInfoBefore.collateralFeeReceiverBalanceInfo.drawnFromHub,
      'collateral fee receiver: drawn'
    );
    if (!params.receiveShares) {
      assertApproxEqRel(
        accountsInfoAfter.collateralFeeReceiverBalanceInfo.addedInHub,
        accountsInfoBefore.collateralFeeReceiverBalanceInfo.addedInHub +
          liquidationMetadata.collateralToLiquidate -
          liquidationMetadata.collateralToLiquidator,
        _approxRelFromBps(1),
        'collateral fee receiver: added'
      );
    } else {
      assertApproxEqAbs(
        accountsInfoAfter.collateralFeeReceiverBalanceInfo.addedInHub,
        accountsInfoBefore.collateralFeeReceiverBalanceInfo.addedInHub +
          liquidationMetadata.collateralToLiquidate -
          liquidationMetadata.collateralToLiquidator,
        2,
        'collateral fee receiver: added (receiveShares)'
      );
    }

    if (
      _getFeeReceiver(params.spoke, params.collateralReserveId) !=
      _getFeeReceiver(params.spoke, params.debtReserveId)
    ) {
      assertEq(
        accountsInfoAfter.debtFeeReceiverBalanceInfo.addedInHub,
        accountsInfoBefore.debtFeeReceiverBalanceInfo.addedInHub,
        'debt fee receiver: added'
      );
      assertEq(
        accountsInfoAfter.debtFeeReceiverBalanceInfo.drawnFromHub,
        accountsInfoBefore.debtFeeReceiverBalanceInfo.drawnFromHub,
        'debt fee receiver: drawn'
      );
    }

    // Spoke
    assertApproxEqRel(
      accountsInfoAfter.spokeBalanceInfo.addedInHub,
      accountsInfoBefore.spokeBalanceInfo.addedInHub - liquidationMetadata.collateralToLiquidate,
      _approxRelFromBps(10),
      'spoke: added'
    );
    assertApproxEqRel(
      accountsInfoAfter.spokeBalanceInfo.drawnFromHub,
      (liquidationMetadata.hasDeficit)
        ? 0
        : accountsInfoBefore.spokeBalanceInfo.drawnFromHub - liquidationMetadata.debtToLiquidate,
      _approxRelFromBps(1),
      'spoke: drawn'
    );
  }

  function _checkTransferSharesCall(
    CheckedLiquidationCallParams memory params,
    LiquidationMetadata memory liquidationMetadata,
    Vm.Log[] memory logs
  ) internal view {
    uint256 transferSharesEventCount = 0;
    for (uint256 i = 0; i < logs.length; i++) {
      if (logs[i].topics[0] == IHubBase.TransferShares.selector) {
        transferSharesEventCount += 1;

        assertEq(
          uint256(logs[i].topics[1]),
          _spokeAssetId(params.spoke, params.collateralReserveId)
        );
        address sender = address(uint160(uint256(logs[i].topics[2])));
        address receiver = address(uint160(uint256(logs[i].topics[3])));
        uint256 shares = abi.decode(logs[i].data, (uint256));
        uint256 expectedShares = _hub(params.spoke, params.collateralReserveId)
          .previewRemoveByAssets(
            _spokeAssetId(params.spoke, params.collateralReserveId),
            liquidationMetadata.collateralToLiquidate - liquidationMetadata.collateralToLiquidator
          );
        assertApproxEqAbs(shares, expectedShares, 1);
        assertEq(sender, address(params.spoke));
        assertEq(receiver, _getFeeReceiver(params.spoke, params.collateralReserveId));
      }
    }

    assertEq(
      transferSharesEventCount,
      (liquidationMetadata.collateralToLiquidate > liquidationMetadata.collateralToLiquidator)
        ? 1
        : 0,
      'transfer shares: event emitted'
    );
  }

  function _checkRiskPremium(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata,
    Vm.Log[] memory logs
  ) internal view {
    uint256 precision = 0.1e18;
    uint256 riskPremiumEventCount;
    for (uint256 i = 0; i < logs.length; i++) {
      if (logs[i].topics[0] == ISpoke.UpdateUserRiskPremium.selector) {
        riskPremiumEventCount += 1;

        assertEq(address(uint160(uint256(logs[i].topics[1]))), address(params.user));
        uint256 actualUserRiskPremium = abi.decode(logs[i].data, (uint256));
        assertApproxEqRel(
          actualUserRiskPremium,
          liquidationMetadata.expectedUserRiskPremium,
          precision,
          'user risk premium: event'
        );
      }
    }

    uint256 riskPremiumEventExpectedCount = 1;
    if (!accountsInfoBefore.hasPositiveRiskPremium && !accountsInfoAfter.hasPositiveRiskPremium) {
      riskPremiumEventExpectedCount = 0;
    }
    assertEq(riskPremiumEventCount, riskPremiumEventExpectedCount, 'riskPremiumEventExpectedCount');

    assertEq(
      accountsInfoAfter.hasPositiveRiskPremium,
      accountsInfoAfter.userAccountData.riskPremium > 0
    );

    assertApproxEqRel(
      accountsInfoAfter.userAccountData.riskPremium,
      liquidationMetadata.expectedUserRiskPremium,
      precision,
      'user risk premium: user account data'
    );

    for (uint256 reserveId = 0; reserveId < params.spoke.getReserveCount(); reserveId++) {
      if (_isBorrowing(params.spoke, reserveId, params.user)) {
        ISpoke.UserPosition memory userPosition = params.spoke.getUserPosition(
          reserveId,
          params.user
        );
        assertNotEq(userPosition.drawnShares, 0, 'borrowed reserve should have non zero base debt');
        uint256 storedUserRiskPremium = userPosition.premiumShares.percentDivDown(
          userPosition.drawnShares
        );
        assertApproxEqRel(
          storedUserRiskPremium,
          accountsInfoAfter.userAccountData.riskPremium,
          precision,
          string.concat(
            'user risk premium: stored risk premium in reserve ',
            vm.toString(reserveId)
          )
        );
      }
    }
  }

  function _checkAvgCollateralFactor(
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata
  ) internal pure {
    assertApproxEqRel(
      accountsInfoAfter.userAccountData.avgCollateralFactor,
      liquidationMetadata.expectedUserAvgCollateralFactor,
      0.1e18,
      'user avg collateral factor: user account data'
    );
  }

  function _execBeforeLiquidation(CheckedLiquidationCallParams memory params) internal virtual {}

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    LiquidationMetadata memory liquidationMetadata
  ) internal virtual {}

  function _checkedLiquidationCall(CheckedLiquidationCallParams memory params) internal virtual {
    // make sure there is enough liquidity to liquidate
    _openSupplyPosition(params.spoke, params.collateralReserveId, MAX_SUPPLY_AMOUNT);

    _execBeforeLiquidation(params);

    AccountsInfo memory accountsInfoBefore = _getAccountsInfo(params);
    LiquidationMetadata memory liquidationMetadata = _getLiquidationMetadata(
      params,
      accountsInfoBefore.userAccountData
    );

    _assertBeforeLiquidation(params, accountsInfoBefore, liquidationMetadata);

    _expectEventsAndCalls(params, accountsInfoBefore, liquidationMetadata);
    vm.recordLogs();
    vm.prank(params.liquidator);
    params.spoke.liquidationCall(
      params.collateralReserveId,
      params.debtReserveId,
      params.user,
      params.debtToCover,
      params.receiveShares
    );
    Vm.Log[] memory logs = vm.getRecordedLogs();

    AccountsInfo memory accountsInfoAfter = _getAccountsInfo(params);

    _checkTransferSharesCall(params, liquidationMetadata, logs);
    _checkRiskPremium(params, accountsInfoBefore, accountsInfoAfter, liquidationMetadata, logs);
    _checkAvgCollateralFactor(accountsInfoAfter, liquidationMetadata);

    _checkPositionStatus(params, accountsInfoBefore, liquidationMetadata);
    _checkHealthFactor(params, accountsInfoBefore, accountsInfoAfter, liquidationMetadata);
    _checkErc20Balances(params, accountsInfoBefore, accountsInfoAfter, liquidationMetadata);
    _checkSpokeBalances(params, accountsInfoBefore, accountsInfoAfter, liquidationMetadata);
    _checkHubBalances(params, accountsInfoBefore, accountsInfoAfter, liquidationMetadata);
    _assertHubLiquidity(
      _hub(params.spoke, params.collateralReserveId),
      params.collateralReserveId,
      'spoke1.liquidationCall'
    );
    _assertHubLiquidity(
      _hub(params.spoke, params.debtReserveId),
      params.debtReserveId,
      'spoke1.liquidationCall'
    );
  }

  // @dev reads `positionStatus.hasPositiveRiskPremium` by temporarily upgrading to mock spoke
  function _hasPositiveRiskPremium(ISpoke spoke, address user) internal returns (bool) {
    address mockSpoke = address(new MockSpoke(spoke.ORACLE()));
    address implementation = _getImplementationAddress(address(spoke));
    vm.prank(_getProxyAdminAddress(address(spoke)));
    ITransparentUpgradeableProxy(address(spoke)).upgradeToAndCall(address(mockSpoke), '');

    bool hasPositiveRiskPremium = MockSpoke(address(spoke)).hasPositiveRiskPremium(user);

    vm.prank(_getProxyAdminAddress(address(spoke)));
    ITransparentUpgradeableProxy(address(spoke)).upgradeToAndCall(implementation, '');

    return hasPositiveRiskPremium;
  }
}
