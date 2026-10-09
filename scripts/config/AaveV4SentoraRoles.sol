// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title AaveV4SentoraRoles
/// @author Aave Labs
/// @notice The Sentora roles carved out of the configurator domain admin roles, and the configurator
/// selectors each one reaches.
/// @dev Two roles take selectors away from roles 200 and 400, which keep every other selector:
///
/// | role                           | selectors                                  | holders                           |
/// | ------------------------------ | ------------------------------------------ | --------------------------------- |
/// | SENTORA_RISK_ROLE              | add / draw caps, CF, max liquidation bonus | Risk Steward, Sentora Executor    |
/// | SENTORA_EMERGENCY_ROLE         | halt, pause, freeze, reset caps            | Emergency Operator, Security Council |
/// | 200 / 400 configurator admins  | every other configurator selector          | Sentora Executor                  |
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
/// configurator admins. The role ids sit outside the per-domain ranges `Roles` reserves, so a
/// granular role appended upstream never collides with them.
library AaveV4SentoraRoles {
  /// @dev Cap, collateral factor and max liquidation bonus updates.
  uint64 internal constant SENTORA_RISK_ROLE = 1000;
  /// @dev One-way emergency actions: halt, pause, freeze and cap resets.
  uint64 internal constant SENTORA_EMERGENCY_ROLE = 1001;

  /// @notice The HubConfigurator selectors `SENTORA_RISK_ROLE` reaches.
  /// @return selectors The selectors.
  function hubRiskSelectors() internal pure returns (bytes4[] memory selectors) {
    selectors = new bytes4[](3);
    selectors[0] = IHubConfigurator.updateSpokeAddCap.selector;
    selectors[1] = IHubConfigurator.updateSpokeDrawCap.selector;
    selectors[2] = IHubConfigurator.updateSpokeCaps.selector;
  }

  /// @notice The SpokeConfigurator selectors `SENTORA_RISK_ROLE` reaches.
  /// @return selectors The selectors.
  function spokeRiskSelectors() internal pure returns (bytes4[] memory selectors) {
    selectors = new bytes4[](6);
    selectors[0] = ISpokeConfigurator.addCollateralFactor.selector;
    selectors[1] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectors[2] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectors[3] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectors[4] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectors[5] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
  }

  /// @notice The HubConfigurator selectors `SENTORA_EMERGENCY_ROLE` reaches.
  /// @return selectors The selectors.
  function hubEmergencySelectors() internal pure returns (bytes4[] memory selectors) {
    selectors = new bytes4[](4);
    selectors[0] = IHubConfigurator.haltAsset.selector;
    selectors[1] = IHubConfigurator.haltSpoke.selector;
    selectors[2] = IHubConfigurator.resetAssetCaps.selector;
    selectors[3] = IHubConfigurator.resetSpokeCaps.selector;
  }

  /// @notice The SpokeConfigurator selectors `SENTORA_EMERGENCY_ROLE` reaches.
  /// @return selectors The selectors.
  function spokeEmergencySelectors() internal pure returns (bytes4[] memory selectors) {
    selectors = new bytes4[](4);
    selectors[0] = ISpokeConfigurator.pauseReserve.selector;
    selectors[1] = ISpokeConfigurator.freezeReserve.selector;
    selectors[2] = ISpokeConfigurator.pauseAllReserves.selector;
    selectors[3] = ISpokeConfigurator.freezeAllReserves.selector;
  }

  /// @notice The HubConfigurator selectors left on `HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE`: every
  /// domain admin selector neither Sentora role reaches.
  /// @return The selectors.
  function hubAdminSelectors() internal pure returns (bytes4[] memory) {
    return
      _without(
        _without(Roles.getHubConfiguratorDomainAdminRoleSelectors(), hubRiskSelectors()),
        hubEmergencySelectors()
      );
  }

  /// @notice The SpokeConfigurator selectors left on `SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE`: every
  /// domain admin selector neither Sentora role reaches.
  /// @return The selectors.
  function spokeAdminSelectors() internal pure returns (bytes4[] memory) {
    return
      _without(
        _without(Roles.getSpokeConfiguratorDomainAdminRoleSelectors(), spokeRiskSelectors()),
        spokeEmergencySelectors()
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
