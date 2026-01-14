// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {IIntentConsumer} from 'src/interfaces/IIntentConsumer.sol';

abstract contract IntentConsumer is IIntentConsumer, NoncesKeyed, EIP712 {
  /// @inheritdoc IIntentConsumer
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
  }

  /// @dev Verifies the signature for given signer & intent hash, and consumes the keyed-nonce.
  /// @param signer The address of the user.
  /// @param intentHash The hash of the intent struct.
  /// @param nonce The keyed-nonce for the intent.
  /// @param deadline The deadline timestamp for the intent.
  /// @param signature The signature bytes.
  function _verifyAndConsumeIntent(
    address signer,
    bytes32 intentHash,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) internal {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(intentHash);
    require(SignatureChecker.isValidSignatureNow(signer, digest, signature), InvalidSignature());
    _useCheckedNonce(signer, nonce);
  }
}
