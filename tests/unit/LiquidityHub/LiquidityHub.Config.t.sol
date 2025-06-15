// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubConfigTest is LiquidityHubBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function test_addSpoke() public {
    uint256 assetId = hub.getAssetCount() - 1;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, address(spoke1));
    vm.prank(HUB_ADMIN);
    hub.addSpoke(assetId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(spoke1));

    DataTypes.SpokeConfig memory spokeData = hub.getSpokeConfig(assetId, address(spoke1));
    assertEq(spokeData.supplyCap, 1, 'spoke supply cap');
    assertEq(spokeData.drawCap, 1, 'spoke draw cap');
  }

  function test_addSpoke_fuzz(DataTypes.SpokeConfig calldata spokeConfig) public {
    uint256 assetId = hub.getAssetCount() - 1;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, address(spoke1));
    vm.prank(HUB_ADMIN);
    hub.addSpoke(assetId, spokeConfig, address(spoke1));

    DataTypes.SpokeConfig memory spokeData = hub.getSpokeConfig(assetId, address(spoke1));
    assertEq(spokeData.supplyCap, spokeConfig.supplyCap, 'spoke supply cap');
    assertEq(spokeData.drawCap, spokeConfig.drawCap, 'spoke draw cap');
  }

  function test_addSpoke_revertsWith_InvalidSpoke() public {
    uint256 assetId = hub.getAssetCount();
    address invalidSpokeAddress = address(0);

    vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
    vm.prank(HUB_ADMIN);
    hub.addSpoke(assetId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), invalidSpokeAddress);
  }

  function test_addSpokes() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig memory daiSpokeConfig = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
    DataTypes.SpokeConfig memory wethSpokeConfig = DataTypes.SpokeConfig({
      supplyCap: 3,
      drawCap: 4
    });

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = daiSpokeConfig;
    spokeConfigs[1] = wethSpokeConfig;

    vm.prank(HUB_ADMIN);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(daiAssetId, address(spoke1));
    emit ILiquidityHub.SpokeAdded(wethAssetId, address(spoke1));
    hub.addSpokes(assetIds, spokeConfigs, address(spoke1));

    DataTypes.SpokeConfig memory daiSpokeData = hub.getSpokeConfig(daiAssetId, address(spoke1));
    DataTypes.SpokeConfig memory wethSpokeData = hub.getSpokeConfig(wethAssetId, address(spoke1));

    assertEq(daiSpokeData.supplyCap, daiSpokeConfig.supplyCap, 'dai spoke supply cap');
    assertEq(daiSpokeData.drawCap, daiSpokeConfig.drawCap, 'dai spoke draw cap');

    assertEq(wethSpokeData.supplyCap, wethSpokeConfig.supplyCap, 'eth spoke supply cap');
    assertEq(wethSpokeData.drawCap, wethSpokeConfig.drawCap, 'eth spoke draw cap');
  }

  function test_addSpokes_revertsWith_InvalidSpoke() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
    spokeConfigs[1] = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

    vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
    vm.prank(HUB_ADMIN);
    hub.addSpokes(assetIds, spokeConfigs, address(0));
  }

  function test_updateSpokeConfig_drawCap() public {
    DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));
    uint256 drawCap = 5;
    assertNotEq(config.drawCap, drawCap);

    config.drawCap = drawCap;

    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(daiAssetId, address(spoke1), config);

    assertEq(hub.getSpokeConfig(daiAssetId, address(spoke1)).drawCap, drawCap, 'asset drawCap');
  }

  function test_updateSpokeConfig_fuzz_drawCap(uint256 drawCap) public {
    DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));
    vm.assume(config.drawCap != drawCap);

    config.drawCap = drawCap;

    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(daiAssetId, address(spoke1), config);

    assertEq(hub.getSpokeConfig(daiAssetId, address(spoke1)).drawCap, drawCap, 'asset drawCap');
  }

  function test_updateSpokeConfig_supplyCap() public {
    DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));
    uint256 supplyCap = 5;
    assertNotEq(config.supplyCap, supplyCap);

    config.supplyCap = supplyCap;

    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(daiAssetId, address(spoke1), config);

    assertEq(
      hub.getSpokeConfig(daiAssetId, address(spoke1)).supplyCap,
      supplyCap,
      'asset supplyCap'
    );
  }

  function test_updateSpokeConfig_fuzz_supplyCap(uint256 supplyCap) public {
    DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));
    vm.assume(config.supplyCap != supplyCap);

    config.supplyCap = supplyCap;

    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(daiAssetId, address(spoke1), config);

    assertEq(
      hub.getSpokeConfig(daiAssetId, address(spoke1)).supplyCap,
      supplyCap,
      'asset supplyCap'
    );
  }

  function test_updateSpokeConfig_emit() public {
    DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));

    vm.prank(HUB_ADMIN);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(
      daiAssetId,
      address(spoke1),
      config.drawCap,
      config.supplyCap
    );
    hub.updateSpokeConfig(daiAssetId, address(spoke1), config);
  }

  function test_addAsset_fuzz(
    address asset,
    uint256 decimals,
    address interestRateStrategy
  ) public {
    vm.assume(asset != address(0) && interestRateStrategy != address(0));
    decimals = bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS());
    _checkedAddAsset(hub, asset, decimals, interestRateStrategy);
  }

  function test_addAsset() public {
    test_addAsset_fuzz(address(tokenList.dai), 18, address(irStrategy));
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
    address asset,
    uint256 decimals,
    address interestRateStrategy
  ) public {
    vm.assume(asset != address(0) && interestRateStrategy != address(0));

    decimals = bound(decimals, hub.MAX_ALLOWED_ASSET_DECIMALS() + 1, type(uint8).max);
    _mockDecimals(asset, decimals);

    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector);

    vm.prank(address(configurator));
    hub.addAsset(asset, interestRateStrategy);
  }

  function test_addAsset_revertsWith_InvalidAssetDecimals() public {
    test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
      address(tokenList.dai),
      hub.MAX_ALLOWED_ASSET_DECIMALS() + 1,
      address(irStrategy)
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetAddress(address interestRateStrategy) public {
    vm.assume(interestRateStrategy != address(0));

    vm.expectRevert(ILiquidityHub.InvalidAssetAddress.selector);

    vm.prank(address(configurator));
    hub.addAsset(address(0), interestRateStrategy);
  }

  function test_addAsset_revertsWith_InvalidAssetAddress() public {
    test_addAsset_fuzz_revertsWith_InvalidAssetAddress(address(irStrategy));
  }

  function test_addAsset_fuzz_revertsWith_InvalidIrStrategy(
    address asset,
    uint256 decimals
  ) public {
    vm.assume(asset != address(0));

    decimals = bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS());
    _mockDecimals(asset, decimals);

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);

    vm.prank(address(configurator));
    hub.addAsset(asset, address(0));
  }

  function test_addAsset_revertsWith_InvalidIrStrategy() public {
    test_addAsset_fuzz_revertsWith_InvalidIrStrategy(address(tokenList.dai), 18);
  }

  function test_updateAssetFlags_fuzz_paused(bool paused) public {
    _checkedUpdateAssetPaused(hub, daiAssetId, paused);
  }

  function test_updateAssetFlags_paused() public {
    assertEq(hub.getAssetConfig(daiAssetId).paused, false, 'asset not paused');
    _checkedUpdateAssetPaused(hub, daiAssetId, true);
    _checkedUpdateAssetPaused(hub, daiAssetId, false);
  }

  function test_updateAssetFlags_fuzz_frozen(bool frozen) public {
    _checkedUpdateAssetFrozen(hub, daiAssetId, frozen);
  }

  function test_updateAssetFlags_frozen() public {
    assertEq(hub.getAssetConfig(daiAssetId).frozen, false, 'asset not frozen');
    _checkedUpdateAssetFrozen(hub, daiAssetId, true);
    _checkedUpdateAssetFrozen(hub, daiAssetId, false);
  }

  function test_updateAssetFlags_fuzz_active(bool active) public {
    _checkedUpdateAssetActive(hub, daiAssetId, active);
  }

  function test_updateAssetFlags_active() public {
    assertEq(hub.getAssetConfig(daiAssetId).active, true, 'asset active');
    _checkedUpdateAssetActive(hub, daiAssetId, false);
    _checkedUpdateAssetActive(hub, daiAssetId, true);
  }

  function test_updateReserveFactor_fuzz_revertsWith_InvalidReserveFactor(
    uint256 assetId,
    uint256 newReserveFactor
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    newReserveFactor = bound(
      newReserveFactor,
      PercentageMath.PERCENTAGE_FACTOR + 1,
      type(uint256).max
    );
    vm.expectRevert(ILiquidityHub.InvalidReserveFactor.selector);
    hub.updateReserveFactor(assetId, newReserveFactor);
  }

  function test_updateReserveFactor_revertsWith_InvalidReserveFactor() public {
    test_updateReserveFactor_fuzz_revertsWith_InvalidReserveFactor(daiAssetId, 101_00);
  }

  function test_updateReserveFactor_fuzz(uint256 assetId, uint256 newReserveFactor) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    newReserveFactor = bound(newReserveFactor, 0, PercentageMath.PERCENTAGE_FACTOR);
    _checkedUpdateReserveFactor(hub, assetId, newReserveFactor);
  }

  function test_updateReserveFactor() public {
    test_updateReserveFactor_fuzz(daiAssetId, 2_00);
  }

  function test_updateInterestRateStrategy_fuzz_revertsWith_InvalidIrStrategy(
    uint256 assetId
  ) public {
    assetId = bound(assetId, 0, hub.getAssetCount() - 1);
    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    hub.updateInterestRateStrategy(assetId, address(0));
  }

  function test_updateInterestRateStrategy_revertsWith_InvalidIrStrategy() public {
    test_updateInterestRateStrategy_fuzz_revertsWith_InvalidIrStrategy(daiAssetId);
  }

  function test_updateInterestRateStrategy_fuzz(address newIrStrategy) public {
    vm.assume(newIrStrategy != address(0));
    _checkedUpdateInterestRateStrategy(hub, daiAssetId, newIrStrategy);
  }

  function test_updateInterestRateStrategy() public {
    address newIrStrategy = makeAddr('newIrStrategy');
    test_updateInterestRateStrategy_fuzz(newIrStrategy);
  }

  function _checkedUpdateAssetActive(ILiquidityHub hub, uint256 assetId, bool active) internal {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.active = active;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, config);

    vm.prank(address(configurator));
    hub.updateAssetFlags({
      assetId: assetId,
      active: active,
      paused: config.paused,
      frozen: config.frozen
    });

    assertEq(hub.getAssetConfig(assetId).active, active, 'asset active status');
  }

  function _checkedUpdateAssetPaused(ILiquidityHub hub, uint256 assetId, bool paused) internal {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.paused = paused;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, config);

    vm.prank(address(configurator));
    hub.updateAssetFlags({
      assetId: assetId,
      active: config.active,
      paused: paused,
      frozen: config.frozen
    });

    assertEq(hub.getAssetConfig(assetId).paused, paused, 'asset paused status');
  }

  function _checkedUpdateAssetFrozen(ILiquidityHub hub, uint256 assetId, bool frozen) internal {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.frozen = frozen;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, config);

    vm.prank(address(configurator));
    hub.updateAssetFlags({
      assetId: assetId,
      active: config.active,
      paused: config.paused,
      frozen: frozen
    });

    assertEq(hub.getAssetConfig(assetId).frozen, frozen, 'asset frozen status');
  }

  function _checkedUpdateReserveFactor(
    ILiquidityHub hub,
    uint256 assetId,
    uint256 reserveFactor
  ) internal {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.reserveFactor = reserveFactor;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, config);

    vm.prank(address(configurator));
    hub.updateReserveFactor(assetId, reserveFactor);

    assertEq(hub.getAssetConfig(assetId).reserveFactor, reserveFactor, 'asset reserveFactor');
  }

  function _checkedUpdateInterestRateStrategy(
    ILiquidityHub hub,
    uint256 assetId,
    address interestRateStrategy
  ) internal {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    config.irStrategy = IReserveInterestRateStrategy(interestRateStrategy);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(assetId, config);

    vm.prank(address(configurator));
    hub.updateInterestRateStrategy(assetId, interestRateStrategy);

    assertEq(
      address(hub.getAssetConfig(assetId).irStrategy),
      interestRateStrategy,
      'asset irStrategy'
    );
  }

  function _checkedAddAsset(
    ILiquidityHub hub,
    address asset,
    uint256 decimals,
    address interestRateStrategy
  ) internal {
    _mockDecimals(asset, decimals);

    uint256 assetId = hub.getAssetCount();

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetAdded(assetId, asset);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(
      hub.getAssetCount(),
      DataTypes.AssetConfig({
        decimals: decimals,
        active: true,
        frozen: false,
        paused: false,
        reserveFactor: 0,
        irStrategy: IReserveInterestRateStrategy(interestRateStrategy)
      })
    );

    vm.prank(address(configurator));
    hub.addAsset(asset, interestRateStrategy);

    assertEq(hub.getAssetCount(), assetId + 1, 'asset count');
    assertEq(hub.getAssetConfig(assetId).decimals, decimals, 'asset decimals');
    assertEq(hub.getAssetConfig(assetId).active, true, 'asset active');
    assertEq(hub.getAssetConfig(assetId).frozen, false, 'asset frozen');
    assertEq(hub.getAssetConfig(assetId).paused, false, 'asset paused');
    assertEq(
      address(hub.getAssetConfig(assetId).irStrategy),
      interestRateStrategy,
      'asset irStrategy'
    );
  }

  function _mockDecimals(address asset, uint256 decimals) internal {
    vm.mockCall(
      asset,
      abi.encodeWithSelector(IERC20Metadata.decimals.selector),
      abi.encode(decimals)
    );
  }
}
