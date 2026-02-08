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
  uint256 internal constant MIN_AMOUNT_IN_BASE_CURRENCY = 100e26; // 1 USD

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
    uint256 userLastRiskPremium;
  }

  struct LiquidationMetadata {
    uint256 debtRayToTarget;
    uint256 collateralAssetsToLiquidate;
    uint256 collateralAssetsToLiquidator;
    uint256 collateralSharesToLiquidate;
    uint256 collateralSharesToLiquidator;
    uint256 debtAssetsToLiquidate;
    uint256 debtRayToLiquidate;
    uint256 drawnSharesToLiquidate;
    uint256 premiumDebtRayToLiquidate;
    uint256 debtAssetsToRestore;
    uint256 liquidationBonus;
    bool fullDebtReserveLiquidated;
    bool hasDeficit;
  }
  struct ExpectEventsAndCallsParams {
    uint256 userDrawnDebt;
    uint256 userPremiumDebt;
    uint256 drawnAmountToRestore;
    int256 realizedDelta;
    IHubBase.PremiumDelta premiumDelta;
    ISpoke.UserPosition userReservePosition;
    ISpoke.UserPosition userDebtPosition;
    IHub collateralHub;
    IHub debtHub;
    uint256 debtAssetId;
    uint256 collateralAssetId;
  }

  function _bound(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId
  ) internal view virtual returns (uint256, uint256) {
    collateralReserveId = bound(collateralReserveId, 0, spoke.getReserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke.getReserveCount() - 1);
    return (collateralReserveId, debtReserveId);
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
      uint256 liquidationBonus = spoke.getLiquidationBonus(
        collateralReserveId,
        user,
        spoke.getUserAccountData(user).healthFactor
      );
      uint256 debtReserveBalance = params.drawnShares.rayMulUp(params.drawnIndex) +
        params.premiumDebtRay.fromRayUp();
      uint256 collateralReserveBalance = params.collateralReserveHub.previewRemoveByShares(
        params.collateralReserveAssetId,
        params.suppliedShares
      );
      debtToCover = bound(
        debtToCover,
        debtReserveBalance.min(
          _convertAssetAmount(
            spoke,
            collateralReserveId,
            collateralReserveBalance.percentDivUp(liquidationBonus),
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

  function _getCalculateDebtToTargetHealthFactorParams(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user
  ) internal virtual returns (LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory) {
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    return
      LiquidationLogic.CalculateDebtToTargetHealthFactorParams({
        totalDebtValueRay: userAccountData.totalDebtValueRay,
        debtAssetUnit: 10 ** spoke.getReserve(debtReserveId).decimals,
        debtAssetPrice: IPriceOracle(spoke.ORACLE()).getReservePrice(debtReserveId),
        collateralFactor: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).dynamicConfigKey
          )
          .collateralFactor,
        liquidationBonus: spoke.getLiquidationBonus(
          collateralReserveId,
          user,
          userAccountData.healthFactor
        ),
        healthFactor: userAccountData.healthFactor,
        targetHealthFactor: spoke.getLiquidationConfig().targetHealthFactor
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
        collateralReserveHub: _hub(spoke, collateralReserveId),
        collateralReserveAssetId: spoke.getReserve(collateralReserveId).assetId,
        suppliedShares: spoke.getUserPosition(collateralReserveId, user).suppliedShares,
        collateralAssetDecimals: spoke.getReserve(collateralReserveId).decimals,
        collateralAssetPrice: IPriceOracle(spoke.ORACLE()).getReservePrice(collateralReserveId),
        drawnShares: spoke.getUserPosition(debtReserveId, user).drawnShares,
        premiumDebtRay: _calculatePremiumDebtRay(spoke, debtReserveId, user),
        drawnIndex: _reserveDrawnIndex(spoke, debtReserveId),
        totalDebtValueRay: userAccountData.totalDebtValueRay,
        debtAssetDecimals: spoke.getReserve(debtReserveId).decimals,
        debtAssetPrice: IPriceOracle(spoke.ORACLE()).getReservePrice(debtReserveId),
        debtToCover: debtToCover,
        collateralFactor: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).dynamicConfigKey
          )
          .collateralFactor,
        healthFactorForMaxBonus: spoke.getLiquidationConfig().healthFactorForMaxBonus,
        liquidationBonusFactor: spoke.getLiquidationConfig().liquidationBonusFactor,
        maxLiquidationBonus: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).dynamicConfigKey
          )
          .maxLiquidationBonus,
        targetHealthFactor: spoke.getLiquidationConfig().targetHealthFactor,
        healthFactor: userAccountData.healthFactor,
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

  // calculate expected user account data after liquidation
  function _calculateExpectedUserAccountData(
    CheckedLiquidationCallParams memory params,
    LiquidationMetadata memory liquidationMetadata
  ) internal virtual returns (ISpoke.UserAccountData memory expectedUserAccountData) {
    KeyValueList.List memory list = KeyValueList.init(params.spoke.getReserveCount());

    for (uint256 reserveId = 0; reserveId < params.spoke.getReserveCount(); reserveId++) {
      if (!_isUsingAsCollateral(params.spoke, reserveId, params.user)) {
        continue;
      }

      if (_getCollateralFactor(params.spoke, reserveId, params.user) == 0) {
        continue;
      }

      IHubBase hub = _hub(params.spoke, reserveId);
      uint256 assetId = _reserveAssetId(params.spoke, reserveId);
      uint256 totalAddedAssets = hub.getAddedAssets(assetId);
      uint256 totalAddedShares = hub.getAddedShares(assetId);
      uint256 userSuppliedShares = params
        .spoke
        .getUserPosition(reserveId, params.user)
        .suppliedShares;

      if (params.collateralReserveId == reserveId) {
        userSuppliedShares -= liquidationMetadata.collateralSharesToLiquidate;
        if (!params.receiveShares) {
          totalAddedAssets -= liquidationMetadata.collateralAssetsToLiquidator;
          totalAddedShares -= liquidationMetadata.collateralSharesToLiquidator;
        }
      }

      if (userSuppliedShares == 0) {
        continue;
      }

      if (params.debtReserveId == reserveId) {
        IHub.Asset memory asset = IHub(address(hub)).getAsset(assetId);
        uint256 drawnIndex = _reserveDrawnIndex(params.spoke, reserveId);
        uint256 premiumDebtRay = _calculatePremiumDebtRay(
          asset.premiumShares,
          asset.premiumOffsetRay,
          drawnIndex
        );
        totalAddedAssets += liquidationMetadata.debtAssetsToLiquidate;
        uint256 aggregatedOwedRayBefore = asset.drawnShares * drawnIndex +
          premiumDebtRay +
          asset.deficitRay;
        totalAddedAssets -= (aggregatedOwedRayBefore.fromRayUp() -
          (aggregatedOwedRayBefore - liquidationMetadata.debtRayToLiquidate).fromRayUp());
      }

      uint256 userSuppliedAssets = userSuppliedShares.mulDivDown(
        totalAddedAssets + Constants.VIRTUAL_ASSETS,
        totalAddedShares + Constants.VIRTUAL_SHARES
      );
      uint256 userSuppliedValue = _convertAmountToValue(
        params.spoke,
        reserveId,
        userSuppliedAssets
      );
      list.add(
        expectedUserAccountData.activeCollateralCount++,
        _getCollateralRisk(params.spoke, reserveId),
        userSuppliedValue
      );
      expectedUserAccountData.totalCollateralValue += userSuppliedValue;
      expectedUserAccountData.avgCollateralFactor +=
        _getCollateralFactor(params.spoke, reserveId, params.user) * userSuppliedValue;
    }

    for (
      uint256 reserveId = 0;
      reserveId < params.spoke.getReserveCount() && !liquidationMetadata.hasDeficit;
      reserveId++
    ) {
      if (!_isBorrowing(params.spoke, reserveId, params.user)) {
        continue;
      }

      uint256 userDrawnShares = params.spoke.getUserPosition(reserveId, params.user).drawnShares;
      uint256 userPremiumDebtRay = _calculatePremiumDebtRay(params.spoke, reserveId, params.user);
      if (params.debtReserveId == reserveId) {
        userDrawnShares -= liquidationMetadata.drawnSharesToLiquidate.toUint120();
        userPremiumDebtRay -= liquidationMetadata.premiumDebtRayToLiquidate;
      }
      if (userDrawnShares == 0) {
        continue;
      }
      expectedUserAccountData.borrowCount++;
      expectedUserAccountData.totalDebtValueRay += _convertAmountToValue(
        params.spoke,
        reserveId,
        userDrawnShares * _reserveDrawnIndex(params.spoke, reserveId) + userPremiumDebtRay
      );
    }

    if (expectedUserAccountData.totalDebtValueRay > 0) {
      expectedUserAccountData.healthFactor = Math.mulDiv(
        expectedUserAccountData.avgCollateralFactor,
        (WadRayMath.WAD * WadRayMath.RAY) / PercentageMath.PERCENTAGE_FACTOR,
        expectedUserAccountData.totalDebtValueRay,
        Math.Rounding.Floor
      );
    } else {
      expectedUserAccountData.healthFactor = type(uint256).max;
    }

    if (expectedUserAccountData.totalCollateralValue != 0) {
      expectedUserAccountData.avgCollateralFactor = expectedUserAccountData
        .avgCollateralFactor
        .mulDivDown(
          WadRayMath.WAD / PercentageMath.PERCENTAGE_FACTOR,
          expectedUserAccountData.totalCollateralValue
        );
    }
    list.sortByKey();

    uint256 remainingDebtToCover = expectedUserAccountData.totalDebtValueRay.fromRayUp();
    for (uint256 i = 0; i < list.length() && remainingDebtToCover > 0; i++) {
      (uint256 collateralRisk, uint256 collateralValue) = list.get(i);
      expectedUserAccountData.riskPremium +=
        collateralRisk * _min(collateralValue, remainingDebtToCover);
      remainingDebtToCover -= _min(collateralValue, remainingDebtToCover);
    }

    expectedUserAccountData.riskPremium = _divUp(
      expectedUserAccountData.riskPremium,
      _max(
        1,
        _min(
          expectedUserAccountData.totalDebtValueRay.fromRayUp(),
          expectedUserAccountData.totalCollateralValue
        )
      )
    );

    return expectedUserAccountData;
  }

  function _expectEventsAndCalls(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    LiquidationMetadata memory liquidationMetadata,
    ISpoke.UserAccountData memory expectedUserAccountData
  ) internal virtual {
    ExpectEventsAndCallsParams memory vars;

    vars.userDebtPosition = params.spoke.getUserPosition(params.debtReserveId, params.user);
    vars.collateralHub = _hub(params.spoke, params.collateralReserveId);
    vars.debtHub = _hub(params.spoke, params.debtReserveId);
    vars.debtAssetId = _reserveAssetId(params.spoke, params.debtReserveId);
    vars.collateralAssetId = _reserveAssetId(params.spoke, params.collateralReserveId);

    (vars.userDrawnDebt, vars.userPremiumDebt) = params.spoke.getUserDebt(
      params.debtReserveId,
      params.user
    );

    vars.drawnAmountToRestore = vars.debtHub.previewRestoreByShares(
      vars.debtAssetId,
      liquidationMetadata.drawnSharesToLiquidate
    );
    uint256 amountToRestore = vars.drawnAmountToRestore +
      liquidationMetadata.premiumDebtRayToLiquidate.fromRayUp();
    vars.premiumDelta = _getExpectedPremiumDeltaForRestore(
      params.spoke,
      params.user,
      params.debtReserveId,
      amountToRestore
    );

    if (
      liquidationMetadata.collateralSharesToLiquidate >
      liquidationMetadata.collateralSharesToLiquidator
    ) {
      vm.expectEmit(address(_hub(params.spoke, params.collateralReserveId)));
      emit IHubBase.TransferShares({
        assetId: _reserveAssetId(params.spoke, params.collateralReserveId),
        sender: address(params.spoke),
        receiver: _getFeeReceiver(params.spoke, params.collateralReserveId),
        shares: liquidationMetadata.collateralSharesToLiquidate -
          liquidationMetadata.collateralSharesToLiquidator
      });
    }

    vm.expectEmit(address(params.spoke));
    emit ISpokeBase.LiquidationCall({
      collateralReserveId: params.collateralReserveId,
      debtReserveId: params.debtReserveId,
      user: params.user,
      liquidator: params.liquidator,
      receiveShares: params.receiveShares,
      debtAmountRestored: amountToRestore,
      drawnSharesLiquidated: liquidationMetadata.drawnSharesToLiquidate,
      premiumDelta: vars.premiumDelta,
      collateralAmountRemoved: vars.collateralHub.previewRemoveByShares(
        vars.collateralAssetId,
        liquidationMetadata.collateralSharesToLiquidate
      ),
      collateralSharesLiquidated: liquidationMetadata.collateralSharesToLiquidate,
      collateralSharesToLiquidator: liquidationMetadata.collateralSharesToLiquidator
    });

    vm.expectCall(
      address(vars.collateralHub),
      abi.encodeCall(
        IHubBase.remove,
        (
          vars.collateralAssetId,
          liquidationMetadata.collateralAssetsToLiquidator,
          params.liquidator
        )
      ),
      (!params.receiveShares && liquidationMetadata.collateralSharesToLiquidator > 0) ? 1 : 0
    );

    vm.expectCall(
      address(vars.debtHub),
      abi.encodeCall(
        IHubBase.restore,
        (vars.debtAssetId, vars.drawnAmountToRestore, vars.premiumDelta)
      ),
      1
    );

    vm.expectCall(
      address(_hub(params.spoke, params.collateralReserveId)),
      abi.encodeCall(
        IHubBase.payFeeShares,
        (
          vars.collateralAssetId,
          liquidationMetadata.collateralSharesToLiquidate -
            liquidationMetadata.collateralSharesToLiquidator
        )
      ),
      liquidationMetadata.collateralSharesToLiquidate >
        liquidationMetadata.collateralSharesToLiquidator
        ? 1
        : 0
    );

    bool riskPremiumOptimisation = accountsInfoBefore.userLastRiskPremium == 0 &&
      expectedUserAccountData.riskPremium == 0;

    {
      for (uint256 i = params.spoke.getReserveCount(); i != 0; ) {
        i--;
        uint256 reserveId = i;
        if (_isBorrowing(params.spoke, reserveId, params.user)) {
          vars.userReservePosition = params.spoke.getUserPosition(reserveId, params.user);
          uint256 assetId = _reserveAssetId(params.spoke, reserveId);

          if (reserveId == params.debtReserveId) {
            vars.userReservePosition.drawnShares -= liquidationMetadata
              .drawnSharesToLiquidate
              .toUint120();
            if (vars.userReservePosition.drawnShares == 0) {
              continue;
            }
            vars.userReservePosition.premiumShares = uint256(vars.userReservePosition.premiumShares)
              .add(vars.premiumDelta.sharesDelta)
              .toUint120();
            vars.userReservePosition.premiumOffsetRay = (vars.userReservePosition.premiumOffsetRay +
              vars.premiumDelta.offsetRayDelta).toInt200();
          }

          IHub targetHub = _hub(params.spoke, reserveId);
          uint256 userReserveDrawnDebt = targetHub.previewRestoreByShares(
            assetId,
            vars.userReservePosition.drawnShares
          );

          if (liquidationMetadata.hasDeficit) {
            uint256 premiumDebtRay = _calculatePremiumDebtRay(
              targetHub,
              assetId,
              vars.userReservePosition.premiumShares,
              vars.userReservePosition.premiumOffsetRay
            );

            IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
              hub: targetHub,
              assetId: assetId,
              oldPremiumShares: vars.userReservePosition.premiumShares,
              oldPremiumOffsetRay: vars.userReservePosition.premiumOffsetRay,
              drawnShares: 0, // risk premium is 0
              riskPremium: 0,
              restoredPremiumRay: premiumDebtRay
            });

            vm.expectCall(
              address(targetHub),
              abi.encodeCall(IHubBase.reportDeficit, (assetId, userReserveDrawnDebt, premiumDelta)),
              1
            );
            vm.expectEmit(address(params.spoke));
            emit ISpoke.ReportDeficit({
              reserveId: reserveId,
              user: params.user,
              drawnShares: vars.userReservePosition.drawnShares,
              premiumDelta: premiumDelta
            });
          } else {
            vm.expectCall(
              address(targetHub),
              abi.encodeWithSelector(IHubBase.reportDeficit.selector, assetId),
              0
            );

            if (!riskPremiumOptimisation) {
              IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
                hub: targetHub,
                assetId: assetId,
                oldPremiumShares: vars.userReservePosition.premiumShares,
                oldPremiumOffsetRay: vars.userReservePosition.premiumOffsetRay,
                drawnShares: vars.userReservePosition.drawnShares,
                riskPremium: expectedUserAccountData.riskPremium,
                restoredPremiumRay: 0
              });

              vm.expectCall(
                address(targetHub),
                abi.encodeCall(IHubBase.refreshPremium, (assetId, premiumDelta)),
                1
              );
              vm.expectEmit(address(params.spoke));
              emit ISpoke.RefreshPremiumDebt({
                reserveId: reserveId,
                user: params.user,
                premiumDelta: premiumDelta
              });
            } else {
              vm.expectCall(
                address(targetHub),
                abi.encodeWithSelector(IHubBase.refreshPremium.selector, assetId),
                0
              );
            }
          }
        }
      }

      if (!liquidationMetadata.hasDeficit && !riskPremiumOptimisation) {
        vm.expectEmit(address(params.spoke));
        emit ISpoke.UpdateUserRiskPremium({
          user: params.user,
          riskPremium: expectedUserAccountData.riskPremium
        });
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
          _reserveAssetId(spoke, collateralReserveId),
          addr
        ),
        debtErc20Balance: getAssetUnderlyingByReserveId(spoke, debtReserveId).balanceOf(addr),
        borrowedFromSpoke: spoke.getUserTotalDebt(debtReserveId, addr),
        drawnFromHub: _hub(spoke, debtReserveId).getSpokeTotalOwed(
          _reserveAssetId(spoke, debtReserveId),
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
        userLastRiskPremium: params.spoke.getUserLastRiskPremium(params.user)
      });
  }

  function _getLiquidationMetadata(
    CheckedLiquidationCallParams memory params,
    ISpoke.UserAccountData memory userAccountDataBefore
  ) internal virtual returns (LiquidationMetadata memory) {
    uint256 debtRayToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
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

    uint256 liquidationBonus = params.spoke.getLiquidationBonus(
      params.collateralReserveId,
      params.user,
      userAccountDataBefore.healthFactor
    );

    bool fullDebtReserveLiquidated = liquidationAmounts.drawnSharesToLiquidate ==
      _getUserDrawnShares(params.spoke, params.debtReserveId, params.user);

    bool hasDeficit = (userAccountDataBefore.activeCollateralCount == 1) &&
      (liquidationAmounts.collateralSharesToLiquidate ==
        params.spoke.getUserPosition(params.collateralReserveId, params.user).suppliedShares) &&
      (userAccountDataBefore.borrowCount > 1 || !fullDebtReserveLiquidated);

    uint256 drawnIndex = _hub(params.spoke, params.debtReserveId).getAssetDrawnIndex(
      _reserveAssetId(params.spoke, params.debtReserveId)
    );
    uint256 debtAssetsToLiquidate = _calculateDebtAssetsToRestore({
      drawnSharesToLiquidate: liquidationAmounts.drawnSharesToLiquidate,
      premiumDebtRayToLiquidate: liquidationAmounts.premiumDebtRayToLiquidate,
      drawnIndex: drawnIndex
    });
    IHubBase collateralHub = _hub(params.spoke, params.collateralReserveId);
    uint256 collateralAssetId = _reserveAssetId(params.spoke, params.collateralReserveId);

    return
      LiquidationMetadata({
        debtRayToTarget: debtRayToTarget,
        collateralAssetsToLiquidate: collateralHub.previewRemoveByShares(
          collateralAssetId,
          liquidationAmounts.collateralSharesToLiquidate
        ),
        collateralAssetsToLiquidator: collateralHub.previewRemoveByShares(
          collateralAssetId,
          liquidationAmounts.collateralSharesToLiquidator
        ),
        collateralSharesToLiquidate: liquidationAmounts.collateralSharesToLiquidate,
        collateralSharesToLiquidator: liquidationAmounts.collateralSharesToLiquidator,
        debtAssetsToLiquidate: debtAssetsToLiquidate,
        debtRayToLiquidate: liquidationAmounts.drawnSharesToLiquidate * drawnIndex +
          liquidationAmounts.premiumDebtRayToLiquidate,
        drawnSharesToLiquidate: liquidationAmounts.drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: liquidationAmounts.premiumDebtRayToLiquidate,
        debtAssetsToRestore: _calculateDebtAssetsToRestore(
          liquidationAmounts.drawnSharesToLiquidate,
          liquidationAmounts.premiumDebtRayToLiquidate,
          drawnIndex
        ),
        liquidationBonus: liquidationBonus,
        fullDebtReserveLiquidated: fullDebtReserveLiquidated,
        hasDeficit: hasDeficit
      });
  }

  function _isCollateralAffectingUserHf(
    CheckedLiquidationCallParams memory params,
    LiquidationLogic.LiquidationAmounts memory liquidationAmounts,
    ISpoke.UserAccountData memory userAccountDataBefore,
    ISpoke.UserAccountData memory userAccountDataAfter
  ) internal view returns (bool) {
    // collateral reserve
    uint256 collateralValueRemoved = userAccountDataBefore.totalCollateralValue -
      userAccountDataAfter.totalCollateralValue;

    // debt reserve
    uint256 drawnIndex = _reserveDrawnIndex(params.spoke, params.debtReserveId);
    uint256 debtValueRayRepaid = _convertAmountToValue(
      params.spoke,
      params.debtReserveId,
      liquidationAmounts.drawnSharesToLiquidate * drawnIndex +
        liquidationAmounts.premiumDebtRayToLiquidate
    );

    if (debtValueRayRepaid == 0) {
      return false;
    }

    uint256 effectiveLiquidationBonusWad = Math.mulDiv(
      collateralValueRemoved,
      WadRayMath.RAY * WadRayMath.WAD,
      debtValueRayRepaid,
      Math.Rounding.Ceil
    );

    // health factor is decreasing due to liquidation bonus / collateral factor if:
    //   lb * cf > hf_beforeLiq
    return
      effectiveLiquidationBonusWad *
        _getCollateralFactor(params.spoke, params.collateralReserveId, params.user) >
      userAccountDataBefore.healthFactor * PercentageMath.PERCENTAGE_FACTOR;
  }

  function _checkPositionStatus(
    CheckedLiquidationCallParams memory params,
    LiquidationMetadata memory liquidationMetadata
  ) internal virtual {
    assertEq(
      _isUsingAsCollateral(params.spoke, params.collateralReserveId, params.user),
      true,
      'user position status: using as collateral'
    );
    bool isBorrowing = _isBorrowing(params.spoke, params.debtReserveId, params.user);
    assertTrue(
      !liquidationMetadata.fullDebtReserveLiquidated
        ? (isBorrowing || liquidationMetadata.hasDeficit)
        : !isBorrowing,
      'user position status: borrowing'
    );
  }

  function _checkHealthFactor(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata
  ) internal virtual {
    // accountsInfoAfter.userAccountData was already checked against expectedUserAccountData
    bool isCollateralAffectingUserHf = _isCollateralAffectingUserHf(
      params,
      LiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: liquidationMetadata.collateralSharesToLiquidate,
        collateralSharesToLiquidator: liquidationMetadata.collateralSharesToLiquidator,
        drawnSharesToLiquidate: liquidationMetadata.drawnSharesToLiquidate,
        premiumDebtRayToLiquidate: liquidationMetadata.premiumDebtRayToLiquidate
      }),
      accountsInfoBefore.userAccountData,
      accountsInfoAfter.userAccountData
    );
    if (accountsInfoAfter.userAccountData.totalDebtValueRay == 0 || !isCollateralAffectingUserHf) {
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

    if (
      liquidationMetadata.hasDeficit ||
      (liquidationMetadata.fullDebtReserveLiquidated &&
        accountsInfoBefore.userAccountData.borrowCount == 1)
    ) {
      assertEq(
        accountsInfoAfter.userAccountData.healthFactor,
        UINT256_MAX,
        'health factor should be max if all debt is liquidated'
      );
    } else if (liquidationMetadata.debtRayToTarget <= liquidationMetadata.debtRayToLiquidate) {
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
          liquidationMetadata.debtAssetsToLiquidate,
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
          liquidationMetadata.debtAssetsToLiquidate,
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
          liquidationMetadata.debtAssetsToLiquidate,
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
          liquidationMetadata.debtAssetsToLiquidate,
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
          liquidationMetadata.collateralAssetsToLiquidator +
          liquidationMetadata.debtAssetsToLiquidate,
        'collateral hub: collateral erc20 balance'
      );
    } else {
      assertEq(
        accountsInfoAfter.collateralHubBalanceInfo.collateralErc20Balance,
        accountsInfoBefore.collateralHubBalanceInfo.collateralErc20Balance -
          liquidationMetadata.collateralAssetsToLiquidator,
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
          liquidationMetadata.debtAssetsToLiquidate,
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
          liquidationMetadata.collateralAssetsToLiquidator -
          liquidationMetadata.debtAssetsToLiquidate,
        'liquidator: collateral erc20 balance'
      );
    } else {
      assertEq(
        accountsInfoAfter.liquidatorBalanceInfo.collateralErc20Balance,
        accountsInfoBefore.liquidatorBalanceInfo.collateralErc20Balance +
          liquidationMetadata.collateralAssetsToLiquidator,
        'liquidator: collateral erc20 balance'
      );
      assertEq(
        accountsInfoAfter.liquidatorBalanceInfo.debtErc20Balance,
        accountsInfoBefore.liquidatorBalanceInfo.debtErc20Balance -
          liquidationMetadata.debtAssetsToLiquidate,
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
    assertApproxEqAbs(
      accountsInfoAfter.userBalanceInfo.suppliedInSpoke,
      accountsInfoBefore.userBalanceInfo.suppliedInSpoke -
        liquidationMetadata.collateralAssetsToLiquidate,
      2,
      'user: collateral supplied'
    );
    assertApproxEqAbs(
      accountsInfoAfter.userBalanceInfo.borrowedFromSpoke,
      (liquidationMetadata.hasDeficit)
        ? 0
        : accountsInfoBefore.userBalanceInfo.borrowedFromSpoke -
          liquidationMetadata.debtAssetsToLiquidate,
      2,
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
      assertApproxEqAbs(
        accountsInfoAfter.liquidatorBalanceInfo.suppliedInSpoke,
        accountsInfoBefore.liquidatorBalanceInfo.suppliedInSpoke,
        2,
        'liquidator: collateral supplied'
      );
    } else {
      assertApproxEqAbs(
        accountsInfoAfter.liquidatorBalanceInfo.suppliedInSpoke,
        accountsInfoBefore.liquidatorBalanceInfo.suppliedInSpoke +
          liquidationMetadata.collateralAssetsToLiquidator,
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
    assertApproxEqAbs(
      accountsInfoAfter.collateralFeeReceiverBalanceInfo.addedInHub,
      accountsInfoBefore.collateralFeeReceiverBalanceInfo.addedInHub +
        liquidationMetadata.collateralAssetsToLiquidate -
        liquidationMetadata.collateralAssetsToLiquidator,
      2,
      'collateral fee receiver: added'
    );

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
    assertApproxEqAbs(
      accountsInfoAfter.spokeBalanceInfo.addedInHub,
      accountsInfoBefore.spokeBalanceInfo.addedInHub -
        (
          params.receiveShares
            ? liquidationMetadata.collateralAssetsToLiquidate -
              liquidationMetadata.collateralAssetsToLiquidator
            : liquidationMetadata.collateralAssetsToLiquidate
        ),
      5,
      'spoke: added'
    );
    assertApproxEqAbs(
      accountsInfoAfter.spokeBalanceInfo.drawnFromHub,
      (liquidationMetadata.hasDeficit)
        ? accountsInfoBefore.spokeBalanceInfo.drawnFromHub -
          accountsInfoBefore.userBalanceInfo.borrowedFromSpoke
        : accountsInfoBefore.spokeBalanceInfo.drawnFromHub -
          liquidationMetadata.debtAssetsToLiquidate,
      2,
      'spoke: drawn'
    );
  }

  function _checkUserAccountData(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata,
    ISpoke.UserAccountData memory expectedUserAccountData
  ) internal view {
    assertEq(accountsInfoAfter.userAccountData, expectedUserAccountData);

    for (uint256 reserveId = 0; reserveId < params.spoke.getReserveCount(); reserveId++) {
      if (_isBorrowing(params.spoke, reserveId, params.user)) {
        ISpoke.UserPosition memory userPosition = params.spoke.getUserPosition(
          reserveId,
          params.user
        );
        assertNotEq(userPosition.drawnShares, 0, 'borrowed reserve should have non zero base debt');
        assertEq(
          userPosition.premiumShares,
          userPosition.drawnShares.percentMulUp(accountsInfoAfter.userLastRiskPremium),
          string.concat('last user risk premium in reserve ', vm.toString(reserveId))
        );
      }
    }

    assertEq(
      accountsInfoAfter.userAccountData.riskPremium,
      accountsInfoAfter.userLastRiskPremium,
      'user risk premium: user account data'
    );
    if (liquidationMetadata.hasDeficit) {
      assertEq(accountsInfoAfter.userLastRiskPremium, 0, 'user risk premium: 0 in deficit');
    }
  }

  function _assertBeforeLiquidation(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    LiquidationMetadata memory liquidationMetadata
  ) internal view virtual {}

  function _checkedLiquidationCall(CheckedLiquidationCallParams memory params) internal virtual {
    // ensures there is enough liquidity to liquidate
    _openSupplyPosition(
      params.spoke,
      params.collateralReserveId,
      params.spoke.getUserSuppliedAssets(params.collateralReserveId, params.user)
    );

    AccountsInfo memory accountsInfoBefore = _getAccountsInfo(params);
    LiquidationMetadata memory liquidationMetadata = _getLiquidationMetadata(
      params,
      accountsInfoBefore.userAccountData
    );
    ISpoke.UserAccountData memory expectedUserAccountData = _calculateExpectedUserAccountData(
      params,
      liquidationMetadata
    );
    _assertBeforeLiquidation(params, accountsInfoBefore, liquidationMetadata);
    _expectEventsAndCalls(params, accountsInfoBefore, liquidationMetadata, expectedUserAccountData);
    vm.prank(params.liquidator);
    params.spoke.liquidationCall(
      params.collateralReserveId,
      params.debtReserveId,
      params.user,
      params.debtToCover,
      params.receiveShares
    );
    AccountsInfo memory accountsInfoAfter = _getAccountsInfo(params);
    _checkUserAccountData(params, accountsInfoAfter, liquidationMetadata, expectedUserAccountData);
    _checkPositionStatus(params, liquidationMetadata);
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
}
