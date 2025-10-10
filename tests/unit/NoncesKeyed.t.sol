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

  function test_symbolic_useNonce_monotonic(bytes32) public {
    vm.setArbitraryStorage(address(mock));

    address owner = vm.randomAddress();
    uint192 key = _randomNonceKey();

    uint256 keyNonce = mock.nonces(owner, key);

    vm.prank(owner);
    uint256 consumedKeyNonce = mock.useNonce(key);

    assertEq(consumedKeyNonce, keyNonce);
    _assertNonceIncrement(mock, owner, keyNonce);
  }

  function test_symbolic_useCheckedNonce_monotonic(bytes32) public {
    vm.setArbitraryStorage(address(mock));

    address owner = vm.randomAddress();
    uint192 key = _randomNonceKey();

    uint256 keyNonce = mock.nonces(owner, key);

    mock.useCheckedNonce(owner, keyNonce);

    _assertNonceIncrement(mock, owner, keyNonce);
  }

  function test_symbolic_useCheckedNonce_revertsWith_InvalidAccountNonce(bytes32) public {
    vm.setArbitraryStorage(address(mock));

    address owner = vm.randomAddress();
    uint192 key = _randomNonceKey();

    uint256 currentKeyNonce = mock.nonces(owner, key);
    (, uint64 currentNonce) = _unpackNonce(currentKeyNonce);
    uint64 invalidNonce = _randomNonce();
    vm.assume(currentNonce != invalidNonce);
    uint256 invalidKeyNonce = _packNonce(key, invalidNonce);

    (bool ok, bytes memory ret) = address(mock).call(
      abi.encodeCall(mock.useCheckedNonce, (owner, invalidKeyNonce))
    );
    assertFalse(ok);
    assertEq(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, owner, currentKeyNonce),
      ret
    );
  }
}
