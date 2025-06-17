// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMulticall is SpokeBase {
  /// Supply and set collateral using multicall
  function test_multicall_supply_setCollateral() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 supplyAmount = 1e18;

    // Set up the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(ISpoke.supply, (daiReserveId, supplyAmount));
    calls[1] = abi.encodeCall(ISpoke.setUsingAsCollateral, (daiReserveId, true));

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(daiReserveId, bob, hub.convertToSuppliedShares(daiAssetId, supplyAmount));
    vm.expectEmit(address(spoke1));
    emit ISpoke.UsingAsCollateral(daiReserveId, bob, true);

    // Execute the multicall
    vm.startPrank(bob);
    spoke1.multicall(calls);
    vm.stopPrank();

    // Check the supply
    uint256 bobSupplied = spoke1.getUserSuppliedAmount(daiReserveId, bob);
    assertEq(bobSupplied, supplyAmount, 'Bob supplied dai amount');

    // Check the collateral
    assertEq(spoke1.getUsingAsCollateral(daiReserveId, bob), true, 'Bob using as collateral');
  }

  /// Supply and update user risk premium using multicall
  function test_multicall_supply_updateUserRp() public {
    // Deal bob dai for supplying dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supplies dai2 and borrows half of it
    Utils.supplyCollateral(spoke2, _dai2ReserveId(spoke2), bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.borrow(spoke2, _dai2ReserveId(spoke2), bob, 1000e18, bob);

    // Check bob's premium drawn shares as proxy for user rp
    uint256 bobPremiumDrawnSharesBefore = spoke2
      .getUserPosition(_dai2ReserveId(spoke2), bob)
      .premiumDrawnShares;

    // Set up the multicall
    bytes[] memory calls = new bytes[](3);
    calls[0] = abi.encodeCall(ISpoke.supply, (_daiReserveId(spoke2), MAX_SUPPLY_AMOUNT));
    calls[1] = abi.encodeCall(ISpoke.setUsingAsCollateral, (_daiReserveId(spoke2), true));
    calls[2] = abi.encodeCall(ISpoke.updateUserRiskPremium, (bob));

    vm.expectEmit(address(spoke2));
    emit ISpoke.Supply(
      _daiReserveId(spoke2),
      bob,
      hub.convertToSuppliedShares(daiAssetId, MAX_SUPPLY_AMOUNT)
    );
    vm.expectEmit(address(spoke2));
    emit ISpoke.UsingAsCollateral(_daiReserveId(spoke2), bob, true);
    vm.expectEmit(address(spoke2));
    emit ISpoke.UserRiskPremiumUpdate(bob, _getLiquidityPremium(spoke2, _daiReserveId(spoke2)));

    // Then he supplies dai and sets as collateral, so user rp should decrease
    vm.startPrank(bob);
    spoke2.multicall(calls);
    vm.stopPrank();

    uint256 bobPremiumDrawnSharesAfter = spoke2
      .getUserPosition(_dai2ReserveId(spoke2), bob)
      .premiumDrawnShares;

    assertLt(
      bobPremiumDrawnSharesAfter,
      bobPremiumDrawnSharesBefore,
      'Bob premium drawn shares should decrease'
    );
  }

  /// Add multiple reserves using multicall
  function test_multicall_addMultipleReserves() public {
    uint256 reserveCountBefore = spoke1.reserveCount();
    uint256 dai2ReserveId = reserveCountBefore;
    uint256 dai3ReserveId = dai2ReserveId + 1;
    DataTypes.ReserveConfig memory dai2Config = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 10_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true
    });
    DataTypes.DynamicReserveConfig memory dai2DynConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 88_00
    });
    DataTypes.ReserveConfig memory dai3Config = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: false,
      paused: false,
      liquidationBonus: 100_00,
      liquidityPremium: 5_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true
    });
    DataTypes.DynamicReserveConfig memory dai3DynConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 70_00
    });

    DataTypes.Reserve memory dai2ReserveExpected;
    dai2ReserveExpected.reserveId = dai2ReserveId;
    dai2ReserveExpected.assetId = daiAssetId;
    dai2ReserveExpected.asset = address(tokenList.dai);
    dai2ReserveExpected.config = dai2Config;
    DataTypes.Reserve memory dai3ReserveExpected;
    dai3ReserveExpected.reserveId = dai3ReserveId;
    dai3ReserveExpected.assetId = daiAssetId;
    dai3ReserveExpected.asset = address(tokenList.dai);
    dai3ReserveExpected.config = dai3Config;

    // Set up the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(ISpoke.addReserve, (daiAssetId, dai2Config, dai2DynConfig));
    calls[1] = abi.encodeCall(ISpoke.addReserve, (daiAssetId, dai3Config, dai3DynConfig));

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveAdded(dai2ReserveId, daiAssetId);
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveAdded(dai3ReserveId, daiAssetId);

    // Execute the multicall
    spoke1.multicall(calls);

    // Check the reserves
    assertEq(spoke1.reserveCount(), reserveCountBefore + 2, 'Reserve count should increase by 2');
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
    DataTypes.Reserve memory newDai = spoke1.getReserve(daiReserveId);
    newDai.config.liquidityPremium += 1;
    newDai.config.liquidationBonus += 1;
    newDai.config.borrowable = false;
    DataTypes.Reserve memory newUsdx = spoke1.getReserve(usdxReserveId);
    newUsdx.config.liquidityPremium += 1;
    newUsdx.config.liquidationBonus += 1;
    newUsdx.config.collateral = false;

    // Set up the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(ISpoke.updateReserveConfig, (daiReserveId, newDai.config));
    calls[1] = abi.encodeCall(ISpoke.updateReserveConfig, (usdxReserveId, newUsdx.config));

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(daiReserveId, newDai.config);
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(usdxReserveId, newUsdx.config);

    // Execute the multicall
    spoke1.multicall(calls);

    // Check the reserve configs
    assertEq(spoke1.getReserve(daiReserveId), newDai);
    assertEq(spoke1.getReserve(usdxReserveId), newUsdx);
  }
}
