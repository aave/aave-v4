// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMultipleHubBase is SpokeBase {
  // New hub and spoke
  ILiquidityHub internal newHub;
  AaveOracle internal newOracle;
  ISpoke internal newSpoke;
  IAssetInterestRateStrategy internal newIrStrategy;

  TestnetERC20 internal assetA;
  TestnetERC20 internal assetB;

  DataTypes.DynamicReserveConfig internal dynReserveConfig =
    DataTypes.DynamicReserveConfig({
      collateralFactor: 80_00, // 80.00%
      liquidationBonus: 100_00, // 100.00%
      liquidationFee: 0 // 0.00%
    });
  IAssetInterestRateStrategy.InterestRateData internal irData =
    IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 90_00, // 90.00%
      baseVariableBorrowRate: 5_00, // 5.00%
      variableRateSlope1: 5_00, // 5.00%
      variableRateSlope2: 5_00 // 5.00%
    });
  bytes internal encodedIrData = abi.encode(irData);

  function setUp() public virtual override {
    deployFixtures();
  }

  function deployFixtures() internal virtual override {
    vm.startPrank(ADMIN);
    accessManager = new AccessManager(ADMIN);
    // Canonical hub and spoke
    hub = new LiquidityHub(address(accessManager));
    spoke1 = new Spoke(address(accessManager));
    oracle1 = new AaveOracle(address(spoke1), 8, 'Spoke 1 (USD)');
    treasurySpoke = new TreasurySpoke(ADMIN, address(hub));
    irStrategy = new AssetInterestRateStrategy(address(hub));

    // New hub and spoke
    newHub = new LiquidityHub(address(accessManager));
    newSpoke = new Spoke(address(accessManager));
    newOracle = new AaveOracle(address(newSpoke), 8, 'New Spoke (USD)');
    newIrStrategy = new AssetInterestRateStrategy(address(newHub));

    assetA = new TestnetERC20('Asset A', 'A', 18);
    assetB = new TestnetERC20('Asset B', 'B', 18);

    spoke1.updateOracle(address(oracle1));
    newSpoke.updateOracle(address(newOracle));
    vm.stopPrank();

    setUpRoles();
  }

  function setUpRoles() internal {
    vm.startPrank(ADMIN);
    // Grant roles with 0 delay
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, ADMIN, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, ADMIN, 0);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, HUB_ADMIN, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, HUB_ADMIN, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, SPOKE_ADMIN, 0);

    // Grant responsibilities to roles
    // Spoke Admin functionalities
    bytes4[] memory selectors = new bytes4[](7);
    selectors[0] = ISpoke.updateOracle.selector;
    selectors[1] = ISpoke.updateReservePriceSource.selector;
    selectors[2] = ISpoke.updateLiquidationConfig.selector;
    selectors[3] = ISpoke.addReserve.selector;
    selectors[4] = ISpoke.updateReserveConfig.selector;
    selectors[5] = ISpoke.updateDynamicReserveConfig.selector;
    selectors[6] = ISpoke.updateUserRiskPremium.selector;

    accessManager.setTargetFunctionRole(address(spoke1), selectors, Roles.SPOKE_ADMIN_ROLE);
    accessManager.setTargetFunctionRole(address(newSpoke), selectors, Roles.SPOKE_ADMIN_ROLE);

    // Liquidity Hub Admin functionalities
    bytes4[] memory hubSelectors = new bytes4[](4);
    hubSelectors[0] = ILiquidityHub.addAsset.selector;
    hubSelectors[1] = ILiquidityHub.updateAssetConfig.selector;
    hubSelectors[2] = ILiquidityHub.addSpoke.selector;
    hubSelectors[3] = ILiquidityHub.updateSpokeConfig.selector;

    accessManager.setTargetFunctionRole(address(hub), hubSelectors, Roles.HUB_ADMIN_ROLE);
    accessManager.setTargetFunctionRole(address(newHub), hubSelectors, Roles.HUB_ADMIN_ROLE);
    vm.stopPrank();
  }
}
