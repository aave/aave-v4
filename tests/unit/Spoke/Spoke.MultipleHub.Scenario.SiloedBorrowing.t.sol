// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMultipleHubSiloedBorrowingTest is SpokeBase {
  struct SiloedLocalVars {
    uint256 assetAId;
    uint256 assetBId;
    uint256 assetASupplyCap;
    uint256 assetBDrawCap;
    uint256 reserveAId;
    uint256 reserveBId;
    uint256 reserveAIdNewSpoke;
  }

  // New hub and spoke
  ILiquidityHub internal newHub;
  MockPriceOracle internal newOracle;
  ISpoke internal newSpoke;
  IDefaultInterestRateStrategy internal newIrStrategy;

  SiloedLocalVars internal siloedVars;

  TestnetERC20 internal assetA;
  TestnetERC20 internal assetB;

  DataTypes.DynamicReserveConfig internal dynReserveConfig =
    DataTypes.DynamicReserveConfig({
      collateralFactor: 80_00 // 80.00%
    });
  IDefaultInterestRateStrategy.InterestRateData internal irData =
    IDefaultInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 90_00, // 90.00%
      baseVariableBorrowRate: 5_00, // 5.00%
      variableRateSlope1: 5_00, // 5.00%
      variableRateSlope2: 5_00 // 5.00%
    });

  function setUp() public virtual override {
    deployFixures();
    setUpSiloedBorrowing();
  }

  function deployFixures() internal {
    // Canonical hub and spoke
    hub = new LiquidityHub();
    oracle1 = new MockPriceOracle();
    spoke1 = new Spoke(address(oracle1));
    irStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);

    // New hub and spoke
    newHub = new LiquidityHub();
    newOracle = new MockPriceOracle();
    newSpoke = new Spoke(address(newOracle));
    newIrStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);

    assetA = new TestnetERC20('Asset A', 'A', 18);
    assetB = new TestnetERC20('Asset B', 'B', 18);
  }

  /* @dev Adds asset B to the new hub and new spoke with 100k draw cap.
   * Adds Asset A to the canonical hub and canonical spoke with no restrictions.
   * Relists Asset A from the canonical hub on the new spoke, with supply cap 500k, 0 borrow cap.
   * SUMMARY:
   * New Spoke: AssetA, canonical hub supplyable up to 500k; Asset B, new hub borrowable up to 100k.
   * Canonical Spoke: Asset A, no restrictions.
   */
  function setUpSiloedBorrowing() internal {
    siloedVars.assetBDrawCap = 100_000e18;
    siloedVars.assetASupplyCap = 500_000e18;

    // Add asset B to the new hub
    newHub.addAsset(
      DataTypes.AssetConfig({
        feeReceiver: address(0),
        decimals: assetB.decimals(),
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 0,
        irStrategy: newIrStrategy
      }),
      address(assetB)
    );
    siloedVars.assetBId = newHub.assetCount() - 1;

    // Add B reserve to the new spoke
    siloedVars.reserveBId = newSpoke.addReserve(
      siloedVars.assetBId,
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
        hub: newHub
      }),
      dynReserveConfig
    );

    // Set the price of B reserve for the new oracle
    newOracle.setReservePrice(siloedVars.reserveBId, 2000e8);

    // Link new hub and new spoke for asset B, 100k draw cap
    newHub.addSpoke(
      siloedVars.assetBId,
      DataTypes.SpokeConfig({drawCap: siloedVars.assetBDrawCap, supplyCap: type(uint256).max}),
      address(newSpoke)
    );

    // Configure interest rate strategy for asset B
    newIrStrategy.setInterestRateParams(siloedVars.assetBId, irData);

    // Add asset A to the canonical hub
    hub.addAsset(
      DataTypes.AssetConfig({
        feeReceiver: address(0),
        decimals: assetA.decimals(),
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 0,
        irStrategy: irStrategy // Use the canonical hub's interest rate strategy
      }),
      address(assetA)
    );
    siloedVars.assetAId = hub.assetCount() - 1;

    // Add A reserve to spoke 1
    siloedVars.reserveAId = spoke1.addReserve(
      siloedVars.assetAId,
      DataTypes.ReserveConfig({
        decimals: assetA.decimals(),
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

    // Set the price of A reserve for the spoke 1 oracle
    oracle1.setReservePrice(siloedVars.reserveAId, 50_000e8);

    // Link canonical hub and spoke 1 for asset A
    hub.addSpoke(
      siloedVars.assetAId,
      DataTypes.SpokeConfig({drawCap: type(uint256).max, supplyCap: type(uint256).max}),
      address(spoke1)
    );

    // Configure interest rate strategy for asset A
    irStrategy.setInterestRateParams(siloedVars.assetAId, irData);

    // Add reserve A from canonical hub to the new spoke
    siloedVars.reserveAIdNewSpoke = newSpoke.addReserve(
      siloedVars.assetAId,
      DataTypes.ReserveConfig({
        decimals: assetA.decimals(),
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

    // Set the price of reserve A for the new oracle
    newOracle.setReservePrice(siloedVars.reserveAIdNewSpoke, 2000e8);

    // Link canonical hub and new spoke for asset A, 500k supply cap, 0 borrow cap
    hub.addSpoke(
      siloedVars.assetAId,
      DataTypes.SpokeConfig({drawCap: 0, supplyCap: siloedVars.assetASupplyCap}),
      address(newSpoke)
    );
  }

  /* @dev Test showcasing a possible configuration for siloed mode
   * A new hub and spoke are deployed with Assets A and B, where B is the only borrowable asset.
   * Users can use usdx as collateral on the new spoke, which supplies to the canonical hub.
   * Users may not borrow usdx from the new spoke, but can use it as collateral to borrow the
   * only borrowable asset: Asset B.
   */
  function test_siloed_borrowing() public {
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
