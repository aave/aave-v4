// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';
import {TokenizationSpokeDeployer} from 'src/config-engine/libraries/TokenizationSpokeDeployer.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title HubEngine
/// @author Aave Labs
/// @notice Library containing hub configurator logic for AaveV4ConfigEngine.
library HubEngine {
  using SafeCast for uint256;

  /// @dev Thrown when replacing an IR strategy but one or more irData fields still carry a
  /// KEEP_CURRENT sentinel. All fields must be explicitly set when the strategy changes.
  error InvalidIrDataWithNewStrategy();

  /// @notice Lists new assets on Hubs via the HubConfigurator.
  /// @dev When `tokenization.name` & `tokenization.symbol` are defined, also deploys a TokenizationSpoke (impl + proxy) via
  /// CREATE2 and registers it on the Hub for the listed asset.
  /// @param listings The asset listings to execute.
  function executeHubAssetListings(IAaveV4ConfigEngine.AssetListing[] calldata listings) external {
    uint256 length = listings.length;
    for (uint256 i; i < length; ++i) {
      bytes memory irData = abi.encode(listings[i].irData);
      listings[i].hubConfigurator.addAsset(
        listings[i].hub,
        listings[i].underlying,
        listings[i].feeReceiver,
        listings[i].liquidityFee,
        listings[i].irStrategy,
        irData
      );

      _deployAndRegisterTokenizationSpoke(listings[i]);
    }
  }

  /// @notice Updates asset config (fee, interest rate, reinvestment) for assets on Hubs.
  /// @dev Dispatches to the appropriate HubConfigurator methods based on sentinel values:
  /// Fee: both set → updateFeeConfig; only fee → updateLiquidityFee; only receiver → updateFeeReceiver.
  /// IR: strategy set → updateInterestRateStrategy; strategy kept + non-sentinel irData fields →
  /// read-modify-write via updateInterestRateData.
  /// Reinvestment: address set → updateReinvestmentController.
  /// @param updates The asset config updates to execute.
  function executeHubAssetConfigUpdates(
    IAaveV4ConfigEngine.AssetConfigUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      uint256 assetId = IHubBase(updates[i].hub).getAssetId(updates[i].underlying);

      bool updateFee = updates[i].liquidityFee != EngineFlags.KEEP_CURRENT;
      bool updateReceiver = updates[i].feeReceiver != EngineFlags.KEEP_CURRENT_ADDRESS;

      if (updateFee && updateReceiver) {
        updates[i].hubConfigurator.updateFeeConfig(
          updates[i].hub,
          assetId,
          updates[i].liquidityFee,
          updates[i].feeReceiver
        );
      } else if (updateFee) {
        updates[i].hubConfigurator.updateLiquidityFee(
          updates[i].hub,
          assetId,
          updates[i].liquidityFee
        );
      } else if (updateReceiver) {
        updates[i].hubConfigurator.updateFeeReceiver(
          updates[i].hub,
          assetId,
          updates[i].feeReceiver
        );
      }

      _updateInterestRateStrategy(assetId, updates[i]);

      if (updates[i].reinvestmentController != EngineFlags.KEEP_CURRENT_ADDRESS) {
        updates[i].hubConfigurator.updateReinvestmentController(
          updates[i].hub,
          assetId,
          updates[i].reinvestmentController
        );
      }
    }
  }

  /// @notice Registers Spokes for multiple assets on Hubs.
  /// @param additions The Spoke-to-assets additions to execute.
  function executeHubSpokeToAssetsAdditions(
    IAaveV4ConfigEngine.SpokeToAssetsAddition[] calldata additions
  ) external {
    uint256 length = additions.length;
    for (uint256 i; i < length; ++i) {
      uint256 assetsLength = additions[i].assets.length;
      uint256[] memory assetIds = new uint256[](assetsLength);
      IHub.SpokeConfig[] memory configs = new IHub.SpokeConfig[](assetsLength);
      for (uint256 j; j < assetsLength; ++j) {
        assetIds[j] = IHubBase(additions[i].hub).getAssetId(additions[i].assets[j].underlying);
        configs[j] = additions[i].assets[j].config;
      }
      additions[i].hubConfigurator.addSpokeToAssets(
        additions[i].hub,
        additions[i].spoke,
        assetIds,
        configs
      );
    }
  }

  /// @notice Updates Spoke config (caps, risk premium threshold, status) on Hubs.
  /// @dev Dispatches to the appropriate HubConfigurator methods based on sentinel values:
  /// Caps: both set → updateSpokeCaps; only add → updateSpokeAddCap; only draw → updateSpokeDrawCap.
  /// Risk premium threshold: set → updateSpokeRiskPremiumThreshold.
  /// Status: active set → updateSpokeActive; halted set → updateSpokeHalted.
  /// @param updates The Spoke config updates to execute.
  function executeHubSpokeConfigUpdates(
    IAaveV4ConfigEngine.SpokeConfigUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      uint256 assetId = IHubBase(updates[i].hub).getAssetId(updates[i].underlying);

      _updateSpokeCaps(assetId, updates[i]);

      if (updates[i].riskPremiumThreshold != EngineFlags.KEEP_CURRENT) {
        updates[i].hubConfigurator.updateSpokeRiskPremiumThreshold(
          updates[i].hub,
          assetId,
          updates[i].spoke,
          updates[i].riskPremiumThreshold
        );
      }

      if (updates[i].active != EngineFlags.KEEP_CURRENT) {
        updates[i].hubConfigurator.updateSpokeActive(
          updates[i].hub,
          assetId,
          updates[i].spoke,
          EngineFlags.toBool(updates[i].active)
        );
      }
      if (updates[i].halted != EngineFlags.KEEP_CURRENT) {
        updates[i].hubConfigurator.updateSpokeHalted(
          updates[i].hub,
          assetId,
          updates[i].spoke,
          EngineFlags.toBool(updates[i].halted)
        );
      }
    }
  }

  /// @notice Halts assets on Hubs.
  /// @param halts The asset halts to execute.
  function executeHubAssetHalts(IAaveV4ConfigEngine.AssetHalt[] calldata halts) external {
    uint256 length = halts.length;
    for (uint256 i; i < length; ++i) {
      uint256 assetId = IHubBase(halts[i].hub).getAssetId(halts[i].underlying);
      halts[i].hubConfigurator.haltAsset(halts[i].hub, assetId);
    }
  }

  /// @notice Deactivates assets on Hubs.
  /// @param deactivations The asset deactivations to execute.
  function executeHubAssetDeactivations(
    IAaveV4ConfigEngine.AssetDeactivation[] calldata deactivations
  ) external {
    uint256 length = deactivations.length;
    for (uint256 i; i < length; ++i) {
      uint256 assetId = IHubBase(deactivations[i].hub).getAssetId(deactivations[i].underlying);
      deactivations[i].hubConfigurator.deactivateAsset(deactivations[i].hub, assetId);
    }
  }

  /// @notice Resets asset caps on Hubs.
  /// @param resets The asset caps resets to execute.
  function executeHubAssetCapsResets(
    IAaveV4ConfigEngine.AssetCapsReset[] calldata resets
  ) external {
    uint256 length = resets.length;
    for (uint256 i; i < length; ++i) {
      uint256 assetId = IHubBase(resets[i].hub).getAssetId(resets[i].underlying);
      resets[i].hubConfigurator.resetAssetCaps(resets[i].hub, assetId);
    }
  }

  /// @notice Deactivates Spokes on Hubs.
  /// @param deactivations The Spoke deactivations to execute.
  function executeHubSpokeDeactivations(
    IAaveV4ConfigEngine.SpokeDeactivation[] calldata deactivations
  ) external {
    uint256 length = deactivations.length;
    for (uint256 i; i < length; ++i) {
      deactivations[i].hubConfigurator.deactivateSpoke(
        deactivations[i].hub,
        deactivations[i].spoke
      );
    }
  }

  /// @notice Resets Spoke caps on Hubs.
  /// @param resets The Spoke caps resets to execute.
  function executeHubSpokeCapsResets(
    IAaveV4ConfigEngine.SpokeCapsReset[] calldata resets
  ) external {
    uint256 length = resets.length;
    for (uint256 i; i < length; ++i) {
      resets[i].hubConfigurator.resetSpokeCaps(resets[i].hub, resets[i].spoke);
    }
  }

  /// @dev Deploys a TokenizationSpoke (impl + proxy) via CREATE2 and registers it on the Hub.
  function _deployAndRegisterTokenizationSpoke(
    IAaveV4ConfigEngine.AssetListing calldata listing
  ) private {
    // if not name and/or symbol given, we assume there is no intention to deploy a TokenizationSpoke, so we skip deployment and registration
    if (
      bytes(listing.tokenization.name).length == 0 || bytes(listing.tokenization.symbol).length == 0
    ) {
      return;
    }

    address proxy = TokenizationSpokeDeployer.deploy(
      listing.hub,
      listing.underlying,
      listing.tokenization.name,
      listing.tokenization.symbol
    );

    uint256 assetId = IHubBase(listing.hub).getAssetId(listing.underlying);

    listing.hubConfigurator.addSpoke(
      listing.hub,
      proxy,
      assetId,
      IHub.SpokeConfig({
        addCap: listing.tokenization.addCap.toUint40(),
        drawCap: 0,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      })
    );
  }

  /// @dev Merges non-sentinel fields from irData into the current on-chain IR data.
  /// Returns empty bytes if all fields are sentinel (no update needed).
  function _mergeInterestRateData(
    address hub,
    uint256 assetId,
    IAssetInterestRateStrategy.InterestRateData calldata irData
  ) private view returns (bytes memory) {
    bool anyUpdated;

    bool updateOptimal = irData.optimalUsageRatio != EngineFlags.KEEP_CURRENT_UINT16;
    bool updateBase = irData.baseDrawnRate != EngineFlags.KEEP_CURRENT_UINT32;
    bool updateBefore = irData.rateGrowthBeforeOptimal != EngineFlags.KEEP_CURRENT_UINT32;
    bool updateAfter = irData.rateGrowthAfterOptimal != EngineFlags.KEEP_CURRENT_UINT32;

    anyUpdated = updateOptimal || updateBase || updateBefore || updateAfter;
    if (!anyUpdated) return '';

    address irStrategy = IHub(hub).getAssetConfig(assetId).irStrategy;
    IAssetInterestRateStrategy.InterestRateData memory current = IAssetInterestRateStrategy(
      irStrategy
    ).getInterestRateData(assetId);

    if (updateOptimal) {
      current.optimalUsageRatio = irData.optimalUsageRatio;
    }
    if (updateBase) {
      current.baseDrawnRate = irData.baseDrawnRate;
    }
    if (updateBefore) {
      current.rateGrowthBeforeOptimal = irData.rateGrowthBeforeOptimal;
    }
    if (updateAfter) {
      current.rateGrowthAfterOptimal = irData.rateGrowthAfterOptimal;
    }

    return abi.encode(current);
  }

  /// @dev Updates the interest rate strategy or data for the given asset.
  /// If a new strategy address is provided, replaces the strategy entirely;
  /// otherwise merges individual rate parameters into the existing data.
  function _updateInterestRateStrategy(
    uint256 assetId,
    IAaveV4ConfigEngine.AssetConfigUpdate calldata update
  ) private {
    if (update.irStrategy != EngineFlags.KEEP_CURRENT_ADDRESS) {
      require(
        update.irData.optimalUsageRatio != EngineFlags.KEEP_CURRENT_UINT16 &&
          update.irData.baseDrawnRate != EngineFlags.KEEP_CURRENT_UINT32 &&
          update.irData.rateGrowthBeforeOptimal != EngineFlags.KEEP_CURRENT_UINT32 &&
          update.irData.rateGrowthAfterOptimal != EngineFlags.KEEP_CURRENT_UINT32,
        InvalidIrDataWithNewStrategy()
      );
      update.hubConfigurator.updateInterestRateStrategy(
        update.hub,
        assetId,
        update.irStrategy,
        abi.encode(update.irData)
      );
    } else {
      bytes memory mergedIrData = _mergeInterestRateData(update.hub, assetId, update.irData);
      if (mergedIrData.length > 0) {
        update.hubConfigurator.updateInterestRateData(update.hub, assetId, mergedIrData);
      }
    }
  }

  /// @dev Updates spoke add/draw caps, calling the most specific configurator method
  /// depending on which caps changed (both, add-only, or draw-only).
  function _updateSpokeCaps(
    uint256 assetId,
    IAaveV4ConfigEngine.SpokeConfigUpdate calldata update
  ) private {
    bool updateAdd = update.addCap != EngineFlags.KEEP_CURRENT;
    bool updateDraw = update.drawCap != EngineFlags.KEEP_CURRENT;

    if (updateAdd && updateDraw) {
      update.hubConfigurator.updateSpokeCaps(
        update.hub,
        assetId,
        update.spoke,
        update.addCap,
        update.drawCap
      );
    } else if (updateAdd) {
      update.hubConfigurator.updateSpokeAddCap(update.hub, assetId, update.spoke, update.addCap);
    } else if (updateDraw) {
      update.hubConfigurator.updateSpokeDrawCap(update.hub, assetId, update.spoke, update.drawCap);
    }
  }
}
