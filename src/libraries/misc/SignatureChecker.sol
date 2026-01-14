// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SignatureChecker as OpenZeppelinSignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';

/// @title SignatureChecker
/// @author Aave Labs
library SignatureChecker {
  /// @notice Checks if a signature is valid for a given signer and data hash.
  /// @dev External wrapper around OpenZeppelin's SignatureChecker.isValidSignatureNow to reduce code size at the expense of an external delegatecall.
  /// @param signer The address of the signer.
  /// @param hash The hash of the data to be signed.
  /// @param signature The signature bytes.
  /// @return True if the signature is valid, false otherwise.
  function isValidSignatureNowCalldata(
    address signer,
    bytes32 hash,
    bytes calldata signature
  ) external view returns (bool) {
    return OpenZeppelinSignatureChecker.isValidSignatureNowCalldata(signer, hash, signature);
  }
}
