// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubConfigTest is LiquidityHubBase {
  using SharesMath for uint256;
  using WadRayMath for uint32;

  bytes public encodedIrData;

  function setUp() public virtual override {
    super.setUp();
    encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
  }

  function test_addSpoke_fuzz_revertsWith_AssetNotListed(
    uint256 assetId,
    DataTypes.SpokeConfig calldata spokeConfig
  ) public {
    assetId = bound(assetId, hub.getAssetCount(), type(uint256).max);
    vm.expectRevert(ILiquidityHub.AssetNotListed.selector);
    Utils.addSpoke(hub, ADMIN, assetId, address(spoke1), spokeConfig);
  }

  function test_addSpoke_fuzz_revertsWith_InvalidSpoke(
    uint256 assetId,
    DataTypes.SpokeConfig calldata spokeConfig
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.InvalidSpoke.selector));
    Utils.addSpoke(hub, ADMIN, assetId, address(0), spokeConfig);
  }

  function test_addSpoke_revertsWith_SpokeAlreadyListed() public {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(daiAssetId, address(spoke1));
    vm.expectRevert(ILiquidityHub.SpokeAlreadyListed.selector);
    Utils.addSpoke(hub, ADMIN, daiAssetId, address(spoke1), spokeConfig);
  }

  function test_addSpoke_fuzz(uint256 assetId, DataTypes.SpokeConfig calldata spokeConfig) public {
    address newSpoke = makeAddr('newSpoke');
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, newSpoke);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(assetId, newSpoke, spokeConfig);
    Utils.addSpoke(hub, ADMIN, assetId, newSpoke, spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, newSpoke), spokeConfig);
  }

  function test_updateSpokeConfig_fuzz_revertsWith_SpokeNotListed(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig calldata spokeConfig
  ) public {
    if (!hub.isSpokeListed(assetId, spoke)) {
      assetId = bound(assetId, hub.getAssetCount(), type(uint256).max);
    }
    vm.expectRevert(ILiquidityHub.SpokeNotListed.selector);
    Utils.updateSpokeConfig(hub, ADMIN, assetId, spoke, spokeConfig);
  }

  function test_updateSpokeConfig_fuzz(
    uint256 assetId,
    DataTypes.SpokeConfig calldata spokeConfig
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 3); // Exclude duplicated DAI and usdy

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(assetId, address(spoke1), spokeConfig);

    Utils.updateSpokeConfig(hub, ADMIN, assetId, address(spoke1), spokeConfig);
    assertEq(hub.getSpokeConfig(assetId, address(spoke1)), spokeConfig);
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);
    assumeNotZeroAddress(interestRateStrategy);

    decimals = uint8(bound(decimals, hub.MAX_ALLOWED_ASSET_DECIMALS() + 1, type(uint8).max));

    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector);
    Utils.addAsset(
      hub,
      ADMIN,
      underlying,
      decimals,
      feeReceiver,
      interestRateStrategy,
      encodedIrData
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidUnderlying(
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) public {
    vm.expectRevert(ILiquidityHub.InvalidUnderlying.selector);
    Utils.addAsset(
      hub,
      ADMIN,
      address(0),
      decimals,
      feeReceiver,
      interestRateStrategy,
      encodedIrData
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidFeeReceiver(
    address underlying,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(interestRateStrategy);

    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));

    vm.expectRevert(ILiquidityHub.InvalidFeeReceiver.selector);
    Utils.addAsset(
      hub,
      ADMIN,
      underlying,
      decimals,
      address(0),
      interestRateStrategy,
      encodedIrData
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidIrStrategy(
    address underlying,
    uint8 decimals,
    address feeReceiver
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);

    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    Utils.addAsset(hub, ADMIN, underlying, decimals, feeReceiver, address(0), encodedIrData);
  }

  function test_addAsset_fuzz_reverts_InvalidIrData(
    address underlying,
    uint8 decimals,
    address feeReceiver,
    address interestRateStrategy
  ) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);
    assumeNotZeroAddress(interestRateStrategy);
    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));

    vm.expectRevert();
    Utils.addAsset(
      hub,
      ADMIN,
      underlying,
      decimals,
      feeReceiver,
      interestRateStrategy,
      abi.encode('invalid')
    );
  }

  function test_addAsset_fuzz(address underlying, uint8 decimals, address feeReceiver) public {
    assumeUnusedAddress(underlying);
    assumeNotZeroAddress(feeReceiver);

    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));

    uint256 expectedAssetId = hub.getAssetCount();
    address interestRateStrategy = address(new AssetInterestRateStrategy(address(hub)));

    DataTypes.AssetConfig memory expectedConfig = DataTypes.AssetConfig({
      feeReceiver: feeReceiver,
      liquidityFee: 0,
      irStrategy: interestRateStrategy
    });

    (, uint32 baseVariableBorrowRate, , ) = abi.decode(
      encodedIrData,
      (uint32, uint32, uint32, uint32)
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetAdded(expectedAssetId, underlying, decimals);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(expectedAssetId, expectedConfig);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetUpdated(
      expectedAssetId,
      WadRayMath.RAY,
      baseVariableBorrowRate.bpsToRay(),
      vm.getBlockTimestamp()
    );

    uint256 assetId = Utils.addAsset(
      hub,
      ADMIN,
      underlying,
      decimals,
      feeReceiver,
      interestRateStrategy,
      encodedIrData
    );

    assertEq(assetId, expectedAssetId, 'asset id');
    assertEq(hub.getAssetCount(), assetId + 1, 'asset count');
    assertEq(hub.getAsset(assetId).decimals, decimals, 'asset decimals');
    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function test_updateAssetConfig_fuzz_revertsWith_InvalidIrStrategy(
    uint256 assetId,
    DataTypes.AssetConfig memory newConfig
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    _assumeValidAssetConfig(assetId, newConfig);
    newConfig.irStrategy = address(0);

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, newConfig);
  }

  function test_updateAssetConfig_fuzz_revertsWith_InvalidLiquidityFee(
    uint256 assetId,
    DataTypes.AssetConfig memory newConfig
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    _assumeValidAssetConfig(assetId, newConfig);
    newConfig.liquidityFee = vm.randomUint(PercentageMath.PERCENTAGE_FACTOR + 1, type(uint256).max);
    vm.expectRevert(ILiquidityHub.InvalidLiquidityFee.selector);
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, newConfig);
  }

  function test_updateAssetConfig_fuzz_revertsWith_InvalidFeeReceiver(
    uint256 assetId,
    DataTypes.AssetConfig memory newConfig
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    _assumeValidAssetConfig(assetId, newConfig);
    newConfig.liquidityFee = vm.randomUint(1, PercentageMath.PERCENTAGE_FACTOR);
    newConfig.feeReceiver = address(0);
    vm.expectRevert(ILiquidityHub.InvalidFeeReceiver.selector);
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, newConfig);
  }

  function test_updateAssetConfig_fuzz_revertsWith_InterestRateStrategyReverts(
    uint256 assetId,
    DataTypes.AssetConfig memory newConfig
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    _assumeValidAssetConfig(assetId, newConfig);
    assumeUnusedAddress(newConfig.irStrategy);
    vm.expectRevert();
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, newConfig);
  }

  function test_updateAssetConfig_fuzz(
    uint256 assetId,
    DataTypes.AssetConfig memory newConfig
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    _assumeValidAssetConfig(assetId, newConfig);
    _mockInterestRateBps(newConfig.irStrategy, 5_00);

    uint256 availableLiquidity = hub.getAvailableLiquidity(assetId);
    (uint256 baseDebt, uint256 premiumDebt) = hub.getAssetDebt(assetId);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetUpdated(
      assetId,
      hub.getAssetDrawnIndex(assetId),
      IBasicInterestRateStrategy(irStrategy).calculateInterestRate({
        assetId: assetId,
        availableLiquidity: availableLiquidity,
        baseDebt: baseDebt,
        premiumDebt: premiumDebt
      }),
      vm.getBlockTimestamp()
    );
    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, newConfig);

    Utils.updateAssetConfig(hub, ADMIN, assetId, newConfig);

    assertEq(hub.getAssetConfig(assetId), newConfig);
  }

  function test_updateAssetConfig_fuzz_Scenario(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    // set same config
    test_updateAssetConfig_fuzz(assetId, config);
    // set new fee receiver
    config.feeReceiver = makeAddr('newFeeReceiver');
    test_updateAssetConfig_fuzz(assetId, config);
    // set zero liquidity fee
    config.liquidityFee = 0;
    test_updateAssetConfig_fuzz(assetId, config);
    // set zero liquidity fee again
    test_updateAssetConfig_fuzz(assetId, config);
    // set non-zero fee receiver
    config.feeReceiver = makeAddr('newFeeReceiver2');
    test_updateAssetConfig_fuzz(assetId, config);
    // set initial config
    test_updateAssetConfig_fuzz(assetId, hub.getAssetConfig(assetId));
  }

  /// Updates to new fee receiver, with previously accrued fees not transferred to the new receiver
  function test_updateAssetConfig_fuzz_NewFeeReceiver(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    address oldFeeReceiver = config.feeReceiver;
    config.feeReceiver = makeAddr('newFeeReceiver');

    uint256 feesShares = hub.getSpokeSuppliedShares(assetId, oldFeeReceiver);
    assertTrue(feesShares > 0, 'no fees');

    test_updateAssetConfig_fuzz(assetId, config);

    assertEq(hub.getSpokeSuppliedShares(assetId, oldFeeReceiver), feesShares);
    assertEq(hub.getSpokeSuppliedShares(assetId, config.feeReceiver), 0);
  }

  /// Updates the fee receiver by reusing a previously assigned spoke, with no impact on accrued fees
  function test_updateAssetConfig_fuzz_ReuseFeeReceiver(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    test_updateAssetConfig_fuzz_NewFeeReceiver(assetId);

    address oldFeeReceiver = address(treasurySpoke);
    uint256 oldFees = hub.getSpokeSuppliedShares(assetId, oldFeeReceiver);

    skip(365 days);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    address newFeeReceiver = config.feeReceiver;

    uint256 newFees = hub.getSpokeSuppliedShares(assetId, newFeeReceiver);
    assertTrue(newFees > 0);

    config.feeReceiver = address(treasurySpoke);
    test_updateAssetConfig_fuzz(assetId, config);

    assertEq(hub.getSpokeSuppliedShares(assetId, config.feeReceiver), oldFees);
    assertEq(hub.getSpokeSuppliedShares(assetId, newFeeReceiver), newFees);
  }

  /// Updates the fee receiver to an existing spoke of the hub, so ends up with existing supplied shares plus accrued fees
  function test_updateAssetConfig_fuzz_UseExistingSpokeAsFeeReceiver(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    address oldFeeReceiver = _getFeeReceiver(assetId);
    address newFeeReceiver = address(spoke1);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    uint256 oldReceiverFees = hub.getSpokeSuppliedShares(assetId, oldFeeReceiver);
    assertTrue(oldReceiverFees > 0);

    // spoke1 adds some assets
    Utils.add({hub: hub, assetId: assetId, caller: address(spoke2), amount: amount, user: bob});
    uint256 newReceiverFees = hub.getSpokeSuppliedShares(assetId, newFeeReceiver);

    updateAssetFeeReceiver(hub, assetId, newFeeReceiver);

    skip(365 days);

    // new fee receiver keeps the existing supplied shares and earns more via fees accrual
    assertTrue(hub.getSpokeSuppliedShares(assetId, newFeeReceiver) > newReceiverFees);

    // old fee receiver keeps the accrued fees
    assertEq(hub.getSpokeSuppliedShares(assetId, oldFeeReceiver), oldReceiverFees);
  }

  /// Triggers accrual when liquidity fee update, based on old liquidity fee
  function test_updateAssetConfig_fuzz_LiquidityFee(uint256 assetId, uint256 liquidityFee) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    uint256 feeShares = hub.getSpokeSuppliedShares(assetId, config.feeReceiver);
    assertTrue(feeShares > 0, 'no fees');

    config.liquidityFee = liquidityFee;
    test_updateAssetConfig_fuzz(assetId, config);

    assertEq(hub.getSpokeSuppliedShares(assetId, config.feeReceiver), feeShares);
  }

  /// No fees accrued whe updating liquidity fee from zero to non-zero
  function test_updateAssetConfig_fuzz_FromZeroLiquidityFee(
    uint256 assetId,
    uint256 liquidityFee
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.liquidityFee = 0;
    test_updateAssetConfig_fuzz(assetId, config);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    config.liquidityFee = liquidityFee;
    config.feeReceiver = makeAddr('feeReceiver');
    test_updateAssetConfig_fuzz(assetId, config);

    assertEq(hub.getSpokeSuppliedShares(assetId, address(0)), 0);
    assertEq(hub.getSpokeSuppliedShares(assetId, config.feeReceiver), 0);
  }

  /// Triggers accrual when interest rate strategy is updated, based on old strategy
  /// Also makes sure that the base borrow rate is updated after accrual
  function test_updateAssetConfig_fuzz_NewInterestRateStrategy(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    uint256 fees = hub.getSpokeSuppliedShares(assetId, address(treasurySpoke));
    assertTrue(fees > 0, 'no fees');

    skip(365 days);
    uint256 futureFees = hub.getSpokeSuppliedShares(assetId, address(treasurySpoke));
    rewind(365 days);

    AssetInterestRateStrategy newIrStrategy = new AssetInterestRateStrategy(address(hub));
    _mockInterestRateRay(address(newIrStrategy), hub.getBaseInterestRate(assetId) * 10);
    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.irStrategy = address(newIrStrategy);
    Utils.updateAssetConfig(hub, ADMIN, assetId, config);

    skip(365 days);
    assertNotEq(hub.getSpokeSuppliedShares(assetId, config.feeReceiver), futureFees);
  }

  function _assumeValidAssetConfig(
    uint256 assetId,
    DataTypes.AssetConfig memory newConfig
  ) internal pure {
    newConfig.liquidityFee = bound(newConfig.liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    vm.assume(address(newConfig.feeReceiver) != address(0) || newConfig.liquidityFee == 0);
    assumeNotPrecompile(newConfig.feeReceiver);
    assumeNotForgeAddress(newConfig.feeReceiver);
    assumeNotZeroAddress(newConfig.irStrategy);
    assumeNotPrecompile(newConfig.irStrategy);
    assumeNotForgeAddress(newConfig.irStrategy);
  }
}
