// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubAccessTest is LiquidityHubBase {
  /// @dev Test showing that restricted functions on hub can only be called by hub admin.
  function test_liquidity_hub_admin_access() public {
    TestnetERC20 tokenA = new TestnetERC20('A', 'A', 18);
    TestnetERC20 tokenB = new TestnetERC20('B', 'B', 18);
    DataTypes.AssetConfig memory assetConfig = DataTypes.AssetConfig({
      active: true,
      frozen: false,
      paused: false,
      feeReceiver: address(0),
      liquidityFee: 0,
      irStrategy: address(irStrategy)
    });
    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      drawCap: 1000e18,
      supplyCap: 1000e18,
      active: true
    });

    // Only Hub Admin can add assets to the hub
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.addAsset(address(tokenA), 18, address(irStrategy));

    // Hub Admin can add assets to the hub
    vm.prank(HUB_ADMIN);
    hub.addAsset(address(tokenA), 18, address(irStrategy));
    uint256 assetAId = hub.getAssetCount() - 1; // Asset A Id

    // Only Hub Admin can update asset config
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.updateAssetConfig(daiAssetId, assetConfig);

    // Hub Admin can update asset config
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, assetConfig);

    // Only Hub Admin can add spoke
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.addSpoke(assetAId, address(spoke1), spokeConfig);

    // Hub Admin can add spoke
    vm.prank(HUB_ADMIN);
    hub.addSpoke(assetAId, address(spoke1), spokeConfig);

    // Only Hub Admin can update spoke config
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.updateSpokeConfig(assetAId, address(spoke1), spokeConfig);

    // Hub Admin can update spoke config
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(assetAId, address(spoke1), spokeConfig);
  }

  function test_setInterestRateData_access() public {
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 50_00, // 50.00% in BPS
        baseVariableBorrowRate: 100_00, // 100.00% in BPS
        variableRateSlope1: 200_00, // 200.00% in BPS
        variableRateSlope2: 300_00 // 300.00% in BPS
      })
    );

    // Only Liquidity Hub can set interest rates
    vm.expectRevert(abi.encodeWithSelector(IAssetInterestRateStrategy.OnlyLiquidityHub.selector));
    irStrategy.setInterestRateData(daiAssetId, encodedIrData);

    // Liquidity Hub can set interest rates
    vm.prank(address(hub));
    irStrategy.setInterestRateData(daiAssetId, encodedIrData);

    // Only Hub Admin can call function on hub to set interest rates
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.setInterestRateData(daiAssetId, encodedIrData);

    // Hub Admin can call function on hub to set interest rates
    vm.prank(HUB_ADMIN);
    hub.setInterestRateData(daiAssetId, encodedIrData);
  }

  /// @dev Test showcasing ability to change role responsibility for a function selector.
  function test_change_role_responsibility() public {
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 50_00, // 50.00% in BPS
        baseVariableBorrowRate: 100_00, // 100.00% in BPS
        variableRateSlope1: 200_00, // 200.00% in BPS
        variableRateSlope2: 300_00 // 300.00% in BPS
      })
    );

    // Change the role responsible for setting interest rate data on the hub
    bytes4[] memory hubSelectors = new bytes4[](1);
    hubSelectors[0] = ILiquidityHub.setInterestRateData.selector;
    vm.prank(ADMIN);
    accessManager.setTargetFunctionRole(address(hub), hubSelectors, Roles.DEFAULT_ADMIN_ROLE);

    // The old role (HUB_ADMIN) should no longer have access
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, HUB_ADMIN)
    );
    vm.prank(HUB_ADMIN);
    hub.setInterestRateData(daiAssetId, encodedIrData);

    // The new role (DEFAULT_ADMIN_ROLE) should have access
    vm.prank(ADMIN);
    hub.setInterestRateData(daiAssetId, encodedIrData);

    // HUB_ADMIN can still access the other hub functions for which it has permissions
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(
      daiAssetId,
      address(spoke1),
      DataTypes.SpokeConfig({drawCap: 1000e18, supplyCap: 1000e18, active: true})
    );
  }

  /// @dev Test showcasing ability to migrate role responsibility for a function selector.
  function test_migrate_role_responsibility() public {
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 50_00, // 50.00% in BPS
        baseVariableBorrowRate: 100_00, // 100.00% in BPS
        variableRateSlope1: 200_00, // 200.00% in BPS
        variableRateSlope2: 300_00 // 300.00% in BPS
      })
    );

    // Say addresses Alice, Bob, and Carol all have the HUB_ADMIN role, allowing them to set interest rate data.
    // Grant roles with 0 delay
    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, alice, 0);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, bob, 0);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, carol, 0);
    vm.stopPrank();

    vm.prank(alice);
    hub.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(bob);
    hub.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(carol);
    hub.setInterestRateData(daiAssetId, encodedIrData);

    // Now, we change the role responsible for setting interest rate data to SPOKE_ADMIN role.
    bytes4[] memory hubSelectors = new bytes4[](1);
    hubSelectors[0] = ILiquidityHub.setInterestRateData.selector;
    vm.prank(ADMIN);
    accessManager.setTargetFunctionRole(address(hub), hubSelectors, Roles.SPOKE_ADMIN_ROLE);

    // Alice, Bob, and Carol should no longer have access to set interest rate data.
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hub.setInterestRateData(daiAssetId, encodedIrData);
    vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, bob));
    vm.prank(bob);
    hub.setInterestRateData(daiAssetId, encodedIrData);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, carol)
    );
    vm.prank(carol);
    hub.setInterestRateData(daiAssetId, encodedIrData);

    // Now, we grant SPOKE_ADMIN role to Alice, Bob, and Carol with 0 delay
    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, alice, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, bob, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, carol, 0);
    vm.stopPrank();

    // Alice, Bob, and Carol should now be able to set interest rate data.
    vm.prank(alice);
    hub.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(bob);
    hub.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(carol);
    hub.setInterestRateData(daiAssetId, encodedIrData);

    // Alice, Bob, and Carol currently have both HUB_ADMIN and SPOKE_ADMIN roles.
    IAccessManager accessManager = IAccessManager(hub.authority());
    (bool hasHubAdminRoleAlice, ) = accessManager.hasRole(Roles.HUB_ADMIN_ROLE, alice);
    (bool hasHubAdminRoleBob, ) = accessManager.hasRole(Roles.HUB_ADMIN_ROLE, bob);
    (bool hasHubAdminRoleCarol, ) = accessManager.hasRole(Roles.HUB_ADMIN_ROLE, carol);
    assertTrue(hasHubAdminRoleAlice);
    assertTrue(hasHubAdminRoleBob);
    assertTrue(hasHubAdminRoleCarol);

    (bool hasSpokeAdminRoleAlice, ) = accessManager.hasRole(Roles.SPOKE_ADMIN_ROLE, alice);
    (bool hasSpokeAdminRoleBob, ) = accessManager.hasRole(Roles.SPOKE_ADMIN_ROLE, bob);
    (bool hasSpokeAdminRoleCarol, ) = accessManager.hasRole(Roles.SPOKE_ADMIN_ROLE, carol);
    assertTrue(hasSpokeAdminRoleAlice);
    assertTrue(hasSpokeAdminRoleBob);
    assertTrue(hasSpokeAdminRoleCarol);

    // We can remove HUB_ADMIN role from Alice, Bob, and Carol.
    vm.startPrank(ADMIN);
    accessManager.revokeRole(Roles.HUB_ADMIN_ROLE, alice);
    accessManager.revokeRole(Roles.HUB_ADMIN_ROLE, bob);
    accessManager.revokeRole(Roles.HUB_ADMIN_ROLE, carol);
    vm.stopPrank();

    // Alice, Bob, and Carol should no longer have HUB_ADMIN role.
    (hasHubAdminRoleAlice, ) = accessManager.hasRole(Roles.HUB_ADMIN_ROLE, alice);
    (hasHubAdminRoleBob, ) = accessManager.hasRole(Roles.HUB_ADMIN_ROLE, bob);
    (hasHubAdminRoleCarol, ) = accessManager.hasRole(Roles.HUB_ADMIN_ROLE, carol);
    assertFalse(hasHubAdminRoleAlice);
    assertFalse(hasHubAdminRoleBob);
    assertFalse(hasHubAdminRoleCarol);

    // Can still call setInterestRateData since they have SPOKE_ADMIN role.
    vm.prank(alice);
    hub.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(bob);
    hub.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(carol);
    hub.setInterestRateData(daiAssetId, encodedIrData);
  }

  /// @dev Test showcasing authority contract can be accessed via hub contract.
  function test_hub_access_manager_exposure() public {
    assertEq(address(hub.authority()), address(accessManager));
  }
}
