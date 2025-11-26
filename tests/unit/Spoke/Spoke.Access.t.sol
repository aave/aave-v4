// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccessTest is SpokeBase {
  using SafeCast for uint256;

  /// @dev Test showing that the hub functions can only be called by spokes, and not by users.
  function testAccess_hub_functions_callable_by_spokes() public {
    // Users are not allowed to directly call the hub functions
    vm.startPrank(bob);
    vm.expectRevert(abi.encodeWithSelector(IHub.SpokeNotActive.selector));
    hub1.add(daiAssetId, 1000e18);

    vm.expectRevert(abi.encodeWithSelector(IHub.SpokeNotActive.selector));
    hub1.remove(daiAssetId, 1000e18, bob);

    vm.expectRevert(abi.encodeWithSelector(IHub.SpokeNotActive.selector));
    hub1.draw(daiAssetId, 1000e18, bob);

    vm.expectRevert(abi.encodeWithSelector(IHub.SpokeNotActive.selector));
    hub1.restore(daiAssetId, 1000e18, ZERO_PREMIUM_DELTA);

    vm.expectRevert(abi.encodeWithSelector(IHub.SpokeNotActive.selector));
    hub1.refreshPremium(daiAssetId, ZERO_PREMIUM_DELTA);

    vm.expectRevert(abi.encodeWithSelector(IHub.SpokeNotActive.selector));
    hub1.payFeeShares(daiAssetId, 1000e18);

    vm.expectRevert(abi.encodeWithSelector(IHub.SpokeNotActive.selector));
    hub1.transferShares(daiAssetId, 1000e18, bob);

    // A spoke is allowed to call the hub functions
    deal(address(tokenList.dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    deal(address(tokenList.dai), address(spoke1), 1000e18);
    tokenList.dai.transfer(address(hub1), 1000e18);
    hub1.add(daiAssetId, 1000e18);
    hub1.draw(daiAssetId, 500e18, address(spoke1));
    tokenList.dai.transfer(address(hub1), 500e18);
    hub1.restore(daiAssetId, 500e18, ZERO_PREMIUM_DELTA);
    hub1.remove(daiAssetId, 1000e18, address(spoke1));
    hub1.refreshPremium(daiAssetId, ZERO_PREMIUM_DELTA);
    tokenList.dai.transfer(address(hub1), 1000e18);
    hub1.add(daiAssetId, 1000e18);
    hub1.payFeeShares(daiAssetId, 1e18);
    hub1.transferShares(
      daiAssetId,
      hub1.getSpokeAddedShares(daiAssetId, address(spoke1)),
      address(spoke2)
    );
    vm.stopPrank();
  }

  /// @dev Test showing that spoke configurations can only be set by spoke admin.
  function testAccess_spoke_admin_config_access() public {
    // updateLiquidationConfig only callable by spoke admin
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: WadRayMath.WAD.toUint128(),
        liquidationBonusFactor: 40_00,
        healthFactorForMaxBonus: 0.9e18
      })
    );

    // Spoke admin can call updateLiquidationConfig
    vm.prank(address(SPOKE_ADMIN));
    spoke1.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: WadRayMath.WAD.toUint128(),
        liquidationBonusFactor: 40_00,
        healthFactorForMaxBonus: 0.9e18
      })
    );

    // addReserve only callable by spoke admin
    address reserveSource = _deployMockPriceFeed(spoke1, 1e8);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.addReserve(
      address(hub1),
      usdzAssetId,
      reserveSource,
      ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 0}),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 100_00,
        liquidationFee: 0
      })
    );

    // Spoke admin can call addReserve
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(
      address(hub1),
      usdzAssetId,
      reserveSource,
      ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 0}),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 100_00,
        liquidationFee: 0
      })
    );

    // updateReserveConfig only callable by spoke admin
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.updateReserveConfig(
      _daiReserveId(spoke1),
      ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 0})
    );

    // Spoke admin can call updateReserveConfig
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(
      _daiReserveId(spoke1),
      ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 0})
    );

    // addDynamicReserveConfig only callable by spoke admin
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.addDynamicReserveConfig(
      _daiReserveId(spoke1),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 100_00,
        liquidationFee: 0
      })
    );

    // Spoke admin can call addDynamicReserveConfig
    vm.prank(SPOKE_ADMIN);
    spoke1.addDynamicReserveConfig(
      _daiReserveId(spoke1),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 100_00,
        liquidationFee: 0
      })
    );
  }

  /// @dev Test showcasing ability to change the authority contract governing access control on the spoke.
  function testAccess_change_authority() public {
    IAccessManager authority = IAccessManager(spoke1.authority());
    address NEW_ADMIN = makeAddr('NEW_ADMIN');
    IAccessManager newAuthority = new AccessManager(NEW_ADMIN);

    uint256 assetId = usdzAssetId;

    // Set up the role for spoke admin to call update liquidation config
    vm.startPrank(NEW_ADMIN);
    newAuthority.grantRole(Roles.SPOKE_ADMIN_ROLE, SPOKE_ADMIN, 0);
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = ISpoke.updateLiquidationConfig.selector;
    newAuthority.setTargetFunctionRole(address(spoke1), selectors, Roles.SPOKE_ADMIN_ROLE);
    vm.stopPrank();

    // Only Admin can change the authority contract
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessManager.AccessManagerUnauthorizedAccount.selector,
        address(this),
        Roles.DEFAULT_ADMIN_ROLE
      )
    );
    authority.updateAuthority(address(spoke1), address(newAuthority));

    // Admin can change the authority contract
    vm.prank(ADMIN);
    authority.updateAuthority(address(spoke1), address(newAuthority));

    assertEq(spoke1.authority(), address(newAuthority), 'Authority not changed');

    // Spoke admin can call update liquidation config on the spoke after authority change
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: WadRayMath.WAD.toUint128(),
        liquidationBonusFactor: 40_00,
        healthFactorForMaxBonus: 0.9e18
      })
    );

    // Spoke admin cannot call add reserve on the spoke after authority change
    address reserveSource = _deployMockPriceFeed(spoke1, 1e8);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, SPOKE_ADMIN)
    );
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(
      address(hub1),
      assetId,
      reserveSource,
      ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 0}),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 100_00,
        liquidationFee: 0
      })
    );

    // Now we also give the spoke admin role capability to add reserve on new authority
    selectors[0] = ISpoke.addReserve.selector;
    vm.prank(NEW_ADMIN);
    newAuthority.setTargetFunctionRole(address(spoke1), selectors, Roles.SPOKE_ADMIN_ROLE);

    // Spoke admin can now call add reserve on the spoke after authority change
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(
      address(hub1),
      assetId,
      reserveSource,
      ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 0}),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 100_00,
        liquidationFee: 0
      })
    );
  }
}
