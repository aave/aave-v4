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
/// HubConfigurator and SpokeConfigurator follow a different approach: a single
/// Domain Admin role per domain (HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE = 200,
/// SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE = 400) initially held all target selectors.
/// As more granular roles are introduced, they are added at the next available ID
/// (201, 202, ... / 401, 402, ...) and the corresponding selectors are reassigned
/// from the Domain Admin role to the new granular role:
///   - Existing role IDs should never be overwritten or reused for a different purpose.
///   - New roles are always appended with an incremented ID.
///   - The Domain Admin role (200/400) only ever has its selector set shrink over
///     time as selectors are divided into more granular roles.
///   - Addresses holding the Domain Admin role should be granted the new
///     granular role to retain their existing access.
///
/// ## Configurator role breakdown
///
/// Each configurator is broken down into five granular roles covering the same five
/// concerns. A role never spans both configurators: a Hub role only holds
/// HubConfigurator selectors and a Spoke role only holds SpokeConfigurator selectors,
/// so Hub and Spoke access is always granted separately. The first two roles are named
/// after the flag they own, because the Hub has no `paused`/`frozen` flags of its own —
/// the equivalent state lives on the Spoke config it holds on each asset.
///
///   - HUB_CONFIGURATOR_SPOKE_ACTIVE_ROLE (201) / SPOKE_CONFIGURATOR_PAUSE_ROLE (401):
///     flips the flag that prevents all activity on a target, in both directions. The
///     Spoke `paused` flag, and the Hub's per-asset Spoke `active` flag which gates
///     every Hub action.
///   - HUB_CONFIGURATOR_SPOKE_HALTED_ROLE (202) / SPOKE_CONFIGURATOR_FREEZE_ROLE (402):
///     flips the flag that prevents new activity on a target, in both directions. The
///     Spoke `frozen` flag, and the Hub's per-asset Spoke `halted` flag which gates the
///     actions that instantly update liquidity.
///   - Listing (203/403): onboards new assets, Spokes and reserves, and sets the
///     properties fixed at listing time.
///   - Emergency (204/404): the one-directional batch flag actions. Every selector only
///     ever moves a target to a safer state (pause, freeze, deactivate, halt) and cannot
///     revert it, so the role can be held by a faster-moving entity than the two-way flag
///     roles above. The batch cap resets stay with the Domain Admin role: zeroing caps is
///     equally one-directional but only risk management can restore them, so it is left
///     to governance rather than to a fast-moving holder.
///   - Risk management (205/405): the risk parameters of an already listed asset or
///     reserve (caps, interest rates, collateral risk, dynamic configs, liquidation
///     config).
///
/// The Domain Admin role (200/400) retains the selectors that fall outside the five:
/// on the Hub the fee and strategy configuration plus the batch cap resets, on the
/// Spoke the reserve price source and position managers.
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
  uint64 public constant HUB_CONFIGURATOR_SPOKE_ACTIVE_ROLE = 201;
  uint64 public constant HUB_CONFIGURATOR_SPOKE_HALTED_ROLE = 202;
  uint64 public constant HUB_CONFIGURATOR_LISTING_ROLE = 203;
  uint64 public constant HUB_CONFIGURATOR_EMERGENCY_ROLE = 204;
  uint64 public constant HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE = 205;

  // Spoke roles
  uint64 public constant SPOKE_DOMAIN_ADMIN_ROLE = 300;
  uint64 public constant SPOKE_CONFIGURATOR_ROLE = 301;
  uint64 public constant SPOKE_USER_POSITION_UPDATER_ROLE = 302;

  // SpokeConfigurator roles — granularize as needed with new roles appended
  uint64 public constant SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE = 400;
  uint64 public constant SPOKE_CONFIGURATOR_PAUSE_ROLE = 401;
  uint64 public constant SPOKE_CONFIGURATOR_FREEZE_ROLE = 402;
  uint64 public constant SPOKE_CONFIGURATOR_LISTING_ROLE = 403;
  uint64 public constant SPOKE_CONFIGURATOR_EMERGENCY_ROLE = 404;
  uint64 public constant SPOKE_CONFIGURATOR_RISK_MANAGEMENT_ROLE = 405;

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
    bytes4[] memory selectors = new bytes4[](7);
    selectors[0] = IHubConfigurator.updateLiquidityFee.selector;
    selectors[1] = IHubConfigurator.updateFeeReceiver.selector;
    selectors[2] = IHubConfigurator.updateFeeConfig.selector;
    selectors[3] = IHubConfigurator.updateInterestRateStrategy.selector;
    selectors[4] = IHubConfigurator.updateReinvestmentController.selector;
    selectors[5] = IHubConfigurator.resetAssetCaps.selector;
    selectors[6] = IHubConfigurator.resetSpokeCaps.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the HubConfigurator Spoke Active role.
  function getHubConfiguratorSpokeActiveRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateSpokeActive.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the HubConfigurator Spoke Halted role.
  function getHubConfiguratorSpokeHaltedRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateSpokeHalted.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the HubConfigurator Listing role.
  function getHubConfiguratorListingRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = IHubConfigurator.addAsset.selector;
    selectors[1] = IHubConfigurator.addAssetWithDecimals.selector;
    selectors[2] = IHubConfigurator.addSpoke.selector;
    selectors[3] = IHubConfigurator.addSpokeToAssets.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the HubConfigurator Emergency role.
  function getHubConfiguratorEmergencyRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = IHubConfigurator.deactivateAsset.selector;
    selectors[1] = IHubConfigurator.haltAsset.selector;
    selectors[2] = IHubConfigurator.deactivateSpoke.selector;
    selectors[3] = IHubConfigurator.haltSpoke.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the HubConfigurator Risk Management role.
  function getHubConfiguratorRiskManagementRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](5);
    selectors[0] = IHubConfigurator.updateSpokeAddCap.selector;
    selectors[1] = IHubConfigurator.updateSpokeDrawCap.selector;
    selectors[2] = IHubConfigurator.updateSpokeCaps.selector;
    selectors[3] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
    selectors[4] = IHubConfigurator.updateInterestRateData.selector;
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
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
    selectors[1] = ISpokeConfigurator.updatePositionManager.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the SpokeConfigurator Pause role.
  function getSpokeConfiguratorPauseRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = ISpokeConfigurator.updatePaused.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the SpokeConfigurator Freeze role.
  function getSpokeConfiguratorFreezeRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = ISpokeConfigurator.updateFrozen.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the SpokeConfigurator Listing role.
  function getSpokeConfiguratorListingRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = ISpokeConfigurator.addReserve.selector;
    selectors[1] = ISpokeConfigurator.updateBorrowable.selector;
    selectors[2] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the SpokeConfigurator Emergency role.
  function getSpokeConfiguratorEmergencyRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = ISpokeConfigurator.pauseReserve.selector;
    selectors[1] = ISpokeConfigurator.pauseAllReserves.selector;
    selectors[2] = ISpokeConfigurator.freezeReserve.selector;
    selectors[3] = ISpokeConfigurator.freezeAllReserves.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the SpokeConfigurator Risk Management role.
  function getSpokeConfiguratorRiskManagementRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](13);
    selectors[0] = ISpokeConfigurator.updateCollateralRisk.selector;
    selectors[1] = ISpokeConfigurator.addCollateralFactor.selector;
    selectors[2] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectors[3] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectors[4] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectors[5] = ISpokeConfigurator.addLiquidationFee.selector;
    selectors[6] = ISpokeConfigurator.updateLiquidationFee.selector;
    selectors[7] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectors[8] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
    selectors[9] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
    selectors[10] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
    selectors[11] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
    selectors[12] = ISpokeConfigurator.updateLiquidationConfig.selector;
    return selectors;
  }
}
