// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {LiquidityHub, ILiquidityHub} from 'src/contracts/LiquidityHub.sol';
import {Spoke, ISpoke} from 'src/contracts/Spoke.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {DefaultReserveInterestRateStrategy, IDefaultInterestRateStrategy} from 'src/contracts/DefaultReserveInterestRateStrategy.sol';

import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {MockPriceOracle, IPriceOracle} from 'tests/mocks/MockPriceOracle.sol';

contract SpokeMultipleHubBase is Test {
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
  ///@dev Lists asset B on canonical hub and spoke with no restrictions.
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

    // List asset B on the canonical hub
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

    // List reserve B on spoke 1 for the canonical hub
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

    // Configure interest rate strategy for asset B on the main hub
    irStrategy.setInterestRateParams(isolationVars.assetBIdMainHub, irData);
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
}
