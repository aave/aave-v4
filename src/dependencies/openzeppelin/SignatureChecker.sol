// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (utils/cryptography/SignatureChecker.sol)

pragma solidity ^0.8.24;

import {ECDSA} from './ECDSA.sol';
import {IERC1271} from './IERC1271.sol';

/**
 * @dev Signature verification helper that can be used instead of `ECDSA.recover` to seamlessly support:
 *
 * * ECDSA signatures from externally owned accounts (EOAs)
 * * ERC-1271 signatures from smart contract wallets like Argent and Safe Wallet (previously Gnosis Safe)
 * * ERC-7913 signatures from keys that do not have an Ethereum address of their own
 *
 * See https://eips.ethereum.org/EIPS/eip-1271[ERC-1271] and https://eips.ethereum.org/EIPS/eip-7913[ERC-7913].
 */
library SignatureChecker {
  /**
   * @dev Checks if a signature is valid for a given signer and data hash. If the signer has code, the
   * signature is validated against it using ERC-1271, otherwise it's validated using `ECDSA.recover`.
   *
   * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
   * change through time. It could return true at block N and false at block N+1 (or the opposite).
   *
   * NOTE: For an extended version of this function that supports ERC-7913 signatures, see {isValidSignatureNow-bytes-bytes32-bytes-}.
   */
  function isValidSignatureNow(
    address signer,
    bytes32 hash,
    bytes memory signature
  ) internal view returns (bool) {
    if (signer.code.length == 0) {
      (address recovered, ECDSA.RecoverError err, ) = ECDSA.tryRecover(hash, signature);
      return err == ECDSA.RecoverError.NoError && recovered == signer;
    } else {
      return isValidERC1271SignatureNow(signer, hash, signature);
    }
  }

  /**
   * @dev Checks if a signature is valid for a given signer and data hash. The signature is validated
   * against the signer smart contract using ERC-1271.
   *
   * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
   * change through time. It could return true at block N and false at block N+1 (or the opposite).
   */
  function isValidERC1271SignatureNow(
    address signer,
    bytes32 hash,
    bytes memory signature
  ) internal view returns (bool result) {
    bytes4 selector = IERC1271.isValidSignature.selector;
    uint256 length = signature.length;

    assembly ('memory-safe') {
      // Encoded calldata is :
      // [ 0x00 - 0x03 ] <selector>
      // [ 0x04 - 0x23 ] <hash>
      // [ 0x24 - 0x44 ] <signature offset> (0x40)
      // [ 0x44 - 0x64 ] <signature length>
      // [ 0x64 - ...  ] <signature data>
      let ptr := mload(0x40)
      mstore(ptr, selector)
      mstore(add(ptr, 0x04), hash)
      mstore(add(ptr, 0x24), 0x40)
      mcopy(add(ptr, 0x44), signature, add(length, 0x20))

      let success := staticcall(gas(), signer, ptr, add(length, 0x64), 0, 0x20)
      result := and(success, and(gt(returndatasize(), 0x19), eq(mload(0x00), selector)))
    }
  }
}
