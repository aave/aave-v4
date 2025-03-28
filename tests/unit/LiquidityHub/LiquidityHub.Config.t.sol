// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubConfigTest is LiquidityHubBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function test_addSpoke() public {
    uint256 assetId = hub.assetCount() - 1;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, address(spoke1));
    vm.prank(HUB_ADMIN);
    hub.addSpoke(assetId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(spoke1));

    DataTypes.SpokeConfig memory spokeData = hub.getSpokeConfig(assetId, address(spoke1));
    assertEq(spokeData.supplyCap, 1, 'spoke supply cap');
    assertEq(spokeData.drawCap, 1, 'spoke draw cap');
  }

  function test_addSpoke_fuzz(DataTypes.SpokeConfig calldata spokeConfig) public {
    uint256 assetId = hub.assetCount() - 1;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, address(spoke1));
    vm.prank(HUB_ADMIN);
    hub.addSpoke(assetId, spokeConfig, address(spoke1));

    DataTypes.SpokeConfig memory spokeData = hub.getSpokeConfig(assetId, address(spoke1));
    assertEq(spokeData.supplyCap, spokeConfig.supplyCap, 'spoke supply cap');
    assertEq(spokeData.drawCap, spokeConfig.drawCap, 'spoke draw cap');
  }

  function test_addSpoke_revertsWith_InvalidSpoke() public {
    uint256 assetId = hub.assetCount();
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

  function test_updateAssetConfig_paused() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    assertEq(config.paused, false);

    config.paused = true;

    hub.updateAssetConfig(daiAssetId, config);
    vm.prank(HUB_ADMIN);
    assertEq(hub.getAssetConfig(daiAssetId).paused, true, 'asset paused');

    config.paused = false;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).paused, false, 'asset un-paused');
  }

  function test_updateAssetConfig_fuzz_paused(bool paused) public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    config.paused = paused;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).paused, paused, 'asset paused');
  }

  function test_updateAssetConfig_frozen() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    assertEq(config.frozen, false);

    config.frozen = true;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).frozen, true, 'asset frozen');

    config.frozen = false;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).frozen, false, 'asset un-frozen');
  }

  function test_updateAssetConfig_fuzz_frozen(bool frozen) public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    config.frozen = frozen;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).frozen, frozen, 'asset frozen');
  }

  function test_updateAssetConfig_active() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    assertEq(config.active, true);

    config.active = false;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).active, false, 'asset not active');

    config.active = true;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).active, true, 'asset active');
  }

  function test_updateAssetConfig_fuzz_active(bool active) public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    config.active = active;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).active, active, 'asset active');
  }

  function test_updateAssetConfig_decimals() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    uint256 newDecimals = 12;
    assertLe(newDecimals, hub.MAX_ALLOWED_ASSET_DECIMALS());
    assertNotEq(config.decimals, newDecimals);

    config.decimals = newDecimals;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);

    assertEq(hub.getAssetConfig(daiAssetId).decimals, newDecimals, 'asset decimals');
  }

  function test_updateAssetConfig_fuzz_decimals(uint256 newDecimals) public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    newDecimals = bound(newDecimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS());
    vm.assume(newDecimals != config.decimals);
    assertNotEq(config.decimals, newDecimals);

    config.decimals = newDecimals;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);

    assertEq(hub.getAssetConfig(daiAssetId).decimals, newDecimals, 'asset decimals');
  }

  function test_updateAssetConfig_fuzz_decimals_revertsWith_InvalidAssetDecimals(
    uint256 assetId
  ) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    uint256 newDecimals = hub.MAX_ALLOWED_ASSET_DECIMALS() + 1; // invalid decimals
    assertNotEq(config.decimals, newDecimals);

    config.decimals = newDecimals;

    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector);
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, config);
  }

  function test_updateAssetConfig_decimals_revertsWith_InvalidAssetDecimals() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    uint256 newDecimals = hub.MAX_ALLOWED_ASSET_DECIMALS() + 1; // invalid decimals
    assertNotEq(config.decimals, newDecimals);

    config.decimals = newDecimals;

    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector);
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);
  }

  function test_updateAssetConfig_revertsWith_InvalidIrStrategy() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);

    config.irStrategy = IReserveInterestRateStrategy(address(0));

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);
  }

  function test_updateAssetConfig_fuzz_revertsWith_InvalidIrStrategy(uint256 assetId) public {
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);

    config.irStrategy = IReserveInterestRateStrategy(address(0));

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(assetId, config);
  }

  function test_updateAssetConfig_irStrategy() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    IReserveInterestRateStrategy newIrStrategy = IReserveInterestRateStrategy(
      makeAddr('newIrStrategy')
    );
    assertNotEq(address(config.irStrategy), address(newIrStrategy));

    config.irStrategy = newIrStrategy;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);

    assertEq(
      address(hub.getAssetConfig(daiAssetId).irStrategy),
      address(newIrStrategy),
      'asset irStrategy'
    );
  }

  function test_updateAssetConfig_fuzz_irStrategy(
    IReserveInterestRateStrategy newIrStrategy
  ) public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    vm.assume(address(newIrStrategy) != address(0) && newIrStrategy != config.irStrategy);

    config.irStrategy = newIrStrategy;

    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, config);

    assertEq(
      address(hub.getAssetConfig(daiAssetId).irStrategy),
      address(newIrStrategy),
      'asset irStrategy'
    );
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

  function test_addAsset() public {
    vm.prank(HUB_ADMIN);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetAdded(hub.assetCount(), address(tokenList.dai));
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: 18,
        active: true,
        frozen: false,
        paused: false,
        irStrategy: irStrategy
      }),
      address(tokenList.dai)
    );

    uint256 assetId = hub.assetCount() - 1;
    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    assertEq(config.decimals, 18, 'asset decimals');
    assertEq(config.active, true, 'asset active');
    assertEq(config.frozen, false, 'asset frozen');
    assertEq(config.paused, false, 'asset paused');
    assertEq(address(config.irStrategy), address(irStrategy), 'asset irStrategy');
  }

  function test_addAsset_fuzz(DataTypes.AssetConfig memory newConfig, address asset) public {
    newConfig.decimals = bound(newConfig.decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS());
    vm.assume(address(newConfig.irStrategy) != address(0) && asset != address(0));

    vm.prank(HUB_ADMIN);
    hub.addAsset(newConfig, asset);

    uint256 assetId = hub.assetCount() - 1;
    DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
    assertEq(config.decimals, newConfig.decimals, 'asset decimals');
    assertEq(config.active, newConfig.active, 'asset active');
    assertEq(config.frozen, newConfig.frozen, 'asset frozen');
    assertEq(config.paused, newConfig.paused, 'asset paused');
    assertEq(address(config.irStrategy), address(newConfig.irStrategy), 'asset irStrategy');
  }

  function test_addAsset_revertsWith_InvalidAssetDecimals() public {
    uint256 invalidDecimals = hub.MAX_ALLOWED_ASSET_DECIMALS() + 1;
    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector);
    vm.prank(HUB_ADMIN);
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: invalidDecimals,
        active: true,
        frozen: false,
        paused: false,
        irStrategy: irStrategy
      }),
      address(tokenList.dai)
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetDecimals(
    bool active,
    bool frozen,
    bool paused,
    IReserveInterestRateStrategy irStrategy
  ) public {
    uint256 invalidDecimals = hub.MAX_ALLOWED_ASSET_DECIMALS() + 1;
    vm.assume(address(irStrategy) != address(0));
    vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector);
    vm.prank(HUB_ADMIN);
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: invalidDecimals,
        active: active,
        frozen: frozen,
        paused: paused,
        irStrategy: irStrategy
      }),
      address(tokenList.dai)
    );
  }

  function test_addAsset_revertsWith_InvalidAssetAddress() public {
    uint256 decimals = hub.MAX_ALLOWED_ASSET_DECIMALS();

    vm.expectRevert(ILiquidityHub.InvalidAssetAddress.selector);
    vm.prank(HUB_ADMIN);
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: decimals,
        active: true,
        frozen: false,
        paused: false,
        irStrategy: irStrategy
      }),
      address(0)
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidAssetAddress(
    bool active,
    bool frozen,
    bool paused,
    uint256 decimals,
    IReserveInterestRateStrategy irStrategy
  ) public {
    decimals = bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS());

    vm.expectRevert(ILiquidityHub.InvalidAssetAddress.selector);
    vm.prank(HUB_ADMIN);
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: decimals,
        active: active,
        frozen: frozen,
        paused: paused,
        irStrategy: irStrategy
      }),
      address(0)
    );
  }

  function test_addAsset_revertsWith_InvalidIrStrategy() public {
    uint256 decimals = hub.MAX_ALLOWED_ASSET_DECIMALS();

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    vm.prank(HUB_ADMIN);
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: decimals,
        active: true,
        frozen: false,
        paused: false,
        irStrategy: IReserveInterestRateStrategy(address(0))
      }),
      address(tokenList.dai)
    );
  }

  function test_addAsset_fuzz_revertsWith_InvalidIrStrategy(
    bool active,
    bool frozen,
    bool paused,
    address token,
    uint256 decimals
  ) public {
    decimals = bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS());
    vm.assume(token != address(0));

    vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
    vm.prank(HUB_ADMIN);
    hub.addAsset(
      DataTypes.AssetConfig({
        decimals: decimals,
        active: active,
        frozen: frozen,
        paused: paused,
        irStrategy: IReserveInterestRateStrategy(address(0))
      }),
      token
    );
  }
}
