// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {AddressesProviderStorage} from 'src/addresses-provider/AddressesProviderStorage.sol';
import {IAddressesProvider} from 'src/addresses-provider/interfaces/IAddressesProvider.sol';

/// @title AddressesProvider
/// @author Aave Labs
/// @notice Main registry of Aave V4 contract addresses.
abstract contract AddressesProvider is
  AddressesProviderStorage,
  Ownable2StepUpgradeable,
  IAddressesProvider
{
  using EnumerableSet for *;

  /// @inheritdoc IAddressesProvider
  string public constant CANONICAL_HUB_TAG = 'CANONICAL_HUB';

  /// @inheritdoc IAddressesProvider
  string public constant CANONICAL_SPOKE_TAG = 'CANONICAL_SPOKE';

  /// @inheritdoc IAddressesProvider
  string public constant TOKENIZATION_SPOKE_TAG = 'TOKENIZATION_SPOKE';

  /// @inheritdoc IAddressesProvider
  string public constant TREASURY_SPOKE_TAG = 'TREASURY_SPOKE';

  /// @dev To be overridden by the inheriting AddressesProvider instance contract.
  function initialize(address owner) external virtual;

  /// @inheritdoc IAddressesProvider
  function setEntry(
    string calldata name,
    string calldata tag,
    address newAddress
  ) external onlyOwner {
    _setEntry({name: name, tag: tag, newAddress: newAddress});
  }

  /// @inheritdoc IAddressesProvider
  function setCanonicalHub(string calldata name, address hub) external onlyOwner {
    _setEntry({name: name, tag: CANONICAL_HUB_TAG, newAddress: hub});
  }

  /// @inheritdoc IAddressesProvider
  function setCanonicalSpoke(string calldata name, address spoke) external onlyOwner {
    _setEntry({name: name, tag: CANONICAL_SPOKE_TAG, newAddress: spoke});
  }

  /// @inheritdoc IAddressesProvider
  function setTokenizationSpoke(string calldata name, address spoke) external onlyOwner {
    _setEntry({name: name, tag: TOKENIZATION_SPOKE_TAG, newAddress: spoke});
  }

  /// @inheritdoc IAddressesProvider
  function setTreasurySpoke(string calldata name, address spoke) external onlyOwner {
    _setEntry({name: name, tag: TREASURY_SPOKE_TAG, newAddress: spoke});
  }

  /// @inheritdoc IAddressesProvider
  function getAddress(bytes32 id) external view returns (address) {
    return _idToEntry[id].addr;
  }

  /// @inheritdoc IAddressesProvider
  function getAddress(string calldata name, string calldata tag) external view returns (address) {
    return _getAddress({name: name, tag: tag});
  }

  /// @inheritdoc IAddressesProvider
  function getEntry(bytes32 id) external view returns (Entry memory) {
    return _idToEntry[id];
  }

  /// @inheritdoc IAddressesProvider
  function getTagCount() external view returns (uint256) {
    return _tagsSet.length();
  }

  /// @inheritdoc IAddressesProvider
  function getTags() external view returns (string[] memory) {
    return _tagsSet.values();
  }

  /// @inheritdoc IAddressesProvider
  function getTags(uint256 start, uint256 end) external view returns (string[] memory) {
    return _tagsSet.values(start, end);
  }

  /// @inheritdoc IAddressesProvider
  function getIdCount(string calldata tag) external view returns (uint256) {
    return _tagToIdSet[tag].length();
  }

  /// @inheritdoc IAddressesProvider
  function getIds(string calldata tag) external view returns (bytes32[] memory) {
    return _tagToIdSet[tag].values();
  }

  /// @inheritdoc IAddressesProvider
  function getIds(
    string calldata tag,
    uint256 start,
    uint256 end
  ) external view returns (bytes32[] memory) {
    return _tagToIdSet[tag].values(start, end);
  }

  /// @inheritdoc IAddressesProvider
  function getAddresses(string calldata tag) external view returns (address[] memory) {
    return _toAddresses(_tagToIdSet[tag].values());
  }

  /// @inheritdoc IAddressesProvider
  function getAddresses(
    string calldata tag,
    uint256 start,
    uint256 end
  ) external view returns (address[] memory) {
    return _toAddresses(_tagToIdSet[tag].values(start, end));
  }

  /// @inheritdoc IAddressesProvider
  function getAddressIdCount(address addr) external view returns (uint256) {
    return _addressToIdSet[addr].length();
  }

  /// @inheritdoc IAddressesProvider
  function getAddressIds(address addr) external view returns (bytes32[] memory) {
    return _addressToIdSet[addr].values();
  }

  /// @inheritdoc IAddressesProvider
  function getAddressIds(
    address addr,
    uint256 start,
    uint256 end
  ) external view returns (bytes32[] memory) {
    return _addressToIdSet[addr].values(start, end);
  }

  /// @inheritdoc IAddressesProvider
  function getEntries(address addr) external view returns (Entry[] memory) {
    return _toEntries(_addressToIdSet[addr].values());
  }

  /// @inheritdoc IAddressesProvider
  function getEntries(
    address addr,
    uint256 start,
    uint256 end
  ) external view returns (Entry[] memory) {
    return _toEntries(_addressToIdSet[addr].values(start, end));
  }

  /// @inheritdoc IAddressesProvider
  function isRegistered(address addr, string calldata tag) external view returns (bool) {
    return _addressToTagCount[addr][keccak256(bytes(tag))] > 0;
  }

  /// @inheritdoc IAddressesProvider
  function getCanonicalHub(string calldata name) external view returns (address) {
    return _getAddress({name: name, tag: CANONICAL_HUB_TAG});
  }

  /// @inheritdoc IAddressesProvider
  function getCanonicalHubs() external view returns (address[] memory) {
    return _toAddresses(_tagToIdSet[CANONICAL_HUB_TAG].values());
  }

  /// @inheritdoc IAddressesProvider
  function getCanonicalHubs(uint256 start, uint256 end) external view returns (address[] memory) {
    return _toAddresses(_tagToIdSet[CANONICAL_HUB_TAG].values(start, end));
  }

  /// @inheritdoc IAddressesProvider
  function getCanonicalSpoke(string calldata name) external view returns (address) {
    return _getAddress({name: name, tag: CANONICAL_SPOKE_TAG});
  }

  /// @inheritdoc IAddressesProvider
  function getCanonicalSpokes() external view returns (address[] memory) {
    return _toAddresses(_tagToIdSet[CANONICAL_SPOKE_TAG].values());
  }

  /// @inheritdoc IAddressesProvider
  function getCanonicalSpokes(uint256 start, uint256 end) external view returns (address[] memory) {
    return _toAddresses(_tagToIdSet[CANONICAL_SPOKE_TAG].values(start, end));
  }

  /// @inheritdoc IAddressesProvider
  function getTokenizationSpoke(string calldata name) external view returns (address) {
    return _getAddress({name: name, tag: TOKENIZATION_SPOKE_TAG});
  }

  /// @inheritdoc IAddressesProvider
  function getTokenizationSpokes() external view returns (address[] memory) {
    return _toAddresses(_tagToIdSet[TOKENIZATION_SPOKE_TAG].values());
  }

  /// @inheritdoc IAddressesProvider
  function getTokenizationSpokes(
    uint256 start,
    uint256 end
  ) external view returns (address[] memory) {
    return _toAddresses(_tagToIdSet[TOKENIZATION_SPOKE_TAG].values(start, end));
  }

  /// @inheritdoc IAddressesProvider
  function getTreasurySpoke(string calldata name) external view returns (address) {
    return _getAddress({name: name, tag: TREASURY_SPOKE_TAG});
  }

  /// @inheritdoc IAddressesProvider
  function getTreasurySpokes() external view returns (address[] memory) {
    return _toAddresses(_tagToIdSet[TREASURY_SPOKE_TAG].values());
  }

  /// @inheritdoc IAddressesProvider
  function getTreasurySpokes(uint256 start, uint256 end) external view returns (address[] memory) {
    return _toAddresses(_tagToIdSet[TREASURY_SPOKE_TAG].values(start, end));
  }

  /// @inheritdoc IAddressesProvider
  function getId(string calldata name, string calldata tag) external pure returns (bytes32) {
    return _getId({name: name, tag: tag});
  }

  function _setEntry(string memory name, string memory tag, address newAddress) internal {
    require(bytes(name).length > 0, InvalidName());
    require(bytes(tag).length > 0, InvalidTag());

    bytes32 id = _getId({name: name, tag: tag});
    Entry memory oldEntry = _idToEntry[id];

    if (newAddress == address(0)) {
      require(oldEntry.addr != address(0), AddressNotSet(id));
      _tagToIdSet[oldEntry.tag].remove(id);
      if (_tagToIdSet[oldEntry.tag].length() == 0) {
        _tagsSet.remove(oldEntry.tag);
      }
      _addressToIdSet[oldEntry.addr].remove(id);
      _addressToTagCount[oldEntry.addr][keccak256(bytes(oldEntry.tag))]--;
      delete _idToEntry[id];
    } else {
      require(oldEntry.addr == address(0), AddressAlreadySet(id));
      _idToEntry[id] = Entry({name: name, tag: tag, addr: newAddress});
      _tagToIdSet[tag].add(id);
      _tagsSet.add(tag);
      _addressToIdSet[newAddress].add(id);
      _addressToTagCount[newAddress][keccak256(bytes(tag))]++;
    }

    emit SetEntry(id, name, tag, oldEntry.addr, newAddress);
  }

  function _getAddress(string memory name, string memory tag) internal view returns (address) {
    return _idToEntry[_getId({name: name, tag: tag})].addr;
  }

  function _toAddresses(bytes32[] memory ids) internal view returns (address[] memory) {
    address[] memory addresses = new address[](ids.length);
    for (uint256 i = 0; i < ids.length; i++) {
      addresses[i] = _idToEntry[ids[i]].addr;
    }
    return addresses;
  }

  function _toEntries(bytes32[] memory ids) internal view returns (Entry[] memory) {
    Entry[] memory entries = new Entry[](ids.length);
    for (uint256 i = 0; i < ids.length; i++) {
      entries[i] = _idToEntry[ids[i]];
    }
    return entries;
  }

  function _getId(string memory name, string memory tag) internal pure returns (bytes32) {
    return keccak256(abi.encode(name, tag));
  }
}
