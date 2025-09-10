// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract SpokeLiquidationCallBaseTest is LiquidationLogicBaseTest {
  using SafeCast for *;
  using PercentageMath for uint256;

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
    DataTypes.UserAccountData userAccountData;
    BalanceInfo userBalanceInfo;
    BalanceInfo collateralHubBalanceInfo;
    BalanceInfo debtHubBalanceInfo;
    BalanceInfo liquidatorBalanceInfo;
    BalanceInfo collateralFeeReceiverBalanceInfo;
    BalanceInfo debtFeeReceiverBalanceInfo;
    BalanceInfo spokeBalanceInfo;
  }

  struct LiquidationMetadata {
    uint256 debtToTarget;
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
      debtToCover = bound(debtToCover, params.reserveDebtBalance, MAX_SUPPLY_AMOUNT);
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
        reserveDebtBalance: spoke.getUserTotalDebt(debtReserveId, user),
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

  function _getCalculateDebtToTargetHealthFactorParams(
    ISpoke spoke,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user
  ) internal virtual returns (LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory) {
    DataTypes.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    return
      LiquidationLogic.CalculateDebtToTargetHealthFactorParams({
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
        reserveDebtBalance: spoke.getUserTotalDebt(debtReserveId, user),
        reserveCollateralBalance: spoke.getUserSuppliedAmount(collateralReserveId, user),
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
    uint256 newHealthFactor
  ) internal virtual {
    DataTypes.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    // add liquidity
    _openSupplyPosition(
      spoke,
      debtReserveId,
      _getRequiredDebtAmountForHf(spoke, user, debtReserveId, newHealthFactor)
    );
    // borrow to be at target health factor
    _borrowToBeAtHf(spoke, user, debtReserveId, newHealthFactor);
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
        suppliedInSpoke: spoke.getUserSuppliedAmount(collateralReserveId, addr),
        addedInHub: spoke.getReserve(collateralReserveId).hub.getSpokeAddedAmount(
          spoke.getReserve(collateralReserveId).assetId,
          addr
        ),
        debtErc20Balance: getAssetUnderlyingByReserveId(spoke, debtReserveId).balanceOf(addr),
        borrowedFromSpoke: spoke.getUserTotalDebt(debtReserveId, addr),
        drawnFromHub: spoke.getReserve(debtReserveId).hub.getSpokeTotalOwed(
          spoke.getReserve(debtReserveId).assetId,
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
        ),
        collateralFeeReceiverBalanceInfo: _getBalanceInfo(
          params.spoke,
          params
            .spoke
            .getReserve(params.collateralReserveId)
            .hub
            .getAssetConfig(params.spoke.getReserve(params.collateralReserveId).assetId)
            .feeReceiver,
          params.collateralReserveId,
          params.debtReserveId
        ),
        debtFeeReceiverBalanceInfo: _getBalanceInfo(
          params.spoke,
          params
            .spoke
            .getReserve(params.debtReserveId)
            .hub
            .getAssetConfig(params.spoke.getReserve(params.debtReserveId).assetId)
            .feeReceiver,
          params.collateralReserveId,
          params.debtReserveId
        ),
        spokeBalanceInfo: _getBalanceInfo(
          params.spoke,
          address(params.spoke),
          params.collateralReserveId,
          params.debtReserveId
        )
      });
  }

  function _getLiquidationMetadata(
    CheckedLiquidationCallParams memory params,
    DataTypes.UserAccountData memory userAccountDataBefore
  ) internal virtual returns (LiquidationMetadata memory) {
    uint256 debtToTarget = liquidationLogicWrapper.calculateDebtToTargetHealthFactor(
      _getCalculateDebtToTargetHealthFactorParams(
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

    bool hasDeficit = (userAccountDataBefore.suppliedCollateralsCount == 1) &&
      (!params.isSolvent || isLiquidationBonusAffectingUserHf) &&
      (collateralToLiquidate ==
        params.spoke.getUserSuppliedAmount(params.collateralReserveId, params.user));

    return
      LiquidationMetadata({
        debtToTarget: debtToTarget,
        collateralToLiquidate: collateralToLiquidate,
        collateralToLiquidator: collateralToLiquidator,
        debtToLiquidate: debtToLiquidate,
        liquidationBonus: liquidationBonus,
        isLiquidationBonusAffectingUserHf: isLiquidationBonusAffectingUserHf,
        hasDeficit: hasDeficit
      });
  }

  function _checkPositionStatus(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    LiquidationMetadata memory liquidationMetadata
  ) internal virtual {
    assertEq(
      params.spoke.isUsingAsCollateral(params.collateralReserveId, params.user),
      true,
      'user position status: using as collateral'
    );
    assertEq(
      params.spoke.isBorrowing(params.debtReserveId, params.user) || liquidationMetadata.hasDeficit,
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
  ) internal {
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

    // Hubs
    address collateralHub = address(params.spoke.getReserve(params.collateralReserveId).hub);
    address debtHub = address(params.spoke.getReserve(params.debtReserveId).hub);
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

  function _checkSpokeBalances(
    CheckedLiquidationCallParams memory params,
    AccountsInfo memory accountsInfoBefore,
    AccountsInfo memory accountsInfoAfter,
    LiquidationMetadata memory liquidationMetadata
  ) internal {
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
    assertEq(
      accountsInfoAfter.liquidatorBalanceInfo.suppliedInSpoke,
      accountsInfoBefore.liquidatorBalanceInfo.suppliedInSpoke,
      'liquidator: collateral supplied'
    );
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
  ) internal {
    // User
    assertEq(
      accountsInfoAfter.userBalanceInfo.addedInHub,
      accountsInfoBefore.userBalanceInfo.addedInHub,
      'user: collateral added'
    );
    assertEq(
      accountsInfoAfter.userBalanceInfo.drawnFromHub,
      accountsInfoBefore.userBalanceInfo.drawnFromHub,
      'user: debt drawn'
    );

    // Hubs
    assertEq(
      accountsInfoAfter.collateralHubBalanceInfo.addedInHub,
      accountsInfoBefore.collateralHubBalanceInfo.addedInHub,
      'collateral hub: collateral added'
    );
    assertEq(
      accountsInfoAfter.collateralHubBalanceInfo.drawnFromHub,
      accountsInfoBefore.collateralHubBalanceInfo.drawnFromHub,
      'collateral hub: debt drawn'
    );
    assertEq(
      accountsInfoAfter.debtHubBalanceInfo.addedInHub,
      accountsInfoBefore.debtHubBalanceInfo.addedInHub,
      'debt hub: collateral added'
    );
    assertEq(
      accountsInfoAfter.debtHubBalanceInfo.drawnFromHub,
      accountsInfoBefore.debtHubBalanceInfo.drawnFromHub,
      'debt hub: debt drawn'
    );

    // Liquidator
    assertEq(
      accountsInfoAfter.liquidatorBalanceInfo.addedInHub,
      accountsInfoBefore.liquidatorBalanceInfo.addedInHub,
      'liquidator: collateral added'
    );
    assertEq(
      accountsInfoAfter.liquidatorBalanceInfo.drawnFromHub,
      accountsInfoBefore.liquidatorBalanceInfo.drawnFromHub,
      'liquidator: debt drawn'
    );

    // Fee Receivers
    assertApproxEqRel(
      accountsInfoAfter.collateralFeeReceiverBalanceInfo.addedInHub,
      accountsInfoBefore.collateralFeeReceiverBalanceInfo.addedInHub +
        liquidationMetadata.collateralToLiquidate -
        liquidationMetadata.collateralToLiquidator,
      _approxRelFromBps(1),
      'collateral fee receiver: collateral added'
    );
    assertEq(
      accountsInfoAfter.collateralFeeReceiverBalanceInfo.drawnFromHub,
      accountsInfoBefore.collateralFeeReceiverBalanceInfo.drawnFromHub,
      'collateral fee receiver: debt drawn'
    );
    assertEq(
      accountsInfoAfter.debtFeeReceiverBalanceInfo.addedInHub,
      accountsInfoBefore.debtFeeReceiverBalanceInfo.addedInHub,
      'debt fee receiver: collateral added'
    );
    assertEq(
      accountsInfoAfter.debtFeeReceiverBalanceInfo.drawnFromHub,
      accountsInfoBefore.debtFeeReceiverBalanceInfo.drawnFromHub,
      'debt fee receiver: debt drawn'
    );

    // Spoke
    assertApproxEqRel(
      accountsInfoAfter.spokeBalanceInfo.addedInHub,
      accountsInfoBefore.spokeBalanceInfo.addedInHub - liquidationMetadata.collateralToLiquidate,
      _approxRelFromBps(1),
      'spoke: collateral added'
    );
    assertApproxEqRel(
      accountsInfoAfter.spokeBalanceInfo.drawnFromHub,
      (liquidationMetadata.hasDeficit)
        ? 0
        : accountsInfoBefore.spokeBalanceInfo.drawnFromHub - liquidationMetadata.debtToLiquidate,
      _approxRelFromBps(1),
      'spoke: debt drawn'
    );
  }

  function _checkedLiquidationCall(CheckedLiquidationCallParams memory params) internal virtual {
    // make sure there is enough liquidity to liquidate
    _openSupplyPosition(params.spoke, params.collateralReserveId, MAX_AMOUNT_IN_BASE_CURRENCY);

    AccountsInfo memory accountsInfoBefore = _getAccountsInfo(params);
    LiquidationMetadata memory liquidationMetadata = _getLiquidationMetadata(
      params,
      accountsInfoBefore.userAccountData
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

    _checkPositionStatus(params, accountsInfoBefore, liquidationMetadata);
    _checkHealthFactor(params, accountsInfoBefore, accountsInfoAfter, liquidationMetadata);
    _checkErc20Balances(params, accountsInfoBefore, accountsInfoAfter, liquidationMetadata);
    _checkSpokeBalances(params, accountsInfoBefore, accountsInfoAfter, liquidationMetadata);
    _checkHubBalances(params, accountsInfoBefore, accountsInfoAfter, liquidationMetadata);
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
