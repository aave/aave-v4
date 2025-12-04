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
    address predictedVault = vm.computeCreateAddress(deployer, vm.getNonce(deployer));
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

  function test_deploy() public {
    assertEq(address(vault.hub()), address(hub1));
    assertEq(vault.assetId(), daiAssetId);
    assertEq(vault.asset(), address(tokenList.dai));
    assertEq(vault.decimals(), IERC20Metadata(address(tokenList.dai)).decimals());
  }

  function test_deposit() public {
    uint256 depositAmount = 1000e18;
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

  function test_mint() public {
    uint256 mintAmount = 1000e18;
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

  function test_withdraw() public {
    uint256 depositAmount = 1000e18;
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

  function test_redeem() public {
    uint256 depositAmount = 1000e18;
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

  function test_depositWithSig() public {
    uint256 depositAmount = 1000e18;
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
      deadline: block.timestamp + 1
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

  function test_mintWithSig() public {
    uint256 mintAmount = 1000e18;
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
      deadline: block.timestamp + 1
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

  function test_withdrawWithSig() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    uint256 depositAmount = 1000e18;
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
      deadline: vm.getBlockTimestamp() + 1 hours
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
    vm.expectEmit(true, true, true, true, address(vault));
    emit IERC4626.Withdraw(user, user, user, depositAmount, depositAmount);
    vault.withdrawWithSig(params, signature);

    assertEq(vault.balanceOf(user), 0);
    assertEq(vault.totalAssets(), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(user), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), 0);
  }

  function test_redeemWithSig() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
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
