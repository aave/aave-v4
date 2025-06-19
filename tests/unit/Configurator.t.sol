// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import 'tests/Base.t.sol';

contract ConfiguratorTest is Base {
  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

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
    // set new fee receiver
    test_setLiquidityFeeAndReceiver_fuzz(daiAssetId, 4_00, makeAddr('newFeeReceiver'));
    // set zero fee receiver and fee
    test_setLiquidityFeeAndReceiver_fuzz(daiAssetId, 0, address(0));
    // set zero fee receiver and fee again
    test_setLiquidityFeeAndReceiver_fuzz(daiAssetId, 0, address(0));
    // set zero fee and initial fee receiver
    test_setLiquidityFeeAndReceiver_fuzz(daiAssetId, 0, address(treasurySpoke));
  }

  function test_setInterestRateStrategy_fuzz_revertsWith_InvalidIrStrategy(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    configurator.setInterestRateStrategy(address(hub), assetId, address(0));
  }

  function test_setInterestRateStrategy_fuzz(uint256 assetId, address irStrategy) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    DataTypes.AssetConfig memory expectedConfig = hub.getAssetConfig(assetId);
    expectedConfig.irStrategy = IBasicInterestRateStrategy(irStrategy);

    _checkedUpdateAssetConfig(
      assetId,
      abi.encodeCall(IConfigurator.setInterestRateStrategy, (address(hub), assetId, irStrategy)),
      expectedConfig
    );
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
      irStrategy: IBasicInterestRateStrategy(interestRateStrategy)
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

  function _mockDecimals(address asset, uint8 decimals) internal {
    vm.mockCall(
      asset,
      abi.encodeWithSelector(IERC20Metadata.decimals.selector),
      abi.encode(decimals)
    );
  }

  function _checkedUpdateAssetConfig(
    uint256 assetId,
    bytes memory configuratorCalldata,
    DataTypes.AssetConfig memory expectedConfig
  ) internal {
    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, expectedConfig);

    (bool success, bytes memory returnData) = address(configurator).call(configuratorCalldata);
    assertTrue(success);
    assertEq(returnData.length, 0);

    assertEq(hub.getAssetConfig(assetId), expectedConfig);
  }
}
