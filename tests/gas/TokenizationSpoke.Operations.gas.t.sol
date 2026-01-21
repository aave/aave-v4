// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';

/// forge-config: default.isolate = true
contract TokenizationSpokeOperations_Gas_Tests is TokenizationSpokeBaseTest {
  string internal constant NAMESPACE = 'TokenizationSpoke.Operations';
  ITokenizationSpoke internal vault;

  function setUp() public virtual override {
    super.setUp();
    vault = daiVault;
    Utils.approve(vault, alice, 2100e18);
    vm.prank(alice);
    vault.deposit(100e18, alice);
  }

  function test_deposit() public {
    vm.prank(alice);
    vault.deposit(1000e18, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'deposit');
  }

  function test_mint() public {
    uint256 shares = vault.previewMint(1000e18);
    vm.prank(alice);
    vault.mint(shares, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'mint');
  }

  function test_withdraw() public {
    vm.startPrank(alice);
    vault.deposit(1000e18, alice);
    vault.withdraw(500e18, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: self, partial');

    uint256 balance = vault.maxWithdraw(alice);
    vault.withdraw(balance, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: self, full');

    vault.deposit(1000e18, alice);
    vault.approve(bob, 1000e18);
    vm.stopPrank();

    vm.startPrank(bob);
    vault.withdraw(500e18, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: on behalf, partial');

    balance = vault.maxWithdraw(alice);
    vault.withdraw(balance, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: on behalf, full');
    vm.stopPrank();
  }

  function test_redeem() public {
    vm.startPrank(alice);
    vault.deposit(1000e18, alice);
    uint256 shares = vault.balanceOf(alice);
    vault.redeem(shares / 2, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: self, partial');

    shares = vault.maxRedeem(alice);
    vault.redeem(shares, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: self, full');

    vault.deposit(1000e18, alice);
    vault.approve(bob, 1000e18);
    vm.stopPrank();

    vm.startPrank(bob);
    shares = vault.balanceOf(alice);
    vault.redeem(shares / 2, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: on behalf, partial');

    shares = vault.maxRedeem(alice);
    vault.redeem(shares, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: on behalf, full');
    vm.stopPrank();
  }

  function test_depositWithSig() public {
    ITokenizationSpoke.VaultDeposit memory p = _depositData(
      vault,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.nonce = _burnRandomNoncesAtKey(vault, p.depositor);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));
    Utils.approve(vault, alice, p.assets);

    vm.prank(vm.randomAddress());
    vault.depositWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'depositWithSig');
  }

  function test_mintWithSig() public {
    ITokenizationSpoke.VaultMint memory p = _mintData(vault, alice, _warpBeforeRandomDeadline());
    p.nonce = _burnRandomNoncesAtKey(vault, p.depositor);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));
    Utils.approve(vault, alice, p.shares);

    vm.prank(vm.randomAddress());
    vault.mintWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'mintWithSig');
  }

  function test_withdrawWithSig() public {
    ITokenizationSpoke.VaultWithdraw memory p = _withdrawData(
      vault,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.nonce = _burnRandomNoncesAtKey(vault, p.owner);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));
    Utils.approve(vault, alice, p.assets);
    vm.prank(alice);
    vault.deposit(p.assets, alice);

    vm.prank(vm.randomAddress());
    vault.withdrawWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawWithSig');
  }

  function test_redeemWithSig() public {
    ITokenizationSpoke.VaultRedeem memory p = _redeemData(
      vault,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.nonce = _burnRandomNoncesAtKey(vault, p.owner);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));
    Utils.approve(vault, alice, p.shares);
    vm.prank(alice);
    vault.mint(p.shares, alice);

    vm.prank(vm.randomAddress());
    vault.redeemWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'redeemWithSig');
  }

  function test_permit() public {
    EIP712Types.Permit memory p = _permitData(vault, alice, _warpBeforeRandomDeadline());
    p.nonce = _burnRandomNoncesAtKey(vault, p.owner, vault.PERMIT_NONCE_KEY());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectEmit(address(vault));
    emit IERC20.Approval(p.owner, p.spender, p.value);
    vm.prank(vm.randomAddress());
    vault.permit(p.owner, p.spender, p.value, p.deadline, v, r, s);
    vm.snapshotGasLastCall(NAMESPACE, 'permit');

    assertEq(vault.allowance(p.owner, p.spender), p.value);
  }
}
