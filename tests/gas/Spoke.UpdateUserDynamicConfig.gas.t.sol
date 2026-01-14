// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

/// forge-config: default.isolate = true
contract SpokeUpdateUserDynamicConfig_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'Spoke.UpdateUserDynamicConfig';
  ISpoke internal spoke;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
    spoke = spoke1;
  }

  function test_updateUserDynamicConfig_1_collateral() public {
    _setupCollateralsWithDynamicConfigUpdate(1);

    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'A. updateUserDynamicConfig: 1 collateral');
  }

  function test_updateUserDynamicConfig_2_collaterals() public {
    _setupCollateralsWithDynamicConfigUpdate(2);

    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'B. updateUserDynamicConfig: 2 collaterals');
  }

  function test_updateUserDynamicConfig_3_collaterals() public {
    _setupCollateralsWithDynamicConfigUpdate(3);

    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'C. updateUserDynamicConfig: 3 collaterals');
  }

  function test_updateUserDynamicConfig_4_collaterals() public {
    _setupCollateralsWithDynamicConfigUpdate(4);

    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'D. updateUserDynamicConfig: 4 collaterals');
  }

  function test_updateUserDynamicConfig_5_collaterals() public {
    _setupCollateralsWithDynamicConfigUpdate(5);

    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'E. updateUserDynamicConfig: 5 collaterals');
  }

  function test_updateUserDynamicConfig_10_collaterals() public {
    _setupCollateralsWithDynamicConfigUpdate(10);

    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'F. updateUserDynamicConfig: 10 collaterals');
  }

  function test_updateUserDynamicConfig_25_collaterals() public {
    _setupCollateralsWithDynamicConfigUpdate(25);

    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'G. updateUserDynamicConfig: 25 collaterals');
  }

  function test_updateUserDynamicConfig_50_collaterals() public {
    _setupCollateralsWithDynamicConfigUpdate(50);

    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'H. updateUserDynamicConfig: 50 collaterals');
  }

  function test_updateUserDynamicConfig_100_collaterals() public {
    _setupCollateralsWithDynamicConfigUpdate(100);

    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'I. updateUserDynamicConfig: 100 collaterals');
  }

  function test_updateUserDynamicConfig_120_collaterals() public {
    _setupCollateralsWithDynamicConfigUpdate(120);

    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'J. updateUserDynamicConfig: 120 collaterals');
  }

  /// @dev Helper function to set up N collateral reserves with updated dynamic config
  /// @param collateralCount Number of collateral reserves to create
  function _setupCollateralsWithDynamicConfigUpdate(uint256 collateralCount) internal {
    // Add new reserves starting from the current reserve count
    uint256 startingReserveId = spoke.getReserveCount();
    _addNewAssetsAndReserves(collateralCount);

    // Supply all new reserves as collateral for alice
    for (uint256 i = 0; i < collateralCount; ++i) {
      uint256 reserveId = startingReserveId + i;
      Utils.supplyCollateral(spoke, reserveId, alice, MAX_SUPPLY_AMOUNT, alice);
    }

    // Update dynamic config for all new reserves to trigger config refresh
    vm.startPrank(SPOKE_ADMIN);
    for (uint256 i = 0; i < collateralCount; ++i) {
      uint256 reserveId = startingReserveId + i;
      ISpoke.DynamicReserveConfig memory newConfig = ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 110_00,
        liquidationFee: 5_00
      });
      spoke.addDynamicReserveConfig(reserveId, newConfig);
    }
    vm.stopPrank();
  }
}
