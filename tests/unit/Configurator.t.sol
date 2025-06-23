// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract ConfiguratorTest is LiquidityHubBase {
  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
    bool fetchErc20Decimals,
    address asset,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    vm.assume(asset != address(0) && interestRateStrategy != address(0));
    decimals = uint8(bound(decimals, hub.MAX_ALLOWED_ASSET_DECIMALS() + 1, type(uint8).max));

    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector, address(hub));
    _addAsset(fetchErc20Decimals, asset, decimals, interestRateStrategy);
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetAddress(
    bool fetchErc20Decimals,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    vm.expectRevert(ILiquidityHub.InvalidAssetAddress.selector, address(hub));
    _addAsset(fetchErc20Decimals, address(0), decimals, interestRateStrategy);
  }

  function test_addAsset_fuzz_revertsWith_InvalidIrStrategy(
    bool fetchErc20Decimals,
    address asset,
    uint8 decimals
  ) public {
    vm.assume(asset != address(0));
    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector, address(hub));

    _addAsset(fetchErc20Decimals, asset, decimals, address(0));
  }

  function test_addAsset_fuzz(
    bool fetchErc20Decimals,
    address asset,
    uint8 decimals,
    address interestRateStrategy
  ) public {
    vm.assume(asset != address(0) && interestRateStrategy != address(0));
    decimals = uint8(bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS()));
    _checkedAddAsset(fetchErc20Decimals, asset, decimals, interestRateStrategy);
  }

  function test_setActive_fuzz(uint256 assetId, bool active) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.active = active;

    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setActive, (address(hub), assetId, active)),
      expectedConfig
    );
  }

  function test_setPaused_fuzz(uint256 assetId, bool paused) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.paused = paused;

    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setPaused, (address(hub), assetId, paused)),
      expectedConfig
    );
  }

  function test_setFrozen_fuzz(uint256 assetId, bool frozen) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.frozen = frozen;

    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setFrozen, (address(hub), assetId, frozen)),
      expectedConfig
    );
  }

  function test_setLiquidityFee_fuzz_revertsWith_InvalidLiquidityFee(
    uint256 assetId,
    uint256 liquidityFee
  ) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    liquidityFee = bound(
      liquidityFee,
      PercentageMathExtended.PERCENTAGE_FACTOR + 1,
      type(uint256).max
    );

    vm.expectRevert(ILiquidityHub.InvalidLiquidityFee.selector);
    configurator.setLiquidityFee(address(hub), assetId, liquidityFee);
  }

  function test_setLiquidityFee_fuzz(uint256 assetId, uint256 liquidityFee) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    liquidityFee = bound(liquidityFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.liquidityFee = liquidityFee;

    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setLiquidityFee, (address(hub), assetId, liquidityFee)),
      expectedConfig
    );
  }

  /// Triggers accrual when liquidity fee update, based on old liquidity fee
  function test_setLiquidityFee_fuzz_Acrrual(uint256 assetId, uint256 liquidityFee) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    uint256 feeShares = hub.getSpokeSuppliedShares(assetId, config.feeReceiver);
    assertTrue(feeShares > 0, 'no fees');

    config.liquidityFee = liquidityFee;
    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setLiquidityFee, (address(hub), assetId, config.liquidityFee)),
      config
    );

    assertEq(hub.getSpokeSuppliedShares(assetId, config.feeReceiver), feeShares);
  }

  function test_setFeeReceiver_fuzz_revertsWith_InvalidFeeReceiver(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    assert(hub.getAssetConfig(assetId).liquidityFee != 0);

    vm.expectRevert(ILiquidityHub.InvalidFeeReceiver.selector);
    configurator.setFeeReceiver(address(hub), assetId, address(0));
  }

  function test_setFeeReceiver_revertsWith_InvalidFeeReceiver(uint256 assetId) public {
    test_setFeeReceiver_fuzz_revertsWith_InvalidFeeReceiver(daiAssetId);
  }

  function test_setFeeReceiver_fuzz(uint256 assetId, address feeReceiver) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    if (feeReceiver == address(0)) {
      test_setLiquidityFee_fuzz(assetId, 0);
    }

    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(assetId);
    if (feeReceiver != oldConfig.feeReceiver) {
      if (oldConfig.feeReceiver != address(0)) {
        vm.expectEmit(address(hub));
        emit ILiquidityHub.SpokeConfigUpdated(assetId, oldConfig.feeReceiver, 0, 0);
      }

      if (feeReceiver != address(0)) {
        vm.expectEmit(address(hub));
        if (hub.getSpoke(assetId, feeReceiver).lastUpdateTimestamp == 0) {
          emit ILiquidityHub.SpokeAdded(assetId, feeReceiver);
        }
        emit ILiquidityHub.SpokeConfigUpdated(
          assetId,
          feeReceiver,
          type(uint256).max,
          type(uint256).max
        );
      }
    }

    // same struct, renaming to expectedConfig
    DataTypes.AssetConfig memory expectedConfig = oldConfig;
    expectedConfig.feeReceiver = feeReceiver;

    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setFeeReceiver, (address(hub), assetId, feeReceiver)),
      expectedConfig
    );
  }

  function test_setFeeReceiver_Scenario() public {
    // set same fee receiver
    test_setFeeReceiver_fuzz(daiAssetId, address(treasurySpoke));
    // set new fee receiver
    test_setFeeReceiver_fuzz(daiAssetId, makeAddr('newFeeReceiver'));
    // set zero fee receiver
    test_setFeeReceiver_fuzz(daiAssetId, address(0));
    // set zero fee receiver again
    test_setFeeReceiver_fuzz(daiAssetId, address(0));
    // set initial fee receiver
    test_setFeeReceiver_fuzz(daiAssetId, address(treasurySpoke));
  }

  /// Updates to new fee receiver, with previously accrued fees not transferred to the new receiver
  function test_setFeeReceiver_fuzz_NewFeeReceiver(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    address oldFeeReceiver = config.feeReceiver;
    config.feeReceiver = makeAddr('newFeeReceiver');

    uint256 feesShares = hub.getSpokeSuppliedShares(assetId, oldFeeReceiver);
    assertTrue(feesShares > 0, 'no fees');

    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setFeeReceiver, (address(hub), assetId, config.feeReceiver)),
      config
    );

    assertEq(hub.getSpokeSuppliedShares(assetId, oldFeeReceiver), feesShares);
    assertEq(hub.getSpokeSuppliedShares(assetId, config.feeReceiver), 0);
  }

  /// Updates the fee receiver by reusing a previously assigned spoke, with no impact on accrued fees
  function test_setFeeReceiver_fuzz_ReuseFeeReceiver(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    test_setFeeReceiver_fuzz_NewFeeReceiver(assetId);

    address oldFeeReceiver = address(treasurySpoke);
    uint256 oldFees = hub.getSpokeSuppliedShares(assetId, oldFeeReceiver);

    skip(365 days);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    address newFeeReceiver = config.feeReceiver;

    uint256 newFees = hub.getSpokeSuppliedShares(assetId, newFeeReceiver);
    assertTrue(newFees > 0);

    config.feeReceiver = address(treasurySpoke);
    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setFeeReceiver, (address(hub), assetId, config.feeReceiver)),
      config
    );

    assertEq(hub.getSpokeSuppliedShares(assetId, config.feeReceiver), oldFees);
    assertEq(hub.getSpokeSuppliedShares(assetId, newFeeReceiver), newFees);
  }

  function test_setLiquidityFeeAndReceiver_fuzz_revertsWith_InvalidLiquidityFee(
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    liquidityFee = bound(
      liquidityFee,
      PercentageMathExtended.PERCENTAGE_FACTOR + 1,
      type(uint256).max
    );
    vm.assume(feeReceiver != address(0));

    vm.expectRevert(ILiquidityHub.InvalidLiquidityFee.selector);
    configurator.setLiquidityFeeAndReceiver(address(hub), assetId, liquidityFee, feeReceiver);
  }

  function test_setLiquidityFeeAndReceiver_fuzz_revertsWith_InvalidFeeReceiver(
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    liquidityFee = bound(liquidityFee, 1, PercentageMathExtended.PERCENTAGE_FACTOR);

    vm.expectRevert(ILiquidityHub.InvalidFeeReceiver.selector);
    configurator.setLiquidityFeeAndReceiver(address(hub), assetId, liquidityFee, address(0));
  }

  function test_setLiquidityFeeAndReceiver_fuzz(
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    if (feeReceiver == address(0)) {
      liquidityFee = 0;
    } else {
      liquidityFee = bound(liquidityFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);
    }

    DataTypes.AssetConfig memory oldConfig = hub.getAssetConfig(assetId);
    if (feeReceiver != oldConfig.feeReceiver) {
      if (oldConfig.feeReceiver != address(0)) {
        vm.expectEmit(address(hub));
        emit ILiquidityHub.SpokeConfigUpdated(assetId, oldConfig.feeReceiver, 0, 0);
      }

      if (feeReceiver != address(0)) {
        vm.expectEmit(address(hub));
        if (hub.getSpoke(assetId, feeReceiver).lastUpdateTimestamp == 0) {
          emit ILiquidityHub.SpokeAdded(assetId, feeReceiver);
        }
        emit ILiquidityHub.SpokeConfigUpdated(
          assetId,
          feeReceiver,
          type(uint256).max,
          type(uint256).max
        );
      }
    }

    // same struct, renaming to expectedConfig
    DataTypes.AssetConfig memory expectedConfig = oldConfig;
    expectedConfig.feeReceiver = feeReceiver;
    expectedConfig.liquidityFee = liquidityFee;

    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(
        IConfigurator.setLiquidityFeeAndReceiver,
        (address(hub), assetId, liquidityFee, feeReceiver)
      ),
      expectedConfig
    );
  }

  function test_setLiquidityFeeAndReceiver_Scenario() public {
    // set same fee receiver
    test_setLiquidityFeeAndReceiver_fuzz(daiAssetId, 18_00, address(treasurySpoke));
    // set new fee receiver and liquidity fee
    test_setLiquidityFeeAndReceiver_fuzz(daiAssetId, 4_00, makeAddr('newFeeReceiver'));
    // set zero fee receiver and fee
    test_setLiquidityFeeAndReceiver_fuzz(daiAssetId, 0, address(0));
    // set zero fee receiver and fee again
    test_setLiquidityFeeAndReceiver_fuzz(daiAssetId, 0, address(0));
    // set zero fee and initial fee receiver
    test_setLiquidityFeeAndReceiver_fuzz(daiAssetId, 0, address(treasurySpoke));
  }

  /// Updates the fee receiver from zero to non-zero, even with zero liquidity fee
  function test_setLiquidityFeeAndReceiver_fuzz_FromZeroFeeReceiver(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.feeReceiver = address(0);
    config.liquidityFee = 0;
    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(
        IConfigurator.setLiquidityFeeAndReceiver,
        (address(hub), assetId, config.liquidityFee, config.feeReceiver)
      ),
      config
    );

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    config.feeReceiver = makeAddr('newFeeReceiver');
    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setFeeReceiver, (address(hub), assetId, config.feeReceiver)),
      config
    );

    assertEq(hub.getSpokeSuppliedShares(assetId, config.feeReceiver), 0);
  }

  /// No fees accrued whe updating liquidity fee from zero to non-zero
  function test_setLiquidityFeeAndReceiver_fuzz_FromZeroLiquidityFee(
    uint256 assetId,
    uint256 liquidityFee
  ) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    liquidityFee = bound(liquidityFee, 1, PercentageMath.PERCENTAGE_FACTOR);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.feeReceiver = address(0);
    config.liquidityFee = 0;
    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(
        IConfigurator.setLiquidityFeeAndReceiver,
        (address(hub), assetId, config.liquidityFee, config.feeReceiver)
      ),
      config
    );

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    config.liquidityFee = liquidityFee;
    config.feeReceiver = makeAddr('feeReceiver');
    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(
        IConfigurator.setLiquidityFeeAndReceiver,
        (address(hub), assetId, config.liquidityFee, config.feeReceiver)
      ),
      config
    );

    assertEq(hub.getSpokeSuppliedShares(assetId, address(0)), 0);
    assertEq(hub.getSpokeSuppliedShares(assetId, config.feeReceiver), 0);
  }

  function test_setInterestRateStrategy_fuzz_revertsWith_InvalidIrStrategy(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    configurator.setInterestRateStrategy(address(hub), assetId, address(0));
  }

  function test_setInterestRateStrategy_fuzz_revertsWith_InterestRateStrategyReverts(uint256 assetId, address interestRateStrategy) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    vm.assume(interestRateStrategy != address(irStrategy) && interestRateStrategy > address(0x0a));

    vm.expectRevert();
    configurator.setInterestRateStrategy(address(hub), assetId, interestRateStrategy);
  }

  function test_setInterestRateStrategy_fuzz(uint256 assetId, address interestRateStrategy) public {
    vm.assume(interestRateStrategy != address(0) && interestRateStrategy != address(Utils.vm));
    
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.irStrategy = interestRateStrategy;
    _mockInterestRate(interestRateStrategy, 5_00);

    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setInterestRateStrategy, (address(hub), assetId, interestRateStrategy)),
      expectedConfig
    );
  }

  /// Triggers accrual when interest rate strategy is updated, based on old strategy
  /// Also makes sure that the base borrow rate is updated after accrual
  function test_setInterestRateStrategy_fuzz_NewInterestRateStrategy(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    uint256 fees = hub.getSpokeSuppliedShares(assetId, address(treasurySpoke));
    assertTrue(fees > 0, 'no fees');

    skip(365 days);
    uint256 futureFees = hub.getSpokeSuppliedShares(assetId, address(treasurySpoke));
    rewind(365 days);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    address newIrStrategy = config.irStrategy;

    config.irStrategy = address(newIrStrategy);
    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setInterestRateStrategy, (address(hub), assetId, newIrStrategy)),
      config
    );

    skip(365 days);
    assertNotEq(hub.getSpokeSuppliedShares(assetId, config.feeReceiver), futureFees);
  }

  function _checkedAddAsset(
    bool fetchErc20Decimals,
    address asset,
    uint8 decimals,
    address interestRateStrategy
  ) internal {
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

    assertEq(_addAsset(fetchErc20Decimals, asset, decimals, interestRateStrategy), assetId);

    assertEq(hub.assetCount(), assetId + 1, 'asset count');
    assertEq(hub.getAssetDecimals(assetId), decimals, 'asset decimals');
    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }

  function _addAsset(
    bool fetchErc20Decimals,
    address asset,
    uint8 decimals,
    address interestRateStrategy
  ) internal returns (uint256) {
    if (fetchErc20Decimals) {
      _mockDecimals(asset, decimals);
      return configurator.addAsset(address(hub), asset, interestRateStrategy);
    } else {
      return configurator.addAsset(address(hub), asset, decimals, interestRateStrategy);
    }
  }

  function _checkedUpdateAssetConfig(
    uint256 assetId,
    bytes memory configuratorCalldata,
    DataTypes.AssetConfig memory expectedConfig
  ) internal {
    // Always accrue first, based on old config
    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, expectedConfig);

    (bool success, bytes memory returnData) = address(configurator).call(configuratorCalldata);
    assertTrue(success);
    assertEq(returnData.length, 0);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }
}
