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
/// HubConfigurator and SpokeConfigurator follow a different approach: a single Domain Base
/// role per domain (HUB_CONFIGURATOR_DOMAIN_BASE_ROLE = 200,
/// SPOKE_CONFIGURATOR_DOMAIN_BASE_ROLE = 400) holds every target selector that has not been
/// carved out into a more granular role. As more granular roles are introduced, they are
/// added at the next available ID (201, 202, ... / 401, 402, ...) and the corresponding
/// selectors are reassigned from the Domain Base role to the new granular role:
///   - Existing role IDs should never be overwritten or reused for a different purpose.
///   - New roles are always appended with an incremented ID.
///   - The Domain Base role (200/400) only ever has its selector set shrink over
///     time as selectors are divided into more granular roles.
///   - Addresses holding the Domain Base role should be granted the new
///     granular role to retain their existing access.
///
/// Both configurators have the same two roles carved out so far, and a role never spans both:
/// a Hub role only holds HubConfigurator selectors and a Spoke role only holds SpokeConfigurator
/// selectors, so Hub and Spoke access is always granted separately.
///   - Risk management (201/401): the risk parameters of an already listed asset, Spoke or
///     reserve. On the Hub the caps, the risk premium threshold and the interest rate data; on
///     the Spoke the collateral risk, the liquidation parameters and the dynamic reserve configs.
///   - Emergency (202/402): the one-directional flag actions, which only ever move a target to a
///     safer state (deactivate, halt, pause, freeze) and cannot revert it, so the role can be
///     held by a faster-moving entity than the Domain Base role. The two-way flags stay with the
///     Domain Base role, as do the Hub cap resets: zeroing caps is equally one-directional, but
///     only risk management can restore them.
library Roles {
  // AccessManager roles
  uint64 public constant ACCESS_MANAGER_ADMIN_ROLE = 0;

  // Hub roles
  uint64 public constant HUB_DOMAIN_BASE_ROLE = 100;
  uint64 public constant HUB_CONFIGURATOR_ROLE = 101;
  uint64 public constant HUB_FEE_MINTER_ROLE = 102;
  uint64 public constant HUB_DEFICIT_ELIMINATOR_ROLE = 103;

  // HubConfigurator roles — granularize as needed with new roles appended
  uint64 public constant HUB_CONFIGURATOR_DOMAIN_BASE_ROLE = 200;
  uint64 public constant HUB_CONFIGURATOR_RISK_MANAGEMENT_ROLE = 201;
  uint64 public constant HUB_CONFIGURATOR_EMERGENCY_ROLE = 202;

  // Spoke roles
  uint64 public constant SPOKE_DOMAIN_BASE_ROLE = 300;
  uint64 public constant SPOKE_CONFIGURATOR_ROLE = 301;
  uint64 public constant SPOKE_USER_POSITION_UPDATER_ROLE = 302;

  // SpokeConfigurator roles — granularize as needed with new roles appended
  uint64 public constant SPOKE_CONFIGURATOR_DOMAIN_BASE_ROLE = 400;
  uint64 public constant SPOKE_CONFIGURATOR_RISK_MANAGEMENT_ROLE = 401;
  uint64 public constant SPOKE_CONFIGURATOR_EMERGENCY_ROLE = 402;

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

  /// @notice Returns the function selectors associated with the HubConfigurator Domain Base role.
  function getHubConfiguratorDomainBaseRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](13);
    selectors[0] = IHubConfigurator.addAsset.selector;
    selectors[1] = IHubConfigurator.addAssetWithDecimals.selector;
    selectors[2] = IHubConfigurator.updateLiquidityFee.selector;
    selectors[3] = IHubConfigurator.updateFeeReceiver.selector;
    selectors[4] = IHubConfigurator.updateFeeConfig.selector;
    selectors[5] = IHubConfigurator.updateInterestRateStrategy.selector;
    selectors[6] = IHubConfigurator.updateReinvestmentController.selector;
    selectors[7] = IHubConfigurator.resetAssetCaps.selector;
    selectors[8] = IHubConfigurator.addSpoke.selector;
    selectors[9] = IHubConfigurator.addSpokeToAssets.selector;
    selectors[10] = IHubConfigurator.updateSpokeActive.selector;
    selectors[11] = IHubConfigurator.updateSpokeHalted.selector;
    selectors[12] = IHubConfigurator.resetSpokeCaps.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the HubConfigurator Risk Management role.
  function getHubConfiguratorRiskManagementRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](5);
    selectors[0] = IHubConfigurator.updateSpokeAddCap.selector;
    selectors[1] = IHubConfigurator.updateSpokeDrawCap.selector;
    selectors[2] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
    selectors[3] = IHubConfigurator.updateSpokeCaps.selector;
    selectors[4] = IHubConfigurator.updateInterestRateData.selector;
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

  /// @notice Returns the function selectors associated with the SpokeConfigurator Domain Base role.
  function getSpokeConfiguratorDomainBaseRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](7);
    selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
    selectors[1] = ISpokeConfigurator.addReserve.selector;
    selectors[2] = ISpokeConfigurator.updatePaused.selector;
    selectors[3] = ISpokeConfigurator.updateFrozen.selector;
    selectors[4] = ISpokeConfigurator.updateBorrowable.selector;
    selectors[5] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    selectors[6] = ISpokeConfigurator.updatePositionManager.selector;
    return selectors;
  }

  /// @notice Returns the function selectors associated with the SpokeConfigurator Risk Management role.
  function getSpokeConfiguratorRiskManagementRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](13);
    selectors[0] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
    selectors[1] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
    selectors[2] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
    selectors[3] = ISpokeConfigurator.updateLiquidationConfig.selector;
    selectors[4] = ISpokeConfigurator.updateCollateralRisk.selector;
    selectors[5] = ISpokeConfigurator.addCollateralFactor.selector;
    selectors[6] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectors[7] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectors[8] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectors[9] = ISpokeConfigurator.addLiquidationFee.selector;
    selectors[10] = ISpokeConfigurator.updateLiquidationFee.selector;
    selectors[11] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectors[12] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
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
}
