// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';

contract TokenizationSpokeWithSigTest is TokenizationSpokeBaseTest {
  using SafeCast for *;

  ITokenizationSpoke public vault;

  function setUp() public virtual override {
    super.setUp();
    vault = daiVault;
  }

  function test_useNonce_monotonic(bytes32) public {
    vm.setArbitraryStorage(address(vault));
    address user = vm.randomAddress();
    uint192 nonceKey = vm.randomUint(0, type(uint192).max).toUint192();

    (, uint64 nonce) = _unpackNonce(vault.nonces(user, nonceKey));

    vm.prank(user);
    vault.useNonce(nonceKey);

    // prettier-ignore
    unchecked { ++nonce; }
    assertEq(vault.nonces(user, nonceKey), _packNonce(nonceKey, nonce));
  }

  function test_depositWithSig(bytes32) public {
    ITokenizationSpoke.TokenizedDeposit memory p = _depositData(
      vault,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.nonce = _burnRandomNoncesAtKey(vault, p.depositor);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));
    Utils.approve(vault, alice, p.assets);

    uint256 shares = IHub(vault.hub()).previewAddByAssets(vault.assetId(), p.assets);

    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(p.depositor, p.receiver, p.assets, shares);

    vm.prank(vm.randomAddress());
    uint256 returnShares = vault.depositWithSig(p, signature);

    assertEq(returnShares, shares);
    _assertNonceIncrement(vault, alice, p.nonce);
    _assertVaultHasNoBalanceOrAllowance(vault, alice);
  }

  function test_mintWithSig(bytes32) public {
    ITokenizationSpoke.TokenizedMint memory p = _mintData(
      vault,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.nonce = _burnRandomNoncesAtKey(vault, p.depositor);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));
    Utils.approve(vault, alice, p.shares);

    uint256 assets = IHub(vault.hub()).previewAddByShares(vault.assetId(), p.shares);

    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(p.depositor, p.receiver, p.shares, assets);

    vm.prank(vm.randomAddress());
    uint256 returnAssets = vault.mintWithSig(p, signature);

    assertEq(returnAssets, assets);
    _assertNonceIncrement(vault, alice, p.nonce);
    _assertVaultHasNoBalanceOrAllowance(vault, alice);
  }

  function test_withdrawWithSig(bytes32) public {
    ITokenizationSpoke.TokenizedWithdraw memory p = _withdrawData(
      vault,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.nonce = _burnRandomNoncesAtKey(vault, p.owner);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));
    Utils.approve(vault, alice, p.assets);
    vm.prank(alice);
    vault.deposit(p.assets, alice);

    uint256 shares = IHub(vault.hub()).previewAddByAssets(vault.assetId(), p.assets);

    vm.expectEmit(address(vault));
    emit IERC4626.Withdraw(p.owner, p.receiver, p.owner, p.assets, shares);

    vm.prank(vm.randomAddress());
    uint256 returnShares = vault.withdrawWithSig(p, signature);

    assertEq(returnShares, shares);
    _assertNonceIncrement(vault, alice, p.nonce);
    _assertVaultHasNoBalanceOrAllowance(vault, alice);
  }

  function test_redeemWithSig(bytes32) public {
    ITokenizationSpoke.TokenizedRedeem memory p = _redeemData(
      vault,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.nonce = _burnRandomNoncesAtKey(vault, p.owner);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));
    Utils.approve(vault, alice, p.shares);
    vm.prank(alice);
    vault.mint(p.shares, alice);

    uint256 assets = IHub(vault.hub()).previewAddByShares(vault.assetId(), p.shares);

    vm.expectEmit(address(vault));
    emit IERC4626.Withdraw(p.owner, p.receiver, p.owner, p.shares, assets);

    vm.prank(vm.randomAddress());
    uint256 returnAssets = vault.redeemWithSig(p, signature);

    assertEq(returnAssets, assets);
    _assertNonceIncrement(vault, alice, p.nonce);
    _assertVaultHasNoBalanceOrAllowance(vault, alice);
  }
}
