// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

/// @title IHubConfiguratorInstance
/// @author Aave Labs
/// @notice HubConfigurator instance interface exposing the initializer and revision.
interface IHubConfiguratorInstance is IHubConfigurator {
  /// @notice Initializes the HubConfigurator instance with the given authority.
  /// @param authority The address of the access-control authority contract.
  function initialize(address authority) external;

  /// @notice Returns the revision number of this HubConfigurator implementation.
  /// @return The revision number.
  function HUB_CONFIGURATOR_REVISION() external view returns (uint64);
}
