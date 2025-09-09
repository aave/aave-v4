// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';

library SignatureCheckerHelper {
  function isValidSignatureNow(
    address signer,
    bytes32 hash,
    bytes memory signature
  ) external view returns (bool) {
    return SignatureChecker.isValidSignatureNow(signer, hash, signature);
  }
}
