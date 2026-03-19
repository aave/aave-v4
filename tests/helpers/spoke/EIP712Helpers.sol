// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {INoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {EIP712Types} from 'tests/helpers/mocks/EIP712Types.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

/// @title EIP712Helpers
/// @notice EIP-712 signing and nonce utilities for the Aave V4 test suite.
abstract contract EIP712Helpers is Test {
  using SafeCast for *;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     SIGNING HELPERS                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _getTypedDataHash(
    TestnetERC20 token,
    EIP712Types.Permit memory permit
  ) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          token.DOMAIN_SEPARATOR(),
          vm.eip712HashStruct('Permit', abi.encode(permit))
        )
      );
  }

  function _getTypedDataHash(
    ISpoke spoke,
    ISpoke.SetUserPositionManagers memory setUserPositionManagers
  ) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          spoke.DOMAIN_SEPARATOR(),
          vm.eip712HashStruct('SetUserPositionManagers', abi.encode(setUserPositionManagers))
        )
      );
  }

  function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
    return abi.encodePacked(r, s, v);
  }

  function _warpAfterRandomDeadline(uint256 maxSkipTime) internal returns (uint256) {
    uint256 deadline = vm.randomUint(0, maxSkipTime - 1);
    vm.warp(vm.randomUint(deadline + 1, maxSkipTime));
    return deadline;
  }

  function _warpBeforeRandomDeadline(uint256 maxSkipTime) internal returns (uint256) {
    uint256 deadline = vm.randomUint(1, maxSkipTime);
    vm.warp(vm.randomUint(0, deadline - 1));
    return deadline;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     NONCE UTILITIES                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _burnRandomNoncesAtKey(
    INoncesKeyed verifier,
    address user,
    uint192 key
  ) internal returns (uint256) {
    uint256 currentKeyNonce = verifier.nonces(user, key);
    (, uint64 nonce) = _unpackNonce(currentKeyNonce);

    uint64 toBurn = vm.randomUint(1, 100).toUint64();
    for (uint256 i; i < toBurn; ++i) {
      vm.prank(user);
      verifier.useNonce(key);
    }
    uint256 newKeyNonce = _packNonce(key, nonce + toBurn);

    assertEq(verifier.nonces(user, key), newKeyNonce);
    return newKeyNonce;
  }

  function _burnRandomNoncesAtKey(INoncesKeyed verifier, address user) internal returns (uint256) {
    return _burnRandomNoncesAtKey(verifier, user, _randomNonceKey());
  }

  function _getRandomInvalidNonceAtKey(
    INoncesKeyed verifier,
    address user,
    uint192 key
  ) internal returns (uint256) {
    (uint192 currentKey, uint64 currentNonce) = _unpackNonce(verifier.nonces(user, key));
    assertEq(currentKey, key);
    uint64 nonce = _randomNonce();
    while (currentNonce == nonce) nonce = _randomNonce();
    return _packNonce(key, nonce);
  }

  function _getRandomNonceAtKey(uint192 key) internal returns (uint256) {
    uint64 nonce = _randomNonce();
    return _packNonce(key, nonce);
  }

  function _randomNonceKey() internal returns (uint192) {
    return uint192(vm.randomUint());
  }

  function _randomNonce() internal returns (uint64) {
    return uint64(vm.randomUint());
  }

  function _assertNonceIncrement(
    INoncesKeyed verifier,
    address who,
    uint256 prevKeyNonce
  ) internal view {
    (uint192 currentKey, ) = _unpackNonce(prevKeyNonce);
    assertEq(verifier.nonces(who, currentKey), _getNextNoncePacked(prevKeyNonce));
  }

  function _getNextNoncePacked(uint256 currentKeyNonce) internal pure returns (uint256) {
    (uint192 nonceKey, uint64 nonce) = _unpackNonce(currentKeyNonce);
    // prettier-ignore
    unchecked { ++nonce; }
    return _packNonce(nonceKey, nonce);
  }

  function _packNonce(uint192 key, uint64 nonce) internal pure returns (uint256) {
    return (uint256(key) << 64) | nonce;
  }

  function _unpackNonce(uint256 keyNonce) internal pure returns (uint192 key, uint64 nonce) {
    return (uint192(keyNonce >> 64), uint64(keyNonce));
  }
}
