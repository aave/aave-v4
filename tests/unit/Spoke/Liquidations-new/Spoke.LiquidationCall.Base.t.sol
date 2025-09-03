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

  /// @notice Bound liquidation config to full range of possible values
  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
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
    dynConfig.liquidationBonus = bound(
      dynConfig.liquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    ).toUint32();
    dynConfig.collateralFactor = bound(
      dynConfig.collateralFactor,
      1,
      (PercentageMath.PERCENTAGE_FACTOR - 1).percentDivDown(dynConfig.liquidationBonus)
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
      debtToCover = bound(debtToCover, params.totalReserveDebt, MAX_SUPPLY_AMOUNT);
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
        totalReserveDebt: spoke.getUserTotalDebt(debtReserveId, user),
        debtToCover: debtToCover,
        totalDebtInBaseCurrency: userAccountData.totalDebtInBaseCurrency,
        healthFactor: userAccountData.healthFactor,
        closeFactor: spoke.getLiquidationConfig().closeFactor,
        variableLiquidationBonus: spoke.getVariableLiquidationBonus(
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

  function _getCalculateDebtToRestoreCloseFactorParams(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user
  ) internal virtual returns (LiquidationLogic.CalculateDebtToRestoreCloseFactorParams memory) {
    DataTypes.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    return
      LiquidationLogic.CalculateDebtToRestoreCloseFactorParams({
        totalDebtInBaseCurrency: userAccountData.totalDebtInBaseCurrency,
        healthFactor: userAccountData.healthFactor,
        closeFactor: spoke.getLiquidationConfig().closeFactor,
        variableLiquidationBonus: spoke.getVariableLiquidationBonus(
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
        totalReserveDebt: spoke.getUserTotalDebt(debtReserveId, user),
        totalReserveCollateral: spoke.getUserSuppliedAmount(collateralReserveId, user),
        debtToCover: debtToCover,
        totalDebtInBaseCurrency: userAccountData.totalDebtInBaseCurrency,
        healthFactor: userAccountData.healthFactor,
        closeFactor: spoke.getLiquidationConfig().closeFactor,
        liquidationBonus: spoke
          .getDynamicReserveConfig(
            collateralReserveId,
            spoke.getUserPosition(collateralReserveId, user).configKey
          )
          .liquidationBonus,
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
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    address liquidator,
    uint256 collateralToLiquidate,
    uint256 debtToLiquidate,
    bool hasDeficit
  ) internal virtual {
    vm.expectEmit(address(spoke));
    emit ISpokeBase.LiquidationCall(
      collateralReserveId,
      debtReserveId,
      user,
      debtToLiquidate,
      collateralToLiquidate,
      liquidator
    );

    for (uint256 reserveId = 0; reserveId < spoke.getReserveCount(); reserveId++) {
      if (spoke.isBorrowing(reserveId, user)) {
        vm.expectCall(
          address(spoke.getReserve(reserveId).hub),
          abi.encodeWithSelector(IHub.reportDeficit.selector, spoke.getReserve(reserveId).assetId),
          hasDeficit ? 1 : 0
        );
      }
    }

    if (!hasDeficit) {
      vm.expectEmit(false, false, false, false, address(spoke));
      // topics > 0 and data are not checked
      emit ISpoke.UserRiskPremiumUpdate(address(0), 0);
    } else {
      vm.expectEmit(address(spoke));
      emit ISpoke.UserRiskPremiumUpdate(user, 0);
    }
  }

  function _checkedLiquidationCall(CheckedLiquidationCallParams memory params) internal virtual {
    DataTypes.UserAccountData memory userAccountDataBefore = params.spoke.getUserAccountData(
      params.user
    );
    uint256 debtToRestoreCloseFactor = liquidationLogicWrapper.calculateDebtToRestoreCloseFactor(
      _getCalculateDebtToRestoreCloseFactorParams(
        params.spoke,
        params.collateralReserveId,
        params.debtReserveId,
        params.user
      )
    );
    (uint256 collateralToLiquidate, , uint256 debtToLiquidate) = liquidationLogicWrapper
      .calculateLiquidationAmounts(
        _getCalculateLiquidationAmountsParams(
          params.spoke,
          params.collateralReserveId,
          params.debtReserveId,
          params.user,
          params.debtToCover
        )
      );

    uint256 variableLiquidationBonus = params.spoke.getVariableLiquidationBonus(
      params.collateralReserveId,
      params.user,
      userAccountDataBefore.healthFactor
    );

    bool isLiquidationBonusAffectingUserHf = variableLiquidationBonus *
      userAccountDataBefore.totalDebtInBaseCurrency >
      userAccountDataBefore.totalCollateralInBaseCurrency * PercentageMath.PERCENTAGE_FACTOR;

    bool hasDeficit = (userAccountDataBefore.suppliedAssetsCount == 1) &&
      (!params.isSolvent || isLiquidationBonusAffectingUserHf) &&
      (collateralToLiquidate ==
        params.spoke.getUserSuppliedAmount(params.collateralReserveId, params.user));

    // make sure there is enough liquidity to liquidate
    _openSupplyPosition(
      params.spoke,
      params.collateralReserveId,
      params.spoke.getUserSuppliedAmount(params.collateralReserveId, params.user)
    );

    _expectEventsAndCalls(
      params.spoke,
      params.collateralReserveId,
      params.debtReserveId,
      params.user,
      params.liquidator,
      collateralToLiquidate,
      debtToLiquidate,
      hasDeficit
    );
    vm.prank(params.liquidator);
    params.spoke.liquidationCall(
      params.collateralReserveId,
      params.debtReserveId,
      params.user,
      params.debtToCover
    );

    DataTypes.UserAccountData memory userAccountDataAfter = params.spoke.getUserAccountData(
      params.user
    );

    if (
      hasDeficit ||
      userAccountDataAfter.totalDebtInBaseCurrency == 0 ||
      (params.isSolvent && !isLiquidationBonusAffectingUserHf)
    ) {
      assertGe(
        userAccountDataAfter.healthFactor,
        userAccountDataBefore.healthFactor,
        'health factor should increase after liquidation'
      );
    } else {
      assertLe(
        userAccountDataAfter.healthFactor,
        userAccountDataBefore.healthFactor,
        'health factor should decrease after liquidation'
      );
    }

    if (userAccountDataAfter.totalDebtInBaseCurrency == 0) {
      assertEq(
        userAccountDataAfter.healthFactor,
        type(uint256).max,
        'health factor should be max if all debt is liquidated'
      );
    } else if (debtToLiquidate == debtToRestoreCloseFactor) {
      assertApproxEqRel(
        userAccountDataAfter.healthFactor,
        _getCloseFactor(params.spoke),
        _approxRelFromBps(1)
      );
    } else if (debtToLiquidate > debtToRestoreCloseFactor) {
      // dust adjusted
      assertGe(userAccountDataAfter.healthFactor, _getCloseFactor(params.spoke));
    } else {
      assertLe(userAccountDataAfter.healthFactor, _getCloseFactor(params.spoke));
    }
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
