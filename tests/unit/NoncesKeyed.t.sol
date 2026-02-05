// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

import 'tests/Base.t.sol';

contract NoncesKeyedTest is Base {
  using SafeCast for *;
  MockNoncesKeyed public mock;

  uint64 internal constant MAX_NONCE = type(uint64).max;

  function setUp() public override {
    mock = new MockNoncesKeyed();
  }

  function test_useNonce_monotonic(bytes32) public {
    vm.setArbitraryStorage(address(mock));

    address owner = vm.randomAddress();
    uint192 key = _randomNonceKey();

    uint256 keyNonce = mock.nonces(owner, key);

    vm.prank(owner);
    uint256 consumedKeyNonce = mock.useNonce(key);

    assertEq(consumedKeyNonce, keyNonce);
    _assertNonceIncrement(mock, owner, keyNonce);
  }

  function test_useCheckedNonce_monotonic(bytes32) public {
    vm.setArbitraryStorage(address(mock));

    address owner = vm.randomAddress();
    uint192 key = _randomNonceKey();

    uint256 keyNonce = mock.nonces(owner, key);

    mock.useCheckedNonce(owner, keyNonce);

    _assertNonceIncrement(mock, owner, keyNonce);
  }

  function test_useCheckedNonce_revertsWith_InvalidAccountNonce(bytes32) public {
    vm.setArbitraryStorage(address(mock));

    address owner = vm.randomAddress();
    uint192 key = _randomNonceKey();

    uint256 currentNonce = _burnRandomNoncesAtKey(mock, owner, key);
    uint256 invalidNonce = _getRandomInvalidNonceAtKey(mock, owner, key);

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, owner, currentNonce)
    );
    mock.useCheckedNonce(owner, invalidNonce);
  }

  function test_useNonce_revertsOnOverflow() public {
    address owner = vm.randomAddress();
    uint192 key = _randomNonceKey();

    mock.setNonce(owner, key, MAX_NONCE);
    assertEq(mock.nonces(owner, key), _packNonce(key, MAX_NONCE));

    vm.prank(owner);
    vm.expectRevert();
    mock.useNonce(key);
  }

  function test_useCheckedNonce_revertsOnOverflow() public {
    address owner = vm.randomAddress();
    uint192 key = _randomNonceKey();

    mock.setNonce(owner, key, MAX_NONCE);
    assertEq(mock.nonces(owner, key), _packNonce(key, MAX_NONCE));

    uint256 keyNonce = mock.nonces(owner, key);

    vm.expectRevert();
    mock.useCheckedNonce(owner, keyNonce);
  }
}
