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

  function test_depositWithSig(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    (address user, uint256 userPk) = makeAddrAndKey('user');

    deal(address(tokenList.dai), user, depositAmount);
    vm.prank(user);
    tokenList.dai.approve(address(daiVault), depositAmount);

    assertEq(tokenList.dai.balanceOf(user), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(daiVault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(daiVault.balanceOf(user), 0);

    EIP712Types.VaultDeposit memory params = _depositData(
      daiVault,
      user,
      depositAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));

    vm.expectEmit(address(daiVault));
    emit IERC4626.Deposit(user, user, depositAmount, depositAmount);
    uint256 shares = daiVault.depositWithSig(params, signature);
    assertEq(tokenList.dai.balanceOf(user), 0);
    assertEq(tokenList.dai.balanceOf(address(daiVault)), 0);
    assertEq(daiVault.totalAssets(), depositAmount);
    assertEq(daiVault.balanceOf(user), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(daiVault)), shares);
  }

  function test_depositWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultDeposit memory params = _depositData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    daiVault.depositWithSig(params, signature);
  }

  function test_depositWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    EIP712Types.VaultDeposit memory params = _depositData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(daiVault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    daiVault.depositWithSig(params, signature);
  }

  function test_depositWithSig_revertsWith_InvalidAccountNonce() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultDeposit memory params = _depositData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(
      INoncesKeyed(address(daiVault)),
      params.depositor,
      nonceKey
    );
    params.nonce = _getRandomInvalidNonceAtKey(
      INoncesKeyed(address(daiVault)),
      params.depositor,
      nonceKey
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));
    vm.expectRevert(
      abi.encodeWithSelector(
        INoncesKeyed.InvalidAccountNonce.selector,
        params.depositor,
        currentNonce
      )
    );
    daiVault.depositWithSig(params, signature);
  }

  function test_depositWithSig_revertsWith_ERC20InsufficientAllowance() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    uint256 depositAmount = vm.randomUint(1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), user, depositAmount);

    EIP712Types.VaultDeposit memory params = _depositData(
      daiVault,
      user,
      depositAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(daiVault),
        0,
        params.assets,
        address(tokenList.dai)
      )
    );
    daiVault.depositWithSig(params, signature);
  }

  function test_mintWithSig(uint256 mintAmount) public {
    mintAmount = bound(mintAmount, 1, MAX_SUPPLY_AMOUNT);
    (address user, uint256 userPk) = makeAddrAndKey('user');

    deal(address(tokenList.dai), user, mintAmount);
    vm.prank(user);
    tokenList.dai.approve(address(daiVault), mintAmount);

    assertEq(tokenList.dai.balanceOf(user), mintAmount);
    assertEq(tokenList.dai.balanceOf(address(daiVault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(daiVault.balanceOf(user), 0);

    EIP712Types.VaultMint memory params = _mintData(
      daiVault,
      user,
      mintAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));

    vm.expectEmit(address(daiVault));
    emit IERC4626.Deposit(user, user, mintAmount, mintAmount);
    uint256 shares = daiVault.mintWithSig(params, signature);
    assertEq(tokenList.dai.balanceOf(user), 0);
    assertEq(tokenList.dai.balanceOf(address(daiVault)), 0);
    assertEq(daiVault.totalAssets(), mintAmount);
    assertEq(daiVault.balanceOf(user), mintAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), mintAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(daiVault)), shares);
  }

  function test_mintWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultMint memory params = _mintData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    daiVault.mintWithSig(params, signature);
  }

  function test_mintWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    EIP712Types.VaultMint memory params = _mintData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(daiVault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    daiVault.mintWithSig(params, signature);
  }

  function test_mintWithSig_revertsWith_InvalidAccountNonce() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultMint memory params = _mintData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(
      INoncesKeyed(address(daiVault)),
      params.depositor,
      nonceKey
    );
    params.nonce = _getRandomInvalidNonceAtKey(
      INoncesKeyed(address(daiVault)),
      params.depositor,
      nonceKey
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));
    vm.expectRevert(
      abi.encodeWithSelector(
        INoncesKeyed.InvalidAccountNonce.selector,
        params.depositor,
        currentNonce
      )
    );
    daiVault.mintWithSig(params, signature);
  }

  function test_mintWithSig_revertsWith_ERC20InsufficientAllowance() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    uint256 mintAmount = vm.randomUint(1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), user, mintAmount);

    EIP712Types.VaultMint memory params = _mintData(
      daiVault,
      user,
      mintAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(daiVault),
        0,
        params.shares,
        address(tokenList.dai)
      )
    );
    daiVault.mintWithSig(params, signature);
  }

  function test_withdrawWithSig(uint256 depositAmount) public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    address caller = vm.randomAddress();
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    _deposit(daiVault, user, depositAmount);

    assertEq(daiVault.balanceOf(user), depositAmount);
    assertEq(daiVault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(user), 0);

    EIP712Types.VaultWithdraw memory params = _withdrawData(
      daiVault,
      user,
      depositAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));

    vm.prank(user);
    IERC20(address(daiVault)).approve(address(caller), depositAmount);

    vm.prank(caller);
    vm.expectEmit(address(daiVault));
    emit IERC4626.Withdraw(user, user, user, depositAmount, depositAmount);
    daiVault.withdrawWithSig(params, signature);

    assertEq(daiVault.balanceOf(user), 0);
    assertEq(daiVault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(user), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(daiVault)), 0);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultWithdraw memory params = _withdrawData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    daiVault.withdrawWithSig(params, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    EIP712Types.VaultWithdraw memory params = _withdrawData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(daiVault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    daiVault.withdrawWithSig(params, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidAccountNonce() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultWithdraw memory params = _withdrawData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(
      INoncesKeyed(address(daiVault)),
      params.owner,
      nonceKey
    );
    params.nonce = _getRandomInvalidNonceAtKey(
      INoncesKeyed(address(daiVault)),
      params.owner,
      nonceKey
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));
    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, params.owner, currentNonce)
    );
    daiVault.withdrawWithSig(params, signature);
  }

  function test_redeemWithSig(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    (address user, uint256 userPk) = makeAddrAndKey('user');
    address caller = vm.randomAddress();
    _deposit(daiVault, user, depositAmount);

    assertEq(daiVault.balanceOf(user), depositAmount);
    assertEq(daiVault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(user), 0);

    EIP712Types.VaultRedeem memory params = _redeemData(
      daiVault,
      user,
      depositAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));

    vm.prank(user);
    IERC20(address(daiVault)).approve(address(caller), depositAmount);

    vm.prank(caller);
    vm.expectEmit(address(daiVault));
    emit IERC4626.Withdraw(user, user, user, depositAmount, depositAmount);
    daiVault.redeemWithSig(params, signature);

    assertEq(daiVault.balanceOf(user), 0);
    assertEq(daiVault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(user), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(daiVault)), 0);
  }

  function test_redeemWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultRedeem memory params = _redeemData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    daiVault.redeemWithSig(params, signature);
  }

  function test_redeemWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    EIP712Types.VaultRedeem memory params = _redeemData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(daiVault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    daiVault.redeemWithSig(params, signature);
  }

  function test_redeemWithSig_revertsWith_InvalidAccountNonce() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultRedeem memory params = _redeemData(
      daiVault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(
      INoncesKeyed(address(daiVault)),
      params.owner,
      nonceKey
    );
    params.nonce = _getRandomInvalidNonceAtKey(
      INoncesKeyed(address(daiVault)),
      params.owner,
      nonceKey
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(daiVault, params));
    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, params.owner, currentNonce)
    );
    daiVault.redeemWithSig(params, signature);
  }

  function test_depositWithPermit(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    (address user, uint256 userPk) = makeAddrAndKey('user');

    deal(address(tokenList.dai), user, depositAmount);

    assertEq(tokenList.dai.balanceOf(user), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(daiVault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(daiVault.balanceOf(user), 0);

    EIP712Types.Permit memory params = EIP712Types.Permit({
      owner: user,
      spender: address(daiVault),
      value: depositAmount,
      deadline: vm.getBlockTimestamp() + 1,
      nonce: tokenList.dai.nonces(user)
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, _getTypedDataHash(tokenList.dai, params));

    vm.prank(user);
    vm.expectEmit(address(daiVault));
    emit IERC4626.Deposit(user, user, depositAmount, depositAmount);
    uint256 shares = daiVault.depositWithPermit(depositAmount, user, params.deadline, v, r, s);

    assertEq(tokenList.dai.balanceOf(user), 0);
    assertEq(tokenList.dai.balanceOf(address(daiVault)), 0);
    assertEq(daiVault.totalAssets(), depositAmount);
    assertEq(daiVault.balanceOf(user), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(daiVault)), shares);
  }

  function test_permit(uint256 approveAmount) public {
    approveAmount = bound(approveAmount, 1, MAX_SUPPLY_AMOUNT);
    (address user, uint256 userPk) = makeAddrAndKey('user');
    TestnetERC20 vaultToken = TestnetERC20(address(daiVault));

    assertEq(vaultToken.allowance(user, address(daiVault)), 0);

    EIP712Types.Permit memory params = EIP712Types.Permit({
      owner: user,
      spender: address(daiVault),
      value: approveAmount,
      nonce: vaultToken.nonces(user),
      deadline: vm.getBlockTimestamp() + 1
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, _getTypedDataHash(vaultToken, params));

    vm.expectEmit(address(daiVault));
    emit IERC20.Approval(user, address(daiVault), params.value);
    vm.prank(user);
    daiVault.permit(user, address(daiVault), params.value, params.deadline, v, r, s);

    assertEq(vaultToken.allowance(user, address(daiVault)), params.value);
  }
}
