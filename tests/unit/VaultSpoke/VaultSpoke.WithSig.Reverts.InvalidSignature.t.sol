// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/VaultSpoke/VaultSpoke.Base.t.sol';

contract VaultSpokeWithSigInvalidSignatureTest is VaultSpokeBaseTest {
  IVaultSpoke public vault;

  function setUp() public virtual override {
    super.setUp();
    vault = daiVault;
  }

  function test_depositWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    EIP712Types.VaultDeposit memory p = _depositData(vault, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.depositWithSig(p, signature);
  }

  function test_mintWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    EIP712Types.VaultMint memory p = _mintData(vault, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.mintWithSig(p, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    EIP712Types.VaultWithdraw memory p = _withdrawData(vault, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.withdrawWithSig(p, signature);
  }

  function test_redeemWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    EIP712Types.VaultRedeem memory p = _redeemData(vault, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.redeemWithSig(p, signature);
  }

  function test_depositWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address depositor = vm.randomAddress();
    while (depositor == randomUser) depositor = vm.randomAddress();

    EIP712Types.VaultDeposit memory p = _depositData(vault, depositor, _warpAfterRandomDeadline());
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(vault, p));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.depositWithSig(p, signature);
  }

  function test_mintWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address depositor = vm.randomAddress();
    while (depositor == randomUser) depositor = vm.randomAddress();

    EIP712Types.VaultMint memory p = _mintData(vault, depositor, _warpAfterRandomDeadline());
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(vault, p));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.mintWithSig(p, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address owner = vm.randomAddress();
    while (owner == randomUser) owner = vm.randomAddress();

    EIP712Types.VaultWithdraw memory p = _withdrawData(vault, owner, _warpAfterRandomDeadline());
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(vault, p));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.withdrawWithSig(p, signature);
  }

  function test_redeemWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address owner = vm.randomAddress();
    while (owner == randomUser) owner = vm.randomAddress();

    EIP712Types.VaultRedeem memory p = _redeemData(vault, owner, _warpAfterRandomDeadline());
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(vault, p));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.redeemWithSig(p, signature);
  }

  function test_depositWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    EIP712Types.VaultDeposit memory p = _depositData(vault, alice, _warpBeforeRandomDeadline());
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(vault, p.depositor, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(vault, p.depositor, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.depositor, currentNonce)
    );
    vm.prank(vm.randomAddress());
    vault.depositWithSig(p, signature);
  }

  function test_mintWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    EIP712Types.VaultMint memory p = _mintData(vault, alice, _warpBeforeRandomDeadline());
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(vault, p.depositor, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(vault, p.depositor, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.depositor, currentNonce)
    );
    vm.prank(vm.randomAddress());
    vault.mintWithSig(p, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    EIP712Types.VaultWithdraw memory p = _withdrawData(vault, alice, _warpBeforeRandomDeadline());
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(vault, p.owner, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(vault, p.owner, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.owner, currentNonce)
    );
    vm.prank(vm.randomAddress());
    vault.withdrawWithSig(p, signature);
  }

  function test_redeemWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    EIP712Types.VaultRedeem memory p = _redeemData(vault, alice, _warpBeforeRandomDeadline());
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(vault, p.owner, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(vault, p.owner, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.owner, currentNonce)
    );
    vm.prank(vm.randomAddress());
    vault.redeemWithSig(p, signature);
  }
}
