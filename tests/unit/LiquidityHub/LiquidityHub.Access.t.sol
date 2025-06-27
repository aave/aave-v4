// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubAccessTest is LiquidityHubBase {
  /// @dev Test showing that restricted functions on hub can only be called by hub admin.
  function test_liquidity_hub_admin_access() public {
    TestnetERC20 tokenA = new TestnetERC20('A', 'A', 18);
    TestnetERC20 tokenB = new TestnetERC20('B', 'B', 18);
    DataTypes.AssetConfig memory assetConfig = DataTypes.AssetConfig({
      feeReceiver: address(0),
      active: true,
      frozen: false,
      paused: false,
      decimals: 18,
      liquidityFee: 0,
      irStrategy: irStrategy
    });
    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      drawCap: 1000e18,
      supplyCap: 1000e18,
      active: true
    });

    // Only Hub Admin can add assets to the hub
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.addAsset(assetConfig, address(tokenA));

    // Hub Admin can add assets to the hub
    vm.prank(HUB_ADMIN);
    hub.addAsset(assetConfig, address(tokenA));
    uint256 assetAId = hub.assetCount() - 1; // Asset A Id

    // Only Hub Admin can update asset config
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.updateAssetConfig(daiAssetId, assetConfig);

    // Hub Admin can update asset config
    vm.prank(HUB_ADMIN);
    hub.updateAssetConfig(daiAssetId, assetConfig);

    // Only Hub Admin can add spoke
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.addSpoke(assetAId, spokeConfig, address(spoke1));

    // Hub Admin can add spoke
    vm.prank(HUB_ADMIN);
    hub.addSpoke(assetAId, spokeConfig, address(spoke1));

    // List token B on hub for preparation of next test
    vm.prank(HUB_ADMIN);
    hub.addAsset(assetConfig, address(tokenB));
    uint256 assetBId = hub.assetCount() - 1;

    // Configure spokes to add
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = assetAId;
    assetIds[1] = assetBId;
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
    hub.updateSpokeConfig(assetAId, address(spoke1), spokeConfig);

    // Hub Admin can update spoke config
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(assetAId, address(spoke1), spokeConfig);

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
    bytes memory encodedIrData = _encodeInterestRateData(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 50_00, // 50.00% in BPS
        baseVariableBorrowRate: 100_00, // 100.00% in BPS
        variableRateSlope1: 200_00, // 200.00% in BPS
        variableRateSlope2: 300_00 // 300.00% in BPS
      })
    );

    // Only Liquidity Hub can set interest rates
    vm.expectRevert(abi.encodeWithSelector(IAssetInterestRateStrategy.OnlyLiquidityHub.selector));
    irStrategy.setInterestRateData(daiAssetId, encodedIrData);

    // Liquidity Hub can set interest rates
    vm.prank(address(hub));
    irStrategy.setInterestRateData(daiAssetId, encodedIrData);

    // Only Hub Admin can call function on hub to set interest rates
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    hub.setInterestRateData(daiAssetId, encodedIrData);

    // Hub Admin can call function on hub to set interest rates
    vm.prank(HUB_ADMIN);
    hub.setInterestRateData(daiAssetId, encodedIrData);
  }

  /// @dev Test showcasing ability to change role responsibility for a function selector.
  function test_change_role_responsibility() public {
    bytes memory encodedIrData = _encodeInterestRateData(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 50_00, // 50.00% in BPS
        baseVariableBorrowRate: 100_00, // 100.00% in BPS
        variableRateSlope1: 200_00, // 200.00% in BPS
        variableRateSlope2: 300_00 // 300.00% in BPS
      })
    );

    // Change the role responsible for setting interest rate data on the hub
    bytes4[] memory hubSelectors = new bytes4[](1);
    hubSelectors[0] = ILiquidityHub.setInterestRateData.selector;
    vm.prank(ADMIN);
    accessManager.setTargetFunctionRole(address(hub), hubSelectors, Roles.DEFAULT_ADMIN_ROLE);

    // The old role (HUB_ADMIN) should no longer have access
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, HUB_ADMIN)
    );
    vm.prank(HUB_ADMIN);
    hub.setInterestRateData(daiAssetId, encodedIrData);

    // The new role (DEFAULT_ADMIN_ROLE) should have access
    vm.prank(ADMIN);
    hub.setInterestRateData(daiAssetId, encodedIrData);

    // HUB_ADMIN can still access the other hub functions for which it has permissions
    vm.prank(HUB_ADMIN);
    hub.updateAssetFees(daiAssetId, address(0), 0);
  }
}
