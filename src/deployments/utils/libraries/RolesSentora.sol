// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title RolesSentora library
/// @author Aave Labs
/// @notice Defines the Sentora market roles that differ from `Roles` and their target selectors.
///
/// Every role and selector not listed here is as in `Roles`. Two roles take configurator selectors
/// away from the Domain Admin roles (200/400), which keep every other selector:
///
/// | role                           | selectors                                  | holders                              |
/// | ------------------------------ | ------------------------------------------ | ------------------------------------ |
/// | SENTORA_RISK_ROLE              | add / draw caps, CF, max liquidation bonus | Risk Steward, Sentora Executor       |
/// | SENTORA_EMERGENCY_ROLE         | halt, pause, freeze, reset caps            | Emergency Operator, Security Council |
/// | 200 / 400 configurator admins  | every other configurator selector          | Sentora Executor                     |
///
/// No holder carries an AccessManager execution delay: the Sentora Executor sits behind its own
/// Timelock, and the Risk Steward bounds what it lets through.
///
/// The risk role includes the bundled dynamic config selectors because the config engine, and the
/// aave-v4-risk-stewards RiskSteward built on it, only ever moves collateral factor and max
/// liquidation bonus through `addDynamicReserveConfig` / `updateDynamicReserveConfig`. The steward
/// pins the liquidation fee those carry.
///
/// The emergency role only gets one-way selectors: unhalting, unpausing and unfreezing stay with the
/// Domain Admin roles. The role ids sit outside the per-domain ranges `Roles` reserves, so a
/// granular role appended upstream never collides with them.
library RolesSentora {
  /// @dev Cap, collateral factor and max liquidation bonus updates.
  uint64 public constant SENTORA_RISK_ROLE = 1000;
  /// @dev One-way emergency actions: halt, pause, freeze and cap resets.
  uint64 public constant SENTORA_EMERGENCY_ROLE = 1001;

  /// @notice Returns the HubConfigurator selectors associated with the Sentora Risk role.
  /// @return selectors The selectors.
  function getHubConfiguratorRiskRoleSelectors() internal pure returns (bytes4[] memory selectors) {
    selectors = new bytes4[](3);
    selectors[0] = IHubConfigurator.updateSpokeAddCap.selector;
    selectors[1] = IHubConfigurator.updateSpokeDrawCap.selector;
    selectors[2] = IHubConfigurator.updateSpokeCaps.selector;
  }

  /// @notice Returns the HubConfigurator selectors associated with the Sentora Emergency role.
  /// @return selectors The selectors.
  function getHubConfiguratorEmergencyRoleSelectors()
    internal
    pure
    returns (bytes4[] memory selectors)
  {
    selectors = new bytes4[](4);
    selectors[0] = IHubConfigurator.haltAsset.selector;
    selectors[1] = IHubConfigurator.haltSpoke.selector;
    selectors[2] = IHubConfigurator.resetAssetCaps.selector;
    selectors[3] = IHubConfigurator.resetSpokeCaps.selector;
  }

  /// @notice Returns the function selectors associated with the HubConfigurator Domain Admin role:
  /// every `Roles` Domain Admin selector neither Sentora role reaches.
  /// @return The selectors.
  function getHubConfiguratorDomainAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    return
      _without(
        _without(
          Roles.getHubConfiguratorDomainAdminRoleSelectors(),
          getHubConfiguratorRiskRoleSelectors()
        ),
        getHubConfiguratorEmergencyRoleSelectors()
      );
  }

  /// @notice Returns the SpokeConfigurator selectors associated with the Sentora Risk role.
  /// @return selectors The selectors.
  function getSpokeConfiguratorRiskRoleSelectors()
    internal
    pure
    returns (bytes4[] memory selectors)
  {
    selectors = new bytes4[](6);
    selectors[0] = ISpokeConfigurator.addCollateralFactor.selector;
    selectors[1] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectors[2] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectors[3] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectors[4] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectors[5] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
  }

  /// @notice Returns the SpokeConfigurator selectors associated with the Sentora Emergency role.
  /// @return selectors The selectors.
  function getSpokeConfiguratorEmergencyRoleSelectors()
    internal
    pure
    returns (bytes4[] memory selectors)
  {
    selectors = new bytes4[](4);
    selectors[0] = ISpokeConfigurator.pauseReserve.selector;
    selectors[1] = ISpokeConfigurator.freezeReserve.selector;
    selectors[2] = ISpokeConfigurator.pauseAllReserves.selector;
    selectors[3] = ISpokeConfigurator.freezeAllReserves.selector;
  }

  /// @notice Returns the function selectors associated with the SpokeConfigurator Domain Admin
  /// role: every `Roles` Domain Admin selector neither Sentora role reaches.
  /// @return The selectors.
  function getSpokeConfiguratorDomainAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    return
      _without(
        _without(
          Roles.getSpokeConfiguratorDomainAdminRoleSelectors(),
          getSpokeConfiguratorRiskRoleSelectors()
        ),
        getSpokeConfiguratorEmergencyRoleSelectors()
      );
  }

  function _without(
    bytes4[] memory all,
    bytes4[] memory excluded
  ) private pure returns (bytes4[] memory kept) {
    uint256 count;
    for (uint256 i; i < all.length; ++i) {
      if (!_contains(excluded, all[i])) ++count;
    }

    kept = new bytes4[](count);
    count = 0;
    for (uint256 i; i < all.length; ++i) {
      if (!_contains(excluded, all[i])) kept[count++] = all[i];
    }
  }

  function _contains(bytes4[] memory selectors, bytes4 selector) private pure returns (bool) {
    for (uint256 i; i < selectors.length; ++i) {
      if (selectors[i] == selector) return true;
    }
    return false;
  }
}
