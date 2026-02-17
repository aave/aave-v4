// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {MathHelpers} from 'tests/helpers/MathHelpers.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ITransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {ISpoke, ISpokeBase} from 'src/spoke/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';
import {IBasicInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Constants} from 'tests/Constants.sol';
import {Utils} from 'tests/Utils.sol';
import {MockSpoke} from 'tests/mocks/MockSpoke.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

/// @title QueryHelpers
/// @notice State-reading helpers and higher-level calculations that combine queries with math.
abstract contract QueryHelpers is MathHelpers {
  using WadRayMath for *;
  using MathUtils for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;
  function getUserInfo(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (ISpoke.UserPosition memory) {
    return spoke.getUserPosition(reserveId, user);
  }

  function getUserDebt(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (DebtData memory data) {
    (data.drawnDebt, data.premiumDebt) = spoke.getUserDebt(reserveId, user);
    data.premiumDebtRay = spoke.getUserPremiumDebtRay(reserveId, user);
    data.totalDebt = data.drawnDebt + data.premiumDebt;
  }

  function _isUsingAsCollateral(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (bool) {
    (bool res, ) = spoke.getUserReserveStatus(reserveId, user);
    return res;
  }

  function _isBorrowing(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (bool) {
    (, bool res) = spoke.getUserReserveStatus(reserveId, user);
    return res;
  }

  function getReserveInfo(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (ISpoke.Reserve memory) {
    return spoke.getReserve(reserveId);
  }

  function _getReserveLastDynamicConfigKey(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint32) {
    return spoke.getReserve(reserveId).dynamicConfigKey;
  }

  function _getLatestDynamicReserveConfig(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (ISpoke.DynamicReserveConfig memory) {
    return
      spoke.getDynamicReserveConfig(reserveId, _getReserveLastDynamicConfigKey(spoke, reserveId));
  }

  function getAssetByReserveId(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint256, IERC20) {
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    (address underlying, ) = reserve.hub.getAssetUnderlyingAndDecimals(reserve.assetId);
    return (reserve.assetId, IERC20(underlying));
  }

  function getAssetUnderlyingByReserveId(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (IERC20) {
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    (address underlying, ) = reserve.hub.getAssetUnderlyingAndDecimals(reserve.assetId);
    return IERC20(underlying);
  }

  function getTotalWithdrawable(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    return spoke.getUserSuppliedAssets(reserveId, user);
  }

  function _getUserHealthFactor(ISpoke spoke, address user) internal view returns (uint256) {
    return spoke.getUserAccountData(user).healthFactor;
  }

  function _getUserLastRiskPremium(ISpoke spoke, address user) internal view returns (uint256) {
    return spoke.getUserLastRiskPremium(user);
  }

  function _getUserRiskPremium(ISpoke spoke, address user) internal view returns (uint256) {
    return spoke.getUserAccountData(user).riskPremium;
  }

  function _getUserAccountData(
    ISpoke spoke,
    address user,
    bool refreshConfig
  ) internal returns (ISpoke.UserAccountData memory) {
    uint256 snapshot = vm.snapshotState();

    address mockSpoke = address(
      new MockSpoke(spoke.ORACLE(), Constants.MAX_ALLOWED_USER_RESERVES_LIMIT)
    );

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

  function getTargetHealthFactor(ISpoke spoke) internal view returns (uint256) {
    ISpoke.LiquidationConfig memory liqConfig = spoke.getLiquidationConfig();
    return liqConfig.targetHealthFactor;
  }

  function _getTargetHealthFactor(ISpoke spoke) internal view returns (uint128) {
    return spoke.getLiquidationConfig().targetHealthFactor;
  }

  function _getCollateralRisk(ISpoke spoke, uint256 reserveId) internal view returns (uint24) {
    return spoke.getReserveConfig(reserveId).collateralRisk;
  }

  function _getCollateralFactor(ISpoke spoke, uint256 reserveId) internal view returns (uint16) {
    return _getLatestDynamicReserveConfig(spoke, reserveId).collateralFactor;
  }

  function _getCollateralFactor(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint16) {
    uint32 dynamicConfigKey = spoke.getUserPosition(reserveId, user).dynamicConfigKey;
    return spoke.getDynamicReserveConfig(reserveId, dynamicConfigKey).collateralFactor;
  }

  function _getCollateralFactor(
    ISpoke spoke,
    function(ISpoke) internal view returns (uint256) reserveId
  ) internal view returns (uint16) {
    return _getLatestDynamicReserveConfig(spoke, reserveId(spoke)).collateralFactor;
  }

  function _getLiquidationFee(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint16) {
    uint32 dynamicConfigKey = spoke.getUserPosition(reserveId, user).dynamicConfigKey;
    return spoke.getDynamicReserveConfig(reserveId, dynamicConfigKey).liquidationFee;
  }

  function _hasRole(
    IAccessManager authority,
    uint64 role,
    address account
  ) internal view returns (bool) {
    (bool hasRole, ) = authority.hasRole(role, account);
    return hasRole;
  }

  function getAssetDrawnDebt(uint256 assetId) internal view returns (uint256) {
    (uint256 drawn, ) = hub1.getAssetOwed(assetId);
    return drawn;
  }

  function _getAssetLiquidityFee(uint256 assetId) internal view returns (uint256) {
    return hub1.getAssetConfig(assetId).liquidityFee;
  }

  function _getFeeReceiver(IHub hub, uint256 assetId) internal view returns (address) {
    return hub.getAssetConfig(assetId).feeReceiver;
  }

  function _getFeeReceiver(ISpoke spoke, uint256 reserveId) internal view returns (address) {
    return _getFeeReceiver(_hub(spoke, reserveId), spoke.getReserve(reserveId).assetId);
  }

  function _spokeMaxCollateralRisk(ISpoke spoke) internal view returns (uint24) {
    uint24 maxCollateralRisk;
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      uint24 collateralRisk = _getCollateralRisk(spoke, reserveId);
      if (collateralRisk > maxCollateralRisk) {
        maxCollateralRisk = collateralRisk;
      }
    }
    return maxCollateralRisk;
  }

  function _spokeMaxBorrowRate(ISpoke spoke) internal view returns (uint32) {
    uint32 maxBorrowRate;
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      uint32 borrowRate = (
        _hub(spoke, reserveId).getAssetDrawnRate(_reserveAssetId(spoke, reserveId)).mulDivUp(
          PercentageMath.PERCENTAGE_FACTOR,
          WadRayMath.RAY
        )
      ).toUint32();
      if (borrowRate > maxBorrowRate) {
        maxBorrowRate = borrowRate;
      }
    }
    return maxBorrowRate;
  }

  function _reserveDrawnIndex(ISpoke spoke, uint256 reserveId) internal view returns (uint256) {
    return _hub(spoke, reserveId).getAssetDrawnIndex(_reserveAssetId(spoke, reserveId));
  }

  function _approveAllUnderlying(ISpoke spoke, address owner, address spender) internal {
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      TestnetERC20 underlying_ = _underlying(spoke, reserveId);
      vm.prank(owner);
      underlying_.approve(spender, UINT256_MAX);
    }
  }

  // --- Reserve ID lookups ---

  function _usdxReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdx.reserveId;
  }

  function _usdyReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdy.reserveId;
  }

  function _daiReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].dai.reserveId;
  }

  function _wethReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].weth.reserveId;
  }

  function _wbtcReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].wbtc.reserveId;
  }

  function _usdzReserveId(ISpoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdz.reserveId;
  }

  // --- Snapshot builders ---

  function getAssetPosition(
    IHub hub,
    uint256 assetId
  ) internal view returns (AssetPosition memory) {
    IHub.Asset memory assetData = hub.getAsset(assetId);
    (uint256 drawn, uint256 premium) = hub.getAssetOwed(assetId);
    return
      AssetPosition({
        assetId: assetId,
        liquidity: assetData.liquidity,
        addedShares: assetData.addedShares,
        addedAmount: hub.getAddedAssets(assetId) - _calculateBurntInterest(hub, assetId),
        drawnShares: assetData.drawnShares,
        drawn: drawn,
        premiumShares: assetData.premiumShares,
        premiumOffsetRay: assetData.premiumOffsetRay,
        premium: premium,
        lastUpdateTimestamp: assetData.lastUpdateTimestamp.toUint40(),
        drawnIndex: assetData.drawnIndex,
        drawnRate: assetData.drawnRate
      });
  }

  function getSpokePosition(
    ISpoke spoke,
    function(ISpoke) internal view returns (uint256) reserveIdFn
  ) internal view returns (SpokePosition memory) {
    return getSpokePosition(spoke, reserveIdFn(spoke));
  }

  function getSpokePosition(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (SpokePosition memory) {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub.SpokeData memory spokeData = hub1.getSpoke(assetId, address(spoke));
    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(assetId, address(spoke));
    return
      SpokePosition({
        reserveId: reserveId,
        assetId: assetId,
        addedShares: spokeData.addedShares,
        addedAmount: hub1.getSpokeAddedAssets(assetId, address(spoke)),
        drawnShares: spokeData.drawnShares,
        drawn: drawn,
        premiumShares: spokeData.premiumShares,
        premiumOffsetRay: spokeData.premiumOffsetRay,
        premium: premium
      });
  }

  // --- Higher-level calculations (need query + math) ---

  function _getExpectedPremiumDelta(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 repayAmount
  ) internal view virtual returns (IHubBase.PremiumDelta memory) {
    DebtData memory userDebt = getUserDebt(spoke, user, reserveId);
    (, uint256 premiumRayToRestore) = _calculateRestoreAmounts(
      repayAmount,
      userDebt.drawnDebt,
      userDebt.premiumDebtRay
    );

    ISpoke.UserPosition memory userPosition = spoke.getUserPosition(reserveId, user);
    uint256 assetId = spoke.getReserve(reserveId).assetId;

    return
      _getExpectedPremiumDelta({
        hub: hub1,
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
    DebtData memory userDebt = getUserDebt(spoke, user, reserveId);
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
      uint256 riskPremium = _getUserLastRiskPremium(spoke, user);

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

    uint256 collPrice = oracle.getReservePrice(collReserveId);
    uint256 collAssetUnits = 10 ** hub1.getAsset(collData.assetId).decimals;

    ISpoke.Reserve memory debtData = spoke.getReserve(debtReserveId);
    uint256 debtAssetUnits = 10 ** hub1.getAsset(debtData.assetId).decimals;
    uint256 debtPrice = oracle.getReservePrice(debtReserveId);

    uint256 normalizedDebtAmount = (debtAmount * debtPrice).wadDivDown(debtAssetUnits);
    uint256 normalizedCollPrice = collPrice.wadDivDown(collAssetUnits);

    return
      normalizedDebtAmount.wadDivUp(
        normalizedCollPrice.toWad().percentMulDown(collDynConf.collateralFactor)
      );
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
    ISpoke.UserAccountData memory userAccountData = _getUserAccountData(spoke, user, true);
    uint256 totalAdjustedCollateralValue = userAccountData.totalCollateralValue.wadMulDown(
      userAccountData.avgCollateralFactor
    );
    uint256 targetTotalDebtValue = totalAdjustedCollateralValue.wadDivUp(desiredHf);
    require(
      userAccountData.totalDebtValueRay / WadRayMath.RAY < targetTotalDebtValue,
      'User has enough debt'
    );
    return targetTotalDebtValue - userAccountData.totalDebtValueRay / WadRayMath.RAY;
  }

  function _getLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 healthFactor
  ) internal view returns (uint256) {
    return spoke.getLiquidationBonus(reserveId, user, healthFactor);
  }
}
