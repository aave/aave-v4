// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

import 'tests/Base.t.sol';

contract NoncesKeyedTest is Base {
  using SafeCast for *;
  NoncesKeyedMock public mock;

  function setUp() public override {
    mock = new NoncesKeyedMock();
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
}
