// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

/// @title ITokenizationSpokeInstance
/// @author Aave Labs
/// @notice TokenizationSpoke instance interface exposing the initializer and revision.
interface ITokenizationSpokeInstance is ITokenizationSpoke {
  /// @notice Initializes the TokenizationSpoke instance with the Hub, tokenized asset, and share token metadata.
  /// @param hub The address of the associated Hub.
  /// @param underlying The address of the underlying asset to be tokenized.
  /// @param shareName The name of the share token.
  /// @param shareSymbol The symbol of the share token.
  function initialize(
    address hub,
    address underlying,
    string memory shareName,
    string memory shareSymbol
  ) external;

  /// @notice Returns the revision number of this TokenizationSpoke implementation.
  function SPOKE_REVISION() external view returns (uint64);
}
