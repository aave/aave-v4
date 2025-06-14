// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMultipleHub is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using WadRayMathExtended for uint256;
  using PercentageMath for uint256;

  uint256 internal daiHub2ReserveId;
  uint256 internal daiHub3ReserveId;

  function setUp() public virtual override {
    super.setUp();
    deployAndConfigureAdditionalHubs();

    // Relist dai on spoke1 for hub 2 dai
    DataTypes.ReserveConfig memory daiHub2Config = DataTypes.ReserveConfig({
      decimals: tokenList.dai.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 78_00,
      liquidationBonus: 100_00,
      liquidityPremium: 20_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true,
      hub: hub2
    });
    daiHub2ReserveId = spoke1.addReserve(daiAssetId, daiHub2Config);

    // Relist dai for hub 3 dai
    DataTypes.ReserveConfig memory daiHub3Config = DataTypes.ReserveConfig({
      decimals: tokenList.dai.decimals(),
      active: true,
      frozen: false,
      paused: false,
      collateralFactor: 78_00,
      liquidationBonus: 100_00,
      liquidityPremium: 20_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true,
      hub: hub3
    });
    daiHub3ReserveId = spoke1.addReserve(hub3DaiAssetId, daiHub3Config);
  }

  function test_borrow_secondHub() public {
    uint256 hub1DaiBorrowAmount = 5e18;
    uint256 hub2DaiBorrowAmount = 1e18;

    // Bob supply to spoke 1 on hub 1
    vm.startPrank(bob);
    spoke1.supply(_daiReserveId(spoke1), 100000e18);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true);
    vm.stopPrank();

    deal(address(tokenList.dai), address(spoke1), 1e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub2), type(uint256).max);
    hub2.add(daiAssetId, 1e18, address(spoke1));
    vm.stopPrank();

    // Bob borrows dai from hub 2
    vm.prank(bob);
    spoke1.borrow(daiHub2ReserveId, hub2DaiBorrowAmount, bob);

    // Bob can also borrow from hub 1
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), hub1DaiBorrowAmount, bob);

    // Check Bob's total debt on each hub
    assertEq(spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob), hub1DaiBorrowAmount);
    assertEq(spoke1.getUserTotalDebt(daiHub2ReserveId, bob), hub2DaiBorrowAmount);

    assertEq(hub.getAssetTotalDebt(daiAssetId), hub1DaiBorrowAmount);
    assertEq(hub2.getAssetTotalDebt(daiAssetId), hub2DaiBorrowAmount);
  }

  function test_borrow_thirdHub() public {
    uint256 hub1DaiBorrowAmount = 5e18;
    uint256 hub3DaiBorrowAmount = 1e18;
    uint256 daiSupplyAmount = 100000e18;

    // Bob supply to spoke 1 on hub 1
    vm.startPrank(bob);
    spoke1.supply(_daiReserveId(spoke1), daiSupplyAmount);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true);
    vm.stopPrank();

    deal(address(tokenList.dai), address(spoke1), hub3DaiBorrowAmount);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub3), type(uint256).max);
    hub3.add(hub3DaiAssetId, hub3DaiBorrowAmount, address(spoke1));
    vm.stopPrank();

    // Bob borrows dai from hub 3
    vm.startPrank(bob);
    spoke1.borrow(daiHub3ReserveId, hub3DaiBorrowAmount, bob);

    // Check Bob's total debt on hub 3
    assertEq(spoke1.getUserTotalDebt(daiHub3ReserveId, bob), hub3DaiBorrowAmount);
    assertEq(hub3.getAssetTotalDebt(hub3DaiAssetId), hub3DaiBorrowAmount);
    assertEq(hub.getAssetTotalDebt(daiAssetId), 0); // No debt on hub 1

    // Check bob is indeed borrowing dai from hub 3
    DataTypes.Reserve memory dai3Reserve = spoke1.getReserve(daiHub3ReserveId);
    assertEq(dai3Reserve.asset, address(tokenList.dai));

    // Bob repays debt on hub3
    tokenList.dai.approve(address(hub3), type(uint256).max);
    spoke1.repay(daiHub3ReserveId, hub3DaiBorrowAmount);
    assertEq(spoke1.getUserTotalDebt(daiHub3ReserveId, bob), 0);
    assertEq(hub3.getAssetTotalDebt(hub3DaiAssetId), 0);

    // Bob withdraws funds from hub1
    spoke1.withdraw(_daiReserveId(spoke1), daiSupplyAmount, bob);
    assertEq(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), bob), 0);
    assertEq(hub.getAssetSuppliedAmount(daiAssetId), 0);

    vm.stopPrank();
  }

  struct IsolationLocalVars {
    uint256 assetAId;
    uint256 assetBId;
    uint256 reserveAId;
    uint256 reserveBId;
    uint256 assetBIdMainHub;
    uint256 reserveBIdMainHub;
  }

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

    DataTypes.AssetConfig memory assetAConfig = DataTypes.AssetConfig({
      decimals: assetA.decimals(),
      active: true,
      paused: false,
      frozen: false,
      irStrategy: newIrStrategy
    });
    DataTypes.AssetConfig memory assetBConfig = DataTypes.AssetConfig({
      decimals: assetB.decimals(),
      active: true,
      paused: false,
      frozen: false,
      irStrategy: newIrStrategy
    });

    // Add assets A and B to the new hub
    newHub.addAsset(assetAConfig, address(assetA));
    vars.assetAId = 0;
    newHub.addAsset(assetBConfig, address(assetB));
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
    newSpoke.supply(vars.reserveAId, 1000e18);
    newSpoke.setUsingAsCollateral(vars.reserveAId, true);

    // Check Bob's supplied amounts and collateral status
    assertEq(
      newSpoke.getUserSuppliedAmount(vars.reserveAId, bob),
      1000e18,
      'bob supplied amount of reserve A on new spoke'
    );
    assertTrue(
      newSpoke.getUsingAsCollateral(vars.reserveAId, bob),
      'bob using reserve A as collateral on new spoke'
    );
    assertEq(
      newHub.getAssetSuppliedAmount(vars.assetAId),
      1000e18,
      'total supplied amount of assetA on new hub'
    );

    // Bob cannot borrow asset B because there is no liquidity
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    newSpoke.borrow(vars.reserveBId, 100e18, bob);

    // List asset B on the canonical (main) hub
    vars.assetBIdMainHub = hub.assetCount();
    hub.addAsset(assetBConfig, address(assetB));

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

    // Set the price of main hub reserve B
    newOracle.setReservePrice(vars.reserveBIdMainHub, 50_000e8);

    // Link main hub and new spoke for asset B from canonical hub
    // 0 supply cap, 100k draw cap
    spokeConfig = DataTypes.SpokeConfig({drawCap: 100_000e18, supplyCap: 0});
    hub.addSpoke(vars.assetBIdMainHub, spokeConfig, address(newSpoke));

    // Configure interest rate strategy for asset B on the main hub
    irStrategy.setInterestRateParams(vars.assetBIdMainHub, irData);

    // Bob still cannot borrow asset B from the new hub because there is no liquidity
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.NotAvailableLiquidity.selector, 0));
    newSpoke.borrow(vars.reserveBId, 100e18, bob);

    // Bob CAN borrow asset B from the main hub up until the draw cap of 100k (TODO: If it had liquidity, but how does it get liquidity?)
    //newSpoke.borrow(vars.reserveBIdMainHub, 100_000e18, bob);

    vm.stopPrank();
  }

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
