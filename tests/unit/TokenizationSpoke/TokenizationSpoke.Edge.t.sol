// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';

contract TokenizationSpokeEdgeTest is TokenizationSpokeBaseTest {
  ITokenizationSpoke public vault;
  TestnetERC20 public asset;

  function setUp() public virtual override {
    super.setUp();
    vault = daiVault;
    asset = TestnetERC20(vault.asset());
  }

  function test_vaultInteractionsForSomeoneElse() public {
    // init 2 users with a 1e18 balance
    uint256 amount = 1e18;
    asset.mint(alice, amount);
    asset.mint(bob, amount);

    uint256 aliceInitialBalance = asset.balanceOf(alice);
    uint256 bobInitialBalance = asset.balanceOf(bob);

    vm.prank(alice);
    asset.approve(address(vault), amount);

    vm.prank(bob);
    asset.approve(address(vault), amount);

    // alice deposits 1e18 for bob
    vm.prank(alice);
    uint256 bobShares = vault.deposit(amount, bob);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), bobShares);
    assertEq(asset.balanceOf(alice), aliceInitialBalance - amount);

    // bob mint bobShares for alice
    uint256 assetsForMint = vault.previewMint(bobShares);
    vm.prank(bob);
    vault.mint(bobShares, alice);
    assertEq(vault.balanceOf(alice), bobShares);
    assertEq(vault.balanceOf(bob), bobShares);
    assertEq(asset.balanceOf(bob), bobInitialBalance - assetsForMint);

    // alice redeem bobShares for bob
    vm.prank(alice);
    uint256 redeemedAssets = vault.redeem(bobShares, bob, alice);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.balanceOf(bob), bobShares);
    assertEq(asset.balanceOf(bob), bobInitialBalance - assetsForMint + redeemedAssets);

    // bob withdraw redeemedAssets for alice
    vm.prank(bob);
    vault.withdraw(redeemedAssets, alice, bob);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(asset.balanceOf(alice), aliceInitialBalance - amount + redeemedAssets);

    _assertVaultHasNoBalanceOrAllowance(vault, alice);
    _assertVaultHasNoBalanceOrAllowance(vault, bob);
  }

  function test_singleDepositWithdraw() public {
    address depositor = alice;
    uint256 assets = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    asset.mint(depositor, assets);
    Utils.approve(vault, depositor, assets);

    uint256 alicePreDepositBal = asset.balanceOf(depositor);

    vm.prank(depositor);
    uint256 shares = vault.deposit(assets, depositor);

    assertEq(vault.previewWithdraw(shares), assets);
    assertEq(vault.previewDeposit(assets), shares);
    assertEq(vault.totalSupply(), shares);
    assertEq(vault.totalAssets(), assets);
    assertEq(vault.balanceOf(depositor), shares);
    assertEq(vault.convertToAssets(vault.balanceOf(depositor)), assets);
    assertEq(asset.balanceOf(depositor), alicePreDepositBal - assets);

    vm.prank(depositor);
    vault.withdraw(assets, depositor, depositor);

    assertEq(vault.totalAssets(), 0);
    assertEq(vault.balanceOf(depositor), 0);
    assertEq(vault.convertToAssets(vault.balanceOf(depositor)), 0);
    assertEq(asset.balanceOf(depositor), alicePreDepositBal);
    _assertVaultHasNoBalanceOrAllowance(vault, depositor);
  }

  function test_singleMintRedeem() public {
    address depositor = alice;
    uint256 shares = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    uint256 expectedAssets = IHub(vault.hub()).previewAddByShares(vault.assetId(), shares);
    asset.mint(depositor, expectedAssets);
    Utils.approve(vault, depositor, expectedAssets);

    uint256 alicePreDepositBal = asset.balanceOf(depositor);

    vm.prank(depositor);
    uint256 assets = vault.mint(shares, depositor);

    assertEq(vault.previewWithdraw(shares), assets);
    assertEq(vault.previewDeposit(assets), shares);
    assertEq(vault.totalSupply(), shares);
    assertEq(vault.totalAssets(), assets);
    assertEq(vault.balanceOf(depositor), shares);
    assertEq(vault.convertToAssets(vault.balanceOf(depositor)), assets);
    assertEq(asset.balanceOf(depositor), alicePreDepositBal - assets);

    vm.prank(depositor);
    vault.redeem(shares, depositor, depositor);

    assertEq(vault.totalAssets(), 0);
    assertEq(vault.balanceOf(depositor), 0);
    assertEq(vault.convertToAssets(vault.balanceOf(depositor)), 0);
    assertEq(asset.balanceOf(depositor), alicePreDepositBal);
    _assertVaultHasNoBalanceOrAllowance(vault, depositor);
  }

  function test_multipleMintDepositRedeemWithdraw() public {
    uint256 mutationAmount = 3000;

    asset.mint(alice, 4000);
    asset.mint(bob, 7001);

    vm.prank(alice);
    asset.approve(address(vault), 4000);
    vm.prank(bob);
    asset.approve(address(vault), 7001);

    // 1. Alice mints 2000 shares
    vm.prank(alice);
    uint256 aliceAssets = vault.mint(2000, alice);
    uint256 aliceShares = vault.previewDeposit(aliceAssets);
    assertEq(aliceShares, 2000);
    assertEq(vault.balanceOf(alice), aliceShares);

    // 2. Bob deposits 4000 tokens
    vm.prank(bob);
    uint256 bobShares = vault.deposit(4000, bob);
    assertEq(vault.totalSupply(), aliceShares + bobShares);

    // 3. Yield accrues via Hub drawnIndex mechanism
    _simulateYield(vault, mutationAmount);

    // Verify share values increased
    assertGt(vault.convertToAssets(vault.balanceOf(alice)), aliceAssets);
    assertGt(vault.convertToAssets(vault.balanceOf(bob)), 4000);

    // 4. Alice deposits 2000 more tokens
    vm.prank(alice);
    vault.deposit(2000, alice);

    // 5. Bob mints 2000 more shares
    vm.prank(bob);
    vault.mint(2000, bob);

    // 6. More yield accrues
    _simulateYield(vault, mutationAmount);

    // 7-10. Gradual redemption/withdrawal
    uint256 aliceSharesBefore = vault.balanceOf(alice);
    vm.prank(alice);
    vault.redeem(aliceSharesBefore / 2, alice, alice);

    uint256 bobAssetsBefore = vault.convertToAssets(vault.balanceOf(bob));
    vm.prank(bob);
    vault.withdraw(bobAssetsBefore / 3, bob, bob);

    // Alice withdraws remaining
    uint256 aliceRemainingAssets = vault.convertToAssets(vault.balanceOf(alice));
    vm.prank(alice);
    vault.withdraw(aliceRemainingAssets, alice, alice);
    assertEq(vault.balanceOf(alice), 0);

    // Bob redeems remaining
    uint256 bobRemainingShares = vault.balanceOf(bob);
    vm.prank(bob);
    vault.redeem(bobRemainingShares, bob, bob);
    assertEq(vault.balanceOf(bob), 0);

    // Vault should be empty (or near-empty due to rounding)
    assertLe(vault.totalSupply(), 1);
    assertEq(asset.balanceOf(address(vault)), 0);
  }

  function test_depositZero_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    vault.deposit(0, alice);
  }

  function test_mintZero_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    vault.mint(0, alice);
  }

  function test_withdrawZero_revertsWith_InvalidAmount() public {
    uint256 assets = 1e18;
    asset.mint(alice, assets);
    Utils.approve(vault, alice, assets);
    vm.prank(alice);
    vault.deposit(assets, alice);

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    vault.withdraw(0, alice, alice);
  }

  function test_redeemZero_revertsWith_InvalidAmount() public {
    uint256 assets = 1e18;
    asset.mint(alice, assets);
    Utils.approve(vault, alice, assets);
    vm.prank(alice);
    vault.deposit(assets, alice);

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    vault.redeem(0, alice, alice);
  }

  function test_deposit_revertsWith_ERC20InsufficientAllowance_noApproval() public {
    uint256 assets = 1e18;
    asset.mint(alice, assets);

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(vault),
        0,
        assets
      )
    );
    vm.prank(alice);
    vault.deposit(assets, alice);
  }

  function test_mint_revertsWith_ERC20InsufficientAllowance_noApproval() public {
    uint256 shares = 1e18;
    uint256 neededAssets = IHub(vault.hub()).previewAddByShares(vault.assetId(), shares);
    asset.mint(alice, neededAssets);

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(vault),
        0,
        neededAssets
      )
    );
    vm.prank(alice);
    vault.mint(shares, alice);
  }

  function test_withdraw_revertsWith_ERC20InsufficientBalance_noBalance() public {
    uint256 assets = 1e18;
    uint256 shares = vault.previewWithdraw(assets);

    vm.expectRevert(
      abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, shares)
    );
    vm.prank(alice);
    vault.withdraw(assets, alice, alice);
  }

  function test_redeem_revertsWith_ERC20InsufficientBalance_noShares() public {
    uint256 shares = 1e18;

    vm.expectRevert(
      abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, shares)
    );
    vm.prank(alice);
    vault.redeem(shares, alice, alice);
  }

  function test_withdraw_revertsWith_ERC20InsufficientBalance() public {
    uint256 depositAssets = 1e18;
    asset.mint(alice, depositAssets);
    Utils.approve(vault, alice, depositAssets);
    vm.prank(alice);
    vault.deposit(depositAssets, alice);

    uint256 withdrawAssets = depositAssets + 1;
    uint256 aliceShares = vault.balanceOf(alice);
    uint256 neededShares = vault.previewWithdraw(withdrawAssets);

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        alice,
        aliceShares,
        neededShares
      )
    );
    vm.prank(alice);
    vault.withdraw(withdrawAssets, alice, alice);
  }

  function test_redeem_revertsWith_ERC20InsufficientBalance_on_InsufficientShares() public {
    uint256 depositAssets = 1e18;
    asset.mint(alice, depositAssets);
    Utils.approve(vault, alice, depositAssets);
    vm.prank(alice);
    uint256 shares = vault.deposit(depositAssets, alice);

    uint256 redeemShares = shares + 1;

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        alice,
        shares,
        redeemShares
      )
    );
    vm.prank(alice);
    vault.redeem(redeemShares, alice, alice);
  }

  function test_withdraw_revertsWith_ERC20InsufficientAllowance_callerNotOwner() public {
    uint256 depositAssets = 1e18;
    asset.mint(alice, depositAssets);
    Utils.approve(vault, alice, depositAssets);
    vm.prank(alice);
    vault.deposit(depositAssets, alice);

    uint256 shares = vault.previewWithdraw(depositAssets);
    vm.expectRevert(
      abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, shares)
    );
    vm.prank(bob);
    vault.withdraw(depositAssets, bob, alice);
  }

  function test_redeem_revertsWith_ERC20InsufficientAllowance_callerNotOwner() public {
    uint256 depositAssets = 1e18;
    asset.mint(alice, depositAssets);
    Utils.approve(vault, alice, depositAssets);
    vm.prank(alice);
    uint256 shares = vault.deposit(depositAssets, alice);

    vm.expectRevert(
      abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, shares)
    );
    vm.prank(bob);
    vault.redeem(shares, bob, alice);
  }
}
