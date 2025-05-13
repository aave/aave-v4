// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Multicall} from 'src/dependencies/openzeppelin/Multicall.sol';
import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubMulticallTest is LiquidityHubBase {
  function test_mulitcall_addMultipleAssets() public {
    IERC20 aave = new TestnetERC20('AAVE', 'AAVE', 18);
    IERC20 gho = new TestnetERC20('GHO', 'GHO', 18);
    uint256 assetCount = hub.assetCount();
    uint256 aaveAssetId = assetCount;
    uint256 ghoAssetId = assetCount + 1;

    DataTypes.AssetConfig memory assetConfig = DataTypes.AssetConfig({
      decimals: 18,
      active: true,
      paused: false,
      frozen: false,
      irStrategy: irStrategy
    });
    DataTypes.Asset memory expectedAaveAsset = DataTypes.Asset({
      suppliedShares: 0,
      availableLiquidity: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      baseDebtIndex: WadRayMath.RAY,
      baseBorrowRate: 0,
      lastUpdateTimestamp: vm.getBlockTimestamp(),
      id: aaveAssetId,
      config: assetConfig
    });
    DataTypes.Asset memory expectedGhoAsset = DataTypes.Asset({
      suppliedShares: 0,
      availableLiquidity: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      baseDebtIndex: WadRayMath.RAY,
      baseBorrowRate: 0,
      lastUpdateTimestamp: vm.getBlockTimestamp(),
      id: ghoAssetId,
      config: assetConfig
    });

    // Setup the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSelector(ILiquidityHub.addAsset.selector, assetConfig, address(aave));
    calls[1] = abi.encodeWithSelector(ILiquidityHub.addAsset.selector, assetConfig, address(gho));

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetAdded(aaveAssetId, address(aave));
    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetAdded(ghoAssetId, address(gho));

    // Execute the multicall
    Multicall(address(hub)).multicall(calls);

    // Check the assets
    DataTypes.Asset memory aaveAsset = hub.getAsset(aaveAssetId);
    DataTypes.Asset memory ghoAsset = hub.getAsset(ghoAssetId);
    _checkAssets(expectedAaveAsset, aaveAsset);
    _checkAssets(expectedGhoAsset, ghoAsset);
  }

  function test_multicall_updateMultipleAssetConfigs() public {
    DataTypes.Asset memory newDaiAsset = hub.getAsset(daiAssetId);
    DataTypes.Asset memory newUsdxAsset = hub.getAsset(usdxAssetId);
    newDaiAsset.config.active = false;
    newUsdxAsset.config.active = false;

    // Setup the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSelector(
      ILiquidityHub.updateAssetConfig.selector,
      daiAssetId,
      newDaiAsset.config
    );
    calls[1] = abi.encodeWithSelector(
      ILiquidityHub.updateAssetConfig.selector,
      usdxAssetId,
      newUsdxAsset.config
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(daiAssetId);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.AssetConfigUpdated(usdxAssetId);

    // Execute the multicall
    Multicall(address(hub)).multicall(calls);

    // Check the assets
    DataTypes.Asset memory daiAsset = hub.getAsset(daiAssetId);
    DataTypes.Asset memory usdxAsset = hub.getAsset(usdxAssetId);
    _checkAssets(newDaiAsset, daiAsset);
    _checkAssets(newUsdxAsset, usdxAsset);
  }

  function test_multicall_addMultipleSpokes() public {
    ISpoke spoke4 = ISpoke(
      new Spoke(address(hub), address(oracle), HEALTH_FACTOR_LIQUIDATION_THRESHOLD)
    );
    ISpoke spoke5 = ISpoke(
      new Spoke(address(hub), address(oracle), HEALTH_FACTOR_LIQUIDATION_THRESHOLD)
    );
    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });

    DataTypes.SpokeData memory expectedSpokeData4 = DataTypes.SpokeData({
      suppliedShares: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      lastUpdateTimestamp: 0,
      config: spokeConfig
    });
    DataTypes.SpokeData memory expectedSpokeData5 = DataTypes.SpokeData({
      suppliedShares: 0,
      baseDrawnShares: 0,
      premiumDrawnShares: 0,
      premiumOffset: 0,
      realizedPremium: 0,
      lastUpdateTimestamp: 0,
      config: spokeConfig
    });

    // Set up the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSelector(
      ILiquidityHub.addSpoke.selector,
      daiAssetId,
      spokeConfig,
      address(spoke4)
    );
    calls[1] = abi.encodeWithSelector(
      ILiquidityHub.addSpoke.selector,
      daiAssetId,
      spokeConfig,
      address(spoke5)
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(daiAssetId, address(spoke4));
    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(daiAssetId, address(spoke5));

    // Execute the multicall
    Multicall(address(hub)).multicall(calls);

    // Check the spokes
    DataTypes.SpokeData memory spokeData4 = hub.getSpoke(daiAssetId, address(spoke4));
    DataTypes.SpokeData memory spokeData5 = hub.getSpoke(daiAssetId, address(spoke5));
    _checkSpokeData(expectedSpokeData4, spokeData4);
    _checkSpokeData(expectedSpokeData5, spokeData5);
  }

  function test_multicall_updateMultipleSpokeConfigs() public {
    uint256 newDrawCap = 20e18;
    uint256 newSupplyCap = 20e18;
    DataTypes.SpokeConfig memory newSpokeConfig = DataTypes.SpokeConfig({
      drawCap: newDrawCap,
      supplyCap: newSupplyCap
    });

    // Set up the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSelector(
      ILiquidityHub.updateSpokeConfig.selector,
      daiAssetId,
      address(spoke1),
      newSpokeConfig
    );
    calls[1] = abi.encodeWithSelector(
      ILiquidityHub.updateSpokeConfig.selector,
      usdxAssetId,
      address(spoke1),
      newSpokeConfig
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(daiAssetId, address(spoke1), newDrawCap, newSupplyCap);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(usdxAssetId, address(spoke1), newDrawCap, newSupplyCap);

    // Execute the multicall
    Multicall(address(hub)).multicall(calls);

    // Check the spoke configs
    DataTypes.SpokeConfig memory daiSpokeConfig = hub.getSpoke(daiAssetId, address(spoke1)).config;
    assertEq(daiSpokeConfig.drawCap, newDrawCap, 'Dai spoke config draw cap mismatch');
    assertEq(daiSpokeConfig.supplyCap, newSupplyCap, 'Dai spoke config supply cap mismatch');
    DataTypes.SpokeConfig memory usdxSpokeConfig = hub
      .getSpoke(usdxAssetId, address(spoke1))
      .config;
    assertEq(usdxSpokeConfig.drawCap, newDrawCap, 'Usdx spoke config draw cap mismatch');
    assertEq(usdxSpokeConfig.supplyCap, newSupplyCap, 'Usdx spoke config supply cap mismatch');
  }

  function _checkSpokeData(
    DataTypes.SpokeData memory expected,
    DataTypes.SpokeData memory actual
  ) internal pure {
    assertEq(expected.suppliedShares, actual.suppliedShares, 'suppliedShares mismatch');
    assertEq(expected.baseDrawnShares, actual.baseDrawnShares, 'baseDrawnShares mismatch');
    assertEq(expected.premiumDrawnShares, actual.premiumDrawnShares, 'premiumDrawnShares mismatch');
    assertEq(expected.premiumOffset, actual.premiumOffset, 'premiumOffset mismatch');
    assertEq(expected.realizedPremium, actual.realizedPremium, 'realizedPremium mismatch');
    assertEq(
      expected.lastUpdateTimestamp,
      actual.lastUpdateTimestamp,
      'lastUpdateTimestamp mismatch'
    );
    assertEq(expected.config.drawCap, actual.config.drawCap, 'drawCap mismatch');
    assertEq(expected.config.supplyCap, actual.config.supplyCap, 'supplyCap mismatch');
  }

  function _checkAssets(
    DataTypes.Asset memory expected,
    DataTypes.Asset memory actual
  ) internal pure {
    assertEq(expected.suppliedShares, actual.suppliedShares, 'suppliedShares mismatch');
    assertEq(expected.availableLiquidity, actual.availableLiquidity, 'availableLiquidity mismatch');
    assertEq(expected.baseDrawnShares, actual.baseDrawnShares, 'baseDrawnShares mismatch');
    assertEq(expected.premiumDrawnShares, actual.premiumDrawnShares, 'premiumDrawnShares mismatch');
    assertEq(expected.premiumOffset, actual.premiumOffset, 'premiumOffset mismatch');
    assertEq(expected.realizedPremium, actual.realizedPremium, 'realizedPremium mismatch');
    assertEq(expected.baseDebtIndex, actual.baseDebtIndex, 'baseDebtIndex mismatch');
    assertEq(expected.baseBorrowRate, actual.baseBorrowRate, 'baseBorrowRate mismatch');
    assertEq(
      expected.lastUpdateTimestamp,
      actual.lastUpdateTimestamp,
      'lastUpdateTimestamp mismatch'
    );
    assertEq(expected.id, actual.id, 'id mismatch');
    assertEq(expected.config.active, actual.config.active, 'active mismatch');
    assertEq(expected.config.frozen, actual.config.frozen, 'frozen mismatch');
    assertEq(expected.config.paused, actual.config.paused, 'paused mismatch');
    assertEq(expected.config.decimals, actual.config.decimals, 'decimals mismatch');
    assertEq(
      address(expected.config.irStrategy),
      address(actual.config.irStrategy),
      'irStrategy mismatch'
    );
  }
}
