// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Libraries
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

// Utils
import {Actor} from '../../shared/utils/Actor.sol';
import {PropertiesConstants} from '../../shared/utils/PropertiesConstants.sol';
import {StdAsserts} from '../../shared/utils/StdAsserts.sol';

// Interfaces
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IHubHandler} from '../handlers/interfaces/IHubHandler.sol';

// Contracts
import {BaseHooks} from '../base/BaseHooks.t.sol';

/// @title DefaultBeforeAfterHooks
/// @notice Helper contract for before and after hooks, state variable caching and postconditions
/// @dev This contract is inherited by handlers
abstract contract DefaultBeforeAfterHooks is BaseHooks {
  using WadRayMath for *;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         STRUCTS                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  struct Debt {
    uint256 drawn;
    uint256 premium;
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

  struct SpokeDataVars {
    IHub.SpokeData spokeData;
    uint256 addedAssets;
    uint256 addedShares;
    Debt debt;
  }

  struct DefaultVars {
    mapping(uint256 assetId => AssetVars) assetVars;
    mapping(uint256 assetId => mapping(address spoke => SpokeDataVars)) spokeDataVars;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       HOOKS STORAGE                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  // Default variables before and after
  DefaultVars defaultVarsBefore;
  DefaultVars defaultVarsAfter;

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
    // Spoke data values
    _setSpokeDataValues(defaultVarsBefore);
  }

  function _defaultHooksAfter() internal {
    // Asset values
    _setAssetValues(defaultVarsAfter);
    // Spoke data values
    _setSpokeDataValues(defaultVarsAfter);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                       HELPERS                                             //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _setAssetValues(DefaultVars storage vars) internal {
    uint256 assetCount = hub.getAssetCount();
    for (uint256 i; i < assetCount; ++i) {
      (uint256 drawn, uint256 premium) = hub.getAssetOwed(i);
      vars.assetVars[i] = AssetVars({
        asset: hub.getAsset(i),
        drawnRate: hub.getAssetDrawnRate(i),
        drawnIndex: hub.getAssetDrawnIndex(i),
        totalAssets: hub.getAddedAssets(i),
        totalShares: hub.getAddedShares(i),
        debt: Debt({drawn: drawn, premium: premium, owed: drawn + premium})
      });
    }
  }

  function _setSpokeDataValues(DefaultVars storage vars) internal {
    uint256 assetCount = hub.getAssetCount();
    for (uint256 i; i < assetCount; ++i) {
      for (uint256 j; j < NUMBER_OF_ACTORS; ++j) {
        address spoke = actors[j];
        (uint256 drawn, uint256 premium) = hub.getSpokeOwed(i, spoke);
        vars.spokeDataVars[i][spoke] = SpokeDataVars({
          spokeData: hub.getSpoke(i, spoke),
          addedAssets: hub.getSpokeAddedAssets(i, spoke),
          addedShares: hub.getSpokeAddedShares(i, spoke),
          debt: Debt({drawn: drawn, premium: premium, owed: drawn + premium})
        });
      }
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   POST CONDITIONS: HUB                                    //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function assert_GPOST_HUB_A(uint256 assetId) internal {
    AssetVars memory varsBefore = _assetVarsBefore(assetId);
    AssetVars memory varsAfter = _assetVarsAfter(assetId);
    assertGe(varsAfter.drawnIndex, varsBefore.drawnIndex, GPOST_HUB_A);
  }

  function assert_GPOST_HUB_B(uint256 assetId) internal {
    AssetVars memory varsBefore = _assetVarsBefore(assetId);
    AssetVars memory varsAfter = _assetVarsAfter(assetId);

    assertFullMulGe(
      varsAfter.totalAssets + SharesMath.VIRTUAL_ASSETS,
      varsBefore.totalShares + SharesMath.VIRTUAL_SHARES,
      varsBefore.totalAssets + SharesMath.VIRTUAL_ASSETS,
      varsAfter.totalShares + SharesMath.VIRTUAL_SHARES,
      GPOST_HUB_B
    );
  }

  function assert_GPOST_HUB_C(uint256 assetId) internal {
    // Read the cached signature of the current action
    bytes4 signature = currentActionSignature;
    if (
      signature == IHubHandler.add.selector ||
      signature == IHubHandler.remove.selector ||
      signature == IHubHandler.draw.selector ||
      signature == IHubHandler.restore.selector ||
      signature == IHubHandler.reportDeficit.selector ||
      signature == IHubHandler.sweep.selector ||
      signature == IHubHandler.reclaim.selector ||
      signature == IHubHandler.eliminateDeficit.selector ||
      signature == IHubHandler.refreshPremium.selector ||
      signature == IHubHandler.payFeeShares.selector ||
      signature == IHubHandler.transferShares.selector
    ) {
      AssetVars memory vars = _assetVarsAfter(assetId);
      assertEq(
        vars.drawnRate,
        IAssetInterestRateStrategy(irStrategy).calculateInterestRate(
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

  function assert_GPOST_HUB_D(uint256 assetId) internal {
    assertLe(_assetVarsAfter(assetId).asset.lastUpdateTimestamp, block.timestamp, GPOST_HUB_D);
  }

  function assert_GPOST_HUB_EF(uint256 assetId, address spoke) internal {
    // Get the spoke config
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    (, uint8 decimals) = hub.getAssetUnderlyingAndDecimals(assetId);

    // GPOST_HUB_E
    SpokeDataVars memory spokeDataBefore = _spokeDataVarsBefore(assetId, spoke);
    SpokeDataVars memory spokeDataAfter = _spokeDataVarsAfter(assetId, spoke);

    if (
      spokeDataAfter.addedAssets > spokeDataBefore.addedAssets &&
      spokeDataAfter.addedShares != spokeDataBefore.addedShares &&
      spokeDataBefore.addedShares != 0 /// @dev required to avoid interest accrual detection
    ) {
      if (spokeConfig.addCap != MAX_ALLOWED_SPOKE_CAP) {
        assertLe(
          spokeDataAfter.addedAssets,
          spokeConfig.addCap * MathUtils.uncheckedExp(10, decimals),
          GPOST_HUB_E
        );
      }
    }

    // GPOST_HUB_F
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

  function assert_GPOST_HUB_G(uint256 assetId) internal {
    assertGe(
      _assetVarsAfter(assetId).asset.lastUpdateTimestamp,
      _assetVarsBefore(assetId).asset.lastUpdateTimestamp,
      GPOST_HUB_G
    );
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          HELPERS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////
  /// @dev Only use these helpers in postConditions, do NOT rely on them at Invariants because they not be populated
  /// when the fuzzer has updated env (eg block.timestamp) which does not invoke any Handler

  function _cacheCurrentActionSignature() internal {
    currentActionSignature = bytes4(msg.sig);
  }

  function _assetVarsBefore(uint256 assetId) internal view returns (AssetVars memory) {
    return defaultVarsBefore.assetVars[assetId];
  }

  function _assetVarsAfter(uint256 assetId) internal view returns (AssetVars memory) {
    return defaultVarsAfter.assetVars[assetId];
  }

  function _spokeDataVarsBefore(
    uint256 assetId,
    address spoke
  ) internal view returns (SpokeDataVars memory) {
    return defaultVarsBefore.spokeDataVars[assetId][spoke];
  }

  function _spokeDataVarsAfter(
    uint256 assetId,
    address spoke
  ) internal view returns (SpokeDataVars memory) {
    return defaultVarsAfter.spokeDataVars[assetId][spoke];
  }
}
