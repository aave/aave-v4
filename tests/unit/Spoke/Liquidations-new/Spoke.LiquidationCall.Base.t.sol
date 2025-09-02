// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract SpokeLiquidationCallBaseTest is LiquidationLogicBaseTest {
  using SafeCast for *;
  using PercentageMath for uint256;
  using WadRayMath for uint256;

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

  function _makeUserLiquidatable(
    ISpoke spoke,
    address user,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    bool isSolvent
  ) internal virtual {
    uint256 supplyAmount = _convertBaseCurrencyToAmount(spoke, collateralReserveId, 100e26);
    _increaseCollateralSupply(spoke, collateralReserveId, supplyAmount, user);

    uint256 borrowAmount = _convertAssetAmount(
      spoke,
      collateralReserveId,
      supplyAmount / 2,
      debtReserveId
    );
    _openSupplyPosition(spoke, debtReserveId, borrowAmount);
    _borrowWithoutHfCheck(spoke, user, debtReserveId, borrowAmount);

    skip(1 days);

    DataTypes.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    uint256 targetHealthFactor;
    if (isSolvent) {
      // health factor of user should be at least its average collateral factor
      targetHealthFactor =
        (userAccountData.avgCollateralFactor + PercentageMath.PERCENTAGE_FACTOR.bpsToWad()) /
        2;
    } else {
      targetHealthFactor = (userAccountData.avgCollateralFactor * 2) / 3;
    }

    _openSupplyPosition(
      spoke,
      debtReserveId,
      _getRequiredDebtAmountForHf(spoke, user, debtReserveId, targetHealthFactor)
    );
    _borrowToBeAtHf(spoke, user, debtReserveId, targetHealthFactor);

    if (collateralReserveId == debtReserveId) {
      _openSupplyPosition(spoke, collateralReserveId, supplyAmount);
    }
  }

  function _expectEmitEvents(ISpoke spoke, address user, bool hasDeficit) internal virtual {
    for (uint256 reserveId = 0; reserveId < spoke.getReserveCount(); reserveId++) {
      if (spoke.isBorrowing(reserveId, user)) {
        vm.expectCall(
          address(spoke.getReserve(reserveId).hub),
          abi.encodeWithSelector(IHub.reportDeficit.selector),
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

  function _checkedLiquidationCall(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    address liquidator,
    bool isSolvent,
    bool hasDeficit
  ) internal virtual {
    DataTypes.UserAccountData memory userAccountDataBefore = spoke.getUserAccountData(user);
    uint256 debtToRestoreCloseFactor = liquidationLogicWrapper.calculateDebtToRestoreCloseFactor(
      _getCalculateDebtToRestoreCloseFactorParams(spoke, collateralReserveId, debtReserveId, user)
    );
    uint256 variableLiquidationBonus = spoke.getVariableLiquidationBonus(
      collateralReserveId,
      user,
      userAccountDataBefore.healthFactor
    );

    _expectEmitEvents(spoke, user, hasDeficit);
    vm.prank(liquidator);
    spoke.liquidationCall(collateralReserveId, debtReserveId, user, debtToCover);

    DataTypes.UserAccountData memory userAccountDataAfter = spoke.getUserAccountData(user);

    if (
      hasDeficit ||
      (isSolvent &&
        variableLiquidationBonus * userAccountDataBefore.totalDebtInBaseCurrency <
        userAccountDataBefore.totalCollateralInBaseCurrency.toWad())
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
    } else if (
      debtToCover >= debtToRestoreCloseFactor &&
      (spoke.getUserSuppliedAmount(collateralReserveId, user) > 0 ||
        spoke.getUserTotalDebt(debtReserveId, user) == 0)
    ) {
      assertApproxEqRel(
        userAccountDataAfter.healthFactor,
        _getCloseFactor(spoke),
        _approxRelFromBps(1)
      );
    }
  }

  function test_liquidationCall(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    address liquidator,
    bool isSolvent,
    bool hasDeficit
  ) internal {
    _makeUserLiquidatable(spoke, user, collateralReserveId, debtReserveId, isSolvent);
    debtToCover = _boundDebtToCoverNoDustRevert(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator
    );
    _checkedLiquidationCall(
      spoke,
      collateralReserveId,
      debtReserveId,
      user,
      debtToCover,
      liquidator,
      isSolvent,
      hasDeficit
    );
  }

  /// @dev Opens a supply position for a random user
  function _increaseCollateralSupply(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    address user
  ) public {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    uint256 initialLiq = spoke.getReserve(reserveId).hub.getLiquidity(assetId);

    deal(spoke, reserveId, user, amount);
    Utils.approve(spoke, reserveId, user, UINT256_MAX);

    Utils.supplyCollateral({
      spoke: spoke,
      reserveId: reserveId,
      caller: user,
      amount: amount,
      onBehalfOf: user
    });

    assertEq(hub1.getLiquidity(assetId), initialLiq + amount);
  }
}
