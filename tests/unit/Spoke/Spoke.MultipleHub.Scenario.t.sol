// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMultipleHubScenarioTest is SpokeBase {
  struct IsolationLocalVars {
    uint256 assetAId;
    uint256 assetBId;
    uint256 reserveAId;
    uint256 reserveBId;
    uint256 assetBIdMainHub;
    uint256 reserveBIdMainHub;
    uint256 spoke1ReserveBId;
  }

  /* @dev Test showcasing a possible configuration for isolation mode
   * A new hub and spoke are deployed with new assets A and B.
   * There is no liquidity for asset B on the new hub, so instead
   * Asset B is listed on the canonical hub and linked to the new spoke with a draw cap.
   * Thus users can borrow asset B from the canonical hub via the new spoke,
   * without being able to supply it from the new spoke.
   */
  function test_isolation_mode() public {
    IsolationLocalVars memory vars;

    // New hub and spoke with A collateral, B borrowable
    ILiquidityHub newHub = new LiquidityHub();
    MockPriceOracle newOracle = new MockPriceOracle();
    ISpoke newSpoke = new Spoke(address(newOracle));

    TestnetERC20 assetA = new TestnetERC20('Asset A', 'A', 18);
    TestnetERC20 assetB = new TestnetERC20('Asset B', 'B', 18);

    // New IrStrategy for new hub
    DefaultReserveInterestRateStrategy newIrStrategy = new DefaultReserveInterestRateStrategy(
      mockAddressesProvider
    );

    // Same config for both assets on new hub
    DataTypes.AssetConfig memory assetConfig = DataTypes.AssetConfig({
      decimals: 18,
      active: true,
      paused: false,
      frozen: false,
      irStrategy: newIrStrategy
    });

    // Add assets A and B to the new hub
    newHub.addAsset(assetConfig, address(assetA));
    vars.assetAId = 0;
    newHub.addAsset(assetConfig, address(assetB));
    vars.assetBId = 1;

    // Configure assets A and B for the new spoke
    DataTypes.ReserveConfig memory reserveAConfig = DataTypes.ReserveConfig({
      decimals: assetA.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 80_00,
      liquidationBonus: 100_00,
      liquidityPremium: 15_00,
      liquidationProtocolFee: 0,
      borrowable: false,
      collateral: true,
      hub: newHub
    });

    DataTypes.ReserveConfig memory reserveBConfig = DataTypes.ReserveConfig({
      decimals: assetB.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 80_00,
      liquidationBonus: 100_00,
      liquidityPremium: 15_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: false,
      hub: newHub
    });

    // Add reserves to the new spoke
    vars.reserveAId = newSpoke.addReserve(vars.assetAId, reserveAConfig);
    vars.reserveBId = newSpoke.addReserve(vars.assetBId, reserveBConfig);

    // Set the prices of the new reserves for the new oracle
    newOracle.setReservePrice(vars.reserveAId, 2000e8);
    newOracle.setReservePrice(vars.reserveBId, 50_000e8);

    // Link hub and spoke
    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      drawCap: type(uint256).max,
      supplyCap: type(uint256).max
    });
    newHub.addSpoke(vars.assetAId, spokeConfig, address(newSpoke));
    newHub.addSpoke(vars.assetBId, spokeConfig, address(newSpoke));

    // Configure interest rate strategy for assets A and B
    IDefaultInterestRateStrategy.InterestRateData memory irData = IDefaultInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      });
    newIrStrategy.setInterestRateParams(vars.assetAId, irData);
    newIrStrategy.setInterestRateParams(vars.assetBId, irData);

    // Bob can supply asset A to the new spoke and set it as collateral
    vm.startPrank(bob);
    assetA.approve(address(newHub), type(uint256).max);
    deal(address(assetA), bob, MAX_SUPPLY_AMOUNT);
    newSpoke.supply(vars.reserveAId, MAX_SUPPLY_AMOUNT);
    newSpoke.setUsingAsCollateral(vars.reserveAId, true);

    // Check Bob's supplied amounts and collateral status
    assertEq(
      newSpoke.getUserSuppliedAmount(vars.reserveAId, bob),
      MAX_SUPPLY_AMOUNT,
      'bob supplied amount of reserve A on new spoke'
    );
    assertTrue(
      newSpoke.getUsingAsCollateral(vars.reserveAId, bob),
      'bob using reserve A as collateral on new spoke'
    );
    assertEq(
      newHub.getAssetSuppliedAmount(vars.assetAId),
      MAX_SUPPLY_AMOUNT,
      'total supplied amount of assetA on new hub'
    );

    // Bob cannot borrow asset B because there is no liquidity
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    newSpoke.borrow(vars.reserveBId, 100e18, bob);

    // List asset B on the canonical (main) hub
    vars.assetBIdMainHub = hub.assetCount();
    assetConfig.irStrategy = irStrategy; // Use the main hub's interest rate strategy
    hub.addAsset(assetConfig, address(assetB));

    // Configure reserve B from the main hub
    DataTypes.ReserveConfig memory reserveBConfigMainHub = DataTypes.ReserveConfig({
      decimals: assetB.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 80_00,
      liquidationBonus: 100_00,
      liquidityPremium: 15_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true,
      hub: hub
    });

    // Add main hub reserve B to the new spoke
    vars.reserveBIdMainHub = newSpoke.addReserve(vars.assetBIdMainHub, reserveBConfigMainHub);

    // Set the price of main hub reserve B on new spoke
    newOracle.setReservePrice(vars.reserveBIdMainHub, 50_000e8);

    // Link main hub and new spoke for asset B
    // 0 supply cap, 100k draw cap
    spokeConfig = DataTypes.SpokeConfig({drawCap: 100_000e18, supplyCap: 0});
    hub.addSpoke(vars.assetBIdMainHub, spokeConfig, address(newSpoke));

    // Configure interest rate strategy for asset B on the main hub
    irStrategy.setInterestRateParams(vars.assetBIdMainHub, irData);

    // Bob still cannot borrow asset B from the new hub because there is no liquidity
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    newSpoke.borrow(vars.reserveBId, 100e18, bob);
    vm.stopPrank();

    // List reserve B on spoke 1 for the main hub, allowing supplying and borrowing
    vars.spoke1ReserveBId = spoke1.addReserve(vars.assetBIdMainHub, reserveBConfigMainHub);

    // Set the price of reserve B on spoke1 for the main hub
    oracle1.setReservePrice(vars.spoke1ReserveBId, 50_000e8);

    // Link main hub and spoke 1 for asset B
    spokeConfig = DataTypes.SpokeConfig({drawCap: type(uint256).max, supplyCap: type(uint256).max});
    hub.addSpoke(vars.assetBIdMainHub, spokeConfig, address(spoke1));

    // Alice can supply asset B to the main hub via spoke 1
    vm.startPrank(alice);
    assetB.approve(address(hub), type(uint256).max);
    deal(address(assetB), alice, 500_000e18);
    spoke1.supply(vars.spoke1ReserveBId, 500_000e18);
    vm.stopPrank();

    // Check Alice's supplied amount of asset B on spoke 1
    assertEq(
      spoke1.getUserSuppliedAmount(vars.spoke1ReserveBId, alice),
      500_000e18,
      'alice supplied amount of reserve B on spoke 1'
    );
    assertEq(
      hub.getAssetSuppliedAmount(vars.assetBIdMainHub),
      500_000e18,
      'total supplied amount of asset B on main hub'
    );

    // Bob CAN borrow asset B from the main hub via new spoke up until the draw cap of 100k
    vm.startPrank(bob);
    newSpoke.borrow(vars.reserveBIdMainHub, 100_000e18, bob);

    // Check Bob's total debt of asset B on the new spoke
    assertEq(newSpoke.getUserTotalDebt(vars.reserveBIdMainHub, bob), 100_000e18);
    assertEq(hub.getAssetTotalDebt(vars.assetBIdMainHub), 100_000e18);

    // Bob cannot borrow asset B from main hub via new spoke past draw cap
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, 100_000e18));
    newSpoke.borrow(vars.reserveBIdMainHub, 1e18, bob);

    // Bob cannot supply B to main hub via new spoke because supply cap is 0
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, 0));
    newSpoke.supply(vars.reserveBIdMainHub, 1e18);
    vm.stopPrank();

    // DAO offboards credit line to new spoke from the canonical hub by setting Asset B draw cap to 0
    hub.updateSpokeConfig(
      vars.assetBIdMainHub,
      address(newSpoke),
      DataTypes.SpokeConfig({drawCap: 0, supplyCap: 0})
    );

    // Bob can repay his debt of asset B on the new spoke
    vm.startPrank(bob);
    assetB.approve(address(hub), type(uint256).max);
    newSpoke.repay(vars.reserveBIdMainHub, 100_000e18);
    assertEq(newSpoke.getUserTotalDebt(vars.reserveBIdMainHub, bob), 0);
    assertEq(hub.getAssetTotalDebt(vars.assetBIdMainHub), 0);

    // Bob cannot draw any additional asset B from the new spoke main hub due to new draw cap of 0
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, 0));
    newSpoke.borrow(vars.reserveBIdMainHub, 1e18, bob);

    vm.stopPrank();
  }

  /* @dev Test showcasing a possible configuration for siloed mode
   * A new hub and spoke are deployed with only Asset B as borrowable.
   * Users can use usdx as collateral on the new spoke, which supplies to the canonical hub.
   * Users may not borrow usdx from the new spoke, but can use it as collateral to borrow
   * the only available asset: Asset B.
   */
  function test_siloed_mode() public {
    // Deploy a new hub and spoke with only B borrowable asset
    ILiquidityHub newHub = new LiquidityHub();
    MockPriceOracle newOracle = new MockPriceOracle();
    ISpoke newSpoke = new Spoke(address(newOracle));

    TestnetERC20 assetB = new TestnetERC20('Asset B', 'B', 18);

    uint256 assetBDrawCap = 100_000e18;
    uint256 usdxSupplyCap = 500_000e18;

    // New IrStrategy for new hub
    DefaultReserveInterestRateStrategy newIrStrategy = new DefaultReserveInterestRateStrategy(
      mockAddressesProvider
    );

    DataTypes.AssetConfig memory assetBConfig = DataTypes.AssetConfig({
      decimals: assetB.decimals(),
      active: true,
      paused: false,
      frozen: false,
      irStrategy: newIrStrategy
    });

    // Add asset B to the new hub
    newHub.addAsset(assetBConfig, address(assetB));
    uint256 assetBId = 0;

    // Configure reserve B for the new spoke
    DataTypes.ReserveConfig memory reserveBConfig = DataTypes.ReserveConfig({
      decimals: assetB.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 80_00,
      liquidationBonus: 100_00,
      liquidityPremium: 15_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true,
      hub: newHub
    });

    // Add B reserve to the new spoke
    uint256 reserveBId = newSpoke.addReserve(assetBId, reserveBConfig);

    // Set the price of B reserve for the new oracle
    newOracle.setReservePrice(reserveBId, 50_000e8);

    // Link new hub and new spoke for asset B, 100k draw cap
    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      drawCap: assetBDrawCap,
      supplyCap: type(uint256).max
    });
    newHub.addSpoke(assetBId, spokeConfig, address(newSpoke));

    // Configure interest rate strategy for asset B
    newIrStrategy.setInterestRateParams(
      assetBId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );

    // Now add usdx from canonical hub to the new spoke
    // Configure usdx reserve for the new spoke
    DataTypes.ReserveConfig memory usdxReserveConfig = DataTypes.ReserveConfig({
      decimals: tokenList.usdx.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 80_00,
      liquidationBonus: 100_00,
      liquidityPremium: 15_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true,
      hub: hub
    });

    // Add usdx reserve to the new spoke
    uint256 usdxReserveIdNewSpoke = newSpoke.addReserve(usdxAssetId, usdxReserveConfig);

    // Set the price of usdx reserve for the new oracle
    newOracle.setReservePrice(usdxReserveIdNewSpoke, 1e8);

    // Link canonical hub and new spoke for usdx, 500k supply cap, 0 borrow cap
    spokeConfig = DataTypes.SpokeConfig({drawCap: 0, supplyCap: usdxSupplyCap});
    hub.addSpoke(usdxAssetId, spokeConfig, address(newSpoke));

    // Bob can supply usdx to the new spoke, canonical hub, up to 500k and set it as collateral
    vm.startPrank(bob);
    tokenList.usdx.approve(address(newHub), type(uint256).max);
    newSpoke.supply(usdxReserveIdNewSpoke, usdxSupplyCap);
    newSpoke.setUsingAsCollateral(usdxReserveIdNewSpoke, true);
    assertEq(
      newSpoke.getUserSuppliedAmount(usdxReserveIdNewSpoke, bob),
      usdxSupplyCap,
      'bob supplied amount of usdx on new spoke'
    );
    assertTrue(
      newSpoke.getUsingAsCollateral(usdxReserveIdNewSpoke, bob),
      'bob using usdx as collateral on new spoke'
    );
    assertEq(
      hub.getAssetSuppliedAmount(usdxAssetId),
      usdxSupplyCap,
      'total supplied amount of usdx on canonical hub'
    );

    // Bob cannot supply past his currently supplied amount due to supply cap
    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, usdxSupplyCap)
    );
    newSpoke.supply(usdxReserveIdNewSpoke, 1e18);

    // Bob cannot borrow usdx from the new spoke, canonical hub, becuase draw cap is 0
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, 0));
    newSpoke.borrow(usdxReserveIdNewSpoke, 1e18, bob);
    vm.stopPrank();

    // Let Alice supply some asset B to the new spoke
    vm.startPrank(alice);
    assetB.approve(address(newHub), type(uint256).max);
    deal(address(assetB), alice, 300_000e18);
    newSpoke.supply(reserveBId, 300_000e18);
    vm.stopPrank();

    // Bob can borrow asset B from the new spoke, new hub, up to 100k
    vm.startPrank(bob);
    newSpoke.borrow(reserveBId, assetBDrawCap, bob);

    // Check Bob's total debt of asset B on the new spoke
    assertEq(newSpoke.getUserTotalDebt(reserveBId, bob), assetBDrawCap);
    assertEq(newHub.getAssetTotalDebt(assetBId), assetBDrawCap);
    assertEq(
      newSpoke.getReserve(reserveBId).asset,
      address(assetB),
      'Bob borrowed asset B from new spoke'
    );

    // Bob cannot borrow additional asset B from the new spoke, new hub, because of draw cap
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.DrawCapExceeded.selector, assetBDrawCap));
    newSpoke.borrow(reserveBId, 1e18, bob);
    vm.stopPrank();
  }
}
