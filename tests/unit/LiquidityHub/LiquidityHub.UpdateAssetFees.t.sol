// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubUpdateAssetFeesTest is LiquidityHubBase {
  /// Triggers accrual always, based on old config
  function test_updateAssetFees_fuzz_always_accrue(
    address feeReceiver,
    uint256 liquidityFee
  ) public {
    liquidityFee = bound(liquidityFee, 1, PercentageMathExtended.PERCENTAGE_FACTOR);
    vm.assume(feeReceiver != address(0));

    uint256 assetId = daiAssetId;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    hub.updateAssetFees(assetId, feeReceiver, liquidityFee);
  }

  /// Triggers accrual always with zero liquidityFee, based on old config
  function test_updateAssetFees_fuzz_always_accrue_withZeroLiquidityFee(
    address feeReceiver
  ) public {
    vm.assume(feeReceiver != address(0));
    uint256 liquidityFee = 0;

    uint256 assetId = daiAssetId;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    hub.updateAssetFees(assetId, feeReceiver, liquidityFee);
  }

  /// Fee receiver cannot be zero if liquidity fee is non-zero
  function test_updateAssetFees_revertsWith_InvalidFeeReceiver() public {
    uint256 assetId = daiAssetId;

    // reverts if zero receiver and non-zero fee
    uint256 nonZeroFee = randomizer(1, PercentageMathExtended.PERCENTAGE_FACTOR);
    vm.expectRevert(ILiquidityHub.InvalidFeeReceiver.selector);
    hub.updateAssetFees(assetId, address(0), nonZeroFee);

    // reverts if zero receiver and non-zero current fee
    uint256 currentLiquidityFee = _getLiquidityFee(assetId);
    vm.expectRevert(ILiquidityHub.InvalidFeeReceiver.selector);
    hub.updateAssetFees(assetId, address(0), currentLiquidityFee);
  }

  /// Liquidity fee cannot be above maximum
  function test_updateAssetFees_revertsWith_InvalidLiquidityFee() public {
    uint256 assetId = daiAssetId;
    address validReceiver = makeAddr('validFeeReceiver');

    uint256 invalidFee = randomizer(PercentageMathExtended.PERCENTAGE_FACTOR, type(uint256).max);
    vm.expectRevert(ILiquidityHub.InvalidLiquidityFee.selector);
    hub.updateAssetFees(assetId, validReceiver, invalidFee);
  }

  /// Triggers accrual always, even if no config change
  function test_updateAssetFees_noChange() public {
    uint256 assetId = daiAssetId;

    address currentFeeReceiver = _getFeeReceiver(assetId);
    uint256 currentLiquidityFee = _getLiquidityFee(assetId);

    // todo: AssetConfigUpdated not emitted

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    hub.updateAssetFees(assetId, currentFeeReceiver, currentLiquidityFee);
  }

  /// Triggers accrual when fee receiver update, with previously accrued fees not transferred to the new fee receiver.
  function test_updateAssetFees_update_feeReceiver() public {
    uint256 assetId = daiAssetId;

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    uint256 currentLiquidityFee = _getLiquidityFee(assetId);
    address currentFeeReceiver = _getFeeReceiver(assetId);
    address newFeeReceiver = makeAddr('newFeeReceiver');

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.feeReceiver = newFeeReceiver;

    uint256 feesShares = hub.getSpokeSuppliedShares(assetId, currentFeeReceiver);
    assertTrue(feesShares > 0, 'no fees');

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(assetId, currentFeeReceiver, 0, 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, newFeeReceiver);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, expectedConfig);

    hub.updateAssetFees(assetId, newFeeReceiver, currentLiquidityFee);

    assertEq(hub.getSpokeSuppliedShares(assetId, currentFeeReceiver), feesShares);
    assertEq(hub.getSpokeSuppliedShares(assetId, newFeeReceiver), 0);
    assertEq(_getFeeReceiver(assetId), newFeeReceiver);
  }

  /// Updates the fee receiver by reusing a previously assigned spoke, with no impact on accrued fees
  function test_updateAssetFees_update_feeReceiver_reuse() public {
    uint256 assetId = daiAssetId;

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    uint256 currentLiquidityFee = _getLiquidityFee(assetId);
    address currentFeeReceiver = _getFeeReceiver(assetId);
    address newFeeReceiver = makeAddr('newFeeReceiver');

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.feeReceiver = newFeeReceiver;

    uint256 currentFees = hub.getSpokeSuppliedShares(assetId, currentFeeReceiver);
    assertTrue(currentFees > 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(assetId, currentFeeReceiver, 0, 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, newFeeReceiver);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, expectedConfig);

    hub.updateAssetFees(assetId, newFeeReceiver, currentLiquidityFee);

    assertEq(hub.getSpokeSuppliedShares(assetId, currentFeeReceiver), currentFees);
    assertEq(hub.getSpokeSuppliedShares(assetId, newFeeReceiver), 0);
    assertEq(_getFeeReceiver(assetId), newFeeReceiver);

    skip(365 days);

    expectedConfig.feeReceiver = currentFeeReceiver;

    uint256 newFees = hub.getSpokeSuppliedShares(assetId, newFeeReceiver);
    assertTrue(newFees > 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(assetId, newFeeReceiver, 0, 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(
      assetId,
      currentFeeReceiver,
      type(uint256).max,
      type(uint256).max
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, expectedConfig);

    // treasury is set back to original spoke
    hub.updateAssetFees(assetId, currentFeeReceiver, currentLiquidityFee);

    assertEq(hub.getSpokeSuppliedShares(assetId, currentFeeReceiver), currentFees);
    assertEq(hub.getSpokeSuppliedShares(assetId, newFeeReceiver), newFees);
    assertEq(_getFeeReceiver(assetId), currentFeeReceiver);
  }

  /// Updates the fee receiver from zero to non-zero, even with zero liquidity fee
  function test_updateAssetFees_update_feeReceiver_fromZero() public {
    uint256 assetId = daiAssetId;

    // set receiver and fee to 0
    hub.updateAssetFees(assetId, address(0), 0);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    address newFeeReceiver = makeAddr('newFeeReceiver');

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.feeReceiver = newFeeReceiver;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, newFeeReceiver);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, expectedConfig);

    hub.updateAssetFees(assetId, newFeeReceiver, _getLiquidityFee(assetId));

    assertEq(hub.getSpokeSuppliedShares(assetId, newFeeReceiver), 0);
    assertEq(_getFeeReceiver(assetId), newFeeReceiver);
  }

  /// Triggers accrual when liquidity fee update, based on old liquidity fee
  function test_updateAssetFees_update_liquidityFee(uint256 liquidityFee) public {
    liquidityFee = bound(liquidityFee, 1, PercentageMathExtended.PERCENTAGE_FACTOR);

    uint256 assetId = daiAssetId;

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    uint256 currentLiquidityFee = _getLiquidityFee(assetId);
    address currentFeeReceiver = _getFeeReceiver(assetId);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);

    uint256 feesShares = hub.getSpokeSuppliedShares(assetId, currentFeeReceiver);
    assertTrue(feesShares > 0, 'no fees');

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    if (currentLiquidityFee != liquidityFee) {
      expectedConfig.liquidityFee = liquidityFee;
      vm.expectEmit(address(hub));
      emit ILiquidityHub.AssetConfigUpdated(assetId, expectedConfig);
    }

    hub.updateAssetFees(assetId, currentFeeReceiver, liquidityFee);

    assertEq(hub.getSpokeSuppliedShares(assetId, currentFeeReceiver), feesShares);
    assertEq(_getLiquidityFee(assetId), liquidityFee);
  }

  /// No fees accrued whe updating liquidity fee from zero to non-zero
  function test_updateAssetFees_update_liquidityFee_fromZero(uint256 liquidityFee) public {
    liquidityFee = bound(liquidityFee, 1, PercentageMathExtended.PERCENTAGE_FACTOR);

    uint256 assetId = daiAssetId;
    // set receiver and fee to 0
    hub.updateAssetFees(assetId, address(0), 0);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    uint256 currentLiquidityFee = _getLiquidityFee(assetId);
    address currentFeeReceiver = _getFeeReceiver(assetId);
    address validFeeReceiver = makeAddr('feeReceiver');

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.liquidityFee = liquidityFee;
    expectedConfig.feeReceiver = validFeeReceiver;

    assertEq(hub.getSpokeSuppliedShares(assetId, currentFeeReceiver), 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, expectedConfig);

    hub.updateAssetFees(assetId, validFeeReceiver, liquidityFee);

    assertEq(hub.getSpokeSuppliedShares(assetId, currentFeeReceiver), 0);
    assertEq(hub.getSpokeSuppliedShares(assetId, validFeeReceiver), 0);
    assertEq(_getLiquidityFee(assetId), liquidityFee);
  }
}
