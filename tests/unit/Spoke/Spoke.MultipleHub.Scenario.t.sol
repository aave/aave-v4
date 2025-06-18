// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Spoke.MultipleHub.Base.t.sol';

contract SpokeMultipleHubScenarioTest is SpokeMultipleHubBase {
  /* @dev Test showcasing a possible configuration for isolation mode
   * A new hub and spoke are deployed with new assets A and B.
   * There is no liquidity for asset B on the new hub, so instead
   * Asset B is listed from the canonical hub and linked to the new spoke with a draw cap.
   * Thus users can borrow asset B from the canonical hub via the new spoke,
   * without being able to supply it from the new spoke.
   */
  function test_isolation_mode() public {
    setUpIsolationMode();

    // Bob can supply asset A to the new spoke and set it as collateral
    vm.startPrank(bob);
    assetA.approve(address(newHub), type(uint256).max);
    deal(address(assetA), bob, MAX_SUPPLY_AMOUNT);
    newSpoke.supply(isolationVars.reserveAId, MAX_SUPPLY_AMOUNT);
    newSpoke.setUsingAsCollateral(isolationVars.reserveAId, true);

    // Check Bob's supplied amounts and collateral status
    assertEq(
      newSpoke.getUserSuppliedAmount(isolationVars.reserveAId, bob),
      MAX_SUPPLY_AMOUNT,
      'bob supplied amount of reserve A on new spoke'
    );
    assertTrue(
      newSpoke.getUsingAsCollateral(isolationVars.reserveAId, bob),
      'bob using reserve A as collateral on new spoke'
    );
    assertEq(
      newHub.getAssetSuppliedAmount(isolationVars.assetAId),
      MAX_SUPPLY_AMOUNT,
      'total supplied amount of assetA on new hub'
    );

    // Bob cannot borrow asset B because there is no liquidity
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    newSpoke.borrow(isolationVars.reserveBId, 100e18, bob);

    // Add main hub reserve B to the new spoke
    isolationVars.reserveBIdMainHub = newSpoke.addReserve(
      isolationVars.assetBIdMainHub,
      DataTypes.ReserveConfig({
        decimals: assetB.decimals(),
        active: true,
        frozen: false,
        paused: false,
        liquidationBonus: 100_00,
        liquidityPremium: 15_00,
        liquidationProtocolFee: 0,
        borrowable: true,
        collateral: true,
        hub: hub
      }),
      dynReserveConfig
    );

    // Set the price of main hub reserve B on new spoke
    newOracle.setReservePrice(isolationVars.reserveBIdMainHub, 50_000e8);

    // Link main hub and new spoke for asset B
    // 0 supply cap, 100k draw cap
    hub.addSpoke(
      isolationVars.assetBIdMainHub,
      DataTypes.SpokeConfig({drawCap: 100_000e18, supplyCap: 0}),
      address(newSpoke)
    );

    // Bob still cannot borrow asset B from the new hub because there is no liquidity
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    newSpoke.borrow(isolationVars.reserveBId, 100e18, bob);
    vm.stopPrank();

    // Alice can supply asset B to the main hub via spoke 1
    vm.startPrank(alice);
    assetB.approve(address(hub), type(uint256).max);
    deal(address(assetB), alice, 500_000e18);
    spoke1.supply(isolationVars.spoke1ReserveBId, 500_000e18);
    vm.stopPrank();

    // Check Alice's supplied amount of asset B on spoke 1
    assertEq(
      spoke1.getUserSuppliedAmount(isolationVars.spoke1ReserveBId, alice),
      500_000e18,
      'alice supplied amount of reserve B on spoke 1'
    );
    assertEq(
      hub.getAssetSuppliedAmount(isolationVars.assetBIdMainHub),
      500_000e18,
      'total supplied amount of asset B on main hub'
    );

    // Bob CAN borrow asset B from the main hub via new spoke up until the draw cap of 100k
    vm.startPrank(bob);
    newSpoke.borrow(isolationVars.reserveBIdMainHub, 100_000e18, bob);

    // Check Bob's total debt of asset B on the new spoke
    assertEq(newSpoke.getUserTotalDebt(isolationVars.reserveBIdMainHub, bob), 100_000e18);
    assertEq(hub.getAssetTotalDebt(isolationVars.assetBIdMainHub), 100_000e18);

    // Bob cannot borrow asset B from main hub via new spoke past draw cap
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, 100_000e18));
    newSpoke.borrow(isolationVars.reserveBIdMainHub, 1e18, bob);

    // Bob cannot supply B to main hub via new spoke because supply cap is 0
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, 0));
    newSpoke.supply(isolationVars.reserveBIdMainHub, 1e18);
    vm.stopPrank();

    // Alice can supply B to the new hub via new spoke
    vm.startPrank(alice);
    assetB.approve(address(newHub), type(uint256).max);
    deal(address(assetB), alice, MAX_SUPPLY_AMOUNT);
    newSpoke.supply(isolationVars.reserveBId, MAX_SUPPLY_AMOUNT);
    vm.stopPrank();

    // Now there is liquidity for asset B on the new hub
    assertEq(
      newHub.getAssetSuppliedAmount(isolationVars.assetBId),
      MAX_SUPPLY_AMOUNT,
      'total supplied amount of asset B on new hub'
    );
    assertEq(
      newSpoke.getReserveSuppliedAmount(isolationVars.reserveBId),
      MAX_SUPPLY_AMOUNT,
      'total supplied amount of reserve B on new spoke'
    );

    // Bob will migrate to borrowing asset B from the new spoke, new hub, so repays canonical hub position
    vm.startPrank(bob);
    assetB.approve(address(hub), type(uint256).max);
    newSpoke.repay(isolationVars.reserveBIdMainHub, 100_000e18);
    assertEq(newSpoke.getUserTotalDebt(isolationVars.reserveBIdMainHub, bob), 0);
    assertEq(hub.getAssetTotalDebt(isolationVars.assetBIdMainHub), 0);

    // Bob opens new borrow position for asset B on the new spoke, new hub
    newSpoke.borrow(isolationVars.reserveBId, 100_000e18, bob);
    assertEq(newSpoke.getUserTotalDebt(isolationVars.reserveBId, bob), 100_000e18);
    assertEq(newHub.getAssetTotalDebt(isolationVars.assetBId), 100_000e18);

    // DAO offboards credit line to new spoke from the canonical hub by setting Asset B draw cap to 0
    hub.updateSpokeConfig(
      isolationVars.assetBIdMainHub,
      address(newSpoke),
      DataTypes.SpokeConfig({drawCap: 0, supplyCap: 0})
    );

    // Now Bob or any other users cannot draw any asset B from the new spoke main hub due to new draw cap of 0
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, 0));
    newSpoke.borrow(isolationVars.reserveBIdMainHub, 1e18, bob);
    vm.stopPrank();
  }

  /* @dev Test showcasing a possible configuration for siloed mode
   * A new hub and spoke are deployed with Assets A and B, where B is the only borrowable asset.
   * Users can use usdx as collateral on the new spoke, which supplies to the canonical hub.
   * Users may not borrow usdx from the new spoke, but can use it as collateral to borrow the
   * only borrowable asset: Asset B.
   */
  function test_siloed_mode() public {
    setUpSiloedMode();

    // Bob can supply Asset A to the new spoke, canonical hub, up to 500k and set it as collateral
    vm.startPrank(bob);
    deal(address(assetA), bob, MAX_SUPPLY_AMOUNT);
    assetA.approve(address(hub), type(uint256).max);
    newSpoke.supply(siloedVars.reserveAIdNewSpoke, siloedVars.assetASupplyCap);
    newSpoke.setUsingAsCollateral(siloedVars.reserveAIdNewSpoke, true);
    assertEq(
      newSpoke.getUserSuppliedAmount(siloedVars.reserveAIdNewSpoke, bob),
      siloedVars.assetASupplyCap,
      'bob supplied amount of asset A on new spoke'
    );
    assertTrue(
      newSpoke.getUsingAsCollateral(siloedVars.reserveAIdNewSpoke, bob),
      'bob using asset A as collateral on new spoke'
    );
    assertEq(
      hub.getAssetSuppliedAmount(siloedVars.assetAId),
      siloedVars.assetASupplyCap,
      'total supplied amount of asset A on canonical hub'
    );

    // Bob cannot supply past his currently supplied amount due to supply cap
    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, siloedVars.assetASupplyCap)
    );
    newSpoke.supply(siloedVars.reserveAIdNewSpoke, 1e18);

    // Bob cannot borrow asset A from the new spoke, canonical hub, because draw cap is 0
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, 0));
    newSpoke.borrow(siloedVars.reserveAIdNewSpoke, 1e18, bob);
    vm.stopPrank();

    // Let Alice supply some asset B to the new spoke
    vm.startPrank(alice);
    assetB.approve(address(newHub), type(uint256).max);
    deal(address(assetB), alice, 300_000e18);
    newSpoke.supply(siloedVars.reserveBId, 300_000e18);
    vm.stopPrank();

    // Bob can borrow asset B from the new spoke, new hub, up to 100k
    vm.startPrank(bob);
    newSpoke.borrow(siloedVars.reserveBId, siloedVars.assetBDrawCap, bob);

    // Check Bob's total debt of asset B on the new spoke
    assertEq(newSpoke.getUserTotalDebt(siloedVars.reserveBId, bob), siloedVars.assetBDrawCap);
    assertEq(newHub.getAssetTotalDebt(siloedVars.assetBId), siloedVars.assetBDrawCap);
    assertEq(
      newSpoke.getReserve(siloedVars.reserveBId).asset,
      address(assetB),
      'Bob borrowed asset B from new spoke'
    );

    // Bob cannot borrow additional asset B from the new spoke, new hub, because of draw cap
    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, siloedVars.assetBDrawCap)
    );
    newSpoke.borrow(siloedVars.reserveBId, 1e18, bob);
    vm.stopPrank();
  }
}
