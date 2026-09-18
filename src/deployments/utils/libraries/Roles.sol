// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title Roles library
/// @author Aave Labs
/// @notice Defines the different roles used by the protocol and their target selectors.
///
/// Role IDs are namespaced by domain:
///   - AccessManager:     0 (default admin)
///   - Hub:               100-199
///   - HubConfigurator:   200-299
///   - Spoke:             300-399
///   - SpokeConfigurator: 400-499
///
/// ## Role strategy
///
/// A single authority contract will be used to manage the roles for all applicable contracts on a given chain.
/// Role IDs, selector mappings, and overall configuration should be kept identical
/// across chains to avoid additional overhead and role divergence.
///
/// Hub and Spoke roles remain granular (e.g. HUB_CONFIGURATOR_ROLE,
/// HUB_FEE_MINTER_ROLE, HUB_DEFICIT_ELIMINATOR_ROLE each control a distinct set
/// of selectors).
///
/// HubConfigurator and SpokeConfigurator follow a different approach: initially,
/// a single Domain Admin role per domain (HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE = 200,
/// SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE = 400) holds all target selectors.
/// As more granular roles are introduced, they are added at the next available ID
/// (201, 202, ... / 401, 402, ...) and the corresponding selectors are reassigned
/// from the Domain Admin role to the new granular role:
///   - Existing role IDs should never be overwritten or reused for a different purpose.
///   - New roles are always appended with an incremented ID.
///   - The Domain Admin role (200/400) only ever has its selector set shrink over
///     time as selectors are divided into more granular roles.
///   - Addresses holding the Domain Admin role should be granted the new
///     granular role to retain their existing access.
library Roles {
  // AccessManager roles
  uint64 public constant ACCESS_MANAGER_ADMIN_ROLE = 0;

  // Hub roles
  uint64 public constant HUB_DOMAIN_ADMIN_ROLE = 100;
  uint64 public constant HUB_CONFIGURATOR_ROLE = 101;
  uint64 public constant HUB_FEE_MINTER_ROLE = 102;
  uint64 public constant HUB_DEFICIT_ELIMINATOR_ROLE = 103;

  // HubConfigurator roles — granularize as needed with new roles appended
  uint64 public constant HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE = 200;

  // Spoke roles
  uint64 public constant SPOKE_DOMAIN_ADMIN_ROLE = 300;
  uint64 public constant SPOKE_CONFIGURATOR_ROLE = 301;
  uint64 public constant SPOKE_USER_POSITION_UPDATER_ROLE = 302;

  // SpokeConfigurator roles — granularize as needed with new roles appended
  uint64 public constant SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE = 400;

  // ─── Hub selector getters ───

  /// @notice Returns the function selectors associated with the Hub Configurator role.
  function getHubConfiguratorRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](5);
    selectors[0] = IHub.addAsset.selector;
    selectors[1] = IHub.updateAssetConfig.selector;
    selectors[2] = IHub.addSpoke.selector;
    selectors[3] = IHub.updateSpokeConfig.selector;
    selectors[4] = IHub.setInterestRateData.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the Hub Fee Minter role.
  function getHubFeeMinterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHub.mintFeeShares.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the Hub Deficit Eliminator role.
  function getHubDeficitEliminatorRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHub.eliminateDeficit.selector;
    return selectors;
  }

  // ─── HubConfigurator selector getters ───

  /// @notice Returns the function selectors associated with the HubConfigurator Domain Admin role.
  function getHubConfiguratorDomainAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](22);
    selectors[0] = IHubConfigurator.addAsset.selector;
    selectors[1] = IHubConfigurator.addAssetWithDecimals.selector;
    selectors[2] = IHubConfigurator.updateLiquidityFee.selector;
    selectors[3] = IHubConfigurator.updateFeeReceiver.selector;
    selectors[4] = IHubConfigurator.updateFeeConfig.selector;
    selectors[5] = IHubConfigurator.updateInterestRateStrategy.selector;
    selectors[6] = IHubConfigurator.updateReinvestmentController.selector;
    selectors[7] = IHubConfigurator.resetAssetCaps.selector;
    selectors[8] = IHubConfigurator.deactivateAsset.selector;
    selectors[9] = IHubConfigurator.haltAsset.selector;
    selectors[10] = IHubConfigurator.addSpoke.selector;
    selectors[11] = IHubConfigurator.addSpokeToAssets.selector;
    selectors[12] = IHubConfigurator.updateSpokeActive.selector;
    selectors[13] = IHubConfigurator.updateSpokeHalted.selector;
    selectors[14] = IHubConfigurator.updateSpokeAddCap.selector;
    selectors[15] = IHubConfigurator.updateSpokeDrawCap.selector;
    selectors[16] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
    selectors[17] = IHubConfigurator.updateSpokeCaps.selector;
    selectors[18] = IHubConfigurator.deactivateSpoke.selector;
    selectors[19] = IHubConfigurator.haltSpoke.selector;
    selectors[20] = IHubConfigurator.resetSpokeCaps.selector;
    selectors[21] = IHubConfigurator.updateInterestRateData.selector;
    return selectors;
  }

  // ─── Spoke selector getters ───

  /// @notice Returns the function selectors associated with the Spoke Position Updater role.
  function getSpokePositionUpdaterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = ISpoke.updateUserDynamicConfig.selector;
    selectors[1] = ISpoke.updateUserRiskPremium.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the Spoke Configurator role.
  function getSpokeConfiguratorRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](7);
    selectors[0] = ISpoke.updateLiquidationConfig.selector;
    selectors[1] = ISpoke.addReserve.selector;
    selectors[2] = ISpoke.updateReserveConfig.selector;
    selectors[3] = ISpoke.updateDynamicReserveConfig.selector;
    selectors[4] = ISpoke.addDynamicReserveConfig.selector;
    selectors[5] = ISpoke.updatePositionManager.selector;
    selectors[6] = ISpoke.updateReservePriceSource.selector;
    return selectors;
  }

  // ─── SpokeConfigurator selector getters ───

  /// @notice Returns the function selectors associated with the SpokeConfigurator Domain Admin role.
  function getSpokeConfiguratorDomainAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](24);
    selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
    selectors[1] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
    selectors[2] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
    selectors[3] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
    selectors[4] = ISpokeConfigurator.updateLiquidationConfig.selector;
    selectors[5] = ISpokeConfigurator.addReserve.selector;
    selectors[6] = ISpokeConfigurator.updatePaused.selector;
    selectors[7] = ISpokeConfigurator.updateFrozen.selector;
    selectors[8] = ISpokeConfigurator.updateBorrowable.selector;
    selectors[9] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    selectors[10] = ISpokeConfigurator.updateCollateralRisk.selector;
    selectors[11] = ISpokeConfigurator.addCollateralFactor.selector;
    selectors[12] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectors[13] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectors[14] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectors[15] = ISpokeConfigurator.addLiquidationFee.selector;
    selectors[16] = ISpokeConfigurator.updateLiquidationFee.selector;
    selectors[17] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectors[18] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
    selectors[19] = ISpokeConfigurator.pauseAllReserves.selector;
    selectors[20] = ISpokeConfigurator.freezeAllReserves.selector;
    selectors[21] = ISpokeConfigurator.pauseReserve.selector;
    selectors[22] = ISpokeConfigurator.freezeReserve.selector;
    selectors[23] = ISpokeConfigurator.updatePositionManager.selector;
    return selectors;
  }
}
