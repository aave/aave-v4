// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AuthorityUtils} from 'src/dependencies/openzeppelin/AuthorityUtils.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {Context} from 'src/dependencies/openzeppelin/Context.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccessTest is SpokeBase, Context {
  /// @dev Test showing that the hub functions can only be called by spokes, and not by users.
  function testAccess_hub_functions_callable_by_spokes() public {
    // Users are not allowed to directly call the hub functions
    vm.startPrank(bob);
    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SpokeNotActive.selector));
    hub.add(daiAssetId, 1000e18, bob);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SpokeNotActive.selector));
    hub.remove(daiAssetId, 1000e18, bob);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SpokeNotActive.selector));
    hub.draw(daiAssetId, 1000e18, bob);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SpokeNotActive.selector));
    hub.restore(daiAssetId, 1000e18, 0, bob);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SpokeNotActive.selector));
    hub.refreshPremiumDebt(daiAssetId, 0, 0, 0, 0);

    // A spoke is allowed to call the hub functions
    deal(address(tokenList.dai), address(spoke1), 1000e18);
    vm.startPrank(address(spoke1));
    tokenList.dai.approve(address(hub), MAX_SUPPLY_AMOUNT);
    deal(address(tokenList.dai), address(spoke1), 1000e18);
    hub.add(daiAssetId, 1000e18, address(spoke1));
    hub.draw(daiAssetId, 500e18, address(spoke1));
    hub.restore(daiAssetId, 500e18, 0, address(spoke1));
    hub.remove(daiAssetId, 1000e18, address(spoke1));
    hub.refreshPremiumDebt(daiAssetId, 0, 0, 0, 0);
    vm.stopPrank();
  }

  /// @dev Test showing that spoke configurations can only be set by spoke admin.
  function testAccess_spoke_admin_config_access() public {
    // updateLiquidationConfig only callable by spoke admin
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.updateLiquidationConfig(
      DataTypes.LiquidationConfig({
        closeFactor: WadRayMath.WAD,
        liquidationBonusFactor: 40_00,
        healthFactorForMaxBonus: 0.9e18
      })
    );

    // Spoke admin can call updateLiquidationConfig
    vm.prank(address(SPOKE_ADMIN));
    spoke1.updateLiquidationConfig(
      DataTypes.LiquidationConfig({
        closeFactor: WadRayMath.WAD,
        liquidationBonusFactor: 40_00,
        healthFactorForMaxBonus: 0.9e18
      })
    );

    // addReserve only callable by spoke admin
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.addReserve(
      10,
      DataTypes.ReserveConfig({
        hub: hub,
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        decimals: 18,
        liquidationBonus: 100_00,
        liquidityPremium: 0,
        liquidationProtocolFee: 0
      }),
      DataTypes.DynamicReserveConfig({collateralFactor: 75_00})
    );

    // Spoke admin can call addReserve
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(
      4,
      DataTypes.ReserveConfig({
        hub: hub,
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        decimals: 18,
        liquidationBonus: 100_00,
        liquidityPremium: 0,
        liquidationProtocolFee: 0
      }),
      DataTypes.DynamicReserveConfig({collateralFactor: 75_00})
    );

    // updateReserveConfig only callable by spoke admin
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.updateReserveConfig(
      _daiReserveId(spoke1),
      DataTypes.ReserveConfig({
        hub: hub,
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        decimals: 18,
        liquidationBonus: 100_00,
        liquidityPremium: 0,
        liquidationProtocolFee: 0
      })
    );

    // Spoke admin can call updateReserveConfig
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(
      _daiReserveId(spoke1),
      DataTypes.ReserveConfig({
        hub: hub,
        active: true,
        frozen: false,
        paused: false,
        borrowable: true,
        collateral: true,
        decimals: 18,
        liquidationBonus: 100_00,
        liquidityPremium: 0,
        liquidationProtocolFee: 0
      })
    );

    // updateDynamicReserveConfig only callable by spoke admin
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    spoke1.updateDynamicReserveConfig(
      _daiReserveId(spoke1),
      DataTypes.DynamicReserveConfig({collateralFactor: 75_00})
    );

    // Spoke admin can call updateDynamicReserveConfig
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(
      _daiReserveId(spoke1),
      DataTypes.DynamicReserveConfig({collateralFactor: 75_00})
    );
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
