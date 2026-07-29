// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IAddressesProvider
/// @author Aave Labs
/// @notice Main registry of the Hub and Spoke addresses of an Aave V4 instance.
interface IAddressesProvider {
  /// @notice Entry registered under an identifier.
  /// @param addr The registered address.
  /// @param name The name of the entry.
  /// @param tag The tag grouping the entry.
  struct Entry {
    address addr;
    string name;
    string tag;
  }

  /// @notice Emitted when the address of an entry is updated.
  /// @param id The identifier of the entry.
  /// @param name The name of the entry.
  /// @param tag The tag grouping the entry.
  /// @param oldAddress The previous address of the entry.
  /// @param newAddress The new address of the entry.
  event SetEntry(
    bytes32 indexed id,
    string name,
    string tag,
    address indexed oldAddress,
    address indexed newAddress
  );

  /// @notice Thrown when the specified tag is invalid.
  error InvalidTag();

  /// @notice Thrown when the specified name is invalid.
  error InvalidName();

  /// @notice Thrown when an address is already registered under the identifier.
  error AddressAlreadySet(bytes32 id);

  /// @notice Thrown when no address is registered under the identifier.
  error AddressNotSet(bytes32 id);

  /// @notice Associates an address with a name, grouped under a tag.
  /// @dev Associating the zero address removes the entry and its identifier from enumeration, it reverts if no address is registered.
  /// @dev Reverts if an address is already registered under the identifier, it must be removed first.
  /// @param name The name of the entry.
  /// @param tag The tag grouping the entry.
  /// @param newAddress The address to associate with the name and tag.
  function setEntry(string calldata name, string calldata tag, address newAddress) external;

  /// @notice Registers the canonical Hub associated with a name.
  /// @dev Registering the zero address removes the entry and its identifier from enumeration, it reverts if no address is registered.
  /// @dev Reverts if an address is already registered under the identifier, it must be removed first.
  /// @param name The name of the Hub.
  /// @param hub The address of the Hub.
  function setCanonicalHub(string calldata name, address hub) external;

  /// @notice Registers the canonical Spoke associated with a name.
  /// @dev Registering the zero address removes the entry and its identifier from enumeration, it reverts if no address is registered.
  /// @dev Reverts if an address is already registered under the identifier, it must be removed first.
  /// @param name The name of the Spoke.
  /// @param spoke The address of the Spoke.
  function setCanonicalSpoke(string calldata name, address spoke) external;

  /// @notice Registers the tokenization Spoke associated with a name.
  /// @dev Registering the zero address removes the entry and its identifier from enumeration, it reverts if no address is registered.
  /// @dev Reverts if an address is already registered under the identifier, it must be removed first.
  /// @param name The name of the Spoke.
  /// @param spoke The address of the Spoke.
  function setTokenizationSpoke(string calldata name, address spoke) external;

  /// @notice Registers the treasury Spoke associated with a name.
  /// @dev Registering the zero address removes the entry and its identifier from enumeration, it reverts if no address is registered.
  /// @dev Reverts if an address is already registered under the identifier, it must be removed first.
  /// @param name The name of the Spoke.
  /// @param spoke The address of the Spoke.
  function setTreasurySpoke(string calldata name, address spoke) external;

  /// @notice Returns the address associated with an identifier.
  /// @param id The identifier of the entry.
  /// @return The address of the entry, the zero address if none is registered.
  function getAddress(bytes32 id) external view returns (address);

  /// @notice Returns the address associated with a name and tag.
  /// @param name The name of the entry.
  /// @param tag The tag grouping the entry.
  /// @return The address of the entry, the zero address if none is registered.
  function getAddress(string calldata name, string calldata tag) external view returns (address);

  /// @notice Returns the entry associated with an identifier.
  /// @param id The identifier of the entry.
  /// @return The entry associated with the identifier.
  function getEntry(bytes32 id) external view returns (Entry memory);

  /// @notice Returns the number of tags with at least one registered entry.
  function getTagCount() external view returns (uint256);

  /// @notice Returns all tags with at least one registered entry.
  function getTags() external view returns (string[] memory);

  /// @notice Returns a slice of the tags with at least one registered entry.
  /// @dev Out-of-range bounds are clamped to the number of tags, it does not revert.
  /// @param start The start index of the slice.
  /// @param end The end index of the slice.
  /// @return The list of tags in the slice.
  function getTags(uint256 start, uint256 end) external view returns (string[] memory);

  /// @notice Returns the number of entries grouped under a tag.
  /// @param tag The tag grouping the entries.
  /// @return The number of entries.
  function getIdCount(string calldata tag) external view returns (uint256);

  /// @notice Returns the identifiers of all entries grouped under a tag.
  /// @param tag The tag grouping the entries.
  /// @return The list of identifiers.
  function getIds(string calldata tag) external view returns (bytes32[] memory);

  /// @notice Returns a slice of the identifiers of the entries grouped under a tag.
  /// @dev Out-of-range bounds are clamped to the number of entries, it does not revert.
  /// @param tag The tag grouping the entries.
  /// @param start The start index of the slice.
  /// @param end The end index of the slice.
  /// @return The list of identifiers in the slice.
  function getIds(
    string calldata tag,
    uint256 start,
    uint256 end
  ) external view returns (bytes32[] memory);

  /// @notice Returns the addresses of all entries grouped under a tag.
  /// @param tag The tag grouping the entries.
  /// @return The list of addresses.
  function getAddresses(string calldata tag) external view returns (address[] memory);

