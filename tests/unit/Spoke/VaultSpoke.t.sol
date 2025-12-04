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
    (address depositor, uint256 userPk) = makeAddrAndKey('user');

    deal(address(tokenList.dai), depositor, depositAmount);
    vm.prank(depositor);
    tokenList.dai.approve(address(vault), depositAmount);

    assertEq(tokenList.dai.balanceOf(depositor), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(vault.balanceOf(depositor), 0);

    EIP712Types.VaultDeposit memory params = EIP712Types.VaultDeposit({
      depositor: depositor,
      assets: depositAmount,
      receiver: depositor,
      nonce: vault.nonces(depositor),
      deadline: block.timestamp + 1
    });

    bytes32 VAULT_DEPOSIT_TYPEHASH = keccak256(
      'VaultDeposit(address depositor,uint256 assets,address receiver,uint256 nonce,uint256 deadline)'
    );

    bytes32 structHash = keccak256(
      abi.encode(
        VAULT_DEPOSIT_TYPEHASH,
        params.depositor,
        params.assets,
        params.receiver,
        params.nonce,
        params.deadline
      )
    );

    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', vault.DOMAIN_SEPARATOR(), structHash));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectEmit(true, true, false, true, address(vault));
    emit IERC4626.Deposit(depositor, depositor, depositAmount, depositAmount);
    uint256 shares = vault.depositWithSig(params, signature);

    assertEq(tokenList.dai.balanceOf(depositor), 0);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(vault.balanceOf(depositor), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(vault)), shares);
  }

  function _depositFromUser(address user, uint256 amount) public {
    deal(address(tokenList.dai), user, amount);

    vm.startPrank(user);
    tokenList.dai.approve(address(vault), amount);
    vault.deposit(amount, user);
    vm.stopPrank();
  }
}
