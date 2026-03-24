// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';

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
      baseDrawnRate: 5_00, // 5.00%
      rateGrowthBeforeOptimal: 5_00, // 5.00%
      rateGrowthAfterOptimal: 5_00 // 5.00%
    });
  bytes internal encodedIrData = abi.encode(irData);

  function setUp() public virtual override {
    _deployFixtures();
  }

  function _deployFixtures() internal virtual {
    _etchSetup();

    TestTypes.TestEnvReport memory report = AaveV4TestOrchestration.deployTestEnv({
      admin: ADMIN,
      treasuryAdmin: ADMIN,
      hubCount: 2,
      spokeCount: 2,
      nativeWrapper: makeAddr('nativeWrapper'),
      hubBytecode: BytecodeHelper.getHubBytecode(),
      spokeBytecode: BytecodeHelper.getSpokeBytecode(),
      salt: bytes32('multiHubTest')
    });

    // Canonical hub and spoke
    accessManager = IAccessManager(report.accessManager);
    hub1 = IHub(report.hubReports[0].hub);
    irStrategy = IAssetInterestRateStrategy(report.hubReports[0].irStrategy);
    spoke1 = ISpoke(report.spokeReports[0].spoke);
    oracle1 = IAaveOracle(report.spokeReports[0].aaveOracle);
    treasurySpoke = ITreasurySpoke(report.treasurySpoke);

    // New hub and spoke
    newHub = IHub(report.hubReports[1].hub);
    newIrStrategy = IAssetInterestRateStrategy(report.hubReports[1].irStrategy);
    newSpoke = ISpoke(report.spokeReports[1].spoke);
    newOracle = IAaveOracle(report.spokeReports[1].aaveOracle);

    // Deploy test tokens
    vm.startPrank(ADMIN);
    assetA = new TestnetERC20('Asset A', 'A', 18);
    assetB = new TestnetERC20('Asset B', 'B', 18);
    vm.stopPrank();

    _setupMultiHubRoles(report);
  }

  function _setupMultiHubRoles(TestTypes.TestEnvReport memory report) internal {
    vm.startPrank(ADMIN);
    IAccessManager(report.accessManager).grantRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      address(this),
      0
    );
    vm.stopPrank();

    AaveV4TestOrchestration.setRolesTestEnv(report);
    AaveV4TestOrchestration.grantRolesTestEnv(report, ADMIN, HUB_ADMIN, SPOKE_ADMIN);

    IAccessManager(report.accessManager).renounceRole(
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      address(this)
    );
  }
}
