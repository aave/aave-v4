// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract SpokeLiquidationCallBaseTest is LiquidationLogicBaseTest {
  using SafeCast for *;
  using PercentageMath for uint256;

  struct CheckedLiquidationCallParams {
    ISpoke spoke;
    uint256 collateralReserveId;
    uint256 debtReserveId;
    address user;
    uint256 debtToCover;
    address liquidator;
    bool isSolvent;
  }

  struct BalanceInfo {
    uint256 collateralErc20Balance;
    uint256 collateralSupplied;
    uint256 debtErc20Balance;
    uint256 debtBorrowed;
  }

  struct AccountsInfo {
    DataTypes.UserAccountData userAccountData;
    BalanceInfo userBalanceInfo;
    BalanceInfo collateralHubBalanceInfo;
    BalanceInfo debtHubBalanceInfo;
    BalanceInfo liquidatorBalanceInfo;
  }

  struct LiquidationMetadata {
    uint256 debtToRestoreHealthFactor;
    uint256 collateralToLiquidate;
    uint256 collateralToLiquidator;
    uint256 debtToLiquidate;
    uint256 liquidationBonus;
    bool isLiquidationBonusAffectingUserHf;
    bool hasDeficit;
  }

  /// @notice Bound liquidation config to full range of possible values
  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual returns (DataTypes.LiquidationConfig memory) {
    liqConfig.targetHealthFactor = bound(
      liqConfig.targetHealthFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      MAX_CLOSE_FACTOR
    ).toUint128();

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
    DataTypes.DynamicReserveConfig memory dynConfig
  ) internal pure virtual returns (DataTypes.DynamicReserveConfig memory) {
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
      _convertBaseCurrencyToAmount(spoke, debtReserveId, 1e26),
      MAX_SUPPLY_AMOUNT
    );

    LiquidationLogic.CalculateMaxDebtToLiquidateParams
      memory params = _getCalculateMaxDebtToLiquidateParams(
        spoke,
        collateralReserveId,
        debtReserveId,
        user,
        debtToCover
      );
    try liquidationLogicWrapper.calculateMaxDebtToLiquidate(params) returns (uint256) {} catch {
      debtToCover = bound(debtToCover, params.reserveDebt, MAX_SUPPLY_AMOUNT);
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
  ) internal returns (bytes memory) {
    uint256[] memory boundedReserveIds = new uint256[](_min(reserveIds.length, maxLength));

    for (uint256 i = 0; i < boundedReserveIds.length; i++) {
      boundedReserveIds[i] = bound(reserveIds[i], 0, spoke.getReserveCount() - 1);
      if (boundedReserveIds[i] == reserveIdToExclude) {
        boundedReserveIds[i] = bound(boundedReserveIds[i] + 1, 0, spoke.getReserveCount() - 1);
      }
    }
    return abi.encode(boundedReserveIds);
  }

  function _getCalculateMaxDebtToLiquidateParams(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) internal virtual returns (LiquidationLogic.CalculateMaxDebtToLiquidateParams memory) {
    DataTypes.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    return
      LiquidationLogic.CalculateMaxDebtToLiquidateParams({
        reserveDebt: spoke.getUserTotalDebt(debtReserveId, user),
        debtToCover: debtToCover,
        totalDebtInBaseCurrency: userAccountData.totalDebtInBaseCurrency,
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
            spoke.getUserPosition(collateralReserveId, user).configKey
          )
          .collateralFactor,
        debtAssetPrice: spoke.oracle().getReservePrice(debtReserveId),
        debtAssetUnit: 10 ** spoke.getReserve(debtReserveId).decimals
      });
  }

  function _getCalculateDebtToRestoreHealthFactorParams(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user
  )
    internal
    virtual
    returns (LiquidationLogic.CalculateDebtToRestoreHealthFactorParams memory)
  {
    DataTypes.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    return
      LiquidationLogic.CalculateDebtToRestoreHealthFactorParams({
        totalDebtInBaseCurrency: userAccountData.totalDebtInBaseCurrency,
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
            spoke.getUserPosition(collateralReserveId, user).configKey
          )
          .collateralFactor,
        debtAssetPrice: spoke.oracle().getReservePrice(debtReserveId),
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
    DataTypes.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    return
      LiquidationLogic.CalculateLiquidationAmountsParams({
        healthFactorForMaxBonus: spoke.getLiquidationConfig().healthFactorForMaxBonus,
        liquidationBonusFactor: spoke.getLiquidationConfig().liquidationBonusFactor,
        reserveDebt: spoke.getUserTotalDebt(debtReserveId, user),
        reserveCollateral: spoke.getUserSuppliedAmount(collateralReserveId, user),
        debtToCover: debtToCover,
        totalDebtInBaseCurrency: userAccountData.totalDebtInBaseCurrency,
        healthFactor: userAccountData.healthFactor,
        targetHealthFactor: spoke.getLiquidationConfig().targetHealthFactor,
        maxLiquidationBonus: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).configKey
          )
          .maxLiquidationBonus,
        collateralFactor: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).configKey
          )
          .collateralFactor,
        debtAssetPrice: spoke.oracle().getReservePrice(debtReserveId),
        debtAssetUnit: 10 ** spoke.getReserve(debtReserveId).decimals,
        collateralAssetPrice: spoke.oracle().getReservePrice(collateralReserveId),
        collateralAssetUnit: 10 ** spoke.getReserve(collateralReserveId).decimals,
        liquidationFee: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).configKey
          )
          .liquidationFee
      });
  }

  function _makeUserLiquidatable(
    ISpoke spoke,
    address user,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 targetHealthFactor
  ) internal virtual {
    DataTypes.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    // add liquidity
    _openSupplyPosition(
      spoke,
      debtReserveId,
      _getRequiredDebtAmountForHf(spoke, user, debtReserveId, targetHealthFactor)
    );
    // borrow to be at target health factor
    _borrowToBeAtHf(spoke, user, debtReserveId, targetHealthFactor);
  }

  function _expectEventsAndCalls(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    LiquidationMetadata memory liquidationMetadata
  ) internal virtual {
    vm.expectEmit(address(params.spoke));
    emit ISpokeBase.LiquidationCall(
      params.collateralReserveId,
      params.debtReserveId,
      params.user,
      liquidationMetadata.debtToLiquidate,
      liquidationMetadata.collateralToLiquidate,
      params.liquidator
    );

    for (uint256 reserveId = 0; reserveId < params.spoke.getReserveCount(); reserveId++) {
      if (params.spoke.isBorrowing(reserveId, params.user)) {
        vm.expectCall(
          address(params.spoke.getReserve(reserveId).hub),
          abi.encodeWithSelector(
            IHub.reportDeficit.selector,
            params.spoke.getReserve(reserveId).assetId
          ),
          liquidationMetadata.hasDeficit ? 1 : 0
        );
      }
    }

    if (!liquidationMetadata.hasDeficit) {
      vm.expectEmit(false, false, false, false, address(params.spoke));
      // topics > 0 and data are not checked
      emit ISpoke.UserRiskPremiumUpdate(address(0), 0);
    } else {
      vm.expectEmit(address(params.spoke));
      emit ISpoke.UserRiskPremiumUpdate(params.user, 0);
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
        collateralSupplied: spoke.getUserSuppliedAmount(collateralReserveId, addr),
        debtErc20Balance: getAssetUnderlyingByReserveId(spoke, debtReserveId).balanceOf(addr),
        debtBorrowed: spoke.getUserTotalDebt(debtReserveId, addr)
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
          address(params.spoke.getReserve(params.collateralReserveId).hub),
          params.collateralReserveId,
          params.debtReserveId
        ),
        debtHubBalanceInfo: _getBalanceInfo(
          params.spoke,
          address(params.spoke.getReserve(params.debtReserveId).hub),
          params.collateralReserveId,
          params.debtReserveId
        ),
        liquidatorBalanceInfo: _getBalanceInfo(
          params.spoke,
          params.liquidator,
          params.collateralReserveId,
          params.debtReserveId
        )
      });
  }

  function _getLiquidationMetadata(
    CheckedLiquidationCallParams memory params,
    DataTypes.UserAccountData memory userAccountDataBefore
  ) internal virtual returns (LiquidationMetadata memory) {
    uint256 debtToRestoreHealthFactor = liquidationLogicWrapper
      .calculateDebtToRestoreHealthFactor(
        _getCalculateDebtToRestoreHealthFactorParams(
          params.spoke,
          params.collateralReserveId,
          params.debtReserveId,
          params.user
        )
      );
    (
      uint256 collateralToLiquidate,
      uint256 collateralToLiquidator,
      uint256 debtToLiquidate
    ) = liquidationLogicWrapper.calculateLiquidationAmounts(
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

    bool isLiquidationBonusAffectingUserHf = liquidationBonus *
      userAccountDataBefore.totalDebtInBaseCurrency >
      userAccountDataBefore.totalCollateralInBaseCurrency * PercentageMath.PERCENTAGE_FACTOR;

    bool hasDeficit = (userAccountDataBefore.suppliedAssetsCount == 1) &&
      (!params.isSolvent || isLiquidationBonusAffectingUserHf) &&
      (collateralToLiquidate ==
        params.spoke.getUserSuppliedAmount(params.collateralReserveId, params.user));

    return
      LiquidationMetadata({
        debtToRestoreHealthFactor: debtToRestoreHealthFactor,
        collateralToLiquidate: collateralToLiquidate,
        collateralToLiquidator: collateralToLiquidator,
        debtToLiquidate: debtToLiquidate,
        liquidationBonus: liquidationBonus,
        isLiquidationBonusAffectingUserHf: isLiquidationBonusAffectingUserHf,
        hasDeficit: hasDeficit
      });
  }

  function _checkHealthFactor(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata
  ) internal virtual {
    if (
      accountsInfoAfter.userAccountData.totalDebtInBaseCurrency == 0 ||
      (params.isSolvent && !liquidationMetadata.isLiquidationBonusAffectingUserHf)
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

    if (accountsInfoAfter.userAccountData.totalDebtInBaseCurrency == 0) {
      assertEq(
        accountsInfoAfter.userAccountData.healthFactor,
        type(uint256).max,
        'health factor should be max if all debt is liquidated'
      );
    } else if (
      liquidationMetadata.debtToLiquidate == liquidationMetadata.debtToRestoreHealthFactor
    ) {
      assertApproxEqRel(
        accountsInfoAfter.userAccountData.healthFactor,
        _getTargetHealthFactor(params.spoke),
        _approxRelFromBps(1)
      );
    } else if (
      liquidationMetadata.debtToLiquidate > liquidationMetadata.debtToRestoreHealthFactor
    ) {
      // dust adjusted
      assertGe(
        accountsInfoAfter.userAccountData.healthFactor,
        _getTargetHealthFactor(params.spoke)
      );
    } else {
      assertLe(
        accountsInfoAfter.userAccountData.healthFactor,
        _getTargetHealthFactor(params.spoke)
      );
    }
  }

  function _checkedLiquidationCall(CheckedLiquidationCallParams memory params) internal virtual {
    AccountsInfo memory accountsInfoBefore = _getAccountsInfo(params);
    LiquidationMetadata memory liquidationMetadata = _getLiquidationMetadata(
      params,
      accountsInfoBefore.userAccountData
    );

    // make sure there is enough liquidity to liquidate
    _openSupplyPosition(
      params.spoke,
      params.collateralReserveId,
      accountsInfoBefore.userBalanceInfo.collateralSupplied
    );

    _expectEventsAndCalls(params, accountsInfoBefore, liquidationMetadata);
    vm.prank(params.liquidator);
    params.spoke.liquidationCall(
      params.collateralReserveId,
      params.debtReserveId,
      params.user,
      params.debtToCover
    );

    AccountsInfo memory accountsInfoAfter = _getAccountsInfo(params);

    _checkHealthFactor(params, accountsInfoBefore, accountsInfoAfter, liquidationMetadata);
  }

  function _increaseCollateralSupplies(
    ISpoke spoke,
    uint256[] memory reserveIds,
    uint256 amountInBaseCurrency,
    address user
  ) internal {
    for (uint256 i = 0; i < reserveIds.length; i++) {
      _increaseCollateralSupply(
        spoke,
        reserveIds[i],
        _convertBaseCurrencyToAmount(spoke, reserveIds[i], amountInBaseCurrency),
        user
      );
    }
  }

  function _increaseDebts(
    ISpoke spoke,
    uint256[] memory reserveIds,
    uint256 amountInBaseCurrency,
    address user
  ) internal {
    for (uint256 i = 0; i < reserveIds.length; i++) {
      uint256 amount = _convertBaseCurrencyToAmount(spoke, reserveIds[i], amountInBaseCurrency);
      _openSupplyPosition(spoke, reserveIds[i], amount);
      Utils.borrow({
        spoke: spoke,
        reserveId: reserveIds[i],
        caller: user,
        amount: amount,
        onBehalfOf: user
      });
    }
  }
}
