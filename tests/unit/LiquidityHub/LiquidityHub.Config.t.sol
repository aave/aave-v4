// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBase.t.sol';

contract LiquidityHubConfigTest is LiquidityHubBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function test_addSpoke() public {
    vm.skip(true, 'pending refactor');

//     uint256 assetId = hub.assetCount() - 1;

//     vm.expectEmit(address(hub));
//     emit ILiquidityHub.SpokeAdded(assetId, address(spoke1));
//     vm.prank(HUB_ADMIN);
//     hub.addSpoke(assetId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(spoke1));

//     DataTypes.SpokeConfig memory spokeData = hub.getSpokeConfig(assetId, address(spoke1));
//     assertEq(spokeData.supplyCap, 1, 'spoke supply cap');
//     assertEq(spokeData.drawCap, 1, 'spoke draw cap');
  
}

  function test_addSpoke_revertsWith_invalid_spoke() public {
    vm.skip(true, 'pending refactor');

//     uint256 assetId = hub.assetCount();

//     vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
//     vm.prank(HUB_ADMIN);
//     hub.addSpoke(assetId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(0));
  
}

  function test_addSpokes() public {
    vm.skip(true, 'pending refactor');

//     uint256[] memory assetIds = new uint256[](2);
//     assetIds[0] = daiAssetId;
//     assetIds[1] = wethAssetId;

//     DataTypes.SpokeConfig memory daiSpokeConfig = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
//     DataTypes.SpokeConfig memory ethSpokeConfig = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

//     DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
//     spokeConfigs[0] = daiSpokeConfig;
//     spokeConfigs[1] = ethSpokeConfig;

//     vm.prank(HUB_ADMIN);
//     vm.expectEmit(address(hub));
//     emit ILiquidityHub.SpokeAdded(daiAssetId, address(spoke1));
//     emit ILiquidityHub.SpokeAdded(wethAssetId, address(spoke1));
//     hub.addSpokes(assetIds, spokeConfigs, address(spoke1));

//     DataTypes.SpokeConfig memory daiSpokeData = hub.getSpokeConfig(daiAssetId, address(spoke1));
//     DataTypes.SpokeConfig memory ethSpokeData = hub.getSpokeConfig(wethAssetId, address(spoke1));

//     assertEq(daiSpokeData.supplyCap, daiSpokeConfig.supplyCap, 'dai spoke supply cap');
//     assertEq(daiSpokeData.drawCap, daiSpokeConfig.drawCap, 'dai spoke draw cap');

//     assertEq(ethSpokeData.supplyCap, ethSpokeConfig.supplyCap, 'eth spoke supply cap');
//     assertEq(ethSpokeData.drawCap, ethSpokeConfig.drawCap, 'eth spoke draw cap');
  
}

  function test_addSpokes_revertsWith_invalid_spoke() public {
    vm.skip(true, 'pending refactor');

//     uint256[] memory assetIds = new uint256[](2);
//     assetIds[0] = daiAssetId;
//     assetIds[1] = wethAssetId;

//     DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
//     spokeConfigs[0] = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
//     spokeConfigs[1] = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

//     vm.expectRevert(ILiquidityHub.InvalidSpoke.selector);
//     vm.prank(HUB_ADMIN);
//     hub.addSpokes(assetIds, spokeConfigs, address(0));
  
}

  function test_updateAssetConfig_paused() public {
    vm.skip(true, 'pending refactor');

//     DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
//     // initially not paused
//     assertEq(config.paused, false);

//     config.paused = true;

//     hub.updateAssetConfig(daiAssetId, config);
//     vm.prank(HUB_ADMIN);
//     assertEq(hub.getAssetConfig(daiAssetId).paused, true, 'asset paused');

//     config.paused = false;

//     vm.prank(HUB_ADMIN);
//     hub.updateAssetConfig(daiAssetId, config);
//     assertEq(hub.getAssetConfig(daiAssetId).paused, false, 'asset un-paused');
  
}

  function test_updateAssetConfig_frozen() public {
    vm.skip(true, 'pending refactor');

//     DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
//     // initially not frozen
//     assertEq(config.frozen, false);

//     config.frozen = true;

//     vm.prank(HUB_ADMIN);
//     hub.updateAssetConfig(daiAssetId, config);
//     assertEq(hub.getAssetConfig(daiAssetId).frozen, true, 'asset frozen');

//     config.frozen = false;

//     vm.prank(HUB_ADMIN);
//     hub.updateAssetConfig(daiAssetId, config);
//     assertEq(hub.getAssetConfig(daiAssetId).frozen, false, 'asset un-frozen');
  
}

  function test_updateAssetConfig_fuzz_decimals(uint256 decimals) public {
    vm.skip(true, 'pending refactor');

//     decimals = bound(decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS());
//     DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
//     assertEq(config.decimals, 18);

//     config.decimals = decimals;

//     vm.prank(HUB_ADMIN);
//     hub.updateAssetConfig(daiAssetId, config);
//     assertEq(hub.getAssetConfig(daiAssetId).decimals, decimals, 'asset decimals');
  
}

  function test_updateAssetConfig_active() public {
    vm.skip(true, 'pending refactor');

//     DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
//     // initially active
//     assertEq(config.active, true);

//     config.active = false;

//     vm.prank(HUB_ADMIN);
//     hub.updateAssetConfig(daiAssetId, config);
//     assertEq(hub.getAssetConfig(daiAssetId).active, false, 'asset not active');

//     config.active = true;

//     vm.prank(HUB_ADMIN);
//     hub.updateAssetConfig(daiAssetId, config);
//     assertEq(hub.getAssetConfig(daiAssetId).active, true, 'asset active');
  
}

  function test_updateAssetConfig_decimals() public {
    vm.skip(true, 'pending refactor');

//     DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
//     uint256 newDecimals = 12;
//     assertNotEq(config.decimals, newDecimals);

//     config.decimals = newDecimals;

//     vm.prank(HUB_ADMIN);
//     hub.updateAssetConfig(daiAssetId, config);

//     assertEq(hub.getAssetConfig(daiAssetId).decimals, newDecimals, 'asset decimals');
  
}

  function test_updateAssetConfig_decimals_revertsWith_InvalidAssetDecimals() public {
    vm.skip(true, 'pending refactor');

//     DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
//     uint256 newDecimals = 19;
//     assertNotEq(config.decimals, newDecimals);

//     config.decimals = newDecimals;

//     vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector);
//     vm.prank(HUB_ADMIN);
//     hub.updateAssetConfig(daiAssetId, config);
  
}

  function test_updateAssetConfig_revertsWith_InvalidIrStrategy() public {
    vm.skip(true, 'pending refactor');

//     DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);

//     config.irStrategy = address(0);

//     vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
//     vm.prank(HUB_ADMIN);
//     hub.updateAssetConfig(daiAssetId, config);
  
}

  function test_updateAssetConfig_irStrategy() public {
    vm.skip(true, 'pending refactor');

//     DataTypes.AssetConfig memory config = hub.getAssetConfig(daiAssetId);
//     address newIrStrategy = makeAddr('newIrStrategy');
//     assertNotEq(config.irStrategy, newIrStrategy);

//     config.irStrategy = newIrStrategy;

//     vm.prank(HUB_ADMIN);
//     hub.updateAssetConfig(daiAssetId, config);

//     assertEq(hub.getAssetConfig(daiAssetId).irStrategy, newIrStrategy, 'asset irStrategy');
  
}

  function test_updateSpokeConfig_drawCap() public {
    vm.skip(true, 'pending refactor');

//     DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));
//     uint256 drawCap = 5;
//     assertNotEq(config.drawCap, drawCap);

//     config.drawCap = drawCap;

//     vm.prank(HUB_ADMIN);
//     hub.updateSpokeConfig(daiAssetId, address(spoke1), config);

//     assertEq(hub.getSpokeConfig(daiAssetId, address(spoke1)).drawCap, drawCap, 'asset drawCap');
  
}

  function test_updateSpokeConfig_supplyCap() public {
    vm.skip(true, 'pending refactor');

//     DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));
//     uint256 drawCap = 5;
//     assertNotEq(config.drawCap, drawCap);

//     config.drawCap = drawCap;

//     vm.prank(HUB_ADMIN);
//     hub.updateSpokeConfig(daiAssetId, address(spoke1), config);

//     assertEq(hub.getSpokeConfig(daiAssetId, address(spoke1)).drawCap, drawCap, 'asset drawCap');
  
}

  function test_updateSpokeConfig_emit() public {
    vm.skip(true, 'pending refactor');

//     DataTypes.SpokeConfig memory config = hub.getSpokeConfig(daiAssetId, address(spoke1));

//     vm.prank(HUB_ADMIN);
//     vm.expectEmit(address(hub));
//     emit ILiquidityHub.SpokeConfigUpdated(
//       daiAssetId,
//       address(spoke1),
//       config.drawCap,
//       config.supplyCap
//     );
//     hub.updateSpokeConfig(daiAssetId, address(spoke1), config);
  
}

  function test_addAsset() public {
    vm.skip(true, 'pending refactor');

//     vm.prank(HUB_ADMIN);
//     hub.addAsset(
//       DataTypes.AssetConfig({
//         decimals: 18,
//         active: true,
//         frozen: false,
//         paused: false,
//         irStrategy: address(irStrategy)
//       }),
//       address(tokenList.dai)
//     );

//     uint256 assetId = hub.assetCount() - 1;
//     DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
//     assertEq(config.decimals, 18, 'asset decimals');
//     assertEq(config.active, true, 'asset active');
//     assertEq(config.frozen, false, 'asset frozen');
//     assertEq(config.paused, false, 'asset paused');
//     assertEq(config.irStrategy, address(irStrategy), 'asset irStrategy');
  
}

  function test_addAsset_fuzz(DataTypes.AssetConfig memory newConfig, address asset) public {
    vm.skip(true, 'pending refactor');

//     newConfig.decimals = bound(newConfig.decimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS());
//     vm.assume(newConfig.irStrategy != address(0) && asset != address(0));

//     vm.prank(HUB_ADMIN);
//     hub.addAsset(newConfig, asset);

//     uint256 assetId = hub.assetCount() - 1;
//     DataTypes.AssetConfig memory config = hub.getAssetConfig(assetId);
//     assertEq(config.decimals, newConfig.decimals, 'asset decimals');
//     assertEq(config.active, newConfig.active, 'asset active');
//     assertEq(config.frozen, newConfig.frozen, 'asset frozen');
//     assertEq(config.paused, newConfig.paused, 'asset paused');
//     assertEq(config.irStrategy, newConfig.irStrategy, 'asset irStrategy');
  
}

  function test_addAsset_revertsWith_InvalidAssetDecimals() public {
    vm.skip(true, 'pending refactor');

//     vm.expectRevert(ILiquidityHub.InvalidAssetDecimals.selector);
//     vm.prank(HUB_ADMIN);
//     hub.addAsset(
//       DataTypes.AssetConfig({
//         decimals: 19, // invalid decimals
//         active: true,
//         frozen: false,
//         paused: false,
//         irStrategy: address(irStrategy)
//       }),
//       address(tokenList.dai)
//     );
  
}

  function test_addAsset_revertsWith_InvalidAssetAddress() public {
    vm.skip(true, 'pending refactor');

//     vm.expectRevert(ILiquidityHub.InvalidAssetAddress.selector);
//     vm.prank(HUB_ADMIN);
//     hub.addAsset(
//       DataTypes.AssetConfig({
//         decimals: 18,
//         active: true,
//         frozen: false,
//         paused: false,
//         irStrategy: address(irStrategy)
//       }),
//       address(0)
//     );
  
}

  function test_addAsset_revertsWith_InvalidIrStrategy() public {
    vm.skip(true, 'pending refactor');

//     vm.expectRevert(ILiquidityHub.InvalidIrStrategy.selector);
//     vm.prank(HUB_ADMIN);
//     hub.addAsset(
//       DataTypes.AssetConfig({
//         decimals: 18,
//         active: true,
//         frozen: false,
//         paused: false,
//         irStrategy: address(0)
//       }),
//       address(tokenList.dai)
//     );
  
}
}
