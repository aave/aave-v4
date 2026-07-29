// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {IAddressesProvider} from 'src/addresses-provider/interfaces/IAddressesProvider.sol';

/// @title AddressesProviderStorage
/// @author Aave Labs
/// @notice Storage layout for the AddressesProvider contract.
/// @dev This contract defines all storage variables used by the AddressesProvider.
abstract contract AddressesProviderStorage {
  /// @dev Map of entry identifiers to their respective entries.
  mapping(bytes32 id => IAddressesProvider.Entry) internal _idToEntry;

  /// @dev Map of tags to their respective sets of entry identifiers.
  mapping(string tag => EnumerableSet.Bytes32Set) internal _tagToIdSet;

  /// @dev Set of all tags.
  /// @dev A tag is included in the set only if it has at least one registered entry.
  EnumerableSet.StringSet internal _tagsSet;

  /// @dev Map of registered addresses to their respective sets of entry identifiers.
  /// @dev An address may be registered under more than one entry.
  mapping(address addr => EnumerableSet.Bytes32Set) internal _addressToIdSet;

  /// @dev Reserved storage space to allow for future layout updates.
  uint256[50] private __gap;
}
