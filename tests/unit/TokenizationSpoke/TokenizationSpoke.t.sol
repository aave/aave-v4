// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';

contract TokenizationSpokeTest is TokenizationSpokeBaseTest {
  ITokenizationSpoke public vault;
  TestnetERC20 public asset;

  function setUp() public virtual override {
    super.setUp();
    vault = daiVault;
    asset = TestnetERC20(vault.asset());
  }

  function test_deposit() public {
    address depositor = alice;
    uint256 assets = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    asset.mint(depositor, assets);
    Utils.approve(vault, depositor, assets);

    uint256 alicePreDepositBal = asset.balanceOf(depositor);
    uint256 expectedShares = IHub(vault.hub()).previewAddByAssets(vault.assetId(), assets);

    vm.expectCall(vault.hub(), abi.encodeCall(IHubBase.add, (vault.assetId(), assets)));
    vm.expectEmit(address(vault));
    emit IERC20.Transfer(address(0), depositor, expectedShares);
    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(depositor, depositor, assets, expectedShares);

    vm.prank(depositor);
    uint256 shares = vault.deposit(assets, depositor);

    assertEq(shares, expectedShares);
    assertEq(vault.previewWithdraw(shares), assets);
    assertEq(vault.previewDeposit(assets), shares);
    assertEq(vault.totalSupply(), shares);
    assertEq(vault.totalAssets(), assets);
    assertEq(vault.balanceOf(depositor), expectedShares);
    assertEq(vault.convertToAssets(vault.balanceOf(depositor)), assets);
    assertEq(asset.balanceOf(depositor), alicePreDepositBal - assets);
    _assertVaultHasNoBalanceOrAllowance(vault, depositor);
  }

  function test_deposit_receiverDifferentFromCaller() public {
    address depositor = alice;
    address receiver = bob;
    uint256 assets = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    asset.mint(depositor, assets);
    Utils.approve(vault, depositor, assets);

    uint256 expectedShares = IHub(vault.hub()).previewAddByAssets(vault.assetId(), assets);

    vm.expectCall(vault.hub(), abi.encodeCall(IHubBase.add, (vault.assetId(), assets)));
    vm.expectEmit(address(vault));
    emit IERC20.Transfer(address(0), receiver, expectedShares);
    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(depositor, receiver, assets, expectedShares);

    vm.prank(depositor);
    uint256 shares = vault.deposit(assets, receiver);

    assertEq(shares, expectedShares);
    assertEq(vault.balanceOf(receiver), expectedShares);
    assertEq(vault.balanceOf(depositor), 0);
    _assertVaultHasNoBalanceOrAllowance(vault, depositor);
    _assertVaultHasNoBalanceOrAllowance(vault, receiver);
  }

  function test_mint() public {
    address depositor = alice;
    uint256 shares = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    uint256 expectedAssets = IHub(vault.hub()).previewAddByShares(vault.assetId(), shares);
    asset.mint(depositor, expectedAssets);
    Utils.approve(vault, depositor, expectedAssets);

    uint256 alicePreDepositBal = asset.balanceOf(depositor);

    vm.expectCall(vault.hub(), abi.encodeCall(IHubBase.add, (vault.assetId(), expectedAssets)));
    vm.expectEmit(address(vault));
    emit IERC20.Transfer(address(0), depositor, shares);
    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(depositor, depositor, expectedAssets, shares);

    vm.prank(depositor);
    uint256 assets = vault.mint(shares, depositor);

    assertEq(assets, expectedAssets);
    assertEq(vault.previewWithdraw(shares), assets);
    assertEq(vault.previewDeposit(assets), shares);
    assertEq(vault.totalSupply(), shares);
    assertEq(vault.totalAssets(), assets);
    assertEq(vault.balanceOf(depositor), shares);
    assertEq(vault.convertToAssets(vault.balanceOf(depositor)), assets);
    assertEq(asset.balanceOf(depositor), alicePreDepositBal - assets);
    _assertVaultHasNoBalanceOrAllowance(vault, depositor);
  }

  function test_mint_receiverDifferentFromCaller() public {
    address depositor = alice;
    address receiver = bob;
    uint256 shares = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    uint256 expectedAssets = IHub(vault.hub()).previewAddByShares(vault.assetId(), shares);
    asset.mint(depositor, expectedAssets);
    Utils.approve(vault, depositor, expectedAssets);

    vm.expectCall(vault.hub(), abi.encodeCall(IHubBase.add, (vault.assetId(), expectedAssets)));
    vm.expectEmit(address(vault));
    emit IERC20.Transfer(address(0), receiver, shares);
    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(depositor, receiver, expectedAssets, shares);

    vm.prank(depositor);
    uint256 assets = vault.mint(shares, receiver);

    assertEq(assets, expectedAssets);
    assertEq(vault.balanceOf(receiver), shares);
    assertEq(vault.balanceOf(depositor), 0);
    _assertVaultHasNoBalanceOrAllowance(vault, depositor);
    _assertVaultHasNoBalanceOrAllowance(vault, receiver);
  }

  function test_withdraw() public {
    address owner = alice;
    uint256 depositAssets = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    asset.mint(owner, depositAssets);
    Utils.approve(vault, owner, depositAssets);
    vm.prank(owner);
    vault.deposit(depositAssets, owner);

    uint256 alicePreWithdrawBal = asset.balanceOf(owner);
    uint256 withdrawAssets = depositAssets;
    uint256 expectedShares = IHub(vault.hub()).previewRemoveByAssets(
      vault.assetId(),
      withdrawAssets
    );

    vm.expectCall(
      vault.hub(),
      abi.encodeCall(IHubBase.remove, (vault.assetId(), withdrawAssets, owner))
    );
    vm.expectEmit(address(vault));
    emit IERC20.Transfer(owner, address(0), expectedShares);
    vm.expectEmit(address(vault));
    emit IERC4626.Withdraw(owner, owner, owner, withdrawAssets, expectedShares);

    vm.prank(owner);
    uint256 shares = vault.withdraw(withdrawAssets, owner, owner);

    assertEq(shares, expectedShares);
    assertEq(vault.totalAssets(), 0);
    assertEq(vault.balanceOf(owner), 0);
    assertEq(vault.convertToAssets(vault.balanceOf(owner)), 0);
    assertEq(asset.balanceOf(owner), alicePreWithdrawBal + withdrawAssets);
    _assertVaultHasNoBalanceOrAllowance(vault, owner);
  }

  function test_withdraw_ownerDifferentFromCaller() public {
    address owner = alice;
    address caller = bob;
    address receiver = carol;
    uint256 depositAssets = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    asset.mint(owner, depositAssets);
    Utils.approve(vault, owner, depositAssets);
    vm.prank(owner);
    uint256 depositedShares = vault.deposit(depositAssets, owner);

    vm.prank(owner);
    vault.approve(caller, depositedShares);

    uint256 withdrawAssets = depositAssets;
    uint256 expectedShares = IHub(vault.hub()).previewRemoveByAssets(
      vault.assetId(),
      withdrawAssets
    );

    vm.expectCall(
      vault.hub(),
      abi.encodeCall(IHubBase.remove, (vault.assetId(), withdrawAssets, receiver))
    );
    vm.expectEmit(address(vault));
    emit IERC20.Transfer(owner, address(0), expectedShares);
    vm.expectEmit(address(vault));
    emit IERC4626.Withdraw(caller, receiver, owner, withdrawAssets, expectedShares);

    vm.prank(caller);
    uint256 shares = vault.withdraw(withdrawAssets, receiver, owner);

    assertEq(shares, expectedShares);
    assertEq(vault.balanceOf(owner), 0);
    assertEq(vault.allowance(owner, caller), 0);
    _assertVaultHasNoBalanceOrAllowance(vault, owner);
    _assertVaultHasNoBalanceOrAllowance(vault, caller);
    _assertVaultHasNoBalanceOrAllowance(vault, receiver);
  }

  function test_redeem() public {
    address owner = alice;
    uint256 mintShares = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    uint256 mintAssets = IHub(vault.hub()).previewAddByShares(vault.assetId(), mintShares);
    asset.mint(owner, mintAssets);
    Utils.approve(vault, owner, mintAssets);
    vm.prank(owner);
    vault.mint(mintShares, owner);

    uint256 alicePreRedeemBal = asset.balanceOf(owner);
    uint256 redeemShares = mintShares;
    uint256 expectedAssets = IHub(vault.hub()).previewRemoveByShares(vault.assetId(), redeemShares);

    vm.expectCall(
      vault.hub(),
      abi.encodeCall(IHubBase.remove, (vault.assetId(), expectedAssets, owner))
    );
    vm.expectEmit(address(vault));
    emit IERC20.Transfer(owner, address(0), redeemShares);
    vm.expectEmit(address(vault));
    emit IERC4626.Withdraw(owner, owner, owner, expectedAssets, redeemShares);

    vm.prank(owner);
    uint256 assets = vault.redeem(redeemShares, owner, owner);

    assertEq(assets, expectedAssets);
    assertEq(vault.totalAssets(), 0);
    assertEq(vault.balanceOf(owner), 0);
    assertEq(vault.convertToAssets(vault.balanceOf(owner)), 0);
    assertEq(asset.balanceOf(owner), alicePreRedeemBal + assets);
    _assertVaultHasNoBalanceOrAllowance(vault, owner);
  }

  function test_redeem_ownerDifferentFromCaller() public {
    address owner = alice;
    address caller = bob;
    address receiver = carol;
    uint256 mintShares = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    uint256 mintAssets = IHub(vault.hub()).previewAddByShares(vault.assetId(), mintShares);
    asset.mint(owner, mintAssets);
    Utils.approve(vault, owner, mintAssets);
    vm.prank(owner);
    vault.mint(mintShares, owner);

    vm.prank(owner);
    vault.approve(caller, mintShares);

    uint256 redeemShares = mintShares;
    uint256 expectedAssets = IHub(vault.hub()).previewRemoveByShares(vault.assetId(), redeemShares);

    vm.expectCall(
      vault.hub(),
      abi.encodeCall(IHubBase.remove, (vault.assetId(), expectedAssets, receiver))
    );
    vm.expectEmit(address(vault));
    emit IERC20.Transfer(owner, address(0), redeemShares);
    vm.expectEmit(address(vault));
    emit IERC4626.Withdraw(caller, receiver, owner, expectedAssets, redeemShares);

    vm.prank(caller);
    uint256 assets = vault.redeem(redeemShares, receiver, owner);

    assertEq(assets, expectedAssets);
    assertEq(vault.balanceOf(owner), 0);
    assertEq(vault.allowance(owner, caller), 0);
    _assertVaultHasNoBalanceOrAllowance(vault, owner);
    _assertVaultHasNoBalanceOrAllowance(vault, caller);
    _assertVaultHasNoBalanceOrAllowance(vault, receiver);
  }
}
