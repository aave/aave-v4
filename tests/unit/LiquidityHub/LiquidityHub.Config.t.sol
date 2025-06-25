// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubConfigTest is LiquidityHubBase {
  using SharesMath for uint256;

  function test_addSpoke_fuzz_revertsWith_InvalidSpoke(uint256 assetId, DataTypes.SpokeConfig calldata spokeConfig) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.InvalidSpoke.selector));
    vm.prank(address(configurator));
    hub.addSpoke(assetId, address(0), spokeConfig);
  }

  function test_addSpoke_fuzz(uint256 assetId, DataTypes.SpokeConfig calldata spokeConfig) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
  
    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, address(spoke1));
    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(assetId, address(spoke1), spokeConfig);
    vm.prank(address(configurator));
    hub.addSpoke(assetId, address(spoke1), spokeConfig);

    assertEq(hub.getSpokeConfig(assetId, address(spoke1)).supplyCap, spokeConfig.supplyCap, 'spoke supply cap');
    assertEq(hub.getSpokeConfig(assetId, address(spoke1)).drawCap, spokeConfig.drawCap, 'spoke draw cap');
  }

  function test_updateSpokeConfig_drawCap() public {
    DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));

    uint256 drawCap = 5;
    assertNotEq(config.drawCap, drawCap);
    config.drawCap = drawCap;

    _checkedUpdateSpokeConfig(daiAssetId, address(spoke1), config);
  }

  function test_updateSpokeConfig_fuzz_drawCap(uint256 drawCap) public {
    DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));

    vm.assume(config.drawCap != drawCap);
    config.drawCap = drawCap;

    _checkedUpdateSpokeConfig(daiAssetId, address(spoke1), config);
  }

  function test_updateSpokeConfig_supplyCap() public {
    DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));

    uint256 supplyCap = 5;
    assertNotEq(config.supplyCap, supplyCap);
    config.supplyCap = supplyCap;

    _checkedUpdateSpokeConfig(daiAssetId, address(spoke1), config);
  }

  function test_updateSpokeConfig_fuzz_supplyCap(uint256 supplyCap) public {
    DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));

    vm.assume(config.supplyCap != supplyCap);
    config.supplyCap = supplyCap;

    _checkedUpdateSpokeConfig(daiAssetId, address(spoke1), config);
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
    address asset,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    vm.assume(asset != address(0) && interestRateStrategy != address(0));
    decimals = uint8(bound(decimals, hub.MAX_ALLOWED_ASSET_DECIMALS() + 1, type(uint8).max));

    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector);

    vm.prank(address(configurator));
    hub.addAsset(asset, decimals, interestRateStrategy);
  }

  function test_addAsset_revertsWith_InvalidAssetDecimals() public {
    test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
      address(tokenList.dai),
      hub.MAX_ALLOWED_ASSET_DECIMALS() + 1,
      address(irStrategy)
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetAddress(
    uint8 decimals,
    address interestRateStrategy
  ) public {
    vm.expectRevert(ILiquidityHub.InvalidAssetAddress.selector);

    vm.prank(address(configurator));
    hub.addAsset(address(0), decimals, interestRateStrategy);
  }

  function test_addAsset_revertsWith_InvalidAssetAddress() public {
    test_addAsset_fuzz_revertsWith_InvalidAssetAddress(18, address(irStrategy));
  }

  function test_addAsset_fuzz_revertsWith_InvalidIrStrategy(address asset, uint8 decimals) public {
    vm.assume(asset != address(0));
    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);

    vm.prank(address(configurator));
    hub.addAsset(asset, decimals, address(0));
  }

  function test_addAsset_revertsWith_InvalidIrStrategy() public {
    test_addAsset_fuzz_revertsWith_InvalidIrStrategy(address(tokenList.dai), 18);
  }

  function test_addAsset_fuzz(address asset, uint8 decimals, address interestRateStrategy) public {
    vm.assume(asset != address(0) && interestRateStrategy != address(0));
    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));
    _checkedAddAsset(asset, decimals, interestRateStrategy);
  }

  function test_addAsset() public {
    test_addAsset_fuzz(address(tokenList.dai), 18, address(irStrategy));
  }

  function test_updateAssetConfig_fuzz_revertsWith_InvalidIrStrategy(
    DataTypes.AssetConfig memory newConfig
  ) public {
    _processAssetConfig(daiAssetId, newConfig);
    newConfig.irStrategy = address(0);

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    hub.updateAssetConfig(daiAssetId, newConfig);
  }

  function test_updateAssetConfig_fuzz_revertsWith_InvalidLiquidityFee(
    DataTypes.AssetConfig memory newConfig
  ) public {
    _processAssetConfig(daiAssetId, newConfig);
    newConfig.liquidityFee = vm.randomUint(
      PercentageMathExtended.PERCENTAGE_FACTOR + 1,
      type(uint256).max
    );
    vm.expectRevert(ILiquidityHub.InvalidLiquidityFee.selector);
    hub.updateAssetConfig(daiAssetId, newConfig);
  }

  function test_updateAssetConfig_fuzz_revertsWith_InvalidFeeReceiver(
    DataTypes.AssetConfig memory newConfig
  ) public {
    _processAssetConfig(daiAssetId, newConfig);
    newConfig.liquidityFee = vm.randomUint(1, PercentageMathExtended.PERCENTAGE_FACTOR);
    newConfig.feeReceiver = address(0);
    vm.expectRevert(ILiquidityHub.InvalidFeeReceiver.selector);
    hub.updateAssetConfig(daiAssetId, newConfig);
  }

  function test_updateAssetConfig_fuzz_revertsWith_InvalidFeeReceiverConfig_oldReceiver(
    DataTypes.AssetConfig memory newConfig,
    uint256
  ) public {
    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(daiAssetId);

    _processAssetConfig(daiAssetId, newConfig);
    vm.assume(newConfig.feeReceiver != oldConfig.feeReceiver);

    hub.updateSpokeConfig(
      daiAssetId,
      oldConfig.feeReceiver,
      DataTypes.SpokeConfig({
        supplyCap: vm.randomUint(1, type(uint256).max),
        drawCap: vm.randomUint(1, type(uint256).max)
      })
    );

    vm.expectRevert(ILiquidityHub.InvalidFeeReceiverConfig.selector);
    hub.updateAssetConfig(daiAssetId, newConfig);
  }

  function test_updateAssetConfig_fuzz_revertsWith_InvalidFeeReceiverConfig_newReceiver(
    DataTypes.AssetConfig memory newConfig,
    uint256
  ) public {
    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(daiAssetId);

    _processAssetConfig(daiAssetId, newConfig);
    vm.assume(newConfig.feeReceiver != oldConfig.feeReceiver);

    newConfig.liquidityFee = bound(
      newConfig.liquidityFee,
      1,
      PercentageMathExtended.PERCENTAGE_FACTOR
    );
    hub.updateSpokeConfig(
      daiAssetId,
      newConfig.feeReceiver,
      DataTypes.SpokeConfig({
        supplyCap: vm.randomUint(0, type(uint256).max - 1),
        drawCap: vm.randomUint(0, type(uint256).max - 1)
      })
    );

    vm.expectRevert(ILiquidityHub.InvalidFeeReceiverConfig.selector);
    hub.updateAssetConfig(daiAssetId, newConfig);
  }

  function test_updateAssetConfig_fuzz_revertsWith_InterestRateStrategyReverts(DataTypes.AssetConfig memory newConfig) public {
    vm.assume(newConfig.irStrategy != address(irStrategy) && newConfig.irStrategy > address(0x0a));
    _processAssetConfig(daiAssetId, newConfig);

    vm.expectRevert();
    hub.updateAssetConfig(daiAssetId, newConfig);
  }

  function test_updateAssetConfig_fuzz(DataTypes.AssetConfig memory newConfig) public {
    _processAssetConfig(daiAssetId, newConfig);
    vm.assume(newConfig.irStrategy != address(0) && newConfig.irStrategy != address(Utils.vm));
    _mockInterestRate(newConfig.irStrategy, 5_00);
    _checkedUpdateAssetConfig(daiAssetId, newConfig);
  }

  function test_updateAssetConfig() public {
    test_updateAssetConfig_fuzz(
      DataTypes.AssetConfig({
        active: false,
        frozen: true,
        paused: true,
        feeReceiver: makeAddr('feeReceiver'),
        liquidityFee: 20_00,
        irStrategy: makeAddr('irStrategy')
      })
    );
  }

  function test_updateAssetConfig_fuzz_SameReceiver(
    uint256 liquidityFee,
    uint256 supplyCap,
    uint256 drawCap
  ) public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    assert(config.feeReceiver != address(0));

    hub.updateSpokeConfig(
      daiAssetId,
      config.feeReceiver,
      DataTypes.SpokeConfig({supplyCap: supplyCap, drawCap: drawCap})
    );

    liquidityFee = bound(liquidityFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);
    config.liquidityFee = liquidityFee;

    _checkedUpdateAssetConfig(daiAssetId, config);
  }

  function test_updateAssetConig_fuzz_ZeroFeeReceiver(uint256 supplyCap, uint256 drawCap) public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);

    uint256 initialLiquidityFee = config.liquidityFee;
    address initialFeeReceiver = config.feeReceiver;
    assert(initialFeeReceiver != address(0));

    hub.updateSpokeConfig(
      daiAssetId,
      address(0),
      DataTypes.SpokeConfig({supplyCap: supplyCap, drawCap: drawCap})
    );

    hub.updateSpokeConfig(
      daiAssetId,
      initialFeeReceiver,
      DataTypes.SpokeConfig({supplyCap: 0, drawCap: 0})
    );
    config.feeReceiver = address(0);
    config.liquidityFee = 0;
    _checkedUpdateAssetConfig(daiAssetId, config);

    hub.updateSpokeConfig(
      daiAssetId,
      initialFeeReceiver,
      DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max})
    );
    config.feeReceiver = initialFeeReceiver;
    config.liquidityFee = initialLiquidityFee;
    _checkedUpdateAssetConfig(daiAssetId, config);
  }

  function test_updateAssetConfig_NoConfigChange() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    _checkedUpdateAssetConfig(daiAssetId, config);
  }

  /// Updates to new fee receiver, with previously accrued fees not transferred to the new receiver
  function test_updateAssetConfig_NewFeeReceiver() public {
    uint256 amount = 1000e18;
    _addLiquidity(daiAssetId, amount);
    _drawLiquidity(daiAssetId, amount, true);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    address oldFeeReceiver = config.feeReceiver;
    config.feeReceiver = makeAddr('newFeeReceiver');
    _processAssetConfig(daiAssetId, config);

    uint256 feesShares = hub.getSpokeSuppliedShares(daiAssetId, oldFeeReceiver);
    assertTrue(feesShares > 0, 'no fees');

    _checkedUpdateAssetConfig(daiAssetId, config);

    assertEq(hub.getSpokeSuppliedShares(daiAssetId, oldFeeReceiver), feesShares);
    assertEq(hub.getSpokeSuppliedShares(daiAssetId, config.feeReceiver), 0);
  }

  /// Updates the fee receiver by reusing a previously assigned spoke, with no impact on accrued fees
  function test_updateAssetConfig_ReuseFeeReceiver() public {
    test_updateAssetConfig_NewFeeReceiver();

    address oldFeeReceiver = address(treasurySpoke);
    uint256 oldFees = hub.getSpokeSuppliedShares(daiAssetId, oldFeeReceiver);

    skip(365 days);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    address newFeeReceiver = config.feeReceiver;

    uint256 newFees = hub.getSpokeSuppliedShares(daiAssetId, newFeeReceiver);
    assertTrue(newFees > 0);

    config.feeReceiver = address(treasurySpoke);
    _processAssetConfig(daiAssetId, config);
    _checkedUpdateAssetConfig(daiAssetId, config);

    assertEq(hub.getSpokeSuppliedShares(daiAssetId, config.feeReceiver), oldFees);
    assertEq(hub.getSpokeSuppliedShares(daiAssetId, newFeeReceiver), newFees);
  }

  /// Updates the fee receiver from zero to non-zero, even with zero liquidity fee
  function test_updateAssetConfig_FromZeroFeeReceiver() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    config.feeReceiver = address(0);
    config.liquidityFee = 0;
    _processAssetConfig(daiAssetId, config);
    _checkedUpdateAssetConfig(daiAssetId, config);

    uint256 amount = 1000e18;
    _addLiquidity(daiAssetId, amount);
    _drawLiquidity(daiAssetId, amount, true);

    config.feeReceiver = makeAddr('newFeeReceiver');
    _processAssetConfig(daiAssetId, config);
    _checkedUpdateAssetConfig(daiAssetId, config);

    assertEq(hub.getSpokeSuppliedShares(daiAssetId, config.feeReceiver), 0);
  }

  /// Triggers accrual when liquidity fee update, based on old liquidity fee
  function test_updateAssetConfig_fuzz_LiquidityFee(uint256 liquidityFee) public {
    liquidityFee = bound(liquidityFee, 1, PercentageMathExtended.PERCENTAGE_FACTOR);

    uint256 amount = 1000e18;
    _addLiquidity(daiAssetId, amount);
    _drawLiquidity(daiAssetId, amount, true);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    uint256 feeShares = hub.getSpokeSuppliedShares(daiAssetId, config.feeReceiver);
    assertTrue(feeShares > 0, 'no fees');

    config.liquidityFee = liquidityFee;
    _checkedUpdateAssetConfig(daiAssetId, config);

    assertEq(hub.getSpokeSuppliedShares(daiAssetId, config.feeReceiver), feeShares);
  }

  /// No fees accrued whe updating liquidity fee from zero to non-zero
  function test_updateAssetConfig_fuzz_FromZeroLiquidityFee(uint256 liquidityFee) public {
    liquidityFee = bound(liquidityFee, 1, PercentageMathExtended.PERCENTAGE_FACTOR);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    config.feeReceiver = address(0);
    config.liquidityFee = 0;
    _processAssetConfig(daiAssetId, config);
    _checkedUpdateAssetConfig(daiAssetId, config);

    uint256 amount = 1000e18;
    _addLiquidity(daiAssetId, amount);
    _drawLiquidity(daiAssetId, amount, true);

    config.liquidityFee = liquidityFee;
    config.feeReceiver = makeAddr('feeReceiver');
    _processAssetConfig(daiAssetId, config);
    _checkedUpdateAssetConfig(daiAssetId, config);

    assertEq(hub.getSpokeSuppliedShares(daiAssetId, address(0)), 0);
    assertEq(hub.getSpokeSuppliedShares(daiAssetId, config.feeReceiver), 0);
  }

  /// Triggers accrual when interest rate strategy is updated, based on old strategy
  /// Also makes sure that the base borrow rate is updated after accrual
  function test_updateAssetConfig_NewInterestRateStrategy() public {
    uint256 amount = 1000e18;
    _addLiquidity(daiAssetId, amount);
    _drawLiquidity(daiAssetId, amount, true);

    uint256 fees = hub.getSpokeSuppliedShares(daiAssetId, address(treasurySpoke));
    assertTrue(fees > 0, 'no fees');

    skip(365 days);
    uint256 futureFees = hub.getSpokeSuppliedShares(daiAssetId, address(treasurySpoke));
    rewind(365 days);

    AssetInterestRateStrategy newIrStrategy = new AssetInterestRateStrategy();
    _mockInterestRate(address(newIrStrategy), hub.getBaseInterestRate(daiAssetId) * 2);
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    config.irStrategy = address(newIrStrategy);
    _checkedUpdateAssetConfig(daiAssetId, config);

    skip(365 days);
    assertNotEq(hub.getSpokeSuppliedShares(daiAssetId, config.feeReceiver), futureFees);
  }

  function _checkedUpdateSpokeConfig(uint256 assetId, address spoke, DataTypes.SpokeConfig memory config) public {


    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(assetId, spoke, config);

    vm.prank(address(configurator));
    hub.updateSpokeConfig(assetId, spoke, config);

    assertEq(hub.getSpokeConfig(assetId, spoke).supplyCap, config.supplyCap, 'spokeConfig.supplyCap');
    assertEq(hub.getSpokeConfig(assetId, spoke).drawCap, config.drawCap, 'spokeConfig.drawCap');
  }

  function _processAssetConfig(uint256 assetId, DataTypes.AssetConfig memory newConfig) public {
    vm.assume(address(newConfig.irStrategy) != address(0));
    newConfig.liquidityFee = bound(
      newConfig.liquidityFee,
      0,
      PercentageMathExtended.PERCENTAGE_FACTOR
    );
    vm.assume(address(newConfig.feeReceiver) != address(0) || newConfig.liquidityFee == 0);

    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(assetId);
    if (oldConfig.feeReceiver != newConfig.feeReceiver) {
      if (oldConfig.feeReceiver != address(0)) {
        hub.updateSpokeConfig(
          assetId,
          oldConfig.feeReceiver,
          DataTypes.SpokeConfig({supplyCap: 0, drawCap: 0})
        );
      }
      if (newConfig.feeReceiver != address(0)) {
        DataTypes.SpokeData memory spokeData = hub.getSpoke(assetId, newConfig.feeReceiver);
        if (spokeData.lastUpdateTimestamp == 0) {
          hub.addSpoke(
            assetId,
            newConfig.feeReceiver,
            DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max})
          );
        } else {
          hub.updateSpokeConfig(
            assetId,
            newConfig.feeReceiver,
            DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max})
          );
        }
      }
    }
  }

  function _checkedAddAsset(address asset, uint8 decimals, address interestRateStrategy) internal {
    uint256 assetId = hub.assetCount();

    DataTypes.AssetConfig memory expectedConfig = DataTypes.AssetConfig({
      active: true,
      frozen: false,
      paused: false,
      feeReceiver: address(0),
      liquidityFee: 0,
      irStrategy: interestRateStrategy
    });

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetAdded(assetId, asset, decimals);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, expectedConfig);

    vm.prank(address(configurator));
    hub.addAsset(asset, decimals, interestRateStrategy);

    assertEq(hub.assetCount(), assetId + 1, 'asset count');
    assertEq(hub.getAsset(assetId).decimals, decimals, 'asset decimals');
    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function _checkedUpdateAssetConfig(
    uint256 assetId,
    DataTypes.AssetConfig memory config
  ) internal {
    // Always accrue first, based on old config
    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, config);

    vm.prank(address(configurator));
    hub.updateAssetConfig(assetId, config);

    assertEq(hub.getAssetConfig(assetId), config);
  }
}
