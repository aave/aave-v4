// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccessTest is SpokeBase {
  /// @dev Test showing that the hub functions can only be called by spokes, and not by users.
  function testAccess_hub_functions_callable_by_spokes() public {
    // Users are not allowed to directly call the hub functions
    vm.startPrank(bob);
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SpokeNotActive.selector));
    hub.add(daiAssetId, 1000e18, bob);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SpokeNotActive.selector));
    hub.remove(daiAssetId, 1000e18, bob);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SpokeNotActive.selector));
    hub.draw(daiAssetId, 1000e18, bob);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SpokeNotActive.selector));
    hub.restore(daiAssetId, 1000e18, 0, bob);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SpokeNotActive.selector));
    hub.refreshPremiumDebt(daiAssetId, 0, 0, 0, 0);

    // A spoke is allowed to call the hub functions
    deal(address(tokenList.dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), MAX_SUPPLY_AMOUNT);
    deal(address(tokenList.dai), address(spoke1), 1000e18);
    hub.add(daiAssetId, 1000e18, address(spoke1));
    hub.draw(daiAssetId, 500e18, address(spoke1));
    hub.restore(daiAssetId, 500e18, 0, address(spoke1));
    hub.remove(daiAssetId, 1000e18, address(spoke1));
    hub.refreshPremiumDebt(daiAssetId, 0, 0, 0, 0);
    vm.stopPrank();
  }

  /// @dev Test showing that spoke configurations can only be set by spoke admin.
  function testAccess_spoke_admin_config_access() public {
    // updateLiquidationConfig only callable by spoke admin
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.updateLiquidationConfig(
      DataTypes.LiquidationConfig({
        closeFactor: WadRayMath.WAD,
        liquidationBonusFactor: 40_00,
        healthFactorForMaxBonus: 0.9e18
      })
    );

    // Spoke admin can call updateLiquidationConfig
    vm.prank(address(SPOKE_ADMIN));
    spoke1.updateLiquidationConfig(
      DataTypes.LiquidationConfig({
        closeFactor: WadRayMath.WAD,
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
      address(hub),
      4,
      reserveSource,
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        liquidityPremium: 0
      }),
      DataTypes.DynamicReserveConfig({
        collateralFactor: 75_00,
        liquidationBonus: 100_00,
        liquidationFee: 0
      })
    );

    // Spoke admin can call addReserve
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(
      address(hub),
      4,
      reserveSource,
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        liquidityPremium: 0
      }),
      DataTypes.DynamicReserveConfig({
        collateralFactor: 75_00,
        liquidationBonus: 100_00,
        liquidationFee: 0
      })
    );

    // updateReserveConfig only callable by spoke admin
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.updateReserveConfig(
      _daiReserveId(spoke1),
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        liquidityPremium: 0
      })
    );

    // Spoke admin can call updateReserveConfig
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(
      _daiReserveId(spoke1),
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        liquidityPremium: 0
      })
    );

    // updateDynamicReserveConfig only callable by spoke admin
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.updateDynamicReserveConfig(
      _daiReserveId(spoke1),
      DataTypes.DynamicReserveConfig({
        collateralFactor: 75_00,
        liquidationBonus: 100_00,
        liquidationFee: 0
      })
    );

    // Spoke admin can call updateDynamicReserveConfig
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(
      _daiReserveId(spoke1),
      DataTypes.DynamicReserveConfig({
        collateralFactor: 75_00,
        liquidationBonus: 100_00,
        liquidationFee: 0
      })
    );
  }

  /// @dev Test showcasing ability to change the authority contract governing access control on the spoke.
  function testAccess_change_authority() public {
    IAccessManager authority = IAccessManager(spoke1.authority());
    address NEW_ADMIN = makeAddr('NEW_ADMIN');
    IAccessManager newAuthority = new AccessManager(NEW_ADMIN);

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
      DataTypes.LiquidationConfig({
        closeFactor: WadRayMath.WAD,
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
      address(hub),
      5,
      reserveSource,
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        liquidityPremium: 0
      }),
      DataTypes.DynamicReserveConfig({
        collateralFactor: 75_00,
        liquidationBonus: 100_00,
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
      address(hub),
      5,
      reserveSource,
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        liquidityPremium: 0
      }),
      DataTypes.DynamicReserveConfig({
        collateralFactor: 75_00,
        liquidationBonus: 100_00,
        liquidationFee: 0
      })
    );
  }
}
