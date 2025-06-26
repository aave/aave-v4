// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract LiquidityHubAccessTest is Base {
  function setUp() public override {
    super.setUp();
    super.initEnvironment();
  }

  /// @dev Test showing that restricted functions on hub can only be called by hub admin.
  function test_liquidity_hub_admin_access() public {
    TestnetERC20 tokenA = new TestnetERC20('A', 'A', 18);
    TestnetERC20 tokenB = new TestnetERC20('B', 'B', 18);

    // Only Hub Admin can add assets to the hub
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.addAsset(
      DataTypes.AssetConfig({
        feeReceiver: address(0),
        active: true,
        frozen: false,
        paused: false,
        decimals: 18,
        liquidityFee: 0,
        irStrategy: irStrategy
      }),
      address(tokenA)
    );

    // Hub Admin can add assets to the hub
    vm.prank(HUB_ADMIN);
    hub.addAsset(
      DataTypes.AssetConfig({
        feeReceiver: address(0),
        active: true,
        frozen: false,
        paused: false,
        decimals: 18,
        liquidityFee: 0,
        irStrategy: irStrategy
      }),
      address(tokenA)
    );
    uint256 assetAId = hub.assetCount() - 1; // Asset A Id

    // Only Hub Admin can update asset config
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.updateAssetConfig(
      daiAssetId,
      DataTypes.AssetConfig({
        feeReceiver: address(0),
        active: true,
        frozen: false,
        paused: false,
        decimals: 18,
        liquidityFee: 0,
        irStrategy: irStrategy
      })
    );

    // Hub Admin can update asset config
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(
      daiAssetId,
      DataTypes.AssetConfig({
        feeReceiver: address(0),
        active: true,
        frozen: false,
        paused: false,
        decimals: 18,
        liquidityFee: 0,
        irStrategy: irStrategy
      })
    );

    // Only Hub Admin can add spoke
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.addSpoke(
      assetAId,
      DataTypes.SpokeConfig({drawCap: 1000e18, supplyCap: 1000e18, active: true}),
      address(spoke1)
    );

    // Hub Admin can add spoke
    vm.prank(HUB_ADMIN);
    hub.addSpoke(
      assetAId,
      DataTypes.SpokeConfig({drawCap: 1000e18, supplyCap: 1000e18, active: true}),
      address(spoke1)
    );

    // List token B on hub for preparation of next test
    vm.prank(HUB_ADMIN);
    hub.addAsset(
      DataTypes.AssetConfig({
        feeReceiver: address(0),
        active: true,
        frozen: false,
        paused: false,
        decimals: 18,
        liquidityFee: 0,
        irStrategy: irStrategy
      }),
      address(tokenB)
    );
    uint256 assetBId = hub.assetCount() - 1;

    // Configure spokes to add
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = assetAId;
    assetIds[1] = assetBId;
    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      drawCap: 1000e18,
      supplyCap: 1000e18,
      active: true
    });
    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = spokeConfig;
    spokeConfigs[1] = spokeConfig;

    // Only Hub Admin can add spokes
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.addSpokes(assetIds, spokeConfigs, address(spoke2));

    // Hub Admin can add spokes
    vm.prank(HUB_ADMIN);
    hub.addSpokes(assetIds, spokeConfigs, address(spoke2));

    // Only Hub Admin can update spoke config
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.updateSpokeConfig(
      assetAId,
      address(spoke1),
      DataTypes.SpokeConfig({drawCap: 2000e18, supplyCap: 2000e18, active: true})
    );

    // Hub Admin can update spoke config
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(
      assetAId,
      address(spoke1),
      DataTypes.SpokeConfig({drawCap: 2000e18, supplyCap: 2000e18, active: true})
    );

    // Only Hub Admin can update asset fees
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.updateAssetFees(daiAssetId, address(0), 0);

    // Hub Admin can update asset fees
    vm.prank(HUB_ADMIN);
    hub.updateAssetFees(daiAssetId, address(0), 0);
  }

  function test_setInterestRateData_access() public {
    // Only Liquidity Hub can set interest rates
    vm.expectRevert(abi.encodeWithSelector(IAssetInterestRateStrategy.OnlyLiquidityHub.selector));
    irStrategy.setInterestRateData(
      daiAssetId,
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 50_00,
        baseVariableBorrowRate: 100_00,
        variableRateSlope1: 200_00,
        variableRateSlope2: 300_00
      })
    );

    // Liquidity Hub can set interest rates
    vm.prank(address(hub));
    irStrategy.setInterestRateData(
      daiAssetId,
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 50_00,
        baseVariableBorrowRate: 100_00,
        variableRateSlope1: 200_00,
        variableRateSlope2: 300_00
      })
    );
  }
}
