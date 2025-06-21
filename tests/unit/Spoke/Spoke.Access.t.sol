// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AuthorityUtils} from 'src/dependencies/openzeppelin/AuthorityUtils.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {Context} from 'src/dependencies/openzeppelin/Context.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccessTest is SpokeBase, Context {
  // TODO: Needed for all permutations of caller, target, and selector?
  function test_authority_no_delay() public {
    // Test that the authority has no delay for canCall
    (bool immediate, uint32 delay) = AuthorityUtils.canCallWithDelay(
      address(accessManager),
      address(HUB_ADMIN),
      address(hub),
      ILiquidityHub.addAsset.selector
    );
    assertTrue(immediate, 'Authority should allow immediate call');
    assertEq(delay, 0, 'Authority should have no delay');
  }

  /*
  // TODO: How? and Needed?
  function test_zero_cost_abstraction() public {
    // Snapshot the gas of querying _msgSender()
    vm.startSnapshotGas('test');
    address sender = _msgSender();
    uint256 msgSenderGas = vm.stopSnapshotGas();
    console.log('gas snapshot msg sender', msgSenderGas);

    vm.startSnapshotGas('test');
    address authority = IAccessManaged(address(hub)).authority();
    uint256 authorityGas = vm.stopSnapshotGas();
    console.log('gas snapshot authority', authorityGas);
  }
  */

  /// @dev Test showing that the hub functions can only be called by spokes, and not by users.
  function testAccess_hub_functions_callable_by_spokes() public {
    // Users are not allowed to directly call the hub functions
    address user = makeAddr('user');
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SpokeNotActive.selector));
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
        hub: hub,
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
        hub: hub,
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
