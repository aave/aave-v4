// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Spoke.MultipleHub.Base.t.sol';

contract SpokeMultipleHubIsolationModeTest is SpokeMultipleHubBase {
  struct IsolationLocalVars {
    uint256 assetAId;
    uint256 assetBId;
    uint256 reserveAId;
    uint256 reserveBId;
    uint256 assetBIdMainHub;
    uint256 reserveBIdMainHub;
    uint256 spoke1ReserveBId;
  }

  IsolationLocalVars internal isolationVars;

  function setUp() public virtual override {
    super.setUp();
    setUpIsolationMode();
  }

  ///@dev Adds new assets A and B to the new hub and spoke, no restrictions.
  ///@dev Lists asset B on canonical hub and spoke with no restrictions.
  function setUpIsolationMode() internal {
    vm.startPrank(ADMIN);
    // Add assets A and B to the new hub
    newHub.addAsset(
      address(assetA),
      assetA.decimals(),
      address(treasurySpoke),
      address(newIrStrategy),
      encodedIrData
    );
    isolationVars.assetAId = newHub.getAssetCount() - 1;
    newHub.addAsset(
      address(assetB),
      assetB.decimals(),
      address(treasurySpoke),
      address(newIrStrategy),
      encodedIrData
    );
    isolationVars.assetBId = newHub.getAssetCount() - 1;

    // Add reserves to the new spoke
    isolationVars.reserveAId = newSpoke.addReserve(
      address(newHub),
      isolationVars.assetAId,
      _deployMockPriceFeed(newSpoke, 2000e8),
      ISpoke.ReserveConfig({
        paused: false,
        frozen: false,
        borrowable: false,
        collateralRisk: 15_00
      }),
      dynReserveConfig
    );
    isolationVars.reserveBId = newSpoke.addReserve(
      address(newHub),
      isolationVars.assetBId,
      _deployMockPriceFeed(newSpoke, 50_000e8),
      ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 15_00}),
      dynReserveConfig
    );

    // Link hub and spoke
    newHub.addSpoke(
      isolationVars.assetAId,
      address(newSpoke),
      IHub.SpokeConfig({
        active: true,
        paused: false,
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumCap: Constants.MAX_ALLOWED_COLLATERAL_RISK
      })
    );
    newHub.addSpoke(
      isolationVars.assetBId,
      address(newSpoke),
      IHub.SpokeConfig({
        active: true,
        paused: false,
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumCap: Constants.MAX_ALLOWED_COLLATERAL_RISK
      })
    );
    vm.stopPrank();

    // List asset B on the canonical hub
    vm.startPrank(ADMIN);
    isolationVars.assetBIdMainHub = hub1.getAssetCount();
    hub1.addAsset(
      address(assetB),
      assetB.decimals(),
      address(treasurySpoke),
      address(irStrategy), // Use the main hub's interest rate strategy
      encodedIrData
    );

    // List reserve B on spoke 1 for the canonical hub
    isolationVars.spoke1ReserveBId = spoke1.addReserve(
      address(hub1),
      isolationVars.assetBIdMainHub,
      _deployMockPriceFeed(newSpoke, 50_000e8),
      ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 15_00}),
      dynReserveConfig
    );

    // Link main hub and spoke 1 for asset B
    hub1.addSpoke(
      isolationVars.assetBIdMainHub,
      address(spoke1),
      IHub.SpokeConfig({
        active: true,
        paused: false,
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumCap: Constants.MAX_ALLOWED_COLLATERAL_RISK
      })
    );
    vm.stopPrank();

    // Approvals
    vm.startPrank(bob);
    assetA.approve(address(newHub), type(uint256).max);
    assetB.approve(address(hub1), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(alice);
    assetB.approve(address(hub1), type(uint256).max);
    assetB.approve(address(newHub), type(uint256).max);
    vm.stopPrank();

    // Deal tokens
    deal(address(assetA), bob, MAX_SUPPLY_AMOUNT);
    deal(address(assetB), alice, MAX_SUPPLY_AMOUNT * 2); // Alice supplies on 2 different hubs
  }

  /* @dev Test showcasing a possible configuration for isolation mode
   * A new hub and spoke are deployed with new assets A and B.
   * There is no liquidity for asset B on the new hub, so instead
   * Asset B is listed from the canonical hub and linked to the new spoke with a draw cap.
   * Thus users can borrow asset B from the canonical hub via the new spoke,
   * without being able to supply it from the new spoke.
   * Users can also supply asset B from the canonical hub and canonical spoke to earn yield as usual.
   */
  function test_isolation_mode() public {
    // Bob can supply asset A to the new spoke and set it as collateral
    Utils.supplyCollateral(newSpoke, isolationVars.reserveAId, bob, MAX_SUPPLY_AMOUNT, bob);

    // Check Bob's supplied amounts and collateral status
    assertEq(
      newSpoke.getUserSuppliedAssets(isolationVars.reserveAId, bob),
      MAX_SUPPLY_AMOUNT,
      'bob supplied amount of reserve A on new spoke'
    );
    assertTrue(
      newSpoke.isUsingAsCollateral(isolationVars.reserveAId, bob),
      'bob using reserve A as collateral on new spoke'
    );
    assertEq(
      newHub.getAddedAssets(isolationVars.assetAId),
      MAX_SUPPLY_AMOUNT,
      'total supplied amount of assetA on new hub'
    );

    // Bob cannot borrow asset B because there is no liquidity
    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, 0));
    Utils.borrow(newSpoke, isolationVars.reserveBId, bob, 1, bob);

    // Add main hub reserve B to the new spoke
    vm.startPrank(ADMIN);
    isolationVars.reserveBIdMainHub = newSpoke.addReserve(
      address(hub1),
      isolationVars.assetBIdMainHub,
      _deployMockPriceFeed(newSpoke, 50_000e8),
      ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 15_00}),
      dynReserveConfig
    );

    // Link main hub and new spoke for asset B
    // 0 supply cap, 100k draw cap
    hub1.addSpoke(
      isolationVars.assetBIdMainHub,
      address(newSpoke),
      IHub.SpokeConfig({
        active: true,
        paused: false,
        addCap: 0,
        drawCap: 100_000,
        riskPremiumCap: 1000_00
      })
    );
    vm.stopPrank();

    // Bob still cannot borrow asset B from the new hub because there is no liquidity
    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientLiquidity.selector, 0));
    Utils.borrow(newSpoke, isolationVars.reserveBId, bob, 1, bob);

    // Alice can supply asset B to the main hub via spoke 1 (and will earn yield as usual)
    Utils.supply(spoke1, isolationVars.spoke1ReserveBId, alice, 500_000e18, alice);

    // Check Alice's supplied amount of asset B on spoke 1
    assertEq(
      spoke1.getUserSuppliedAssets(isolationVars.spoke1ReserveBId, alice),
      500_000e18,
      'alice supplied amount of reserve B on spoke 1'
    );
    assertEq(
      hub1.getAddedAssets(isolationVars.assetBIdMainHub),
      500_000e18,
      'total supplied amount of asset B on main hub'
    );

    // Bob CAN borrow asset B from the main hub via new spoke up until the draw cap of 100k
    Utils.borrow(newSpoke, isolationVars.reserveBIdMainHub, bob, 100_000e18, bob);

    // Check Bob's total debt of asset B on the new spoke
    assertEq(newSpoke.getUserTotalDebt(isolationVars.reserveBIdMainHub, bob), 100_000e18);
    assertEq(hub1.getAssetTotalOwed(isolationVars.assetBIdMainHub), 100_000e18);

    // Bob cannot borrow asset B from main hub via new spoke past draw cap
    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, 100_000));
    Utils.borrow(newSpoke, isolationVars.reserveBIdMainHub, bob, 1, bob);

    // Bob cannot supply B to main hub via new spoke because supply cap is 0
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, 0));
    Utils.supply(newSpoke, isolationVars.reserveBIdMainHub, bob, 1e18, bob);

    // Alice can supply B to the new hub via new spoke
    Utils.supply(newSpoke, isolationVars.reserveBId, alice, MAX_SUPPLY_AMOUNT, alice);

    // Now there is liquidity for asset B on the new hub
    assertEq(
      newHub.getAddedAssets(isolationVars.assetBId),
      MAX_SUPPLY_AMOUNT,
      'total supplied amount of asset B on new hub'
    );
    assertEq(
      newSpoke.getReserveSuppliedAssets(isolationVars.reserveBId),
      MAX_SUPPLY_AMOUNT,
      'total supplied amount of reserve B on new spoke'
    );

    // Bob will migrate to borrowing asset B from the new spoke, new hub, so repays canonical hub position
    Utils.repay(newSpoke, isolationVars.reserveBIdMainHub, bob, 100_000e18, bob);
    assertEq(newSpoke.getUserTotalDebt(isolationVars.reserveBIdMainHub, bob), 0);
    assertEq(hub1.getAssetTotalOwed(isolationVars.assetBIdMainHub), 0);

    // Bob opens new borrow position for asset B on the new spoke, new hub
    Utils.borrow(newSpoke, isolationVars.reserveBId, bob, 100_000e18, bob);
    assertEq(newSpoke.getUserTotalDebt(isolationVars.reserveBId, bob), 100_000e18);
    assertEq(newHub.getAssetTotalOwed(isolationVars.assetBId), 100_000e18);

    // DAO offboards credit line to new spoke from the canonical hub by setting Asset B draw cap to 0
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      isolationVars.assetBIdMainHub,
      address(newSpoke),
      IHub.SpokeConfig({
        active: true,
        paused: false,
        addCap: 0,
        drawCap: 0,
        riskPremiumCap: 1000_00
      })
    );

    // Now Bob or any other users cannot draw any asset B from the new spoke main hub due to new draw cap of 0
    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, 0));
    Utils.borrow(newSpoke, isolationVars.reserveBIdMainHub, bob, 1e18, bob);
  }
}
