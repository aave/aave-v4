// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IHubSpokeFactory} from 'src/factory/interfaces/IHubSpokeFactory.sol';

/// @title HubSpokeFactoryStorage
/// @author Aave Labs
/// @notice Storage layout for the HubSpokeFactory contract.
/// @dev This contract defines all storage variables used by the HubSpokeFactory.
abstract contract HubSpokeFactoryStorage {
  /// @dev Map of instance type to its canonical implementation.
  mapping(IHubSpokeFactory.InstanceType instanceType => address) internal _implementations;

  /// @dev Map of deployer and instance type to the instances deployed, in deployment order.
  mapping(address deployer => mapping(IHubSpokeFactory.InstanceType instanceType => address[]))
    internal _instances;

  /// @dev Map of instance address to its deployment information.
  mapping(address instance => IHubSpokeFactory.InstanceInfo) internal _instanceInfo;

  /// @dev Map of deployer, Hub and underlying asset to the deployed TokenizationSpoke.
  mapping(address deployer => mapping(address hub => mapping(address underlying => address)))
    internal _tokenizationSpokes;

  /// @dev Reserved storage space to allow for future layout updates.
  uint256[46] private __gap;
}
