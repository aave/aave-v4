// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title ISpokeConfiguratorInstance
/// @author Aave Labs
/// @notice SpokeConfigurator instance interface exposing the initializer and revision.
interface ISpokeConfiguratorInstance is ISpokeConfigurator {
  /// @notice Initializes the SpokeConfigurator instance with the given authority.
  /// @param authority The address of the access-control authority contract.
  function initialize(address authority) external;

  /// @notice Returns the revision number of this SpokeConfigurator implementation.
  function SPOKE_CONFIGURATOR_REVISION() external view returns (uint64);
}
