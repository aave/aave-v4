// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/VaultSpoke/VaultSpoke.Base.t.sol';
import {IERC4626} from 'src/dependencies/openzeppelin/IERC4626.sol';

contract VaultSpokeTest is VaultSpokeBaseTest {
  function test_deposit(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    deal(address(tokenList.dai), alice, depositAmount);

    assertEq(tokenList.dai.balanceOf(alice), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(daiVault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(daiVault.balanceOf(alice), 0);

    vm.startPrank(alice);
    tokenList.dai.approve(address(daiVault), depositAmount);
    vm.expectEmit(address(daiVault));
    emit IERC4626.Deposit(alice, alice, depositAmount, depositAmount);
    uint256 shares = daiVault.deposit(depositAmount, alice);
    vm.stopPrank();

    assertEq(tokenList.dai.balanceOf(alice), 0);
    assertEq(tokenList.dai.balanceOf(address(daiVault)), 0);
    assertEq(daiVault.totalAssets(), depositAmount);
    assertEq(daiVault.balanceOf(alice), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(daiVault)), shares);
  }

  function test_deposit_zero_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    daiVault.deposit(0, alice);
  }

  function test_deposit_revertsWith_MaxDepositExceeded(uint256 newMaxCap) public {
    uint256 daiDecimalMultiplier = MathUtils.uncheckedExp(10, tokenList.dai.decimals());
    // Max cap is not scaled by asset decimals
    newMaxCap = bound(newMaxCap, 1, MAX_SUPPLY_AMOUNT / daiDecimalMultiplier);
    uint256 depositAmount = newMaxCap *
      daiDecimalMultiplier +
      vm.randomUint(1, UINT256_MAX - newMaxCap * daiDecimalMultiplier);
    vm.prank(ADMIN);
    hub1.updateSpokeConfig(
      daiAssetId,
      address(daiVault),
      IHub.SpokeConfig({
        addCap: uint40(newMaxCap),
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK,
        active: true,
        paused: false
      })
    );

    IHub.SpokeConfig memory config = hub1.getSpokeConfig(daiAssetId, address(daiVault));
    assertEq(config.addCap, uint40(newMaxCap));

    vm.prank(alice);
    tokenList.dai.approve(address(daiVault), depositAmount);
    vm.expectRevert(
      abi.encodeWithSelector(
        IVaultSpoke.MaxDepositExceeded.selector,
        newMaxCap * MathUtils.uncheckedExp(10, tokenList.dai.decimals()),
        depositAmount
      )
    );
    vm.prank(alice);
    daiVault.deposit(depositAmount, alice);
  }

  function test_mint(uint256 mintAmount) public {
    mintAmount = bound(mintAmount, 1, MAX_SUPPLY_AMOUNT);
    deal(address(tokenList.dai), alice, mintAmount);

    assertEq(tokenList.dai.balanceOf(alice), mintAmount);
    assertEq(tokenList.dai.balanceOf(address(daiVault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(daiVault.balanceOf(alice), 0);

    vm.startPrank(alice);
    tokenList.dai.approve(address(daiVault), mintAmount);
    vm.expectEmit(address(daiVault));
    emit IERC4626.Deposit(alice, alice, mintAmount, mintAmount);
    uint256 shares = daiVault.mint(mintAmount, alice);
    vm.stopPrank();

    assertEq(tokenList.dai.balanceOf(alice), 0);
    assertEq(tokenList.dai.balanceOf(address(daiVault)), 0);
    assertEq(daiVault.totalAssets(), mintAmount);
    assertEq(daiVault.balanceOf(alice), mintAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), mintAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(daiVault)), shares);
  }

  function test_mint_zero_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    daiVault.mint(0, alice);
  }

  function test_mint_revertsWith_MaxMintExceeded(uint256 newMaxCap) public {
    uint256 daiDecimalMultiplier = MathUtils.uncheckedExp(10, tokenList.dai.decimals());
    // Max cap is not scaled by asset decimals
    newMaxCap = bound(newMaxCap, 1, MAX_SUPPLY_AMOUNT / daiDecimalMultiplier);
    uint256 mintAmount = newMaxCap *
      daiDecimalMultiplier +
      vm.randomUint(1, UINT256_MAX - newMaxCap * daiDecimalMultiplier);
    vm.prank(ADMIN);
    hub1.updateSpokeConfig(
      daiAssetId,
      address(daiVault),
      IHub.SpokeConfig({
        addCap: uint40(newMaxCap),
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK,
        active: true,
        paused: false
      })
    );

    IHub.SpokeConfig memory config = hub1.getSpokeConfig(daiAssetId, address(daiVault));
    assertEq(config.addCap, uint40(newMaxCap));

    vm.prank(alice);
    tokenList.dai.approve(address(daiVault), mintAmount);
    vm.expectRevert(
      abi.encodeWithSelector(
        IVaultSpoke.MaxMintExceeded.selector,
        newMaxCap * MathUtils.uncheckedExp(10, tokenList.dai.decimals()),
        mintAmount
      )
    );
    vm.prank(alice);
    daiVault.mint(mintAmount, alice);
  }

  function test_withdraw(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    _deposit(daiVault, alice, depositAmount);

    assertEq(daiVault.balanceOf(alice), depositAmount);
    assertEq(daiVault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(alice), 0);

    vm.startPrank(alice);
    vm.expectEmit(address(daiVault));
    emit IERC4626.Withdraw(alice, alice, alice, depositAmount, depositAmount);
    daiVault.withdraw(depositAmount, alice, alice);
    vm.stopPrank();

    assertEq(daiVault.balanceOf(alice), 0);
    assertEq(daiVault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(alice), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(daiVault)), 0);
  }

  function test_withdraw_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    daiVault.withdraw(0, alice, alice);
  }

  function test_withdraw_revertsWith_MaxWithdrawExceeded(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 withdrawAmount = depositAmount + vm.randomUint(1, UINT256_MAX - depositAmount);
    vm.prank(alice);
    _deposit(daiVault, alice, depositAmount);

    vm.expectRevert(
      abi.encodeWithSelector(
        IVaultSpoke.MaxWithdrawExceeded.selector,
        depositAmount,
        withdrawAmount
      )
    );
    vm.prank(alice);
    daiVault.withdraw(withdrawAmount, alice, alice);
  }

  function test_redeem(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    _deposit(daiVault, alice, depositAmount);

    assertEq(daiVault.balanceOf(alice), depositAmount);
    assertEq(daiVault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(alice), 0);

    vm.startPrank(alice);
    vm.expectEmit(address(daiVault));
    emit IERC4626.Withdraw(alice, alice, alice, depositAmount, depositAmount);
    daiVault.redeem(depositAmount, alice, alice);
    vm.stopPrank();

    assertEq(daiVault.balanceOf(alice), 0);
    assertEq(daiVault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(alice), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(daiVault)), 0);
  }

  function test_redeem_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    daiVault.redeem(0, alice, alice);
  }

  function test_redeem_revertsWith_MaxRedeemExceeded(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 redeemAmount = depositAmount + vm.randomUint(1, UINT256_MAX - depositAmount);
    vm.prank(alice);
    _deposit(daiVault, alice, depositAmount);

    vm.expectRevert(
      abi.encodeWithSelector(IVaultSpoke.MaxRedeemExceeded.selector, depositAmount, redeemAmount)
    );
    vm.prank(alice);
    daiVault.redeem(redeemAmount, alice, alice);
  }
}
