// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubAccessTest is HubBase {
  /// @dev Test showing that restricted functions on hub can only be called by hub admin.
  function test_hub_admin_access() public {
    TestnetERC20 tokenA = new TestnetERC20('A', 'A', 18);
    IHub.AssetConfig memory assetConfig = IHub.AssetConfig({
      feeReceiver: address(treasurySpoke),
      liquidityFee: 0,
      irStrategy: address(irStrategy),
      reinvestmentController: address(0)
    });
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: 1000,
      drawCap: 1000,
      riskPremiumCap: 1000_00
    });

    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );

    // Only Hub Admin can add assets to the hub
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub1.addAsset(address(tokenA), 18, address(treasurySpoke), address(irStrategy), encodedIrData);

    // Hub Admin can add assets to the hub
    vm.prank(HUB_ADMIN);
    hub1.addAsset(address(tokenA), 18, address(treasurySpoke), address(irStrategy), encodedIrData);
    uint256 assetAId = hub1.getAssetCount() - 1; // Asset A Id

    // Only Hub Admin can update asset config
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub1.updateAssetConfig(daiAssetId, assetConfig, new bytes(0));

    // Hub Admin can update asset config
    vm.prank(HUB_ADMIN);
    hub1.updateAssetConfig(daiAssetId, assetConfig, new bytes(0));

    // Only Hub Admin can add spoke
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub1.addSpoke(assetAId, address(spoke1), spokeConfig);

    // Hub Admin can add spoke
    vm.prank(HUB_ADMIN);
    hub1.addSpoke(assetAId, address(spoke1), spokeConfig);

    // Only Hub Admin can update spoke config
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub1.updateSpokeConfig(assetAId, address(spoke1), spokeConfig);

    // Hub Admin can update spoke config
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(assetAId, address(spoke1), spokeConfig);
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

    // Only Hub can set interest rates
    vm.expectRevert(abi.encodeWithSelector(IAssetInterestRateStrategy.OnlyHub.selector));
    irStrategy.setInterestRateData(daiAssetId, encodedIrData);

    // Hub can set interest rates
    vm.prank(address(hub1));
    irStrategy.setInterestRateData(daiAssetId, encodedIrData);

    // Only Hub Admin can call function on hub to set interest rates
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub1.setInterestRateData(daiAssetId, encodedIrData);

    // Hub Admin can call function on hub to set interest rates
    vm.prank(HUB_ADMIN);
    hub1.setInterestRateData(daiAssetId, encodedIrData);

    assertBorrowRateSynced(hub1, daiAssetId, 'setInterestRateData');
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
    hubSelectors[0] = IHub.setInterestRateData.selector;
    vm.prank(ADMIN);
    accessManager.setTargetFunctionRole(address(hub1), hubSelectors, Roles.DEFAULT_ADMIN_ROLE);

    // The old role (HUB_ADMIN) should no longer have access
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, HUB_ADMIN)
    );
    vm.prank(HUB_ADMIN);
    hub1.setInterestRateData(daiAssetId, encodedIrData);

    // The new role (DEFAULT_ADMIN_ROLE) should have access
    vm.prank(ADMIN);
    hub1.setInterestRateData(daiAssetId, encodedIrData);

    // HUB_ADMIN can still access the other hub functions for which it has permissions
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      daiAssetId,
      address(spoke1),
      IHub.SpokeConfig({
        active: true,
        paused: false,
        addCap: 1000,
        drawCap: 1000,
        riskPremiumCap: 1000_00
      })
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
    hub1.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(bob);
    hub1.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(carol);
    hub1.setInterestRateData(daiAssetId, encodedIrData);

    // Now, we change the role responsible for setting interest rate data to SET_INTEREST_RATE role.
    uint64 SET_INTEREST_RATE_ROLE = 4;
    bytes4[] memory hubSelectors = new bytes4[](1);
    hubSelectors[0] = IHub.setInterestRateData.selector;
    vm.prank(ADMIN);
    accessManager.setTargetFunctionRole(address(hub1), hubSelectors, SET_INTEREST_RATE_ROLE);

    // Alice, Bob, and Carol should no longer have access to set interest rate data.
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    hub1.setInterestRateData(daiAssetId, encodedIrData);
    vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, bob));
    vm.prank(bob);
    hub1.setInterestRateData(daiAssetId, encodedIrData);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, carol)
    );
    vm.prank(carol);
    hub1.setInterestRateData(daiAssetId, encodedIrData);

    // Now, we grant SET_INTEREST_RATE role to Alice, Bob, and Carol with 0 delay
    vm.startPrank(ADMIN);
    accessManager.grantRole(SET_INTEREST_RATE_ROLE, alice, 0);
    accessManager.grantRole(SET_INTEREST_RATE_ROLE, bob, 0);
    accessManager.grantRole(SET_INTEREST_RATE_ROLE, carol, 0);
    vm.stopPrank();

    // Alice, Bob, and Carol should now be able to set interest rate data.
    vm.prank(alice);
    hub1.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(bob);
    hub1.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(carol);
    hub1.setInterestRateData(daiAssetId, encodedIrData);

    // Alice, Bob, and Carol currently have both HUB_ADMIN and SET_INTEREST_RATE roles.
    IAccessManager accessManager = IAccessManager(hub1.authority());
    assertTrue(_hasRole(accessManager, Roles.HUB_ADMIN_ROLE, alice));
    assertTrue(_hasRole(accessManager, Roles.HUB_ADMIN_ROLE, bob));
    assertTrue(_hasRole(accessManager, Roles.HUB_ADMIN_ROLE, carol));

    assertTrue(_hasRole(accessManager, SET_INTEREST_RATE_ROLE, alice));
    assertTrue(_hasRole(accessManager, SET_INTEREST_RATE_ROLE, bob));
    assertTrue(_hasRole(accessManager, SET_INTEREST_RATE_ROLE, carol));

    // We can remove HUB_ADMIN role from Alice, Bob, and Carol.
    vm.startPrank(ADMIN);
    accessManager.revokeRole(Roles.HUB_ADMIN_ROLE, alice);
    accessManager.revokeRole(Roles.HUB_ADMIN_ROLE, bob);
    accessManager.revokeRole(Roles.HUB_ADMIN_ROLE, carol);
    vm.stopPrank();

    // Alice, Bob, and Carol should no longer have HUB_ADMIN role.
    assertFalse(_hasRole(accessManager, Roles.HUB_ADMIN_ROLE, alice));
    assertFalse(_hasRole(accessManager, Roles.HUB_ADMIN_ROLE, bob));
    assertFalse(_hasRole(accessManager, Roles.HUB_ADMIN_ROLE, carol));

    // Can still call setInterestRateData since they have SET_INTEREST_RATE role.
    vm.prank(alice);
    hub1.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(bob);
    hub1.setInterestRateData(daiAssetId, encodedIrData);
    vm.prank(carol);
    hub1.setInterestRateData(daiAssetId, encodedIrData);
  }

  /// @dev Test showcasing authority contract can be accessed via hub contract.
  function test_hub_access_manager_exposure() public view {
    assertEq(address(hub1.authority()), address(accessManager));
  }

  /// @dev Test showcasing ability to change the authority contract governing access control on the hub1.
  function test_change_authority() public {
    IHub.AssetConfig memory assetConfig = IHub.AssetConfig({
      feeReceiver: address(treasurySpoke),
      liquidityFee: 0,
      irStrategy: address(irStrategy),
      reinvestmentController: address(0)
    });
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: 1000,
      drawCap: 1000,
      riskPremiumCap: 1000_00
    });

    IAccessManager authority = IAccessManager(hub1.authority());
    address NEW_ADMIN = makeAddr('NEW_ADMIN');
    IAccessManager newAuthority = new AccessManager(NEW_ADMIN);

    // Set up the role for hub admin to call update asset config
    vm.startPrank(NEW_ADMIN);
    newAuthority.grantRole(Roles.HUB_ADMIN_ROLE, HUB_ADMIN, 0);
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHub.updateAssetConfig.selector;
    newAuthority.setTargetFunctionRole(address(hub1), selectors, Roles.HUB_ADMIN_ROLE);
    vm.stopPrank();

    // Only Admin can change the authority contract
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedAccount.selector,
        address(this),
        Roles.DEFAULT_ADMIN_ROLE
      )
    );
    authority.updateAuthority(address(hub1), address(newAuthority));

    // Admin can change the authority contract
    vm.prank(ADMIN);
    authority.updateAuthority(address(hub1), address(newAuthority));

    assertEq(hub1.authority(), address(newAuthority), 'Authority not changed');

    // Hub admin can call update asset config on the hub after authority change
    vm.prank(HUB_ADMIN);
    hub1.updateAssetConfig(daiAssetId, assetConfig, new bytes(0));

    // Hub admin cannot call update spoke config on the hub after authority change
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, HUB_ADMIN)
    );
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(daiAssetId, address(spoke1), spokeConfig);

    // Now we also give the hub admin role capability to update spoke config on new authority
    selectors[0] = IHub.updateSpokeConfig.selector;
    vm.prank(NEW_ADMIN);
    newAuthority.setTargetFunctionRole(address(hub1), selectors, Roles.HUB_ADMIN_ROLE);

    // Hub admin can now call update spoke config on the hub after authority change
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(daiAssetId, address(spoke1), spokeConfig);
  }
}
