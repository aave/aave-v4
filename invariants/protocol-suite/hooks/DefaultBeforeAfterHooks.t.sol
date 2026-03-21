// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Libraries
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';

// Utils
import {Constants} from 'tests/Constants.sol';

// Interfaces
import {ISpokeHandler} from '../handlers/interfaces/ISpokeHandler.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

// Contracts
import {BaseHooks} from '../base/BaseHooks.t.sol';

/// @title DefaultBeforeAfterHooks
/// @notice Helper contract for before and after hooks, state variable caching and postconditions
/// @dev This contract is inherited by handlers
abstract contract DefaultBeforeAfterHooks is BaseHooks {
  using WadRayMath for *;
  using EnumerableSet for EnumerableSet.AddressSet;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         STRUCTS                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  struct Debt {
    uint256 drawn;
    uint256 premiumRay;
    uint256 owed;
  }

  struct AssetVars {
    IHub.Asset asset;
    uint256 drawnRate;
    uint256 drawnIndex;
    uint256 totalAssets;
    uint256 totalShares;
    Debt debt;
  }

  struct UserVars {
    ISpoke.UserPosition position;
    Debt debt;
    bool collateral;
    bool borrowing;
  }

  struct UserAccountDataVars {
    ISpoke.UserAccountData data;
  }

  struct SpokeVars {
    IHub.SpokeData spokeData;
    uint256 addedAssets;
    uint256 addedShares;
    Debt debt;
  }

  struct DefaultVars {
    mapping(address hub => mapping(uint256 assetId => AssetVars)) assetVars;
    mapping(address hub => mapping(uint256 assetId => mapping(address spoke => SpokeVars))) spokeVars;
    mapping(address spoke => mapping(uint256 reserveId => mapping(address user => UserVars))) userVars;
    mapping(address spoke => mapping(address user => UserAccountDataVars)) userAccountDataVars;
  }

  struct UserInfo {
    address spoke;
    uint256 reserveId;
    address user;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       HOOKS STORAGE                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  // Default variables before and after
  DefaultVars defaultVarsBefore;
  DefaultVars defaultVarsAfter;

  // Temp array of users to check postconditions for, reset after each handler on _resetState
  UserInfo[] usersToCheck;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           SETUP                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Default hooks setup
  function _setUpDefaultHooks() internal {}

  /// @notice Helper to initialize storage arrays of default vars
  function _setUpDefaultVars(DefaultVars storage _defaultVars) internal {}

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HOOKS                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _defaultHooksBefore() internal {
    // Asset values
    _setAssetValues(defaultVarsBefore);
    // Spoke asset values
    _setSpokeAssetValues(defaultVarsBefore);
    // User values
    _setUserValues(defaultVarsBefore);
  }

  function _defaultHooksAfter() internal {
    // Asset values
    _setAssetValues(defaultVarsAfter);
    // Spoke asset values
    _setSpokeAssetValues(defaultVarsAfter);
    // User values
    _setUserValues(defaultVarsAfter);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       HELPERS                                             //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev Only use these helpers in postConditions, do NOT rely on them at Invariants because they not be populated
  /// when the fuzzer has updated env (eg block.timestamp) which does not invoke any Handler

  function _setAssetValues(DefaultVars storage defaultVars) internal {
    for (uint256 i; i < hubs.length(); i++) {
      IHub hub = IHub(hubs.at(i));
      uint256 assetCount = hub.getAssetCount();
      for (uint256 j; j < assetCount; j++) {
        (uint256 drawn, ) = hub.getAssetOwed(j);
        uint256 premiumRay = hub.getAssetPremiumRay(j);
        defaultVars.assetVars[address(hub)][j] = AssetVars({
          asset: hub.getAsset(j),
          drawnRate: hub.getAssetDrawnRate(j),
          drawnIndex: hub.getAssetDrawnIndex(j),
          totalAssets: hub.getAddedAssets(j),
          totalShares: hub.getAddedShares(j),
          debt: Debt({drawn: drawn, premiumRay: premiumRay, owed: drawn + premiumRay.fromRayUp()})
        });
      }
    }
  }

  function _setSpokeAssetValues(DefaultVars storage defaultVars) internal {
    for (uint256 i; i < hubs.length(); i++) {
      IHub hub = IHub(hubs.at(i));
      uint256 assetCount = hub.getAssetCount();
      for (uint256 j; j < assetCount; j++) {
        for (uint256 k; k < allSpokes.length; k++) {
          address spoke = allSpokes[k];
          (uint256 drawn, ) = hub.getSpokeOwed(j, spoke);
          uint256 premiumRay = hub.getSpokePremiumRay(j, spoke);
          defaultVars.spokeVars[address(hub)][j][spoke] = SpokeVars({
            spokeData: hub.getSpoke(j, spoke),
            addedAssets: hub.getSpokeAddedAssets(j, spoke),
            addedShares: hub.getSpokeAddedShares(j, spoke),
            debt: Debt({drawn: drawn, premiumRay: premiumRay, owed: drawn + premiumRay.fromRayUp()})
          });
        }
      }
    }
  }

  function _setUserValues(DefaultVars storage defaultVars) internal {
    for (uint256 i; i < usersToCheck.length; ++i) {
      UserInfo memory userInfo = usersToCheck[i];
      ISpoke spoke = ISpoke(userInfo.spoke);
      address user = userInfo.spoke;
      defaultVars.userAccountDataVars[userInfo.spoke][userInfo.user].data = spoke
        .getUserAccountData(userInfo.user);

      // Cache values for all reserves of the spoke, used after actions: updateUserRiskPremium, updateUserDynamicConfig
      if (userInfo.reserveId == CHECK_ALL_RESERVES) {
        uint256 reserveCount = spoke.getReserveCount();
        for (uint256 j; j < reserveCount; ++j) {
          _setUserVars(defaultVars, spoke, j, user);
        }
      } else {
        // Cache values for a specific reserve of the spoke, used after actions: supply, withdraw, borrow, repay, setUsingAsCollateral
        _setUserVars(defaultVars, spoke, userInfo.reserveId, user);
      }
    }
  }

  function _setUserVars(
    DefaultVars storage defaultVars,
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal {
    (uint256 drawn, ) = spoke.getUserDebt(reserveId, user);
    uint256 premiumRay = spoke.getUserPremiumDebtRay(reserveId, user);
    (bool collateral, bool borrowing) = spoke.getUserReserveStatus(reserveId, user);
    defaultVars.userVars[address(spoke)][reserveId][user] = UserVars({
      position: spoke.getUserPosition(reserveId, user),
      debt: Debt({drawn: drawn, premiumRay: premiumRay, owed: drawn + premiumRay.fromRayUp()}),
      collateral: collateral,
      borrowing: borrowing
    });
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   POST CONDITIONS: HUB                                    //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function assert_GPOST_HUB_A(address hubAddress, uint256 assetId) internal {
    AssetVars memory varsBefore = _assetVarsBefore(hubAddress, assetId);
    AssetVars memory varsAfter = _assetVarsAfter(hubAddress, assetId);
    assertGe(varsAfter.drawnIndex, varsBefore.drawnIndex, GPOST_HUB_A);
  }

  function assert_GPOST_HUB_B(address hubAddress, uint256 assetId) internal {
    AssetVars memory varsBefore = _assetVarsBefore(hubAddress, assetId);
    AssetVars memory varsAfter = _assetVarsAfter(hubAddress, assetId);

    assertFullMulGe(
      varsAfter.totalAssets + SharesMath.VIRTUAL_ASSETS,
      varsBefore.totalShares + SharesMath.VIRTUAL_SHARES,
      varsBefore.totalAssets + SharesMath.VIRTUAL_ASSETS,
      varsAfter.totalShares + SharesMath.VIRTUAL_SHARES,
      GPOST_HUB_B
    );
  }

  function assert_GPOST_HUB_C(address hubAddress, uint256 assetId) internal {
    // Read the cached signature of the current action
    bytes4 signature = currentActionSignature;
    if (
      signature == ISpokeHandler.supply.selector ||
      signature == ISpokeHandler.withdraw.selector ||
      signature == ISpokeHandler.borrow.selector ||
      signature == ISpokeHandler.repay.selector ||
      signature == ISpokeHandler.updateUserRiskPremium.selector ||
      signature == ISpokeHandler.liquidationCall.selector
    ) {
      AssetVars memory vars = _assetVarsAfter(hubAddress, assetId);
      assertEq(
        vars.drawnRate,
        IAssetInterestRateStrategy(hubInfo[hubAddress].irStrategy).calculateInterestRate(
          assetId,
          vars.asset.liquidity,
          vars.debt.drawn,
          vars.asset.deficitRay.fromRayUp(),
          vars.asset.swept
        ),
        GPOST_HUB_C
      );
    }
  }

  function assert_GPOST_HUB_D(address hubAddress, uint256 assetId) internal {
    assertLe(
      _assetVarsAfter(hubAddress, assetId).asset.lastUpdateTimestamp,
      block.timestamp,
      GPOST_HUB_D
    );
  }

  function assert_GPOST_HUB_EF(address hubAddress, uint256 assetId, address spoke) internal {
    // Get the spoke config
    IHub.SpokeConfig memory spokeConfig = IHub(hubAddress).getSpokeConfig(assetId, spoke);
    (, uint8 decimals) = IHub(hubAddress).getAssetUnderlyingAndDecimals(assetId);

    SpokeVars memory spokeDataBefore = _spokeVarsBefore(hubAddress, assetId, spoke);
    SpokeVars memory spokeDataAfter = _spokeVarsAfter(hubAddress, assetId, spoke);

    // GPOST_HUB_E: spoke-level addedAssets must be within addCap after an add action
    if (
      spokeDataAfter.addedAssets > spokeDataBefore.addedAssets &&
      spokeDataAfter.addedShares != spokeDataBefore.addedShares /// @dev required to avoid interest accrual detection
    ) {
      if (spokeConfig.addCap != MAX_ALLOWED_SPOKE_CAP) {
        assertLe(
          spokeDataAfter.addedAssets,
          spokeConfig.addCap * MathUtils.uncheckedExp(10, decimals),
          GPOST_HUB_E
        );
      }
    }

    // GPOST_HUB_F: spoke-level owed must be within drawCap after a draw action
    if (spokeDataAfter.debt.owed > spokeDataBefore.debt.owed) {
      if (spokeConfig.drawCap != MAX_ALLOWED_SPOKE_CAP) {
        assertLe(
          spokeDataAfter.debt.owed + spokeDataAfter.spokeData.deficitRay.fromRayUp(),
          spokeConfig.drawCap * MathUtils.uncheckedExp(10, decimals),
          GPOST_HUB_F
        );
      }
    }
  }

  function assert_GPOST_HUB_G(address hubAddress, uint256 assetId) internal {
    assertGe(
      _assetVarsAfter(hubAddress, assetId).asset.lastUpdateTimestamp,
      _assetVarsBefore(hubAddress, assetId).asset.lastUpdateTimestamp,
      GPOST_HUB_G
    );
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   POST CONDITIONS: SPOKE                                  //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function assert_GPOST_SP_A(address spoke, uint256 reserveId, address user) internal {
    ISpoke.UserPosition memory userPosition = ISpoke(spoke).getUserPosition(reserveId, user);
    uint256 userRiskPremium = ISpoke(spoke).getUserAccountData(user).riskPremium;

    uint256 expected = PercentageMath.percentMulUp(userPosition.drawnShares, userRiskPremium);
    assertEq(userPosition.premiumShares, expected, GPOST_SP_A);
  }

  function assert_GPOST_SP_B(address spoke, uint256 reserveId, address user) internal {
    UserVars memory userVarsBefore = _userVarsBefore(spoke, reserveId, user);
    UserVars memory userVarsAfter = _userVarsAfter(spoke, reserveId, user);

    if (userVarsAfter.debt.premiumRay < userVarsBefore.debt.premiumRay) {
      assertTrue(
        currentActionSignature == ISpokeHandler.repay.selector ||
          currentActionSignature == ISpokeHandler.liquidationCall.selector,
        GPOST_SP_B
      );
    }

    if (userVarsAfter.debt.drawn < userVarsBefore.debt.drawn) {
      assertTrue(
        currentActionSignature == ISpokeHandler.repay.selector ||
          currentActionSignature == ISpokeHandler.liquidationCall.selector,
        GPOST_SP_B2
      );
      assertEq(userVarsAfter.debt.premiumRay, 0, GPOST_SP_B2);
    }
  }

  function assert_GPOST_SP_E(address spoke, uint256 reserveId, address user) internal {
    uint32 latestKey = ISpoke(spoke).getReserve(reserveId).dynamicConfigKey;
    uint32 userKey = ISpoke(spoke).getUserPosition(reserveId, user).dynamicConfigKey;
    bytes4 signature = currentActionSignature;

    if (
      signature == ISpokeHandler.borrow.selector ||
      signature == ISpokeHandler.withdraw.selector ||
      signature == ISpokeHandler.setUsingAsCollateral.selector ||
      signature == ISpokeHandler.updateUserDynamicConfig.selector
    ) {
      if (_userVarsBefore(spoke, reserveId, user).collateral) {
        assertEq(latestKey, userKey, GPOST_SP_E);
      }
    }
  }

  function assert_GPOST_LIQ_G(address spoke, address user) internal {
    UserAccountDataVars memory dataBefore = _userAccountDataVarsBefore(spoke, user);
    UserAccountDataVars memory dataAfter = _userAccountDataVarsAfter(spoke, user);

    bytes4 signature = currentActionSignature;

    if (
      dataBefore.data.healthFactor < Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD &&
      dataAfter.data.healthFactor < dataBefore.data.healthFactor
    ) {
      assertTrue(signature == ISpokeHandler.liquidationCall.selector, GPOST_SP_LIQ_G);
    }
  }

  function assert_GPOST_SP_LIQ_H(address spoke, address user) internal {
    if (
      _userAccountDataVarsAfter(spoke, user).data.healthFactor <
      Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    ) {
      assertTrue(
        currentActionSignature == ISpokeHandler.supply.selector ||
          currentActionSignature == ISpokeHandler.repay.selector ||
          currentActionSignature == ISpokeHandler.liquidationCall.selector ||
          currentActionSignature == ISpokeHandler.updateUserRiskPremium.selector,
        GPOST_SP_LIQ_H
      );
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          HELPERS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _registerUserToCheck(address spoke, uint256 reserveId, address user) internal {
    usersToCheck.push(UserInfo(spoke, reserveId, user));
  }

  function _cacheCurrentActionSignature() internal {
    currentActionSignature = bytes4(msg.sig);
  }

  function _assetVarsBefore(
    address hubAddress,
    uint256 assetId
  ) internal view returns (AssetVars memory) {
    return defaultVarsBefore.assetVars[hubAddress][assetId];
  }

  function _assetVarsAfter(
    address hubAddress,
    uint256 assetId
  ) internal view returns (AssetVars memory) {
    return defaultVarsAfter.assetVars[hubAddress][assetId];
  }

  function _spokeVarsBefore(
    address hubAddress,
    uint256 assetId,
    address spoke
  ) internal view returns (SpokeVars memory) {
    return defaultVarsBefore.spokeVars[hubAddress][assetId][spoke];
  }

  function _spokeVarsAfter(
    address hubAddress,
    uint256 assetId,
    address spoke
  ) internal view returns (SpokeVars memory) {
    return defaultVarsAfter.spokeVars[hubAddress][assetId][spoke];
  }

  function _userVarsBefore(
    address spoke,
    uint256 reserveId,
    address user
  ) internal view returns (UserVars memory) {
    return defaultVarsBefore.userVars[spoke][reserveId][user];
  }

  function _userVarsAfter(
    address spoke,
    uint256 reserveId,
    address user
  ) internal view returns (UserVars memory) {
    return defaultVarsAfter.userVars[spoke][reserveId][user];
  }

  function _userAccountDataVarsBefore(
    address spoke,
    address user
  ) internal view returns (UserAccountDataVars memory) {
    return defaultVarsBefore.userAccountDataVars[spoke][user];
  }

  function _userAccountDataVarsAfter(
    address spoke,
    address user
  ) internal view returns (UserAccountDataVars memory) {
    return defaultVarsAfter.userAccountDataVars[spoke][user];
  }
}
