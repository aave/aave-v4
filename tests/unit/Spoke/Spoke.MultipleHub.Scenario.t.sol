// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMultipleHubScenarioTest is Test {
  struct IsolationLocalVars {
    uint256 assetAId;
    uint256 assetBId;
    uint256 reserveAId;
    uint256 reserveBId;
    uint256 assetBIdMainHub;
    uint256 reserveBIdMainHub;
    uint256 spoke1ReserveBId;
  }

  struct SiloedLocalVars {
    uint256 assetAId;
    uint256 assetBId;
    uint256 assetASupplyCap;
    uint256 assetBDrawCap;
    uint256 reserveAId;
    uint256 reserveBId;
    uint256 reserveAIdNewSpoke;
  }

  uint256 internal constant MAX_SUPPLY_AMOUNT = 1e30;
  address internal mockAddressesProvider = makeAddr('mockAddressesProvider');

  // Canonical hub and spoke
  ILiquidityHub internal hub;
  ISpoke internal spoke1;
  MockPriceOracle internal oracle1;
  IDefaultInterestRateStrategy internal irStrategy;

  // New hub and spoke
  ILiquidityHub internal newHub;
  MockPriceOracle internal newOracle;
  ISpoke internal newSpoke;
  IDefaultInterestRateStrategy internal newIrStrategy;

  IsolationLocalVars internal isolationVars;
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

  address internal alice = makeAddr('alice');
  address internal bob = makeAddr('bob');

  function setUp() public virtual {
    deployFixures();
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

  ///@dev Adds new assets A and B to the new hub and spoke, no restrictions.
  function setUpIsolationMode() internal {
    // Add assets A and B to the new hub
    newHub.addAsset(
      DataTypes.AssetConfig({
        feeReceiver: address(0),
        decimals: 18,
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 0,
        irStrategy: newIrStrategy
      }),
      address(assetA)
    );
    isolationVars.assetAId = newHub.assetCount() - 1;
    newHub.addAsset(
      DataTypes.AssetConfig({
        feeReceiver: address(0),
        decimals: 18,
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 0,
        irStrategy: newIrStrategy
      }),
      address(assetB)
    );
    isolationVars.assetBId = newHub.assetCount() - 1;

    // Add reserves to the new spoke
    isolationVars.reserveAId = newSpoke.addReserve(
      isolationVars.assetAId,
      DataTypes.ReserveConfig({
        decimals: assetA.decimals(),
        active: true,
        frozen: false,
        paused: false,
        liquidationBonus: 100_00,
        liquidityPremium: 15_00,
        liquidationProtocolFee: 0,
        borrowable: false,
        collateral: true,
        hub: newHub
      }),
      dynReserveConfig
    );
    isolationVars.reserveBId = newSpoke.addReserve(
      isolationVars.assetBId,
      DataTypes.ReserveConfig({
        decimals: assetB.decimals(),
        active: true,
        frozen: false,
        paused: false,
        liquidationBonus: 100_00,
        liquidityPremium: 15_00,
        liquidationProtocolFee: 0,
        borrowable: true,
        collateral: false,
        hub: newHub
      }),
      dynReserveConfig
    );

    // Set the prices of the new reserves for the new oracle
    newOracle.setReservePrice(isolationVars.reserveAId, 2000e8);
    newOracle.setReservePrice(isolationVars.reserveBId, 50_000e8);

    // Link hub and spoke
    newHub.addSpoke(
      isolationVars.assetAId,
      DataTypes.SpokeConfig({drawCap: type(uint256).max, supplyCap: type(uint256).max}),
      address(newSpoke)
    );
    newHub.addSpoke(
      isolationVars.assetBId,
      DataTypes.SpokeConfig({drawCap: type(uint256).max, supplyCap: type(uint256).max}),
      address(newSpoke)
    );

    // Configure interest rate strategy for assets A and B
    newIrStrategy.setInterestRateParams(isolationVars.assetAId, irData);
    newIrStrategy.setInterestRateParams(isolationVars.assetBId, irData);
  }

  /* @dev Adds asset B to the new hub and new spoke with 100k draw cap.
   * Adds Asset A to the canonical hub and canonical spoke with no restrictions.
   * Relists Asset A from the canonical hub on the new spoke, with supply cap 500k, 0 borrow cap.
   * SUMMARY:
   * New Spoke: AssetA, canonical hub supplyable up to 500k; Asset B, new hub borrowable up to 100k.
   * Canonical Spoke: Asset A, no restrictions.
   */
  function setUpSiloedMode() internal {
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

  /* @dev Test showcasing a possible configuration for isolation mode
   * A new hub and spoke are deployed with new assets A and B.
   * There is no liquidity for asset B on the new hub, so instead
   * Asset B is listed on the canonical hub and linked to the new spoke with a draw cap.
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

    // List asset B on the canonical (main) hub
    isolationVars.assetBIdMainHub = hub.assetCount();
    hub.addAsset(
      DataTypes.AssetConfig({
        feeReceiver: address(0),
        decimals: 18,
        active: true,
        paused: false,
        frozen: false,
        liquidityFee: 0,
        irStrategy: irStrategy // Use the main hub's interest rate strategy
      }),
      address(assetB)
    );

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

    // Configure interest rate strategy for asset B on the main hub
    irStrategy.setInterestRateParams(isolationVars.assetBIdMainHub, irData);

    // Bob still cannot borrow asset B from the new hub because there is no liquidity
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    newSpoke.borrow(isolationVars.reserveBId, 100e18, bob);
    vm.stopPrank();

    // List reserve B on spoke 1 for the main hub, allowing supplying and borrowing
    isolationVars.spoke1ReserveBId = spoke1.addReserve(
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

    // Set the price of reserve B on spoke1 for the main hub
    oracle1.setReservePrice(isolationVars.spoke1ReserveBId, 50_000e8);

    // Link main hub and spoke 1 for asset B
    hub.addSpoke(
      isolationVars.assetBIdMainHub,
      DataTypes.SpokeConfig({drawCap: type(uint256).max, supplyCap: type(uint256).max}),
      address(spoke1)
    );

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

    // DAO offboards credit line to new spoke from the canonical hub by setting Asset B draw cap to 0
    hub.updateSpokeConfig(
      isolationVars.assetBIdMainHub,
      address(newSpoke),
      DataTypes.SpokeConfig({drawCap: 0, supplyCap: 0})
    );

    // Bob can repay his debt of asset B on the new spoke
    vm.startPrank(bob);
    assetB.approve(address(hub), type(uint256).max);
    newSpoke.repay(isolationVars.reserveBIdMainHub, 100_000e18);
    assertEq(newSpoke.getUserTotalDebt(isolationVars.reserveBIdMainHub, bob), 0);
    assertEq(hub.getAssetTotalDebt(isolationVars.assetBIdMainHub), 0);

    // Bob cannot draw any additional asset B from the new spoke main hub due to new draw cap of 0
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, 0));
    newSpoke.borrow(isolationVars.reserveBIdMainHub, 1e18, bob);
    vm.stopPrank();
  }

  /* @dev Test showcasing a possible configuration for siloed mode
   * A new hub and spoke are deployed with only Asset B as borrowable.
   * Users can use usdx as collateral on the new spoke, which supplies to the canonical hub.
   * Users may not borrow usdx from the new spoke, but can use it as collateral to borrow
   * the only available asset: Asset B.
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
