// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {INoncesKeyed} from 'src/interfaces/INoncesKeyed.sol';

/// @notice Provides tracking nonces for addresses. Supports key-ed nonces, where nonces will only increment for each key.
/// @author Modified from OpenZeppelin https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.2.0/contracts/utils/NoncesKeyed.sol
/// @dev Follows the https://eips.ethereum.org/EIPS/eip-4337#semi-abstracted-nonce-support[ERC-4337's semi-abstracted nonce system].
contract NoncesKeyed is INoncesKeyed {
  /// @custom:storage-location erc7201:aaveV4.storage.NoncesKeyed
  struct NoncesKeyedStorage {
    mapping(address owner => mapping(uint192 key => uint64 nonce)) _nonces;
  }

  /// @dev The storage slot for the NoncesKeyed storage struct.
  bytes32 private constant NAMESPACE_SLOT =
    // keccak256(abi.encode(uint256(keccak256("aaveV4.storage.NoncesKeyed")) - 1)) & ~bytes32(uint256(0xff))
    0x2b874476222a0679b83c59cab04594a8acca28c3b5e642121f957978e6a22200;

  /// @inheritdoc INoncesKeyed
  function useNonce(uint192 key) external returns (uint256) {
    return _useNonce(msg.sender, key);
  }

  /// @inheritdoc INoncesKeyed
  function nonces(address owner, uint192 key) external view returns (uint256) {
    return _pack(key, _getNoncesKeyedStorage()._nonces[owner][key]);
  }

  /// @notice Consumes the next unused nonce for an address and key.
  /// @dev Returns the current packed `keyNonce`. Consumed nonce is increased, so calling this function twice
  /// with the same arguments will return different (sequential) results.
  function _useNonce(address owner, uint192 key) internal returns (uint256) {
    // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
    // decremented or reset. This guarantees that the nonce never overflows.
    unchecked {
      // It is important to do x++ and not ++x here.
      return _pack(key, _getNoncesKeyedStorage()._nonces[owner][key]++);
    }
  }

  /// @dev Same as `_useNonce` but checking that `nonce` is the next valid for `owner` for specified packed `keyNonce`.
  function _useCheckedNonce(address owner, uint256 keyNonce) internal {
    (uint192 key, ) = _unpack(keyNonce);
    uint256 current = _useNonce(owner, key);
    require(keyNonce == current, InvalidAccountNonce(owner, current));
  }

  /// @dev Pack key and nonce into a keyNonce.
  function _pack(uint192 key, uint64 nonce) private pure returns (uint256) {
    return (uint256(key) << 64) | nonce;
  }

  /// @dev Unpack a keyNonce into its key and nonce components.
  function _unpack(uint256 keyNonce) private pure returns (uint192 key, uint64 nonce) {
    return (uint192(keyNonce >> 64), uint64(keyNonce));
  }

  /// @dev Loads the NoncesKeyed storage struct.
  function _getNoncesKeyedStorage() private pure returns (NoncesKeyedStorage storage $) {
    assembly ('memory-safe') {
      $.slot := NAMESPACE_SLOT
    }
  }
}
