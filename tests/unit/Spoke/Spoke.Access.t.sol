// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccessTest is SpokeBase {
  /// @dev Test showing that the hub functions can only be called by spokes, and not by users.
  function testAccess_hub_functions_callable_by_spokes() public {
    // Users are not allowed to directly call the hub functions
    address user = makeAddr('user');
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, user)
    );
    vm.prank(user);
    hub.add(daiAssetId, 1000e18, user);

    // A spoke is allowed to call the hub functions
    deal(address(tokenList.dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), 1000e18);
    hub.add(daiAssetId, 1000e18, address(spoke1));
    vm.stopPrank();
  }

  /// @dev Test showing that spoke configurations can only be set by spoke admin.
  function testAccess_spoke_configurations() public {
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
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        decimals: 18,
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
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        decimals: 18,
        liquidationBonus: 100_00,
        liquidityPremium: 0,
        liquidationProtocolFee: 0
      }),
      DataTypes.DynamicReserveConfig({collateralFactor: 75_00})
    );
  }
}
