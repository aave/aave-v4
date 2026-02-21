// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {HubQueryHelpers} from 'tests/helpers/hub/HubQueryHelpers.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ITransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {ISpoke, ISpokeBase} from 'src/spoke/interfaces/ISpoke.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IBasicInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {SpokeConstants} from 'tests/helpers/spoke/SpokeConstants.sol';
import {KeyValueList} from 'src/spoke/libraries/KeyValueList.sol';
import {MockSpoke} from 'tests/helpers/mocks/MockSpoke.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';

/// @title SpokeQueryHelpers
/// @notice Spoke-level state-reading helpers and higher-level calculations.
///         Extends HubQueryHelpers so spoke tests have access to hub helpers.
abstract contract SpokeQueryHelpers is HubQueryHelpers {
  using WadRayMath for *;
  using MathUtils for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;
  using KeyValueList for KeyValueList.List;

  uint256 internal constant MAX_SUPPLY_ASSET_UNITS = MAX_SUPPLY_AMOUNT / 1e18;

  struct ReserveInfo {
    uint256 reserveId;
    ISpoke.ReserveConfig reserveConfig;
    ISpoke.DynamicReserveConfig dynReserveConfig;
  }

  struct DebtData {
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 premiumDebtRay;
    uint256 totalDebt;
  }

  struct SpokePosition {
    uint256 reserveId;
    uint256 assetId;
    uint256 addedShares;
    uint256 addedAmount;
    uint256 drawnShares;
    uint256 drawn;
    uint256 premiumShares;
    int256 premiumOffsetRay;
    uint256 premium;
  }

  struct DynamicConfigEntry {
    uint32 key;
    bool enabled;
  }

  struct UserActionData {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 repayAmount;
    uint256 userBalanceBefore;
    uint256 userBalanceAfter;
    ISpoke.UserPosition userPosBefore;
    uint256 premiumDebtRayBefore;
  }

  struct ReserveSetupParams {
    uint256 reserveId;
    uint256 supplyAmount;
    uint256 borrowAmount;
    address supplier;
    address borrower;
  }

  struct TokenBalances {
    uint256 spokeBalance;
    uint256 hubBalance;
  }

  struct SharesAndAmount {
    uint256 amount;
    uint256 shares;
  }

  struct SupplyBorrowLocal {
    uint256 collateralReserveAssetId;
    uint256 borrowReserveAssetId;
    uint256 collateralSupplyShares;
    uint256 borrowSupplyShares;
    uint256 reserveSharesBefore;
    uint256 userSharesBefore;
    uint256 borrowerDrawnDebtBefore;
    uint256 reserveDrawnDebtBefore;
    uint256 borrowerDrawnDebtAfter;
    uint256 reserveDrawnDebtAfter;
  }

  struct UserSnapshot {
    uint256 tokenBalance;
    uint256 suppliedShares;
    uint256 suppliedAmount;
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 totalDebt;
    ISpoke.UserPosition position;
  }

  struct ReserveSnapshot {
    uint256 totalSuppliedShares;
    uint256 totalSuppliedAmount;
    uint256 totalDrawnDebt;
    uint256 totalPremiumDebt;
    uint256 totalDebt;
  }

  // --- Spoke-specific utility functions ---

  function _underlying(ISpoke spoke, uint256 reserveId) internal view returns (TestnetERC20) {
    return TestnetERC20(spoke.getReserve(reserveId).underlying);
  }

  function _hub(ISpoke spoke, uint256 reserveId) internal view returns (IHub) {
    return IHub(address(spoke.getReserve(reserveId).hub));
  }

  function _reserveAssetId(ISpoke spoke, uint256 reserveId) internal view returns (uint256) {
    return spoke.getReserve(reserveId).assetId;
  }

  // --- Spoke-specific math helpers ---

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

  function _calculateExactRestoreAmount(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 repayAmount
  ) internal view returns (uint256 baseRestored, uint256 premiumRestored) {
    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(reserveId, user);
    IHub hub = _hub(spoke, reserveId);
    uint256 assetId = _reserveAssetId(spoke, reserveId);
    return _calculateExactRestoreAmount(userDrawnDebt, userPremiumDebt, repayAmount, hub, assetId);
  }

  function _calculateExactRestoreAmount(
    uint256 drawn,
    uint256 premium,
    uint256 restoreAmount,
    IHub hub,
    uint256 assetId
  ) internal view returns (uint256, uint256) {
    if (restoreAmount <= premium) {
      return (0, restoreAmount);
    }
    uint256 drawnRestored = _min(drawn, restoreAmount - premium);
    drawnRestored = hub.previewRestoreByShares(
      assetId,
      hub.previewRestoreByAssets(assetId, drawnRestored)
    );
    return (drawnRestored, premium);
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

  // --- Spoke query helpers ---

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
      new MockSpoke(spoke.ORACLE(), SpokeConstants.MAX_ALLOWED_USER_RESERVES_LIMIT)
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

  function _getLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 healthFactor
  ) internal view returns (uint256) {
    return spoke.getLiquidationBonus(reserveId, user, healthFactor);
  }

  function _hasRole(
    IAccessManager authority,
    uint64 role,
    address account
  ) internal view returns (bool) {
    (bool hasRole, ) = authority.hasRole(role, account);
    return hasRole;
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

  function _getFeeReceiver(ISpoke spoke, uint256 reserveId) internal view returns (address) {
    return _getFeeReceiver(_hub(spoke, reserveId), spoke.getReserve(reserveId).assetId);
  }

  // --- Higher-level calculations (need spoke + hub, derived from spoke) ---

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
    assertLt(
      userAccountData.totalDebtValueRay / WadRayMath.RAY,
      targetTotalDebtValue,
      'User has enough debt'
    );
    return targetTotalDebtValue - userAccountData.totalDebtValueRay / WadRayMath.RAY;
  }

  // --- Spoke position builders (derive hub from spoke) ---

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
    IHub hub = _hub(spoke, reserveId);
    IHub.SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke));
    (uint256 drawn, uint256 premium) = hub.getSpokeOwed(assetId, address(spoke));
    return
      SpokePosition({
        reserveId: reserveId,
        assetId: assetId,
        addedShares: spokeData.addedShares,
        addedAmount: hub.getSpokeAddedAssets(assetId, address(spoke)),
        drawnShares: spokeData.drawnShares,
        drawn: drawn,
        premiumShares: spokeData.premiumShares,
        premiumOffsetRay: spokeData.premiumOffsetRay,
        premium: premium
      });
  }

  // --- Functions moved from SpokeBase ---

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

  function _getUserDrawnShares(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    return spoke.getUserPosition(reserveId, user).drawnShares;
  }

  function _getUserDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (DebtData memory) {
    DebtData memory userDebt;
    userDebt.totalDebt = spoke.getUserTotalDebt(reserveId, user);
    (userDebt.drawnDebt, userDebt.premiumDebt) = spoke.getUserDebt(reserveId, user);
    assertEq(userDebt.totalDebt, userDebt.drawnDebt + userDebt.premiumDebt);
    return userDebt;
  }

  // assert that user position matches expected
  function _assertUserPosition(
    ISpoke.UserPosition memory userPos,
    ISpoke.UserPosition memory expectedUserPos,
    string memory label
  ) internal pure {
    assertEq(
      userPos.suppliedShares,
      expectedUserPos.suppliedShares,
      string.concat('user supplied shares ', label)
    );
    assertEq(
      userPos.drawnShares,
      expectedUserPos.drawnShares,
      string.concat('user drawnShares ', label)
    );
    assertEq(
      userPos.premiumShares,
      expectedUserPos.premiumShares,
      string.concat('user premiumShares ', label)
    );
    assertApproxEqAbs(
      userPos.premiumOffsetRay,
      expectedUserPos.premiumOffsetRay,
      1,
      string.concat('user premiumOffsetRay ', label)
    );
  }

  function _assertUserDebt(
    DebtData memory userDebt,
    DebtData memory expectedUserDebt,
    string memory label
  ) internal pure {
    assertEq(
      userDebt.drawnDebt,
      expectedUserDebt.drawnDebt,
      string.concat('user drawn debt ', label)
    );
    assertApproxEqAbs(
      userDebt.premiumDebt,
      expectedUserDebt.premiumDebt,
      1,
      string.concat('user premium debt ', label)
    );
    assertApproxEqAbs(
      userDebt.totalDebt,
      expectedUserDebt.totalDebt,
      1,
      string.concat('user total debt ', label)
    );
  }

  function _assertUserRpUnchanged(ISpoke spoke, address user) internal view {
    uint256 riskPremiumPreview = spoke.getUserAccountData(user).riskPremium;
    uint256 riskPremiumStored = _getUserRpStored(spoke, user);
    assertEq(riskPremiumStored, riskPremiumPreview, 'user risk premium mismatch vs preview');
  }

  /// after a repay action, the stored user risk premium should not match the on-the-fly calculation, due to lack of notify
  /// instead RP should remain same as prior value
  function _assertUserRpUnchangedAfterRepay(
    ISpoke spoke,
    address user,
    uint256 expectedRP
  ) internal view {
    uint256 riskPremiumPreview = spoke.getUserAccountData(user).riskPremium;
    uint256 riskPremiumStored = _getUserRpStored(spoke, user);
    assertEq(riskPremiumStored, expectedRP, 'user risk premium mismatch vs expected');
    assertNotEq(
      riskPremiumStored,
      riskPremiumPreview,
      'user risk premium expected mismatch without notify'
    );
  }

  /// @dev get stored user risk premium from storage
  function _getUserRpStored(ISpoke spoke, address user) internal view returns (uint256) {
    return spoke.getUserLastRiskPremium(user);
  }

  function _isHealthy(ISpoke spoke, address user) internal view returns (bool) {
    return _isHealthy(spoke.getUserAccountData(user).healthFactor);
  }

  function _isHealthy(uint256 healthFactor) internal pure returns (bool) {
    return healthFactor >= SpokeConstants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
  }

  function _calculateExpectedUserRP(ISpoke spoke, address user) internal view returns (uint256) {
    return _calculateExpectedUserRP(spoke, user, false);
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

  function _getSpokeDynConfigKeys(
    ISpoke spoke
  ) internal view returns (DynamicConfigEntry[] memory) {
    uint256 reserveCount = spoke.getReserveCount();
    DynamicConfigEntry[] memory configs = new DynamicConfigEntry[](reserveCount);
    for (uint256 reserveId; reserveId < reserveCount; ++reserveId) {
      configs[reserveId] = DynamicConfigEntry(spoke.getReserve(reserveId).dynamicConfigKey, true);
    }
    return configs;
  }

  // returns reserveId => User(DynamicConfigKey, usingAsCollateral) map.
  function _getUserDynConfigKeys(
    ISpoke spoke,
    address user
  ) internal view returns (DynamicConfigEntry[] memory) {
    uint256 reserveCount = spoke.getReserveCount();
    DynamicConfigEntry[] memory configs = new DynamicConfigEntry[](reserveCount);
    for (uint256 reserveId; reserveId < reserveCount; ++reserveId) {
      configs[reserveId] = _getUserDynConfigKeys(spoke, user, reserveId);
    }
    return configs;
  }

  function _getUserDynConfig(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (ISpoke.DynamicReserveConfig memory) {
    return
      spoke.getDynamicReserveConfig(
        reserveId,
        spoke.getUserPosition(reserveId, user).dynamicConfigKey
      );
  }

  // deref and return current UserDynamicReserveConfig for a specific reserveId on user position.
  function _getUserDynConfigKeys(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (DynamicConfigEntry memory) {
    ISpoke.UserPosition memory pos = spoke.getUserPosition(reserveId, user);
    return DynamicConfigEntry(pos.dynamicConfigKey, _isUsingAsCollateral(spoke, reserveId, user));
  }

  function _randomReserveId(ISpoke spoke) internal returns (uint256) {
    return vm.randomUint(0, spoke.getReserveCount() - 1);
  }

  function _randomInvalidReserveId(ISpoke spoke) internal returns (uint256) {
    return vm.randomUint(spoke.getReserveCount(), UINT256_MAX);
  }

  function _randomConfigKey() internal returns (uint16) {
    return vm.randomUint(0, type(uint16).max).toUint16();
  }

  function _randomSpoke(IHub hub, uint256 assetId) internal returns (ISpoke) {
    uint256 spokeCount = hub.getSpokeCount(assetId);
    uint256 spokeIndex = vm.randomUint(0, spokeCount - 1);
    return ISpoke(hub.getSpokeAddress(assetId, spokeIndex));
  }

  function _reserveId(ISpoke spoke, uint256 assetId) internal view returns (uint256) {
    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      if (spoke.getReserve(id).assetId == assetId) {
        return id;
      }
    }
    revert('not found');
  }

  function _nextDynamicConfigKey(ISpoke spoke, uint256 reserveId) internal view returns (uint32) {
    uint32 dynamicConfigKey = spoke.getReserve(reserveId).dynamicConfigKey;
    return (dynamicConfigKey + 1) % type(uint32).max;
  }

  function _randomUninitializedConfigKey(
    ISpoke spoke,
    uint256 reserveId
  ) internal returns (uint32) {
    uint32 dynamicConfigKey = _nextDynamicConfigKey(spoke, reserveId);
    if (spoke.getDynamicReserveConfig(reserveId, dynamicConfigKey).maxLiquidationBonus != 0) {
      revert('no uninitialized config keys');
    }
    return vm.randomUint(dynamicConfigKey, type(uint32).max).toUint32();
  }

  function _randomInitializedConfigKey(ISpoke spoke, uint256 reserveId) internal returns (uint32) {
    uint32 dynamicConfigKey = _nextDynamicConfigKey(spoke, reserveId);
    if (spoke.getDynamicReserveConfig(reserveId, dynamicConfigKey).maxLiquidationBonus != 0) {
      // all config keys are initialized
      return vm.randomUint(0, type(uint32).max).toUint32();
    }
    return vm.randomUint(0, spoke.getReserve(reserveId).dynamicConfigKey).toUint32();
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
        ? SpokeConstants.MIN_LIQUIDATION_BONUS
        : (PercentageMath.PERCENTAGE_FACTOR - 1).percentDivDown(collateralFactor).toUint32();
  }

  function _randomMaxLiquidationBonus(ISpoke spoke, uint256 reserveId) internal returns (uint32) {
    return
      vm
        .randomUint(
          SpokeConstants.MIN_LIQUIDATION_BONUS,
          _maxLiquidationBonusUpperBound(spoke, reserveId)
        )
        .toUint32();
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

  function _randomCollateralFactor(ISpoke spoke, uint256 reserveId) internal returns (uint16) {
    return vm.randomUint(10_00, _collateralFactorUpperBound(spoke, reserveId)).toUint16();
  }

  /// @dev Returns the id of the reserve corresponding to the given Liquidity Hub asset id
  function getReserveIdByAssetId(
    ISpoke spoke,
    IHub hub,
    uint256 assetId
  ) internal view returns (uint256) {
    for (uint256 reserveId; reserveId < spoke.getReserveCount(); ++reserveId) {
      ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
      if (address(hub) == address(reserve.hub) && assetId == reserve.assetId) {
        return reserveId;
      }
    }
    revert('not found');
  }

  // assert that user's position and debt accounting matches expected
  function _assertUserPositionAndDebt(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 debtAmount,
    uint256 suppliedAmount,
    uint256 expectedPremiumDebtRay,
    string memory label
  ) internal view {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub hub = _hub(spoke, reserveId);

    // user position
    ISpoke.UserPosition memory userPos = getUserInfo(spoke, user, reserveId);
    ISpoke.UserPosition memory expectedUserPos = _calcUserPositionBySuppliedAndDebtAmount(
      spoke,
      user,
      expectedPremiumDebtRay,
      assetId,
      debtAmount,
      suppliedAmount,
      hub
    );

    // user debt
    DebtData memory expectedUserDebt = _calcExpectedUserDebt(hub, assetId, expectedUserPos);
    DebtData memory userDebt = _getUserDebt(spoke, reserveId, user);
    assertEq(_isBorrowing(spoke, reserveId, user), userDebt.totalDebt > 0);

    // assertions
    _assertUserPosition(userPos, expectedUserPos, label);
    _assertUserDebt(userDebt, expectedUserDebt, label);
  }

  function _calcExpectedUserDebt(
    IHub hub,
    uint256 assetId,
    ISpoke.UserPosition memory userPos
  ) internal view returns (DebtData memory userDebt) {
    userDebt.premiumDebt = _calculatePremiumDebt(
      hub,
      assetId,
      userPos.premiumShares,
      userPos.premiumOffsetRay
    );
    userDebt.drawnDebt = hub.previewRestoreByShares(assetId, userPos.drawnShares);
    userDebt.totalDebt = userDebt.drawnDebt + userDebt.premiumDebt;
  }

  // calculate expected user position using latest risk premium
  function _calcUserPositionBySuppliedAndDebtAmount(
    ISpoke spoke,
    address user,
    uint256 expectedPremiumDebtRay,
    uint256 assetId,
    uint256 debtAmount,
    uint256 suppliedAmount,
    IHub hub
  ) internal view returns (ISpoke.UserPosition memory userPos) {
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    userPos.drawnShares = hub.previewRestoreByAssets(assetId, debtAmount).toUint120();
    userPos.premiumShares = hub
      .previewRestoreByAssets(assetId, debtAmount)
      .percentMulUp(userAccountData.riskPremium)
      .toUint120();
    userPos.premiumOffsetRay =
      _calculatePremiumAssetsRay(hub, assetId, userPos.premiumShares).toInt256().toInt200() -
      expectedPremiumDebtRay.toInt256().toInt200();
    userPos.suppliedShares = hub.previewAddByAssets(assetId, suppliedAmount).toUint120();
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

  /// assert that sum across User storage debt matches Reserve storage debt
  function _assertUsersAndReserveDebt(
    ISpoke spoke,
    uint256 reserveId,
    address[] memory users,
    string memory label
  ) internal view {
    DebtData memory reserveDebt;
    DebtData memory usersDebt;
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    IHub hub = _hub(spoke, reserveId);

    reserveDebt.totalDebt = spoke.getReserveTotalDebt(reserveId);
    (reserveDebt.drawnDebt, reserveDebt.premiumDebt) = spoke.getReserveDebt(reserveId);

    for (uint256 i = 0; i < users.length; ++i) {
      ISpoke.UserPosition memory userData = getUserInfo(spoke, users[i], reserveId);
      (uint256 drawnDebt, uint256 premiumDebt) = spoke.getUserDebt(reserveId, users[i]);

      usersDebt.drawnDebt += drawnDebt;
      usersDebt.premiumDebt += premiumDebt;
      usersDebt.totalDebt += drawnDebt + premiumDebt;

      assertEq(
        drawnDebt,
        hub.previewRestoreByShares(assetId, userData.drawnShares),
        string.concat('user ', vm.toString(i), ' drawn debt ', label)
      );
      assertEq(
        premiumDebt,
        _calculatePremiumDebt(hub, assetId, userData.premiumShares, userData.premiumOffsetRay),
        string.concat('user ', vm.toString(i), ' premium debt ', label)
      );
    }

    assertEq(
      reserveDebt.drawnDebt,
      usersDebt.drawnDebt,
      string.concat('reserve vs sum users drawn debt ', label)
    );
    assertEq(
      reserveDebt.premiumDebt,
      usersDebt.premiumDebt,
      string.concat('reserve vs sum users premium debt ', label)
    );
    assertEq(
      reserveDebt.totalDebt,
      usersDebt.totalDebt,
      string.concat('reserve vs sum users total debt ', label)
    );
  }

  // --- Snapshot builders ---

  function _snapshotUser(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (UserSnapshot memory snap) {
    address underlying = spoke.getReserve(reserveId).underlying;
    snap.tokenBalance = IERC20(underlying).balanceOf(user);
    snap.suppliedShares = spoke.getUserPosition(reserveId, user).suppliedShares;
    snap.suppliedAmount = spoke.getUserSuppliedAssets(reserveId, user);
    (snap.drawnDebt, snap.premiumDebt) = spoke.getUserDebt(reserveId, user);
    snap.totalDebt = snap.drawnDebt + snap.premiumDebt;
    snap.position = spoke.getUserPosition(reserveId, user);
  }

  function _snapshotReserve(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (ReserveSnapshot memory snap) {
    IHub hub = IHub(address(spoke.getReserve(reserveId).hub));
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    snap.totalSuppliedShares = hub.getSpokeAddedShares(assetId, address(spoke));
    snap.totalSuppliedAmount = spoke.getReserveSuppliedAssets(reserveId);
    (snap.totalDrawnDebt, snap.totalPremiumDebt) = spoke.getReserveDebt(reserveId);
    snap.totalDebt = snap.totalDrawnDebt + snap.totalPremiumDebt;
  }
}
