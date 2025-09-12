// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMulticall is SpokeBase {
  using SafeCast for uint256;

  /// Supply and set collateral using multicall
  function test_multicall_supply_setCollateral() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 supplyAmount = 1e18;

    // Set up the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(ISpokeBase.supply, (daiReserveId, supplyAmount, bob));
    calls[1] = abi.encodeCall(ISpoke.setUsingAsCollateral, (daiReserveId, true, bob));

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(
      daiReserveId,
      bob,
      bob,
      hub1.convertToAddedShares(daiAssetId, supplyAmount)
    );
    vm.expectEmit(address(spoke1));
    emit ISpoke.UsingAsCollateral(daiReserveId, bob, bob, true);

    // Execute the multicall
    vm.prank(bob);
    spoke1.multicall(calls);

    // Check the supply
    uint256 bobSupplied = spoke1.getUserSuppliedAssets(daiReserveId, bob);
    assertEq(bobSupplied, supplyAmount, 'Bob supplied dai amount');

    // Check the collateral
    assertEq(spoke1.isUsingAsCollateral(daiReserveId, bob), true, 'Bob using as collateral');
  }

  /// Supply and update user risk premium using multicall
  function test_multicall_supply_updateUserRp() public {
    // Deal bob dai for supplying dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supplies dai2 and borrows half of it
    Utils.supplyCollateral(spoke2, _dai2ReserveId(spoke2), bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.borrow(spoke2, _dai2ReserveId(spoke2), bob, 1000e18, bob);

    // Check bob's premium drawn shares as proxy for user rp
    uint256 bobpremiumSharesBefore = spoke2
      .getUserPosition(_dai2ReserveId(spoke2), bob)
      .premiumShares;

    // Set up the multicall
    bytes[] memory calls = new bytes[](3);
    calls[0] = abi.encodeCall(ISpokeBase.supply, (_daiReserveId(spoke2), MAX_SUPPLY_AMOUNT, bob));
    calls[1] = abi.encodeCall(ISpoke.setUsingAsCollateral, (_daiReserveId(spoke2), true, bob));
    calls[2] = abi.encodeCall(ISpoke.updateUserRiskPremium, (bob));

    vm.expectEmit(address(spoke2));
    emit ISpokeBase.Supply(
      _daiReserveId(spoke2),
      bob,
      bob,
      hub1.convertToAddedShares(daiAssetId, MAX_SUPPLY_AMOUNT)
    );
    vm.expectEmit(address(spoke2));
    emit ISpoke.UsingAsCollateral(_daiReserveId(spoke2), bob, bob, true);
    vm.expectEmit(address(spoke2));
    emit ISpoke.UserRiskPremiumUpdate(bob, _getCollateralRisk(spoke2, _daiReserveId(spoke2)));

    // Then he supplies dai and sets as collateral, so user rp should decrease
    vm.prank(bob);
    spoke2.multicall(calls);

    uint256 bobpremiumSharesAfter = spoke2
      .getUserPosition(_dai2ReserveId(spoke2), bob)
      .premiumShares;

    assertLt(
      bobpremiumSharesAfter,
      bobpremiumSharesBefore,
      'Bob premium drawn shares should decrease'
    );
  }

  /// Add multiple reserves using multicall
  function test_multicall_addMultipleReserves() public {
    uint256 reserveCountBefore = spoke1.getReserveCount();
    uint256 dai2ReserveId = reserveCountBefore;
    uint256 dai3ReserveId = dai2ReserveId + 1;
    DataTypes.ReserveConfig memory dai2Config = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 10_00
    });
    DataTypes.DynamicReserveConfig memory dai2DynConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 88_00,
      maxLiquidationBonus: 100_00,
      liquidationFee: 0
    });
    DataTypes.ReserveConfig memory dai3Config = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 5_00
    });
    DataTypes.DynamicReserveConfig memory dai3DynConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 70_00,
      maxLiquidationBonus: 100_00,
      liquidationFee: 0
    });

    // Add a third dai to hub
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    vm.prank(HUB_ADMIN);
    hub1.addAsset(
      address(tokenList.dai),
      18,
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    uint256 dai3AssetId = hub1.getAssetCount() - 1;

    Reserve memory dai2ReserveExpected;
    dai2ReserveExpected.reserveId = dai2ReserveId;
    dai2ReserveExpected.assetId = daiAssetId.toUint16();
    dai2ReserveExpected.paused = dai2Config.paused;
    dai2ReserveExpected.frozen = dai2Config.frozen;
    dai2ReserveExpected.borrowable = dai2Config.borrowable;
    dai2ReserveExpected.collateralRisk = dai2Config.collateralRisk;
    Reserve memory dai3ReserveExpected;
    dai3ReserveExpected.reserveId = dai3ReserveId;
    dai3ReserveExpected.assetId = daiAssetId.toUint16();
    dai3ReserveExpected.paused = dai3Config.paused;
    dai3ReserveExpected.frozen = dai3Config.frozen;
    dai3ReserveExpected.borrowable = dai3Config.borrowable;
    dai3ReserveExpected.collateralRisk = dai3Config.collateralRisk;

    // Set up the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(
      ISpoke.addReserve,
      (address(hub1), dai2AssetId, _deployMockPriceFeed(spoke1, 1e8), dai2Config, dai2DynConfig)
    );
    calls[1] = abi.encodeCall(
      ISpoke.addReserve,
      (address(hub1), dai3AssetId, _deployMockPriceFeed(spoke1, 1e8), dai3Config, dai3DynConfig)
    );

    vm.expectEmit(address(spoke1));
    emit ISpoke.AddReserve(dai2ReserveId, dai2AssetId, address(hub1));
    vm.expectEmit(address(spoke1));
    emit ISpoke.AddReserve(dai3ReserveId, dai3AssetId, address(hub1));

    // Execute the multicall
    vm.prank(SPOKE_ADMIN);
    spoke1.multicall(calls);

    // Check the reserves
    assertEq(
      spoke1.getReserveCount(),
      reserveCountBefore + 2,
      'Reserve count should increase by 2'
    );
    assertEq(spoke1.getReserveConfig(dai2ReserveId), dai2Config);
    assertEq(spoke1.getReserveConfig(dai3ReserveId), dai3Config);
    assertEq(spoke1.getDynamicReserveConfig(dai2ReserveId), dai2DynConfig);
    assertEq(spoke1.getDynamicReserveConfig(dai3ReserveId), dai3DynConfig);
  }

  /// Update multiple reserve configs using multicall
  function test_multicall_updateMultipleReserveConfigs() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    // Set up the new reserve configs
    DataTypes.ReserveConfig memory newDaiConfig = spoke1.getReserveConfig(daiReserveId);
    newDaiConfig.collateralRisk += 1;
    newDaiConfig.borrowable = false;
    DataTypes.ReserveConfig memory newUsdxConfig = spoke1.getReserveConfig(usdxReserveId);
    newUsdxConfig.collateralRisk += 1;

    // Set up the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(ISpoke.updateReserveConfig, (daiReserveId, newDaiConfig));
    calls[1] = abi.encodeCall(ISpoke.updateReserveConfig, (usdxReserveId, newUsdxConfig));

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdate(daiReserveId, newDaiConfig);
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdate(usdxReserveId, newUsdxConfig);

    // Execute the multicall
    vm.prank(SPOKE_ADMIN);
    spoke1.multicall(calls);

    // Check the reserve configs
    assertEq(spoke1.getReserveConfig(daiReserveId), newDaiConfig);
    assertEq(spoke1.getReserveConfig(usdxReserveId), newUsdxConfig);
  }

  function test_multicall_getters() public {
    bytes[] memory calls = new bytes[](5);
    calls[0] = abi.encodeCall(ISpokeBase.supply, (_daiReserveId(spoke1), 120e18, alice));
    calls[1] = abi.encodeCall(ISpoke.setUsingAsCollateral, (_daiReserveId(spoke1), true, alice));
    calls[2] = abi.encodeCall(ISpokeBase.borrow, (_daiReserveId(spoke1), 80e18, alice));
    calls[3] = abi.encodeCall(ISpoke.getUserRiskPremium, (alice));
    calls[4] = abi.encodeCall(ISpokeBase.getUserDebt, (_daiReserveId(spoke1), alice));

    vm.prank(alice);
    bytes[] memory ret = spoke1.multicall(calls);

    assertEq(ret.length, calls.length);
    assertEq(ret[0].length, 0);
    assertEq(ret[1].length, 0);
    assertEq(ret[2].length, 0);
    assertEq(ret[3], abi.encode(_calculateExpectedUserRP(alice, spoke1)));
    assertEq(ret[4], abi.encode(80e18, 0));
  }

  function test_multicall_forwards_first_revert() public {
    bytes[] memory calls = new bytes[](3);
    calls[0] = abi.encodeCall(ISpokeBase.supply, (_daiReserveId(spoke1), 120e18, alice));
    calls[1] = abi.encodeCall(ISpokeBase.withdraw, (_daiReserveId(spoke1), 121e18, alice));
    calls[2] = abi.encodeCall(ISpoke.setUsingAsCollateral, (_daiReserveId(spoke1), true, alice));

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(ISpoke.InsufficientSupply.selector, 120e18));
    spoke1.multicall(calls);
  }
}
