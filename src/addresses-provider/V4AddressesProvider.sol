// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {V4AddressesProviderStorage} from 'src/addresses-provider/V4AddressesProviderStorage.sol';
import {IV4AddressesProvider} from 'src/addresses-provider/interfaces/IV4AddressesProvider.sol';

/// @title V4AddressesProvider
/// @author Aave Labs
/// @notice Main registry of Aave V4 contract addresses.
abstract contract V4AddressesProvider is
  V4AddressesProviderStorage,
  Ownable2StepUpgradeable,
  IV4AddressesProvider
{
  using EnumerableSet for *;

  /// @inheritdoc IV4AddressesProvider
  string public constant CANONICAL_HUB_TAG = 'CANONICAL_HUB';

  /// @inheritdoc IV4AddressesProvider
  string public constant CANONICAL_SPOKE_TAG = 'CANONICAL_SPOKE';

  /// @inheritdoc IV4AddressesProvider
  string public constant TOKENIZATION_SPOKE_TAG = 'TOKENIZATION_SPOKE';

  /// @inheritdoc IV4AddressesProvider
  string public constant TREASURY_SPOKE_TAG = 'TREASURY_SPOKE';

  /// @dev To be overridden by the inheriting V4AddressesProvider instance contract.
  function initialize(address owner) external virtual;

  /// @inheritdoc IV4AddressesProvider
  function setAddress(
    string calldata name,
    string calldata tag,
    address newAddress
  ) external onlyOwner {
    _setAddress({name: name, tag: tag, newAddress: newAddress});
  }

  /// @inheritdoc IV4AddressesProvider
  function setCanonicalHub(string calldata name, address hub) external onlyOwner {
    _setAddress({name: name, tag: CANONICAL_HUB_TAG, newAddress: hub});
  }

  /// @inheritdoc IV4AddressesProvider
  function setCanonicalSpoke(string calldata name, address spoke) external onlyOwner {
    _setAddress({name: name, tag: CANONICAL_SPOKE_TAG, newAddress: spoke});
  }

  /// @inheritdoc IV4AddressesProvider
  function setTokenizationSpoke(string calldata name, address spoke) external onlyOwner {
    _setAddress({name: name, tag: TOKENIZATION_SPOKE_TAG, newAddress: spoke});
  }

  /// @inheritdoc IV4AddressesProvider
  function setTreasurySpoke(string calldata name, address spoke) external onlyOwner {
    _setAddress({name: name, tag: TREASURY_SPOKE_TAG, newAddress: spoke});
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddress(bytes32 id) external view returns (address) {
    return _addressEntries[id].addr;
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddress(string calldata name, string calldata tag) external view returns (address) {
    return _getAddress({name: name, tag: tag});
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddressEntry(bytes32 id) external view returns (AddressEntry memory) {
    return _addressEntries[id];
  }

  /// @inheritdoc IV4AddressesProvider
  function getTagCount() external view returns (uint256) {
    return _tags.length();
  }

  /// @inheritdoc IV4AddressesProvider
  function getTags() external view returns (string[] memory) {
    return _tags.values();
  }

  /// @inheritdoc IV4AddressesProvider
  function getTags(uint256 start, uint256 end) external view returns (string[] memory) {
    return _tags.values(start, end);
  }

  /// @inheritdoc IV4AddressesProvider
  function getIdCount(string calldata tag) external view returns (uint256) {
    return _taggedIds[tag].length();
  }

  /// @inheritdoc IV4AddressesProvider
  function getIds(string calldata tag) external view returns (bytes32[] memory) {
    return _taggedIds[tag].values();
  }

  /// @inheritdoc IV4AddressesProvider
  function getIds(
    string calldata tag,
    uint256 start,
    uint256 end
  ) external view returns (bytes32[] memory) {
    return _taggedIds[tag].values(start, end);
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddresses(string calldata tag) external view returns (address[] memory) {
    return _toAddresses(_taggedIds[tag].values());
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddresses(
    string calldata tag,
    uint256 start,
    uint256 end
  ) external view returns (address[] memory) {
    return _toAddresses(_taggedIds[tag].values(start, end));
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddressIdCount(address addr) external view returns (uint256) {
    return _addressIds[addr].length();
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddressIds(address addr) external view returns (bytes32[] memory) {
    return _addressIds[addr].values();
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddressIds(
    address addr,
    uint256 start,
    uint256 end
  ) external view returns (bytes32[] memory) {
    return _addressIds[addr].values(start, end);
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddressEntries(address addr) external view returns (AddressEntry[] memory) {
    return _toEntries(_addressIds[addr].values());
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddressEntries(
    address addr,
    uint256 start,
    uint256 end
  ) external view returns (AddressEntry[] memory) {
    return _toEntries(_addressIds[addr].values(start, end));
  }

  /// @inheritdoc IV4AddressesProvider
  function getCanonicalHub(string calldata name) external view returns (address) {
    return _getAddress({name: name, tag: CANONICAL_HUB_TAG});
  }

  /// @inheritdoc IV4AddressesProvider
  function getCanonicalHubs() external view returns (address[] memory) {
    return _toAddresses(_taggedIds[CANONICAL_HUB_TAG].values());
  }

  /// @inheritdoc IV4AddressesProvider
  function getCanonicalHubs(uint256 start, uint256 end) external view returns (address[] memory) {
    return _toAddresses(_taggedIds[CANONICAL_HUB_TAG].values(start, end));
  }

  /// @inheritdoc IV4AddressesProvider
  function getCanonicalSpoke(string calldata name) external view returns (address) {
    return _getAddress({name: name, tag: CANONICAL_SPOKE_TAG});
  }

  /// @inheritdoc IV4AddressesProvider
  function getCanonicalSpokes() external view returns (address[] memory) {
    return _toAddresses(_taggedIds[CANONICAL_SPOKE_TAG].values());
  }

  /// @inheritdoc IV4AddressesProvider
  function getCanonicalSpokes(uint256 start, uint256 end) external view returns (address[] memory) {
    return _toAddresses(_taggedIds[CANONICAL_SPOKE_TAG].values(start, end));
  }

  /// @inheritdoc IV4AddressesProvider
  function getTokenizationSpoke(string calldata name) external view returns (address) {
    return _getAddress({name: name, tag: TOKENIZATION_SPOKE_TAG});
  }

  /// @inheritdoc IV4AddressesProvider
  function getTokenizationSpokes() external view returns (address[] memory) {
    return _toAddresses(_taggedIds[TOKENIZATION_SPOKE_TAG].values());
  }

  /// @inheritdoc IV4AddressesProvider
  function getTokenizationSpokes(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory) {
    return _toAddresses(_taggedIds[TOKENIZATION_SPOKE_TAG].values(start, end));
  }

  /// @inheritdoc IV4AddressesProvider
  function getTreasurySpoke(string calldata name) external view returns (address) {
    return _getAddress({name: name, tag: TREASURY_SPOKE_TAG});
  }

  /// @inheritdoc IV4AddressesProvider
  function getTreasurySpokes() external view returns (address[] memory) {
    return _toAddresses(_taggedIds[TREASURY_SPOKE_TAG].values());
  }

  /// @inheritdoc IV4AddressesProvider
  function getTreasurySpokes(uint256 start, uint256 end) external view returns (address[] memory) {
    return _toAddresses(_taggedIds[TREASURY_SPOKE_TAG].values(start, end));
  }

  /// @inheritdoc IV4AddressesProvider
  function getId(string calldata name, string calldata tag) external pure returns (bytes32) {
    return _getId({name: name, tag: tag});
  }

  function _setAddress(string memory name, string memory tag, address newAddress) internal {
    require(bytes(name).length > 0, InvalidName());
    require(bytes(tag).length > 0, InvalidTag());

    bytes32 id = _getId({name: name, tag: tag});
    AddressEntry memory oldEntry = _addressEntries[id];

    if (newAddress == address(0)) {
      require(oldEntry.addr != address(0), AddressNotSet(id));
      _taggedIds[oldEntry.tag].remove(id);
      if (_taggedIds[oldEntry.tag].length() == 0) {
        _tags.remove(oldEntry.tag);
      }
      _addressIds[oldEntry.addr].remove(id);
      delete _addressEntries[id];
    } else {
      require(oldEntry.addr == address(0), AddressAlreadySet(id));
      _addressEntries[id] = AddressEntry({addr: newAddress, name: name, tag: tag});
      _taggedIds[tag].add(id);
      _tags.add(tag);
      _addressIds[newAddress].add(id);
    }

    emit AddressSet(id, name, tag, oldEntry.addr, newAddress);
  }

  function _getAddress(string memory name, string memory tag) internal view returns (address) {
    return _addressEntries[_getId({name: name, tag: tag})].addr;
  }

  function _getId(string memory name, string memory tag) internal pure returns (bytes32) {
    return keccak256(abi.encode(name, tag));
  }

  function _toAddresses(bytes32[] memory ids) internal view returns (address[] memory) {
    address[] memory addresses = new address[](ids.length);
    for (uint256 i = 0; i < ids.length; i++) {
      addresses[i] = _addressEntries[ids[i]].addr;
    }
    return addresses;
  }

  function _toEntries(bytes32[] memory ids) internal view returns (AddressEntry[] memory) {
    AddressEntry[] memory entries = new AddressEntry[](ids.length);
    for (uint256 i = 0; i < ids.length; i++) {
      entries[i] = _addressEntries[ids[i]];
    }
    return entries;
  }
}
