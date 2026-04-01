// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {HubHelpers} from 'tests/helpers/hub/HubHelpers.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Constants} from 'tests/helpers/spoke/Constants.sol';
import {Types} from 'tests/helpers/spoke/Types.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';

/// @title QueryHelpers
/// @notice Core spoke-level state-reading helpers, dynamic config queries,
///         and position builders.
///         Extends HubHelpers so spoke tests have access to hub helpers.
abstract contract QueryHelpers is HubHelpers, Constants, Types {
  using SafeCast for *;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      RESERVE QUERIES                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _underlying(ISpoke spoke, uint256 reserveId) internal view returns (TestnetERC20) {
    return TestnetERC20(spoke.getReserve(reserveId).underlying);
  }

  function _hub(ISpoke spoke, uint256 reserveId) internal view returns (IHub) {
    return IHub(address(spoke.getReserve(reserveId).hub));
  }

  function _reserveAssetId(ISpoke spoke, uint256 reserveId) internal view returns (uint256) {
    return spoke.getReserve(reserveId).assetId;
  }

  function _reserveId(ISpoke spoke, uint256 assetId) internal view returns (uint256) {
    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      if (spoke.getReserve(id).assetId == assetId) {
        return id;
      }
    }
    revert('not found');
  }

  /// @dev Returns the id of the reserve corresponding to the given Liquidity Hub asset id
  function _getReserveIdByAssetId(
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

  function _getAssetByReserveId(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (uint256, IERC20) {
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    (address underlying, ) = reserve.hub.getAssetUnderlyingAndDecimals(reserve.assetId);
    return (reserve.assetId, IERC20(underlying));
  }

  function _getAssetUnderlyingByReserveId(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (IERC20) {
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    (address underlying, ) = reserve.hub.getAssetUnderlyingAndDecimals(reserve.assetId);
    return IERC20(underlying);
  }

  function _getLatestDynamicReserveConfig(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (ISpoke.DynamicReserveConfig memory) {
    return spoke.getDynamicReserveConfig(reserveId, spoke.getReserve(reserveId).dynamicConfigKey);
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

  function _getTokenBalances(
    IERC20 token,
    address spoke,
    address hub
  ) internal view returns (TokenBalances memory) {
    return TokenBalances({spokeBalance: token.balanceOf(spoke), hubBalance: token.balanceOf(hub)});
  }

  function _hasRole(
    IAccessManager authority,
    uint64 role,
    address account
  ) internal view returns (bool) {
    (bool hasRole, ) = authority.hasRole(role, account);
    return hasRole;
  }

  function _reserveDrawnIndex(ISpoke spoke, uint256 reserveId) internal view returns (uint256) {
    return _hub(spoke, reserveId).getAssetDrawnIndex(_reserveAssetId(spoke, reserveId));
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

  function _getSpokeDynConfigKeys(
    ISpoke spoke
  ) internal view returns (DynamicConfigEntry[] memory) {
    uint256 reserveCount = spoke.getReserveCount();
    DynamicConfigEntry[] memory configs = new DynamicConfigEntry[](reserveCount);
    for (uint256 reserveId; reserveId < reserveCount; ++reserveId) {
      configs[reserveId] = DynamicConfigEntry({
        key: spoke.getReserve(reserveId).dynamicConfigKey,
        enabled: true
      });
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

  function _nextDynamicConfigKey(ISpoke spoke, uint256 reserveId) internal view returns (uint32) {
    uint32 dynamicConfigKey = spoke.getReserve(reserveId).dynamicConfigKey;
    return (dynamicConfigKey + 1) % type(uint32).max;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       USER QUERIES                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _getUserInfo(
    ISpoke spoke,
    address user,
    uint256 reserveId
  ) internal view returns (ISpoke.UserPosition memory) {
    return spoke.getUserPosition(reserveId, user);
  }

  function _getUserDebt(
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

  function _getTotalWithdrawable(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    return spoke.getUserSuppliedAssets(reserveId, user);
  }

  function _getUserHealthFactor(ISpoke spoke, address user) internal view returns (uint256) {
    return spoke.getUserAccountData(user).healthFactor;
  }

  function _getUserRiskPremium(ISpoke spoke, address user) internal view returns (uint256) {
    return spoke.getUserAccountData(user).riskPremium;
  }

  function _getUserDrawnShares(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    return spoke.getUserPosition(reserveId, user).drawnShares;
  }

  /// @dev get stored user risk premium from storage
  function _getUserRpStored(ISpoke spoke, address user) internal view returns (uint256) {
    return spoke.getUserLastRiskPremium(user);
  }

  function _isHealthy(ISpoke spoke, address user) internal view returns (bool) {
    return _isHealthy(spoke.getUserAccountData(user).healthFactor);
  }

  function _isHealthy(uint256 healthFactor) internal pure returns (bool) {
    return healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     SNAPSHOT BUILDERS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _getSpokePosition(
    ISpoke spoke,
    function(ISpoke) internal view returns (uint256) reserveIdFn
  ) internal view returns (SpokePosition memory) {
    return _getSpokePosition(spoke, reserveIdFn(spoke));
  }

  function _getSpokePosition(
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
