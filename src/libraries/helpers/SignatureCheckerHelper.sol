// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';

/**
 * @notice Simple wrapper library for OpenZeppelin's SignatureChecker to expose `isValidSignatureNow` externally.
 */
library SignatureCheckerHelper {
  /**
   * @dev Checks if a signature is valid for a given signer and data hash. If the signer is a smart contract, the
   * signature is validated against that smart contract using ERC-1271, otherwise it's validated using `ECDSA.recover`.
   *
   * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
   * change through time. It could return true at block N and false at block N+1 (or the opposite).
   */
  function isValidSignatureNow(
    address signer,
    bytes32 hash,
    bytes memory signature
  ) external view returns (bool) {
    return SignatureChecker.isValidSignatureNow(signer, hash, signature);
  }
}
