// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Spoke.MultipleHub.Base.t.sol';

contract SpokeMultipleHubSiloedBorrowingTest is SpokeMultipleHubBase {
  struct SiloedLocalVars {
    uint256 assetAId;
    uint256 assetBId;
    uint256 assetASupplyCap;
    uint256 assetBDrawCap;
    uint256 reserveAId;
    uint256 reserveBId;
    uint256 reserveAIdNewSpoke;
  }

  SiloedLocalVars internal siloedVars;

  function setUp() public virtual override {
    super.setUp();
    setUpSiloedBorrowing();
  }

  /* @dev Adds asset B to the new hub and new spoke with 100k draw cap.
   * Adds Asset A to the canonical hub and canonical spoke with no restrictions.
   * Relists Asset A from the canonical hub on the new spoke, with supply cap 500k, 0 borrow cap.
   * SUMMARY:
   * New Spoke: AssetA, canonical hub supplyable up to 500k; Asset B, new hub borrowable up to 100k.
   * Canonical Spoke: Asset A, no restrictions.
   */
  function setUpSiloedBorrowing() internal {
    vm.startPrank(ADMIN);
    siloedVars.assetBDrawCap = 100_000e18;
    siloedVars.assetASupplyCap = 500_000e18;

    // Add asset B to the new hub
    newHub.addAsset(
      address(assetB),
      assetB.decimals(),
      address(treasurySpoke),
      address(newIrStrategy),
      encodedIrData
    );
    siloedVars.assetBId = newHub.getAssetCount() - 1;

    // Add B reserve to the new spoke
    siloedVars.reserveBId = newSpoke.addReserve(
      address(newHub),
      siloedVars.assetBId,
      _deployMockPriceFeed(newSpoke, 2000e8),
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        collateralRisk: 15_00,
        borrowable: true,
        collateral: true
      }),
      dynReserveConfig
    );

    // Link new hub and new spoke for asset B, 100k draw cap
    newHub.addSpoke(
      siloedVars.assetBId,
      address(newSpoke),
      DataTypes.SpokeConfig({
        active: true,
        supplyCap: UINT256_MAX,
        drawCap: siloedVars.assetBDrawCap
      })
    );

    // Add asset A to the canonical hub
    hub.addAsset(
      address(assetA),
      assetA.decimals(),
      address(treasurySpoke),
      address(irStrategy), // Use the canonical hub's interest rate strategy
      encodedIrData
    );
    siloedVars.assetAId = hub.getAssetCount() - 1;

    // Add A reserve to spoke 1
    siloedVars.reserveAId = spoke1.addReserve(
      address(hub),
      siloedVars.assetAId,
      _deployMockPriceFeed(spoke1, 50_000e8),
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        collateralRisk: 15_00,
        borrowable: true,
        collateral: true
      }),
      dynReserveConfig
    );

    // Link canonical hub and spoke 1 for asset A
    hub.addSpoke(
      siloedVars.assetAId,
      address(spoke1),
      DataTypes.SpokeConfig({
        active: true,
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max
      })
    );

    // Add reserve A from canonical hub to the new spoke
    siloedVars.reserveAIdNewSpoke = newSpoke.addReserve(
      address(hub),
      siloedVars.assetAId,
      _deployMockPriceFeed(newSpoke, 2000e8),
      DataTypes.ReserveConfig({
        active: true,
        frozen: false,
        paused: false,
        collateralRisk: 15_00,
        borrowable: true,
        collateral: true
      }),
      dynReserveConfig
    );

    // Link canonical hub and new spoke for asset A, 500k supply cap, 0 borrow cap
    hub.addSpoke(
      siloedVars.assetAId,
      address(newSpoke),
      DataTypes.SpokeConfig({active: true, supplyCap: siloedVars.assetASupplyCap, drawCap: 0})
    );
    vm.stopPrank();

    // Approvals
    vm.prank(bob);
    assetA.approve(address(hub), type(uint256).max);

    vm.prank(alice);
    assetB.approve(address(newHub), type(uint256).max);

    // Deal tokens
    deal(address(assetA), bob, MAX_SUPPLY_AMOUNT);
    deal(address(assetB), alice, MAX_SUPPLY_AMOUNT);
  }

  /* @dev Test showcasing a possible configuration for siloed mode
   * A new hub and spoke are deployed with Assets A and B, where B is the only borrowable asset.
   * Users can use usdx as collateral on the new spoke, which supplies to the canonical hub.
   * Users may not borrow usdx from the new spoke, but can use it as collateral to borrow the
   * only borrowable asset: Asset B.
   */
  function test_siloed_borrowing() public {
    // Bob can supply Asset A to the new spoke, canonical hub, up to 500k and set it as collateral
    Utils.supplyCollateral(
      newSpoke,
      siloedVars.reserveAIdNewSpoke,
      bob,
      siloedVars.assetASupplyCap,
      bob
    );
    assertEq(
      newSpoke.getUserSuppliedAmount(siloedVars.reserveAIdNewSpoke, bob),
      siloedVars.assetASupplyCap,
      'bob supplied amount of asset A on new spoke'
    );
    assertTrue(
      newSpoke.isUsingAsCollateral(siloedVars.reserveAIdNewSpoke, bob),
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
    Utils.supply(newSpoke, siloedVars.reserveAIdNewSpoke, bob, 1e18, bob);

    // Bob cannot borrow asset A from the new spoke, canonical hub, because draw cap is 0
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, 0));
    Utils.borrow(newSpoke, siloedVars.reserveAIdNewSpoke, bob, 1e18, bob);

    // Let Alice supply some asset B to the new spoke
    Utils.supply(newSpoke, siloedVars.reserveBId, alice, siloedVars.assetBDrawCap * 2, alice);

    // Bob can borrow asset B from the new spoke, new hub, up to 100k
    Utils.borrow(newSpoke, siloedVars.reserveBId, bob, siloedVars.assetBDrawCap, bob);

    // Check Bob's total debt of asset B on the new spoke
    assertEq(newSpoke.getUserTotalDebt(siloedVars.reserveBId, bob), siloedVars.assetBDrawCap);
    assertEq(newHub.getAssetTotalDebt(siloedVars.assetBId), siloedVars.assetBDrawCap);
    assertEq(
      newSpoke.getReserve(siloedVars.reserveBId).underlying,
      address(assetB),
      'Bob borrowed asset B from new spoke'
    );

    // Bob cannot borrow additional asset B from the new spoke, new hub, because of draw cap
    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, siloedVars.assetBDrawCap)
    );
    Utils.borrow(newSpoke, siloedVars.reserveBId, bob, 1e18, bob);
  }
}
