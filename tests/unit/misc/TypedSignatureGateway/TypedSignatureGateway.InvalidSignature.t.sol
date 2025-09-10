// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/TypedSignatureGateway/TypedSignatureGateway.Base.t.sol';

contract TypedSignatureGatewayInvalidSignatureTest is TypedSignatureGatewayBaseTest {
  function test_supplyWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.Supply memory p = _supplyData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.Withdraw memory p = _withdrawData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_borrowWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.Borrow memory p = _borrowData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_repayWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.Repay memory p = _repayData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_supplyWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.Supply memory p = _supplyData(spoke1, onBehalfOf, deadline);
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.Withdraw memory p = _withdrawData(spoke1, onBehalfOf, deadline);
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_borrowWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    vm.assume(randomUser != alice);
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.Borrow memory p = _borrowData(spoke1, onBehalfOf, deadline);
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_repayWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    vm.assume(randomUser != alice);
    uint256 deadline = vm.randomUint(1, MAX_SKIP_TIME);
    vm.warp(deadline - 1);

    EIP712Types.Repay memory p = _repayData(spoke1, onBehalfOf, deadline);
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_supplyWithSig_revertsWith_InvalidSignature_dueTo_InvalidNonce() public {
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.Supply memory p = _supplyData(spoke1, alice, deadline);
    _consumeRandomNonces(alice);
    p.nonce = vm.randomUint(0, gateway.nonces(alice) - 1);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_InvalidNonce() public {
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.Withdraw memory p = _withdrawData(spoke1, alice, deadline);
    _consumeRandomNonces(alice);
    p.nonce = vm.randomUint(0, gateway.nonces(alice) - 1);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_borrowWithSig_revertsWith_InvalidSignature_dueTo_InvalidNonce() public {
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.Borrow memory p = _borrowData(spoke1, alice, deadline);
    _consumeRandomNonces(alice);
    p.nonce = vm.randomUint(0, gateway.nonces(alice) - 1);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_repayWithSig_revertsWith_InvalidSignature_dueTo_InvalidNonce() public {
    uint256 deadline = _warpAfterRandomDeadline();

    EIP712Types.Repay memory p = _repayData(spoke1, alice, deadline);
    _consumeRandomNonces(alice);
    p.nonce = vm.randomUint(0, gateway.nonces(alice) - 1);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }
}
