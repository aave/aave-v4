// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/multi-hub/Spoke.MultipleHub.Base.t.sol';

contract SpokeMultipleHubSiloedBorrowingTest is SpokeMultipleHubBase {
  struct SiloedLocalVars {
    uint256 assetAId;
    uint256 assetBId;
    uint40 assetAAddCap;
    uint40 assetBDrawCap;
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
   * Relists Asset A from the canonical hub on the new spoke, with add cap 500k, 0 borrow cap.
   * SUMMARY:
   * New Spoke: AssetA, canonical hub supplyable up to 500k; Asset B, new hub borrowable up to 100k.
   * Canonical Spoke: Asset A, no restrictions.
   */
  function setUpSiloedBorrowing() internal {
    vm.startPrank(ADMIN);
    siloedVars.assetBDrawCap = 100_000;
    siloedVars.assetAAddCap = 500_000;

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
      _getDefaultReserveConfig(15_00),
      dynReserveConfig
    );

    // Link new hub and new spoke for asset B, 100k draw cap
    newHub.addSpoke(
      siloedVars.assetBId,
      address(newSpoke),
      IHub.SpokeConfig({
        halted: false,
        active: true,
        addCap: MAX_ALLOWED_SPOKE_CAP,
        drawCap: siloedVars.assetBDrawCap,
        riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
      })
    );

    // Add asset A to the canonical hub
    hub1.addAsset(
      address(assetA),
      assetA.decimals(),
      address(treasurySpoke),
      address(irStrategy), // Use the canonical hub's drawn rate strategy
      encodedIrData
    );
    siloedVars.assetAId = hub1.getAssetCount() - 1;

    // Add A reserve to spoke 1
    siloedVars.reserveAId = spoke1.addReserve(
      address(hub1),
      siloedVars.assetAId,
      _deployMockPriceFeed(spoke1, 50_000e8),
      _getDefaultReserveConfig(15_00),
      dynReserveConfig
    );

    // Link canonical hub and spoke 1 for asset A
    hub1.addSpoke(
      siloedVars.assetAId,
      address(spoke1),
      IHub.SpokeConfig({
        active: true,
        halted: false,
        addCap: MAX_ALLOWED_SPOKE_CAP,
        drawCap: MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
      })
    );

    // Add reserve A from canonical hub to the new spoke
    siloedVars.reserveAIdNewSpoke = newSpoke.addReserve(
      address(hub1),
      siloedVars.assetAId,
      _deployMockPriceFeed(newSpoke, 2000e8),
      _getDefaultReserveConfig(15_00),
      dynReserveConfig
    );

    // Link canonical hub and new spoke for asset A, 500k add cap, 0 borrow cap
    hub1.addSpoke(
      siloedVars.assetAId,
      address(newSpoke),
      IHub.SpokeConfig({
        active: true,
        halted: false,
        addCap: siloedVars.assetAAddCap,
        drawCap: 0,
        riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
      })
    );
    vm.stopPrank();

    // Approvals
    vm.startPrank(bob);
    assetA.approve(address(spoke1), UINT256_MAX);
    assetB.approve(address(spoke1), UINT256_MAX);
    assetA.approve(address(newSpoke), UINT256_MAX);
    assetB.approve(address(newSpoke), UINT256_MAX);
    vm.stopPrank();

    vm.startPrank(alice);
    assetA.approve(address(spoke1), UINT256_MAX);
    assetB.approve(address(spoke1), UINT256_MAX);
    assetA.approve(address(newSpoke), UINT256_MAX);
    assetB.approve(address(newSpoke), UINT256_MAX);
    vm.stopPrank();

    // Deal tokens
    deal(address(assetA), bob, MAX_SUPPLY_AMOUNT);
    deal(address(assetB), alice, MAX_SUPPLY_AMOUNT);
  }

  /* @dev Test showcasing a possible configuration for siloed mode
   * A new hub and spoke are deployed with Assets A and B, where B is the only borrowable asset.
   * Users can use usdx as collateral on the new spoke, which supplies to the canonical hub1.
   * Users may not borrow usdx from the new spoke, but can use it as collateral to borrow the
   * only borrowable asset: Asset B.
   */
  function test_siloed_borrowing() public {
    // Bob can supply Asset A to the new spoke, canonical hub, up to 500k and set it as collateral
    uint256 assetAAddCapAmount = siloedVars.assetAAddCap * 10 ** assetA.decimals();
    SpokeActions.supplyCollateral({
      spoke: newSpoke,
      reserveId: siloedVars.reserveAIdNewSpoke,
      caller: bob,
      amount: assetAAddCapAmount,
      onBehalfOf: bob
    });
    assertEq(
      newSpoke.getUserSuppliedAssets(siloedVars.reserveAIdNewSpoke, bob),
      assetAAddCapAmount,
      'bob supplied amount of asset A on new spoke'
    );
    assertTrue(
      _isUsingAsCollateral(newSpoke, siloedVars.reserveAIdNewSpoke, bob),
      'bob using asset A as collateral on new spoke'
    );
    assertEq(
      hub1.getAddedAssets(siloedVars.assetAId),
      assetAAddCapAmount,
      'total supplied amount of asset A on canonical hub'
    );

    // Bob cannot supply past his currently supplied amount due to add cap
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, siloedVars.assetAAddCap));
    SpokeActions.supply({
      spoke: newSpoke,
      reserveId: siloedVars.reserveAIdNewSpoke,
      caller: bob,
      amount: 1e18,
      onBehalfOf: bob
    });

    // Bob cannot borrow asset A from the new spoke, canonical hub, because draw cap is 0
    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, 0));
    SpokeActions.borrow({
      spoke: newSpoke,
      reserveId: siloedVars.reserveAIdNewSpoke,
      caller: bob,
      amount: 1e18,
      onBehalfOf: bob
    });

    uint256 assetBDrawCapAmount = siloedVars.assetBDrawCap * 10 ** assetB.decimals();

    // Let Alice supply some asset B to the new spoke
    SpokeActions.supply({
      spoke: newSpoke,
      reserveId: siloedVars.reserveBId,
      caller: alice,
      amount: assetBDrawCapAmount * 2,
      onBehalfOf: alice
    });

    // Bob can borrow asset B from the new spoke, new hub, up to 100k
    SpokeActions.borrow({
      spoke: newSpoke,
      reserveId: siloedVars.reserveBId,
      caller: bob,
      amount: assetBDrawCapAmount,
      onBehalfOf: bob
    });

    // Check Bob's total debt of asset B on the new spoke
    assertEq(newSpoke.getUserTotalDebt(siloedVars.reserveBId, bob), assetBDrawCapAmount);
    assertEq(newHub.getAssetTotalOwed(siloedVars.assetBId), assetBDrawCapAmount);
    assertEq(
      address(_getAssetUnderlyingByReserveId(newSpoke, siloedVars.reserveBId)),
      address(assetB),
      'Bob borrowed asset B from new spoke'
    );

    // Bob cannot borrow additional asset B from the new spoke, new hub, because of draw cap
    vm.expectRevert(
      abi.encodeWithSelector(IHub.DrawCapExceeded.selector, siloedVars.assetBDrawCap)
    );
    SpokeActions.borrow({
      spoke: newSpoke,
      reserveId: siloedVars.reserveBId,
      caller: bob,
      amount: 1e18,
      onBehalfOf: bob
    });
  }
}
