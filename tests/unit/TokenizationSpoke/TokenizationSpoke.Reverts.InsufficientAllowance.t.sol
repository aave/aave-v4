// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';

contract TokenizationSpokeInsufficientAllowanceTest is TokenizationSpokeBaseTest {
  ITokenizationSpoke public vault;

  function setUp() public virtual override {
    super.setUp();
    vault = daiVault;
  }

  function test_deposit_revertsWith_ERC20InsufficientAllowance() public {
    (uint256 amount, uint256 allowance) = _setArbitraryAllowance();
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(vault),
        allowance,
        amount
      )
    );
    vm.prank(alice);
    vault.deposit(amount, alice);
  }

  function test_mint_revertsWith_ERC20InsufficientAllowance() public {
    (uint256 amount, uint256 allowance) = _setArbitraryAllowance();
    uint256 shares = vault.previewMint(amount);

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(vault),
        allowance,
        amount
      )
    );
    vm.prank(alice);
    vault.mint(shares, alice);
  }

  function test_depositWithSig_revertsWith_ERC20InsufficientAllowance() public {
    (uint256 amount, uint256 allowance) = _setArbitraryAllowance();
    uint256 deadline = _warpBeforeRandomDeadline();

    ITokenizationSpoke.TokenizedDeposit memory p = _depositData(vault, alice, deadline);
    p.assets = amount;
    p.nonce = _burnRandomNoncesAtKey(vault, p.depositor);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(vault),
        allowance,
        p.assets
      )
    );
    vm.prank(vm.randomAddress());
    vault.depositWithSig(p, signature);
  }

  function test_mintWithSig_revertsWith_ERC20InsufficientAllowance() public {
    (uint256 amount, uint256 allowance) = _setArbitraryAllowance();
    uint256 deadline = _warpBeforeRandomDeadline();

    ITokenizationSpoke.TokenizedMint memory p = _mintData(vault, alice, deadline);
    p.shares = vault.previewMint(amount);
    p.nonce = _burnRandomNoncesAtKey(vault, p.depositor);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(vault, p));

    uint256 neededAssets = IHub(vault.hub()).previewAddByShares(vault.assetId(), p.shares);

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(vault),
        allowance,
        neededAssets
      )
    );
    vm.prank(vm.randomAddress());
    vault.mintWithSig(p, signature);
  }

  function _setArbitraryAllowance() internal returns (uint256, uint256) {
    uint256 amount = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    uint256 allowance = vm.randomUint(0, amount - 1);
    Utils.approve(vault, alice, allowance);

    return (amount, allowance);
  }
}
