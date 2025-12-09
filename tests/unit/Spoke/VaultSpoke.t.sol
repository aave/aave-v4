// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/VaultSpoke.Base.t.sol';

contract VaultSpokeTest is VaultSpokeBaseTest {
  function test_deploy_reverts_InvalidAssetId() public {
    uint256 invalidAssetId = hub1.getAssetCount() + 1;
    vm.expectRevert();
    new VaultSpokeInstance(address(hub1), invalidAssetId);
  }

  function test_deploy_reverts_InvalidHub() public {
    address invalidHub = address(0);
    vm.expectRevert();
    new VaultSpokeInstance(invalidHub, daiAssetId);
  }

  function test_deploy() public view {
    assertEq(address(vault.hub()), address(hub1));
    assertEq(vault.assetId(), daiAssetId);
    assertEq(vault.asset(), address(tokenList.dai));
    assertEq(vault.decimals(), IERC20Metadata(address(tokenList.dai)).decimals());
  }

  /// @dev Cannot re-initialize the contract
  function test_reinitialize_revertsWith_InvalidInitialization() public {
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    VaultSpoke(address(vault)).initialize('new name');
  }

  /// @dev Cannot directly initialize the implementation contract
  function test_cannot_init_impl() public {
    VaultSpokeInstance vaultImpl = new VaultSpokeInstance(address(hub1), daiAssetId);
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vaultImpl.initialize('impl name');
  }

  function test_deposit(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    deal(address(tokenList.dai), alice, depositAmount);

    assertEq(tokenList.dai.balanceOf(alice), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(vault.balanceOf(alice), 0);

    vm.startPrank(alice);
    tokenList.dai.approve(address(vault), depositAmount);
    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(alice, alice, depositAmount, depositAmount);
    uint256 shares = vault.deposit(depositAmount, alice);
    vm.stopPrank();

    assertEq(tokenList.dai.balanceOf(alice), 0);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(vault.balanceOf(alice), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), shares);
  }

  function test_deposit_zero_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    vault.deposit(0, alice);
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
      address(vault),
      IHub.SpokeConfig({
        addCap: uint40(newMaxCap),
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK,
        active: true,
        paused: false
      })
    );

    IHub.SpokeConfig memory config = hub1.getSpokeConfig(daiAssetId, address(vault));
    assertEq(config.addCap, uint40(newMaxCap));

    vm.prank(alice);
    tokenList.dai.approve(address(vault), depositAmount);

    vm.expectRevert(
      abi.encodeWithSelector(
        IVaultSpoke.MaxDepositExceeded.selector,
        newMaxCap * MathUtils.uncheckedExp(10, tokenList.dai.decimals()),
        depositAmount
      )
    );
    vm.prank(alice);
    vault.deposit(depositAmount, alice);
  }

  function test_mint(uint256 mintAmount) public {
    mintAmount = bound(mintAmount, 1, MAX_SUPPLY_AMOUNT);
    deal(address(tokenList.dai), alice, mintAmount);

    assertEq(tokenList.dai.balanceOf(alice), mintAmount);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(vault.balanceOf(alice), 0);

    vm.startPrank(alice);
    tokenList.dai.approve(address(vault), mintAmount);
    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(alice, alice, mintAmount, mintAmount);
    uint256 shares = vault.mint(mintAmount, alice);
    vm.stopPrank();

    assertEq(tokenList.dai.balanceOf(alice), 0);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(vault.totalAssets(), mintAmount);
    assertEq(vault.balanceOf(alice), mintAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), mintAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), shares);
  }

  function test_mint_zero_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    vault.mint(0, alice);
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
      address(vault),
      IHub.SpokeConfig({
        addCap: uint40(newMaxCap),
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK,
        active: true,
        paused: false
      })
    );

    IHub.SpokeConfig memory config = hub1.getSpokeConfig(daiAssetId, address(vault));
    assertEq(config.addCap, uint40(newMaxCap));

    vm.prank(alice);
    tokenList.dai.approve(address(vault), mintAmount);

    vm.expectRevert(
      abi.encodeWithSelector(
        IVaultSpoke.MaxMintExceeded.selector,
        newMaxCap * MathUtils.uncheckedExp(10, tokenList.dai.decimals()),
        mintAmount
      )
    );
    vm.prank(alice);
    vault.mint(mintAmount, alice);
  }

  function test_withdraw(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    _deposit(vault, alice, depositAmount);

    assertEq(vault.balanceOf(alice), depositAmount);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(alice), 0);

    vm.startPrank(alice);
    vm.expectEmit(address(vault));
    emit IERC4626.Withdraw(alice, alice, alice, depositAmount, depositAmount);
    vault.withdraw(depositAmount, alice, alice);
    vm.stopPrank();

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(alice), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), 0);
  }

  function test_withdraw_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    vault.withdraw(0, alice, alice);
  }

  function test_withdraw_revertsWith_MaxWithdrawExceeded(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 withdrawAmount = depositAmount + vm.randomUint(1, UINT256_MAX - depositAmount);
    vm.prank(alice);
    _deposit(vault, alice, depositAmount);

    vm.expectRevert(
      abi.encodeWithSelector(
        IVaultSpoke.MaxWithdrawExceeded.selector,
        depositAmount,
        withdrawAmount
      )
    );
    vm.prank(alice);
    vault.withdraw(withdrawAmount, alice, alice);
  }

  function test_redeem(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    _deposit(vault, alice, depositAmount);

    assertEq(vault.balanceOf(alice), depositAmount);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(alice), 0);

    vm.startPrank(alice);
    vm.expectEmit(address(vault));
    emit IERC4626.Withdraw(alice, alice, alice, depositAmount, depositAmount);
    vault.redeem(depositAmount, alice, alice);
    vm.stopPrank();

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(alice), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), 0);
  }

  function test_redeem_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(alice);
    vault.redeem(0, alice, alice);
  }

  function test_redeem_revertsWith_MaxRedeemExceeded(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 redeemAmount = depositAmount + vm.randomUint(1, UINT256_MAX - depositAmount);
    vm.prank(alice);
    _deposit(vault, alice, depositAmount);

    vm.expectRevert(
      abi.encodeWithSelector(IVaultSpoke.MaxRedeemExceeded.selector, depositAmount, redeemAmount)
    );
    vm.prank(alice);
    vault.redeem(redeemAmount, alice, alice);
  }

  function test_depositWithSig(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    (address user, uint256 userPk) = makeAddrAndKey('user');

    deal(address(tokenList.dai), user, depositAmount);
    vm.prank(user);
    tokenList.dai.approve(address(vault), depositAmount);

    assertEq(tokenList.dai.balanceOf(user), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(vault.balanceOf(user), 0);

    EIP712Types.VaultDeposit memory params = _depositData(
      vault,
      user,
      depositAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(user, user, depositAmount, depositAmount);
    uint256 shares = vault.depositWithSig(params, signature);

    assertEq(tokenList.dai.balanceOf(user), 0);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(vault.balanceOf(user), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), shares);
  }

  function test_depositWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultDeposit memory params = _depositData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vault.depositWithSig(params, signature);
  }

  function test_depositWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    EIP712Types.VaultDeposit memory params = _depositData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(vault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vault.depositWithSig(params, signature);
  }

  function test_depositWithSig_revertsWith_InvalidAccountNonce() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultDeposit memory params = _depositData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(
      INoncesKeyed(address(vault)),
      params.depositor,
      nonceKey
    );
    params.nonce = _getRandomInvalidNonceAtKey(
      INoncesKeyed(address(vault)),
      params.depositor,
      nonceKey
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectRevert(
      abi.encodeWithSelector(
        INoncesKeyed.InvalidAccountNonce.selector,
        params.depositor,
        currentNonce
      )
    );
    vault.depositWithSig(params, signature);
  }

  function test_depositWithSig_revertsWith_ERC20InsufficientAllowance() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    uint256 depositAmount = vm.randomUint(1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), user, depositAmount);

    EIP712Types.VaultDeposit memory params = _depositData(
      vault,
      user,
      depositAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(vault),
        0,
        params.assets,
        address(tokenList.dai)
      )
    );
    vault.depositWithSig(params, signature);
  }

  function test_mintWithSig(uint256 mintAmount) public {
    mintAmount = bound(mintAmount, 1, MAX_SUPPLY_AMOUNT);
    (address user, uint256 userPk) = makeAddrAndKey('user');

    deal(address(tokenList.dai), user, mintAmount);
    vm.prank(user);
    tokenList.dai.approve(address(vault), mintAmount);

    assertEq(tokenList.dai.balanceOf(user), mintAmount);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(vault.balanceOf(user), 0);

    EIP712Types.VaultMint memory params = _mintData(
      vault,
      user,
      mintAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(user, user, mintAmount, mintAmount);
    uint256 shares = vault.mintWithSig(params, signature);

    assertEq(tokenList.dai.balanceOf(user), 0);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(vault.totalAssets(), mintAmount);
    assertEq(vault.balanceOf(user), mintAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), mintAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), shares);
  }

  function test_mintWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultMint memory params = _mintData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vault.mintWithSig(params, signature);
  }

  function test_mintWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    EIP712Types.VaultMint memory params = _mintData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(vault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vault.mintWithSig(params, signature);
  }

  function test_mintWithSig_revertsWith_InvalidAccountNonce() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultMint memory params = _mintData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(
      INoncesKeyed(address(vault)),
      params.depositor,
      nonceKey
    );
    params.nonce = _getRandomInvalidNonceAtKey(
      INoncesKeyed(address(vault)),
      params.depositor,
      nonceKey
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectRevert(
      abi.encodeWithSelector(
        INoncesKeyed.InvalidAccountNonce.selector,
        params.depositor,
        currentNonce
      )
    );
    vault.mintWithSig(params, signature);
  }

  function test_mintWithSig_revertsWith_ERC20InsufficientAllowance() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    uint256 mintAmount = vm.randomUint(1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), user, mintAmount);

    EIP712Types.VaultMint memory params = _mintData(
      vault,
      user,
      mintAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(vault),
        0,
        params.shares,
        address(tokenList.dai)
      )
    );
    vault.mintWithSig(params, signature);
  }

  function test_withdrawWithSig(uint256 depositAmount) public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    _deposit(vault, user, depositAmount);

    assertEq(vault.balanceOf(user), depositAmount);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(user), 0);

    EIP712Types.VaultWithdraw memory params = _withdrawData(
      vault,
      user,
      depositAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.prank(user);
    IERC20(address(vault)).approve(bob, depositAmount);

    vm.prank(bob);
    vm.expectEmit(address(vault));
    emit IERC4626.Withdraw(bob, user, user, depositAmount, depositAmount);
    vault.withdrawWithSig(params, signature);

    assertEq(vault.balanceOf(user), 0);
    assertEq(vault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(user), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), 0);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultWithdraw memory params = _withdrawData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vault.withdrawWithSig(params, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    EIP712Types.VaultWithdraw memory params = _withdrawData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(vault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vault.withdrawWithSig(params, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidAccountNonce() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultWithdraw memory params = _withdrawData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(
      INoncesKeyed(address(vault)),
      params.owner,
      nonceKey
    );
    params.nonce = _getRandomInvalidNonceAtKey(
      INoncesKeyed(address(vault)),
      params.owner,
      nonceKey
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, params.owner, currentNonce)
    );
    vault.withdrawWithSig(params, signature);
  }

  function test_redeemWithSig(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    (address user, uint256 userPk) = makeAddrAndKey('user');
    _deposit(vault, user, depositAmount);

    assertEq(vault.balanceOf(user), depositAmount);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(user), 0);

    EIP712Types.VaultRedeem memory params = _redeemData(
      vault,
      user,
      depositAmount,
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.prank(user);
    IERC20(address(vault)).approve(bob, depositAmount);

    vm.prank(bob);
    vm.expectEmit(address(vault));
    emit IERC4626.Withdraw(bob, user, user, depositAmount, depositAmount);
    vault.redeemWithSig(params, signature);

    assertEq(vault.balanceOf(user), 0);
    assertEq(vault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(user), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), 0);
  }

  function test_redeemWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultRedeem memory params = _redeemData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vault.redeemWithSig(params, signature);
  }

  function test_redeemWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    EIP712Types.VaultRedeem memory params = _redeemData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(vault, params));

    vm.expectRevert(IVaultSpoke.InvalidSignature.selector);
    vault.redeemWithSig(params, signature);
  }

  function test_redeemWithSig_revertsWith_InvalidAccountNonce() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    EIP712Types.VaultRedeem memory params = _redeemData(
      vault,
      user,
      vm.randomUint(1, MAX_SUPPLY_AMOUNT),
      vm.getBlockTimestamp() + 1
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(
      INoncesKeyed(address(vault)),
      params.owner,
      nonceKey
    );
    params.nonce = _getRandomInvalidNonceAtKey(
      INoncesKeyed(address(vault)),
      params.owner,
      nonceKey
    );
    bytes memory signature = _sign(userPk, _getTypedDataHash(vault, params));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, params.owner, currentNonce)
    );
    vault.redeemWithSig(params, signature);
  }

  function test_depositWithPermit(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    (address user, uint256 userPk) = makeAddrAndKey('user');

    deal(address(tokenList.dai), user, depositAmount);

    assertEq(tokenList.dai.balanceOf(user), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(vault.balanceOf(user), 0);

    EIP712Types.Permit memory params = EIP712Types.Permit({
      owner: user,
      spender: address(vault),
      value: depositAmount,
      deadline: vm.getBlockTimestamp() + 1,
      nonce: tokenList.dai.nonces(user)
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, _getTypedDataHash(tokenList.dai, params));

    vm.prank(user);
    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(user, user, depositAmount, depositAmount);
    uint256 shares = vault.depositWithPermit(depositAmount, user, params.deadline, v, r, s);

    assertEq(tokenList.dai.balanceOf(user), 0);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(vault.balanceOf(user), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), shares);
  }

  function test_permit(uint256 approveAmount) public {
    approveAmount = bound(approveAmount, 1, MAX_SUPPLY_AMOUNT);
    (address user, uint256 userPk) = makeAddrAndKey('user');
    TestnetERC20 vaultToken = TestnetERC20(address(vault));

    assertEq(vaultToken.allowance(user, address(vault)), 0);

    EIP712Types.Permit memory params = EIP712Types.Permit({
      owner: user,
      spender: address(vault),
      value: approveAmount,
      nonce: vaultToken.nonces(user),
      deadline: vm.getBlockTimestamp() + 1
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, _getTypedDataHash(vaultToken, params));

    vm.expectEmit(address(vault));
    emit IERC20.Approval(user, address(vault), params.value);
    vm.prank(user);
    vault.permit(user, address(vault), params.value, params.deadline, v, r, s);

    assertEq(vaultToken.allowance(user, address(vault)), params.value);
  }
}
