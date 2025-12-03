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
    uint256 shares = vault.deposit(depositAmount, alice);
    vm.stopPrank();

    assertEq(tokenList.dai.balanceOf(alice), 0);
    assertEq(tokenList.dai.balanceOf(address(vault)), 0);
    assertEq(vault.totalAssets(), depositAmount);
    assertEq(vault.balanceOf(alice), depositAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), depositAmount);
  }

  function _depositFromUser(address user, uint256 amount) public {
    deal(address(tokenList.dai), user, amount);

    vm.startPrank(user);
    tokenList.dai.approve(address(vault), amount);
    vault.deposit(amount, user);
    vm.stopPrank();
  }
}
