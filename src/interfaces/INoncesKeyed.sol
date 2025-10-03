// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

interface INoncesKeyed {
  /// @notice Thrown when nonce being consumed does not match `currentNonce` for `account`.
  error InvalidAccountNonce(address account, uint256 currentNonce);

  /// @notice Allows caller to revoke their next sequential nonce at specified `key`.
  /// @param key The key which specifies lifetime of the nonce.
  /// @return keyNonce The consumed keyNonce.
  function useNonce(uint192 key) external returns (uint256 keyNonce);

  /// @notice Returns the next unused nonce for an address and key. Result contains the key prefix.
  /// @param owner The address of the nonce over.
  /// @param key The key which specifies lifetime of the nonce.
  /// @return keyNonce The first 24 bytes are for the key, & the last 8 bytes for the nonce.
  function nonces(address owner, uint192 key) external view returns (uint256 keyNonce);
}
