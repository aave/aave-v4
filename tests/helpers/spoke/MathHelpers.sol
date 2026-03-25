// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {QueryHelpers} from 'tests/helpers/spoke/QueryHelpers.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {ITransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';
import {KeyValueList} from 'src/spoke/libraries/KeyValueList.sol';
import {MockSpoke} from 'tests/helpers/mocks/MockSpoke.sol';

/// @title MathHelpers
/// @notice Complex spoke-level calculations, premium delta, health-factor math,
///         and risk-premium re-implementation for the Aave V4 test suite.
abstract contract MathHelpers is QueryHelpers {
  using WadRayMath for *;
  using MathUtils for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;
  using KeyValueList for KeyValueList.List;

  uint256 internal constant MAX_SUPPLY_ASSET_UNITS = MAX_SUPPLY_AMOUNT / 1e18;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  CONVERSIONS & DEBT MATH                                  //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _convertAmountToValue(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal view returns (uint256) {
    return
      _convertAmountToValue(
        amount,
        IPriceOracle(spoke.ORACLE()).getReservePrice(reserveId),
        10 ** _underlying(spoke, reserveId).decimals()
      );
  }

  function _convertValueToAmount(
    ISpoke spoke,
    uint256 reserveId,
    uint256 valueAmount
  ) internal view returns (uint256) {
    return
      _convertValueToAmount(
        valueAmount,
        IPriceOracle(spoke.ORACLE()).getReservePrice(reserveId),
        10 ** _underlying(spoke, reserveId).decimals()
      );
  }

  function _convertAssetAmount(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount,
    uint256 toReserveId
  ) internal view returns (uint256) {
    return
      _convertValueToAmount(spoke, toReserveId, _convertAmountToValue(spoke, reserveId, amount));
  }

  function _calculatePremiumDebtRay(
    ISpoke spoke,
    uint256 reserveId,
    uint256 premiumShares,
    int256 premiumOffsetRay
  ) internal view returns (uint256) {
    IHub hub = _hub(spoke, reserveId);
    uint256 assetId = _reserveAssetId(spoke, reserveId);
    return _calculatePremiumDebtRay(hub, assetId, premiumShares, premiumOffsetRay);
  }

  function _calculatePremiumDebtRay(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    ISpoke.UserPosition memory userPosition = spoke.getUserPosition(reserveId, user);
    return
      _calculatePremiumDebtRay(
        spoke,
        reserveId,
        userPosition.premiumShares,
        userPosition.premiumOffsetRay
      );
  }

  function _calculateMaxSupplyAmount(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint256) {
    return MAX_SUPPLY_ASSET_UNITS * 10 ** spoke.getReserve(reserveId).decimals;
  }

  function _calculateRestoreAmounts(
    uint256 restoreAmount,
    uint256 drawn,
    uint256 premiumRay
  ) internal pure returns (uint256 drawnAmountToRestore, uint256 premiumRayToRestore) {
    if (restoreAmount <= premiumRay / WadRayMath.RAY) {
      return (0, restoreAmount.toRay());
    }
    return (drawn.min(restoreAmount - premiumRay.fromRayUp()), premiumRay);
  }

  function _calculateExpectedPremiumDebt(
    uint256 initialDrawnDebt,
    uint256 currentDrawnDebt,
    uint256 userRiskPremium
  ) internal pure returns (uint256) {
    return (currentDrawnDebt - initialDrawnDebt).percentMulUp(userRiskPremium);
  }

  function _calculateExactRestoreAmount(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 repayAmount
  ) internal view returns (uint256 baseRestored, uint256 premiumRestored) {
    (uint256 drawn, uint256 premium) = spoke.getUserDebt(reserveId, user);
    return
      _calculateExactRestoreAmount(
        _hub(spoke, reserveId),
        _reserveAssetId(spoke, reserveId),
        drawn,
        premium,
        repayAmount
      );
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   POSITION CALCULATIONS                                   //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _getUserAccountData(
    ISpoke spoke,
    address user,
    bool refreshConfig
  ) internal returns (ISpoke.UserAccountData memory) {
    uint256 snapshot = vm.snapshotState();

    address mockSpoke = address(new MockSpoke(spoke.ORACLE(), MAX_ALLOWED_USER_RESERVES_LIMIT));

    address implementation = _getImplementationAddress(address(spoke));

    vm.prank(_getProxyAdminAddress(address(spoke)));
    ITransparentUpgradeableProxy(address(spoke)).upgradeToAndCall(address(mockSpoke), '');

    vm.prank(user);
    ISpoke.UserAccountData memory userAccountData = MockSpoke(address(spoke))
      .calculateUserAccountData(user, refreshConfig);

    vm.prank(_getProxyAdminAddress(address(spoke)));
    ITransparentUpgradeableProxy(address(spoke)).upgradeToAndCall(implementation, '');

    vm.revertToState(snapshot);

    return userAccountData;
  }

  function _getExpectedPremiumDelta(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 repayAmount
  ) internal view virtual returns (IHubBase.PremiumDelta memory) {
    DebtData memory userDebt = _getUserDebt(spoke, user, reserveId);
    (, uint256 premiumRayToRestore) = _calculateRestoreAmounts(
      repayAmount,
      userDebt.drawnDebt,
      userDebt.premiumDebtRay
    );

    ISpoke.UserPosition memory userPosition = spoke.getUserPosition(reserveId, user);
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub hub = _hub(spoke, reserveId);

    return
      _getExpectedPremiumDelta({
        hub: hub,
        assetId: assetId,
        oldPremiumShares: userPosition.premiumShares,
        oldPremiumOffsetRay: userPosition.premiumOffsetRay,
        drawnShares: 0,
        riskPremium: 0,
        restoredPremiumRay: premiumRayToRestore
      });
  }

  function _getExpectedPremiumDeltaForRestore(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 repayAmount
  ) internal view virtual returns (IHubBase.PremiumDelta memory) {
    DebtData memory userDebt = _getUserDebt(spoke, user, reserveId);
    (uint256 drawnDebtToRestore, uint256 premiumRayToRestore) = _calculateRestoreAmounts(
      repayAmount,
      userDebt.drawnDebt,
      userDebt.premiumDebtRay
    );

    {
      ISpoke.UserPosition memory userPosition = spoke.getUserPosition(reserveId, user);
      uint256 assetId = spoke.getReserve(reserveId).assetId;
      IHub hub = IHub(address(spoke.getReserve(reserveId).hub));

      uint256 restoredShares = drawnDebtToRestore.rayDivDown(hub.getAssetDrawnIndex(assetId));
      uint256 riskPremium = _getUserRpStored(spoke, user);

      return
        _getExpectedPremiumDelta({
          hub: hub,
          assetId: assetId,
          oldPremiumShares: userPosition.premiumShares,
          oldPremiumOffsetRay: userPosition.premiumOffsetRay,
          drawnShares: userPosition.drawnShares - restoredShares,
          riskPremium: riskPremium,
          restoredPremiumRay: premiumRayToRestore
        });
    }
  }

  function _calcMinimumCollAmount(
    ISpoke spoke,
    uint256 collReserveId,
    uint256 debtReserveId,
    uint256 debtAmount
  ) internal view returns (uint256) {
    if (debtAmount == 0) return 1;
    IPriceOracle oracle = IPriceOracle(spoke.ORACLE());
    ISpoke.Reserve memory collData = spoke.getReserve(collReserveId);
    ISpoke.DynamicReserveConfig memory collDynConf = _getLatestDynamicReserveConfig(
      spoke,
      collReserveId
    );

    IHub collHub = IHub(address(collData.hub));
    uint256 collPrice = oracle.getReservePrice(collReserveId);
    uint256 collAssetUnits = 10 ** collHub.getAsset(collData.assetId).decimals;

    ISpoke.Reserve memory debtData = spoke.getReserve(debtReserveId);
    IHub debtHub = IHub(address(debtData.hub));
    uint256 debtAssetUnits = 10 ** debtHub.getAsset(debtData.assetId).decimals;
    uint256 debtPrice = oracle.getReservePrice(debtReserveId);

    uint256 normalizedDebtAmount = (debtAmount * debtPrice).wadDivDown(debtAssetUnits);
    uint256 normalizedCollPrice = collPrice.wadDivDown(collAssetUnits);

    return
      normalizedDebtAmount.wadDivUp(
        normalizedCollPrice.toWad().percentMulDown(collDynConf.collateralFactor)
      );
  }

  function _calcMaxDebtAmount(
    ISpoke spoke,
    uint256 collReserveId,
    uint256 debtReserveId,
    uint256 collAmount
  ) internal view returns (uint256) {
    IPriceOracle oracle = IPriceOracle(spoke.ORACLE());
    uint16 collFactor = _getLatestDynamicReserveConfig(spoke, collReserveId).collateralFactor;

    uint256 normalizedCollPrice;
    {
      ISpoke.Reserve memory collData = spoke.getReserve(collReserveId);
      uint256 collAssetUnits = 10 **
        IHub(address(collData.hub)).getAsset(collData.assetId).decimals;
      normalizedCollPrice = (collAmount * oracle.getReservePrice(collReserveId)).wadDivDown(
        collAssetUnits
      );
    }

    uint256 normalizedDebtAmount;
    {
      ISpoke.Reserve memory debtData = spoke.getReserve(debtReserveId);
      uint256 debtAssetUnits = 10 **
        IHub(address(debtData.hub)).getAsset(debtData.assetId).decimals;
      normalizedDebtAmount = oracle.getReservePrice(debtReserveId).wadDivDown(debtAssetUnits);
    }

    uint256 maxDebt = normalizedCollPrice.toWad().percentMulDown(collFactor) /
      normalizedDebtAmount.toWad();

    return maxDebt > 1 ? maxDebt - 1 : maxDebt;
  }

  function _getRequiredDebtAmountForHf(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 desiredHf
  ) internal returns (uint256 requiredDebtAmount) {
    uint256 requiredDebtAmountValue = _getRequiredDebtValueForHf(spoke, user, desiredHf);
    return _convertValueToAmount(spoke, reserveId, requiredDebtAmountValue);
  }

  function _getRequiredDebtValueForHf(
    ISpoke spoke,
    address user,
    uint256 desiredHf
  ) internal returns (uint256 requiredDebtValue) {
    ISpoke.UserAccountData memory userAccountData = _getUserAccountData({
      spoke: spoke,
      user: user,
      refreshConfig: true
    });
    uint256 totalAdjustedCollateralValue = userAccountData.totalCollateralValue.wadMulDown(
      userAccountData.avgCollateralFactor
    );
    uint256 targetTotalDebtValue = totalAdjustedCollateralValue.wadDivUp(desiredHf);
    assertLe(
      userAccountData.totalDebtValueRay / WadRayMath.RAY,
      targetTotalDebtValue,
      'User has enough debt'
    );
    return targetTotalDebtValue - userAccountData.totalDebtValueRay / WadRayMath.RAY;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                 RISK PREMIUM CALCULATION                                  //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  struct CalculateRiskPremiumLocal {
    uint256 reserveCount;
    uint256 totalDebtValue;
    uint256 healthFactor;
    uint256 activeCollateralCount;
    uint32 dynamicConfigKey;
    uint256 collateralFactor;
    uint256 collateralValue;
    ISpoke.UserPosition pos;
    uint256 riskPremium;
    uint256 utilizedSupply;
    uint256 idx;
  }

  function _calculateExpectedUserRP(ISpoke spoke, address user) internal view returns (uint256) {
    return _calculateExpectedUserRP({spoke: spoke, user: user, refreshDynamicConfig: false});
  }

  function _calculateExpectedUserRP(
    ISpoke spoke,
    address user,
    bool refreshDynamicConfig
  ) internal view returns (uint256) {
    CalculateRiskPremiumLocal memory vars;
    vars.reserveCount = spoke.getReserveCount();

    // Find all reserves user has supplied, adding up total debt
    for (uint256 reserveId; reserveId < vars.reserveCount; ++reserveId) {
      // totalDebtValue is scaled by RAY here, downscaled later
      vars.totalDebtValue += _convertAmountToValue(
        spoke,
        reserveId,
        spoke.getUserPosition(reserveId, user).drawnShares * _reserveDrawnIndex(spoke, reserveId) +
          _calculatePremiumDebtRay(spoke, reserveId, user)
      );

      if (_isUsingAsCollateral(spoke, reserveId, user)) {
        vars.dynamicConfigKey = refreshDynamicConfig
          ? spoke.getReserve(reserveId).dynamicConfigKey
          : spoke.getUserPosition(reserveId, user).dynamicConfigKey;
        vars.collateralFactor = spoke
          .getDynamicReserveConfig(reserveId, vars.dynamicConfigKey)
          .collateralFactor;

        vars.collateralValue = _convertAmountToValue(
          spoke,
          reserveId,
          spoke.getUserSuppliedAssets(reserveId, user)
        );
        vars.healthFactor += (vars.collateralValue * vars.collateralFactor);
        ++vars.activeCollateralCount;
      }
    }

    if (vars.totalDebtValue == 0) {
      return 0;
    }

    vars.totalDebtValue = vars.totalDebtValue.fromRayUp();

    // Gather up list of reserves as collateral to sort by collateral risk
    KeyValueList.List memory reserveCollateralRisk = KeyValueList.init(vars.activeCollateralCount);
    for (uint256 reserveId; reserveId < vars.reserveCount; ++reserveId) {
      if (_isUsingAsCollateral(spoke, reserveId, user)) {
        reserveCollateralRisk.add(vars.idx, _getCollateralRisk(spoke, reserveId), reserveId);
        ++vars.idx;
      }
    }

    // Sort supplied reserves by collateral risk
    reserveCollateralRisk.sortByKey();
    vars.idx = 0;

    // While user's normalized debt amount is non-zero, iterate through supplied reserves, and add up collateral risk
    while (vars.totalDebtValue > 0 && vars.idx < reserveCollateralRisk.length()) {
      (uint256 collateralRisk, uint256 reserveId) = reserveCollateralRisk.get(vars.idx);
      vars.collateralValue = _convertAmountToValue(
        spoke,
        reserveId,
        spoke.getUserSuppliedAssets(reserveId, user)
      );

      if (vars.collateralValue >= vars.totalDebtValue) {
        vars.riskPremium += vars.totalDebtValue * collateralRisk;
        vars.utilizedSupply += vars.totalDebtValue;
        vars.totalDebtValue = 0;
        break;
      } else {
        vars.riskPremium += vars.collateralValue * collateralRisk;
        vars.utilizedSupply += vars.collateralValue;
        vars.totalDebtValue -= vars.collateralValue;
      }

      ++vars.idx;
    }

    return _divUp(vars.riskPremium, vars.utilizedSupply);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                    BOUNDS & UTILITIES                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _spokeMaxDrawnRate(ISpoke spoke) internal view returns (uint32) {
    uint32 maxDrawnRate;
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      uint32 drawnRate = (
        _hub(spoke, reserveId).getAssetDrawnRate(_reserveAssetId(spoke, reserveId)).mulDivUp(
          PercentageMath.PERCENTAGE_FACTOR,
          WadRayMath.RAY
        )
      ).toUint32();
      if (drawnRate > maxDrawnRate) {
        maxDrawnRate = drawnRate;
      }
    }
    return maxDrawnRate;
  }

  function _maxLiquidationBonusUpperBound(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint32) {
    return
      _maxLiquidationBonusUpperBound(
        _getLatestDynamicReserveConfig(spoke, reserveId).collateralFactor
      ).toUint32();
  }

  function _maxLiquidationBonusUpperBound(
    uint256 collateralFactor
  ) internal pure returns (uint256) {
    return
      collateralFactor == 0
        ? MIN_LIQUIDATION_BONUS
        : (PercentageMath.PERCENTAGE_FACTOR - 1).percentDivDown(collateralFactor).toUint32();
  }

  function _collateralFactorUpperBound(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint16) {
    return
      _collateralFactorUpperBound(
        _getLatestDynamicReserveConfig(spoke, reserveId).maxLiquidationBonus
      );
  }

  function _collateralFactorUpperBound(uint256 maxLiquidationBonus) internal pure returns (uint16) {
    return (PercentageMath.PERCENTAGE_FACTOR - 1).percentDivDown(maxLiquidationBonus).toUint16();
  }
}
