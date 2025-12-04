// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import 'src/Spoke/Instances/VaultSpokeInstance.sol';
import 'src/Spoke/Interfaces/IVaultSpoke.sol';

contract VaultSpokeTest is SpokeBase {
  IVaultSpoke vault;
  address proxyAdminOwner = makeAddr('proxyAdminOwner');

  function setUp() public override {
    super.setUp();
    address deployer = makeAddr('deployer');
    address vaultImpl = address(new VaultSpokeInstance(address(hub1), daiAssetId));
    vault = IVaultSpoke(
      _proxify(
        deployer,
        vaultImpl,
        proxyAdminOwner,
        abi.encodeCall(VaultSpoke.initialize, ('hub1-DAI'))
      )
    );

    // Add VaultSpoke to Hub
    IHub.SpokeConfig memory config = IHub.SpokeConfig({
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK,
      active: true,
      paused: false
    });
    vm.prank(ADMIN);
    hub1.addSpoke(daiAssetId, address(vault), config);
  }

  function test_deploy() public view {
    assertEq(address(vault.hub()), address(hub1));
    assertEq(vault.assetId(), daiAssetId);
    assertEq(vault.asset(), address(tokenList.dai));
    assertEq(vault.decimals(), IERC20Metadata(address(tokenList.dai)).decimals());
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
    vm.expectEmit(true, true, false, true, address(vault));
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

  function test_mint(uint256 mintAmount) public {
    mintAmount = bound(mintAmount, 1, MAX_SUPPLY_AMOUNT);
    deal(address(tokenList.dai), alice, mintAmount);

    assertEq(tokenList.dai.balanceOf(alice), mintAmount);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(vault.balanceOf(alice), 0);

    vm.startPrank(alice);
    tokenList.dai.approve(address(vault), mintAmount);
    vm.expectEmit(true, true, false, true, address(vault));
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

  function test_withdraw(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    _depositFromUser(alice, depositAmount);

    assertEq(vault.balanceOf(alice), depositAmount);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(alice), 0);

    vm.startPrank(alice);
    vm.expectEmit(true, true, true, true, address(vault));
    emit IERC4626.Withdraw(alice, alice, alice, depositAmount, depositAmount);
    vault.withdraw(depositAmount, alice, alice);
    vm.stopPrank();

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(alice), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), 0);
  }

  function test_redeem(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    _depositFromUser(alice, depositAmount);

    assertEq(vault.balanceOf(alice), depositAmount);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(alice), 0);

    vm.startPrank(alice);
    vm.expectEmit(true, true, true, true, address(vault));
    emit IERC4626.Withdraw(alice, alice, alice, depositAmount, depositAmount);
    vault.redeem(depositAmount, alice, alice);
    vm.stopPrank();

    assertEq(vault.balanceOf(alice), 0);
    assertEq(vault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(alice), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), 0);
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

    EIP712Types.VaultDeposit memory params = EIP712Types.VaultDeposit({
      depositor: user,
      assets: depositAmount,
      receiver: user,
      nonce: vault.nonces(user),
      deadline: vm.getBlockTimestamp() + 1
    });
    bytes32 functionTypehash = keccak256(
      'VaultDeposit(address depositor,uint256 assets,address receiver,uint256 nonce,uint256 deadline)'
    );
    bytes32 structHash = keccak256(
      abi.encode(
        functionTypehash,
        params.depositor,
        params.assets,
        params.receiver,
        params.nonce,
        params.deadline
      )
    );
    bytes memory signature = _getVaultSignature(userPk, structHash);

    vm.expectEmit(true, true, false, true, address(vault));
    emit IERC4626.Deposit(user, user, depositAmount, depositAmount);
    uint256 shares = vault.depositWithSig(params, signature);

    assertEq(tokenList.dai.balanceOf(user), 0);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(vault.balanceOf(user), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), shares);
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

    EIP712Types.VaultMint memory params = EIP712Types.VaultMint({
      depositor: user,
      shares: mintAmount,
      receiver: user,
      nonce: vault.nonces(user),
      deadline: vm.getBlockTimestamp() + 1
    });
    bytes32 functionTypehash = keccak256(
      'VaultMint(address depositor,uint256 shares,address receiver,uint256 nonce,uint256 deadline)'
    );
    bytes32 structHash = keccak256(
      abi.encode(
        functionTypehash,
        params.depositor,
        params.shares,
        params.receiver,
        params.nonce,
        params.deadline
      )
    );
    bytes memory signature = _getVaultSignature(userPk, structHash);

    vm.expectEmit(true, true, false, true, address(vault));
    emit IERC4626.Deposit(user, user, mintAmount, mintAmount);
    uint256 shares = vault.mintWithSig(params, signature);

    assertEq(tokenList.dai.balanceOf(user), 0);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(vault.totalAssets(), mintAmount);
    assertEq(vault.balanceOf(user), mintAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), mintAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), shares);
  }

  function test_withdrawWithSig(uint256 depositAmount) public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    _depositFromUser(user, depositAmount);

    assertEq(vault.balanceOf(user), depositAmount);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(user), 0);

    EIP712Types.VaultWithdraw memory params = EIP712Types.VaultWithdraw({
      owner: user,
      assets: depositAmount,
      receiver: user,
      nonce: vault.nonces(user),
      deadline: vm.getBlockTimestamp() + 1
    });
    bytes32 functionTypehash = keccak256(
      'VaultWithdraw(address owner,uint256 assets,address receiver,uint256 nonce,uint256 deadline)'
    );
    bytes32 structHash = keccak256(
      abi.encode(
        functionTypehash,
        params.owner,
        params.assets,
        params.receiver,
        params.nonce,
        params.deadline
      )
    );
    bytes memory signature = _getVaultSignature(userPk, structHash);

    vm.prank(user);
    IERC20(address(vault)).approve(bob, depositAmount);

    vm.prank(bob);
    vm.expectEmit(true, true, true, true, address(vault));
    emit IERC4626.Withdraw(bob, user, user, depositAmount, depositAmount);
    vault.withdrawWithSig(params, signature);

    assertEq(vault.balanceOf(user), 0);
    assertEq(vault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(user), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), 0);
  }

  function test_redeemWithSig(uint256 depositAmount) public {
    depositAmount = bound(depositAmount, 1, MAX_SUPPLY_AMOUNT);
    (address user, uint256 userPk) = makeAddrAndKey('user');
    _depositFromUser(user, depositAmount);

    assertEq(vault.balanceOf(user), depositAmount);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
    assertEq(tokenList.dai.balanceOf(user), 0);

    EIP712Types.VaultRedeem memory params = EIP712Types.VaultRedeem({
      owner: user,
      shares: depositAmount,
      receiver: user,
      nonce: vault.nonces(user),
      deadline: vm.getBlockTimestamp() + 1
    });
    bytes32 functionTypehash = keccak256(
      'VaultRedeem(address owner,uint256 shares,address receiver,uint256 nonce,uint256 deadline)'
    );
    bytes32 structHash = keccak256(
      abi.encode(
        functionTypehash,
        params.owner,
        params.shares,
        params.receiver,
        params.nonce,
        params.deadline
      )
    );
    bytes memory signature = _getVaultSignature(userPk, structHash);

    vm.prank(user);
    IERC20(address(vault)).approve(bob, depositAmount);

    vm.prank(bob);
    vm.expectEmit(true, true, true, true, address(vault));
    emit IERC4626.Withdraw(bob, user, user, depositAmount, depositAmount);
    vault.redeemWithSig(params, signature);

    assertEq(vault.balanceOf(user), 0);
    assertEq(vault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(user), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), 0);
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
    vm.expectEmit(true, true, false, true, address(vault));
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

    assertEq(IERC20(address(vault)).allowance(user, address(vault)), 0);

    EIP712Types.Permit memory params = EIP712Types.Permit({
      owner: user,
      spender: address(vault),
      value: approveAmount,
      nonce: vault.nonces(user),
      deadline: vm.getBlockTimestamp() + 1
    });
    bytes32 functionTypehash = keccak256(
      'Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'
    );
    bytes32 structHash = keccak256(
      abi.encode(
        functionTypehash,
        params.owner,
        params.spender,
        params.value,
        params.nonce,
        params.deadline
      )
    );
    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', vault.DOMAIN_SEPARATOR(), structHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

    vm.expectEmit(address(vault));
    emit IERC20.Approval(user, address(vault), params.value);
    vm.prank(user);
    vault.permit(user, address(vault), params.value, params.deadline, v, r, s);

    assertEq(IERC20(address(vault)).allowance(user, address(vault)), params.value);
  }

  function _depositFromUser(address user, uint256 amount) public {
    deal(address(tokenList.dai), user, amount);

    vm.startPrank(user);
    tokenList.dai.approve(address(vault), amount);
    vault.deposit(amount, user);
    vm.stopPrank();
  }

  function _getVaultSignature(
    uint256 userPk,
    bytes32 structHash
  ) internal view returns (bytes memory) {
    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', vault.DOMAIN_SEPARATOR(), structHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    return abi.encodePacked(r, s, v);
  }
}
