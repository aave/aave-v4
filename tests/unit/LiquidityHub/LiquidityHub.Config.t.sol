// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBase.t.sol';

contract LiquidityHubConfigTest is LiquidityHubBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function test_addSpoke() public {
    uint256 assetId = hub.assetCount() - 1;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, address(spoke1));
    hub.addSpoke(assetId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(spoke1));

    DataTypes.SpokeConfig memory spokeData = hub.getSpokeConfig(assetId, address(spoke1));
    assertEq(spokeData.supplyCap, 1, 'spoke supply cap');
    assertEq(spokeData.drawCap, 1, 'spoke draw cap');
  }

  function test_addSpoke_revertsWith_invalid_spoke() public {
    uint256 assetId = hub.assetCount();
    vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
    hub.addSpoke(assetId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(0));
  }

  function test_addSpokes() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig memory daiSpokeConfig = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
    DataTypes.SpokeConfig memory ethSpokeConfig = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = daiSpokeConfig;
    spokeConfigs[1] = ethSpokeConfig;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(daiAssetId, address(spoke1));
    emit ILiquidityHub.SpokeAdded(wethAssetId, address(spoke1));
    hub.addSpokes(assetIds, spokeConfigs, address(spoke1));

    DataTypes.SpokeConfig memory daiSpokeData = hub.getSpokeConfig(daiAssetId, address(spoke1));
    DataTypes.SpokeConfig memory ethSpokeData = hub.getSpokeConfig(wethAssetId, address(spoke1));

    assertEq(daiSpokeData.supplyCap, daiSpokeConfig.supplyCap, 'dai spoke supply cap');
    assertEq(daiSpokeData.drawCap, daiSpokeConfig.drawCap, 'dai spoke draw cap');

    assertEq(ethSpokeData.supplyCap, ethSpokeConfig.supplyCap, 'eth spoke supply cap');
    assertEq(ethSpokeData.drawCap, ethSpokeConfig.drawCap, 'eth spoke draw cap');
  }

  function test_addSpokes_revertsWith_invalid_spoke() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
    spokeConfigs[1] = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

    vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
    hub.addSpokes(assetIds, spokeConfigs, address(0));
  }

  function test_updateAssetConfig_paused() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    // initially not paused
    assertEq(config.paused, false);

    config.paused = true;

    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).paused, true, 'asset paused');

    config.paused = false;

    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).paused, false, 'asset un-paused');
  }

  function test_updateAssetConfig_frozen() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    // initially not frozen
    assertEq(config.frozen, false);

    config.frozen = true;

    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).frozen, true, 'asset frozen');

    config.frozen = false;

    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).frozen, false, 'asset un-frozen');
  }

  function test_updateAssetConfig_fuzz_decimals(uint256 decimals) public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    assertEq(config.decimals, 18);

    config.decimals = decimals;

    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).decimals, decimals, 'asset decimals');
  }

  function test_updateAssetConfig_active() public {
    DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
    // initially active
    assertEq(config.active, true);

    config.active = false;

    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).active, false, 'asset not active');

    config.active = true;

    hub.updateAssetConfig(daiAssetId, config);
    assertEq(hub.getAssetConfig(daiAssetId).active, true, 'asset active');
  }

  function test_updateAssetConfig_revertsWith_AssetCannotBePaused() public {
    // spoke1 supply weth
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: 1e18,
      riskPremium: 0,
      user: alice,
      to: address(spoke1)
    });

    assertGt(hub.getAssetSuppliedShares(wethAssetId), 0);

    DataTypes.AssetConfig memory config = hub.getAssetConfig(wethAssetId);
    config.active = false;

    vm.prank(ADMIN);
    vm.expectRevert(ILiquidityHub.AssetCannotBePaused.selector);
    hub.updateAssetConfig(wethAssetId, config);
  }
}
