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
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.addReserve(
      10,
      address(hub),
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        liquidationBonus: 100_00,
        liquidityPremium: 0,
        liquidationProtocolFee: 0
      }),
      DataTypes.DynamicReserveConfig({collateralFactor: 75_00})
    );

    // Spoke admin can call addReserve
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(
      4,
      address(hub),
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        liquidationBonus: 100_00,
        liquidityPremium: 0,
        liquidationProtocolFee: 0
      }),
      DataTypes.DynamicReserveConfig({collateralFactor: 75_00})
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
        liquidationBonus: 100_00,
        liquidityPremium: 0,
        liquidationProtocolFee: 0
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
        liquidationBonus: 100_00,
        liquidityPremium: 0,
        liquidationProtocolFee: 0
      })
    );

    // updateDynamicReserveConfig only callable by spoke admin
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.updateDynamicReserveConfig(
      _daiReserveId(spoke1),
      DataTypes.DynamicReserveConfig({collateralFactor: 75_00})
    );

    // Spoke admin can call updateDynamicReserveConfig
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(
      _daiReserveId(spoke1),
      DataTypes.DynamicReserveConfig({collateralFactor: 75_00})
    );
  }
}