  /// @notice Returns a slice of the addresses of the entries grouped under a tag.
  /// @dev Out-of-range bounds are clamped to the number of entries, it does not revert.
  /// @param tag The tag grouping the entries.
  /// @param start The start index of the slice.
  /// @param end The end index of the slice.
  /// @return The list of addresses in the slice.
  function getAddresses(
    string calldata tag,
    uint256 start,
    uint256 end
  ) external view returns (address[] memory);

  /// @notice Returns the number of entries registered for an address.
  /// @param addr The registered address.
  /// @return The number of entries.
  function getAddressIdCount(address addr) external view returns (uint256);

  /// @notice Returns the identifiers of all entries registered for an address.
  /// @param addr The registered address.
  /// @return The list of identifiers.
  function getAddressIds(address addr) external view returns (bytes32[] memory);

  /// @notice Returns a slice of the identifiers of the entries registered for an address.
  /// @dev Out-of-range bounds are clamped to the number of entries, it does not revert.
  /// @param addr The registered address.
  /// @param start The start index of the slice.
  /// @param end The end index of the slice.
  /// @return The list of identifiers in the slice.
  function getAddressIds(
    address addr,
    uint256 start,
    uint256 end
  ) external view returns (bytes32[] memory);

  /// @notice Returns all entries registered for an address.
  /// @param addr The registered address.
  /// @return The list of entries.
  function getEntries(address addr) external view returns (Entry[] memory);

  /// @notice Returns a slice of the entries registered for an address.
  /// @dev Out-of-range bounds are clamped to the number of entries, it does not revert.
  /// @param addr The registered address.
  /// @param start The start index of the slice.
  /// @param end The end index of the slice.
  /// @return The list of entries in the slice.
  function getEntries(
    address addr,
    uint256 start,
    uint256 end
  ) external view returns (Entry[] memory);

  /// @notice Returns the canonical Hub associated with a name.
  /// @param name The name of the Hub.
  /// @return The address of the Hub, the zero address if none is registered.
  function getCanonicalHub(string calldata name) external view returns (address);

  /// @notice Returns the addresses of all registered canonical Hubs.
  /// @return The list of canonical Hub addresses.
  function getCanonicalHubs() external view returns (address[] memory);

  /// @notice Returns a slice of the addresses of the registered canonical Hubs.
  /// @dev Out-of-range bounds are clamped to the number of entries, it does not revert.
  /// @param start The start index of the slice.
  /// @param end The end index of the slice.
  /// @return The list of canonical Hub addresses in the slice.
  function getCanonicalHubs(uint256 start, uint256 end) external view returns (address[] memory);

  /// @notice Returns the canonical Spoke associated with a name.
  /// @param name The name of the Spoke.
  /// @return The address of the Spoke, the zero address if none is registered.
  function getCanonicalSpoke(string calldata name) external view returns (address);

  /// @notice Returns the addresses of all registered canonical Spokes.
  /// @return The list of canonical Spoke addresses.
  function getCanonicalSpokes() external view returns (address[] memory);

  /// @notice Returns a slice of the addresses of the registered canonical Spokes.
  /// @dev Out-of-range bounds are clamped to the number of entries, it does not revert.
  /// @param start The start index of the slice.
  /// @param end The end index of the slice.
  /// @return The list of canonical Spoke addresses in the slice.
  function getCanonicalSpokes(uint256 start, uint256 end) external view returns (address[] memory);

  /// @notice Returns the tokenization Spoke associated with a name.
  /// @param name The name of the Spoke.
  /// @return The address of the Spoke, the zero address if none is registered.
  function getTokenizationSpoke(string calldata name) external view returns (address);

  /// @notice Returns the addresses of all registered tokenization Spokes.
  /// @return The list of tokenization Spoke addresses.
  function getTokenizationSpokes() external view returns (address[] memory);

  /// @notice Returns a slice of the addresses of the registered tokenization Spokes.
  /// @dev Out-of-range bounds are clamped to the number of entries, it does not revert.
  /// @param start The start index of the slice.
  /// @param end The end index of the slice.
  /// @return The list of tokenization Spoke addresses in the slice.
  function getTokenizationSpokes(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory);

  /// @notice Returns the treasury Spoke associated with a name.
  /// @param name The name of the Spoke.
  /// @return The address of the Spoke, the zero address if none is registered.
  function getTreasurySpoke(string calldata name) external view returns (address);

  /// @notice Returns the addresses of all registered treasury Spokes.
  /// @return The list of treasury Spoke addresses.
  function getTreasurySpokes() external view returns (address[] memory);

  /// @notice Returns a slice of the addresses of the registered treasury Spokes.
  /// @dev Out-of-range bounds are clamped to the number of entries, it does not revert.
  /// @param start The start index of the slice.
  /// @param end The end index of the slice.
  /// @return The list of treasury Spoke addresses in the slice.
  function getTreasurySpokes(uint256 start, uint256 end) external view returns (address[] memory);

  /// @notice Returns the identifier of the entry associated with a name and tag.
  /// @dev The identifier is the hash of the ABI-encoded name and tag.
  /// @param name The name of the entry.
  /// @param tag The tag grouping the entry.
  /// @return The identifier of the entry.
  function getId(string calldata name, string calldata tag) external pure returns (bytes32);

  /// @notice Returns the tag grouping all canonical Hubs.
  function CANONICAL_HUB_TAG() external view returns (string memory);

  /// @notice Returns the tag grouping all canonical Spokes.
  function CANONICAL_SPOKE_TAG() external view returns (string memory);

  /// @notice Returns the tag grouping all tokenization Spokes.
  function TOKENIZATION_SPOKE_TAG() external view returns (string memory);

  /// @notice Returns the tag grouping all treasury Spokes.
  function TREASURY_SPOKE_TAG() external view returns (string memory);
}
