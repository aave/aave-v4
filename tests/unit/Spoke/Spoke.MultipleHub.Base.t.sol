// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMultipleHubBase is SpokeBase {
  // New hub and spoke
  ILiquidityHub internal newHub;
  MockPriceOracle internal newOracle;
  ISpoke internal newSpoke;
  IAssetInterestRateStrategy internal newIrStrategy;

  TestnetERC20 internal assetA;
  TestnetERC20 internal assetB;

  DataTypes.DynamicReserveConfig internal dynReserveConfig =
    DataTypes.DynamicReserveConfig({
      collateralFactor: 80_00 // 80.00%
    });
  IAssetInterestRateStrategy.InterestRateData internal irData =
    IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 90_00, // 90.00%
      baseVariableBorrowRate: 5_00, // 5.00%
      variableRateSlope1: 5_00, // 5.00%
      variableRateSlope2: 5_00 // 5.00%
    });

  function setUp() public virtual override {
    deployFixtures();
  }

  function deployFixtures() internal virtual override {
    vm.startPrank(ADMIN);
    accessManager = new AccessManager(ADMIN);
    // Canonical hub and spoke
    hub = new LiquidityHub(address(accessManager));
    oracle1 = new MockPriceOracle();
    spoke1 = new Spoke(address(oracle1), address(accessManager));
    irStrategy = new AssetInterestRateStrategy(address(accessManager));

    // New hub and spoke
    newHub = new LiquidityHub(address(accessManager));
    newOracle = new MockPriceOracle();
    newSpoke = new Spoke(address(newOracle), address(accessManager));
    newIrStrategy = new AssetInterestRateStrategy(address(accessManager));

    assetA = new TestnetERC20('Asset A', 'A', 18);
    assetB = new TestnetERC20('Asset B', 'B', 18);
    vm.stopPrank();
  }

  function setUpRoles() internal virtual override {
    vm.startPrank(ADMIN);
    // Grant roles
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, ADMIN, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, ADMIN, 0);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, HUB_ADMIN, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, HUB_ADMIN, 0);
    accessManager.grantRole(Roles.SPOKE_ROLE, HUB_ADMIN, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, SPOKE_ADMIN, 0);
    accessManager.grantRole(Roles.SPOKE_ROLE, address(spoke1), 0);
    accessManager.grantRole(Roles.SPOKE_ROLE, address(newSpoke), 0);
    accessManager.grantRole(Roles.GOVERNOR_ROLE, GOVERNOR, 0);

    // Grant responsibilities to roles
    // Spoke Admin functionalities
    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = ISpoke.updateLiquidationConfig.selector;
    selectors[1] = ISpoke.addReserve.selector;
    selectors[2] = ISpoke.updateReserveConfig.selector;
    selectors[3] = ISpoke.updateDynamicReserveConfig.selector;

    accessManager.setTargetFunctionRole(address(spoke1), selectors, Roles.SPOKE_ADMIN_ROLE);
    accessManager.setTargetFunctionRole(address(newSpoke), selectors, Roles.SPOKE_ADMIN_ROLE);

    // Liquidity Hub Admin functionalities
    bytes4[] memory hubSelectors = new bytes4[](6);
    hubSelectors[0] = ILiquidityHub.addAsset.selector;
    hubSelectors[1] = ILiquidityHub.updateAssetConfig.selector;
    hubSelectors[2] = ILiquidityHub.addSpoke.selector;
    hubSelectors[3] = ILiquidityHub.addSpokes.selector;
    hubSelectors[4] = ILiquidityHub.updateSpokeConfig.selector;
    hubSelectors[5] = ILiquidityHub.updateAssetFees.selector;

    accessManager.setTargetFunctionRole(address(hub), hubSelectors, Roles.HUB_ADMIN_ROLE);
    accessManager.setTargetFunctionRole(address(newHub), hubSelectors, Roles.HUB_ADMIN_ROLE);

    // Spoke functionalities
    bytes4[] memory spokeSelectors = new bytes4[](5);
    spokeSelectors[0] = ILiquidityHub.add.selector;
    spokeSelectors[1] = ILiquidityHub.remove.selector;
    spokeSelectors[2] = ILiquidityHub.draw.selector;
    spokeSelectors[3] = ILiquidityHub.restore.selector;
    spokeSelectors[4] = ILiquidityHub.refreshPremiumDebt.selector;

    accessManager.setTargetFunctionRole(address(hub), spokeSelectors, Roles.SPOKE_ROLE);
    accessManager.setTargetFunctionRole(address(newHub), spokeSelectors, Roles.SPOKE_ROLE);
    vm.stopPrank();
  }
}
