// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMultipleHubBase is SpokeBase {
  // New hub and spoke
  IHub internal newHub;
  IAaveOracle internal newOracle;
  ISpoke internal newSpoke;
  IAssetInterestRateStrategy internal newIrStrategy;

  TestnetERC20 internal assetA;
  TestnetERC20 internal assetB;

  ISpoke.DynamicReserveConfig internal dynReserveConfig =
    ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00, // 80.00%
      maxLiquidationBonus: 100_00, // 100.00%
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
    accessManager = IAccessManager(address(new AccessManagerEnumerable(ADMIN)));
    // Canonical hub and spoke
    hub1 = DeployUtils.deployHub(address(accessManager), hex'01');
    (spoke1, oracle1) = _deploySpokeWithOracle(ADMIN, address(accessManager), 'Spoke 1 (USD)');
    treasurySpoke = new TreasurySpoke(ADMIN, address(hub1));
    irStrategy = new AssetInterestRateStrategy(address(hub1));

    // New hub and spoke
    newHub = DeployUtils.deployHub(address(accessManager), hex'02');
    (newSpoke, newOracle) = _deploySpokeWithOracle(
      ADMIN,
      address(accessManager),
      'New Spoke (USD)'
    );
    newIrStrategy = new AssetInterestRateStrategy(address(newHub));

    assetA = new TestnetERC20('Asset A', 'A', 18);
    assetB = new TestnetERC20('Asset B', 'B', 18);
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
    bytes4[] memory selectors = new bytes4[](6);
    selectors[0] = ISpoke.updateReservePriceSource.selector;
    selectors[1] = ISpoke.updateLiquidationConfig.selector;
    selectors[2] = ISpoke.addReserve.selector;
    selectors[3] = ISpoke.updateReserveConfig.selector;
    selectors[4] = ISpoke.addDynamicReserveConfig.selector;
    selectors[5] = ISpoke.updateUserRiskPremium.selector;

    accessManager.setTargetFunctionRole(address(spoke1), selectors, Roles.SPOKE_ADMIN_ROLE);
    accessManager.setTargetFunctionRole(address(newSpoke), selectors, Roles.SPOKE_ADMIN_ROLE);

    // Hub Admin functionalities
    bytes4[] memory hubSelectors = new bytes4[](4);
    hubSelectors[0] = IHub.addAsset.selector;
    hubSelectors[1] = IHub.updateAssetConfig.selector;
    hubSelectors[2] = IHub.addSpoke.selector;
    hubSelectors[3] = IHub.updateSpokeConfig.selector;

    accessManager.setTargetFunctionRole(address(hub1), hubSelectors, Roles.HUB_ADMIN_ROLE);
    accessManager.setTargetFunctionRole(address(newHub), hubSelectors, Roles.HUB_ADMIN_ROLE);
    vm.stopPrank();
  }
}
