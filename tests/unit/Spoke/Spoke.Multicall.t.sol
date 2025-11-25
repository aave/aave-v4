// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMulticall is SpokeBase {
  using SafeCast for uint256;

  TestnetERC20 usda;

  function setUp() public override {
    super.setUp();
    usda = new TestnetERC20('USDA', 'USDA', Constants.MIN_ALLOWED_UNDERLYING_DECIMALS);
  }

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
      hub1.previewAddByAssets(daiAssetId, supplyAmount),
      supplyAmount
    );
    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral(daiReserveId, bob, bob, true);

    // Execute the multicall
    vm.prank(bob);
    spoke1.multicall(calls);

    // Check the supply
    uint256 bobSupplied = spoke1.getUserSuppliedAssets(daiReserveId, bob);
    assertEq(bobSupplied, supplyAmount, 'Bob supplied dai amount');

    // Check the collateral
    assertEq(_isUsingAsCollateral(spoke1, daiReserveId, bob), true, 'Bob using as collateral');
  }

  /// Supply and update user risk premium using multicall
  function test_multicall_supply_updateUserRp() public {
    // Deal bob dai for supplying dai and usdz
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supplies usdz and borrows half of it
    Utils.supplyCollateral(spoke2, _usdzReserveId(spoke2), bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.borrow(spoke2, _usdzReserveId(spoke2), bob, 1000e18, bob);

    // Check bob's premium drawn shares as proxy for user rp
    uint256 bobpremiumSharesBefore = spoke2
      .getUserPosition(_usdzReserveId(spoke2), bob)
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
      hub1.previewAddByAssets(daiAssetId, MAX_SUPPLY_AMOUNT),
      MAX_SUPPLY_AMOUNT
    );
    vm.expectEmit(address(spoke2));
    emit ISpoke.SetUsingAsCollateral(_daiReserveId(spoke2), bob, bob, true);
    vm.expectEmit(address(spoke2));
    emit ISpoke.UpdateUserRiskPremium(bob, _getCollateralRisk(spoke2, _daiReserveId(spoke2)));

    // Then he supplies dai and sets as collateral, so user rp should decrease
    vm.prank(bob);
    spoke2.multicall(calls);

    uint256 bobpremiumSharesAfter = spoke2
      .getUserPosition(_usdzReserveId(spoke2), bob)
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
    uint256 usdzReserveId = reserveCountBefore;
    uint256 usdaReserveId = usdzReserveId + 1;
    ISpoke.ReserveConfig memory usdzConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      receiveSharesEnabled: true,
      collateralRisk: 10_00
    });
    ISpoke.DynamicReserveConfig memory usdzDynConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 88_00,
      maxLiquidationBonus: 100_00,
      liquidationFee: 0
    });
    ISpoke.ReserveConfig memory usdaConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      receiveSharesEnabled: true,
      collateralRisk: 5_00
    });
    ISpoke.DynamicReserveConfig memory usdaDynConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 70_00,
      maxLiquidationBonus: 100_00,
      liquidationFee: 0
    });

    // Add usda
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    vm.prank(HUB_ADMIN);
    hub1.addAsset(address(usda), 18, address(treasurySpoke), address(irStrategy), encodedIrData);
    uint256 usdaAssetId = hub1.getAssetCount() - 1;

    Reserve memory usdzReserveExpected;
    usdzReserveExpected.reserveId = usdzReserveId;
    usdzReserveExpected.assetId = usdzAssetId.toUint16();
    usdzReserveExpected.paused = usdzConfig.paused;
    usdzReserveExpected.frozen = usdzConfig.frozen;
    usdzReserveExpected.borrowable = usdzConfig.borrowable;
    usdzReserveExpected.collateralRisk = usdzConfig.collateralRisk;
    Reserve memory usdaReserveExpected;
    usdaReserveExpected.reserveId = usdaReserveId;
    usdaReserveExpected.assetId = usdaAssetId.toUint16();
    usdaReserveExpected.paused = usdaConfig.paused;
    usdaReserveExpected.frozen = usdaConfig.frozen;
    usdaReserveExpected.borrowable = usdaConfig.borrowable;
    usdaReserveExpected.collateralRisk = usdaConfig.collateralRisk;

    {
      // Set up the multicall
      bytes[] memory calls = new bytes[](2);
      calls[0] = abi.encodeCall(
        ISpoke.addReserve,
        (address(hub1), usdzAssetId, _deployMockPriceFeed(spoke1, 1e8), usdzConfig, usdzDynConfig)
      );
      calls[1] = abi.encodeCall(
        ISpoke.addReserve,
        (address(hub1), usdaAssetId, _deployMockPriceFeed(spoke1, 1e8), usdaConfig, usdaDynConfig)
      );

      vm.expectEmit(address(spoke1));
      emit ISpoke.AddReserve(usdzReserveId, usdzAssetId, address(hub1));
      vm.expectEmit(address(spoke1));
      emit ISpoke.AddReserve(usdaReserveId, usdaAssetId, address(hub1));

      // Execute the multicall
      vm.prank(SPOKE_ADMIN);
      spoke1.multicall(calls);
    }

    // Check the reserves
    assertEq(
      spoke1.getReserveCount(),
      reserveCountBefore + 2,
      'Reserve count should increase by 2'
    );
    assertEq(spoke1.getReserveConfig(usdzReserveId), usdzConfig);
    assertEq(spoke1.getReserveConfig(usdaReserveId), usdaConfig);
    assertEq(_getLatestDynamicReserveConfig(spoke1, usdzReserveId), usdzDynConfig);
    assertEq(_getLatestDynamicReserveConfig(spoke1, usdaReserveId), usdaDynConfig);
  }

  /// Update multiple reserve configs using multicall
  function test_multicall_updateMultipleReserveConfigs() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    // Set up the new reserve configs
    ISpoke.ReserveConfig memory newDaiConfig = spoke1.getReserveConfig(daiReserveId);
    newDaiConfig.collateralRisk += 1;
    newDaiConfig.borrowable = false;
    ISpoke.ReserveConfig memory newUsdxConfig = spoke1.getReserveConfig(usdxReserveId);
    newUsdxConfig.collateralRisk += 1;

    // Set up the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(ISpoke.updateReserveConfig, (daiReserveId, newDaiConfig));
    calls[1] = abi.encodeCall(ISpoke.updateReserveConfig, (usdxReserveId, newUsdxConfig));

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateReserveConfig(daiReserveId, newDaiConfig);
    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateReserveConfig(usdxReserveId, newUsdxConfig);

    // Execute the multicall
    vm.prank(SPOKE_ADMIN);
    spoke1.multicall(calls);

    // Check the reserve configs
    assertEq(spoke1.getReserveConfig(daiReserveId), newDaiConfig);
    assertEq(spoke1.getReserveConfig(usdxReserveId), newUsdxConfig);
  }

  function test_multicall_getters() public {
    uint256 supplyAmount = 120e18;
    uint256 borrowAmount = 80e18;

    bytes[] memory calls = new bytes[](4);
    calls[0] = abi.encodeCall(ISpokeBase.supply, (_daiReserveId(spoke1), supplyAmount, alice));
    calls[1] = abi.encodeCall(ISpoke.setUsingAsCollateral, (_daiReserveId(spoke1), true, alice));
    calls[2] = abi.encodeCall(ISpokeBase.borrow, (_daiReserveId(spoke1), borrowAmount, alice));
    calls[3] = abi.encodeCall(ISpokeBase.getUserDebt, (_daiReserveId(spoke1), alice));

    vm.prank(alice);
    bytes[] memory ret = spoke1.multicall(calls);

    assertEq(ret.length, calls.length);
    assertEq(ret[0], abi.encode(supplyAmount, supplyAmount));
    assertEq(ret[1].length, 0);
    assertEq(ret[2], abi.encode(borrowAmount, borrowAmount));
    assertEq(ret[3], abi.encode(borrowAmount, 0));
  }

  function test_multicall_forwards_first_revert() public {
    uint256 supplyAmount = 120e18;

    bytes[] memory calls = new bytes[](3);
    calls[0] = abi.encodeCall(ISpokeBase.supply, (_daiReserveId(spoke1), supplyAmount, alice));
    calls[1] = abi.encodeCall(ISpokeBase.withdraw, (_daiReserveId(spoke1), 0, alice));
    calls[2] = abi.encodeCall(ISpoke.setUsingAsCollateral, (_daiReserveId(spoke1), true, alice));

    vm.prank(alice);
    vm.expectRevert(IHub.InvalidAmount.selector);
    spoke1.multicall(calls);
  }
}
