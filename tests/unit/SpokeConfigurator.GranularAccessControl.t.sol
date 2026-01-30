// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfiguratorGranularAccessControlTest is SpokeBase {
  using SafeCast for uint256;

  // Granular role constants
  uint64 constant RESERVE_MANAGER_ROLE = 102;
  uint64 constant LIQUIDATION_CONFIG_MANAGER_ROLE = 103;
  uint64 constant POSITION_MANAGER_ADMIN_ROLE = 104;

  // Role holders
  address RESERVE_MANAGER = makeAddr('RESERVE_MANAGER');
  address LIQUIDATION_CONFIG_MANAGER = makeAddr('LIQUIDATION_CONFIG_MANAGER');
  address POSITION_MANAGER_ADMIN = makeAddr('POSITION_MANAGER_ADMIN');

  SpokeConfigurator spokeConfigurator;
  IAccessManager manager;

  address spokeAddr;
  ISpoke spoke;
  uint256 reserveId;

  // Arrays storing calldata for each role's functions
  bytes[] internal reserveManagerCalldata;
  bytes[] internal liquidationConfigManagerCalldata;
  bytes[] internal positionManagerAdminCalldata;

  function setUp() public virtual override {
    super.setUp();

    manager = IAccessManager(spoke1.authority());
    spokeConfigurator = new SpokeConfigurator(address(manager));

    // Grant SPOKE_ADMIN_ROLE to spokeConfigurator so it can call spoke functions
    vm.startPrank(ADMIN);
    manager.grantRole(Roles.SPOKE_ADMIN_ROLE, address(spokeConfigurator), 0);

    // Grant granular roles to role holders
    manager.grantRole(RESERVE_MANAGER_ROLE, RESERVE_MANAGER, 0);
    manager.grantRole(LIQUIDATION_CONFIG_MANAGER_ROLE, LIQUIDATION_CONFIG_MANAGER, 0);
    manager.grantRole(POSITION_MANAGER_ADMIN_ROLE, POSITION_MANAGER_ADMIN, 0);

    // Set up RESERVE_MANAGER_ROLE permissions (19 functions)
    bytes4[] memory reserveSelectors = new bytes4[](19);
    reserveSelectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
    reserveSelectors[1] = ISpokeConfigurator.updateMaxReserves.selector;
    reserveSelectors[2] = ISpokeConfigurator.addReserve.selector;
    reserveSelectors[3] = ISpokeConfigurator.updatePaused.selector;
    reserveSelectors[4] = ISpokeConfigurator.updateFrozen.selector;
    reserveSelectors[5] = ISpokeConfigurator.updateBorrowable.selector;
    reserveSelectors[7] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    reserveSelectors[8] = ISpokeConfigurator.updateCollateralRisk.selector;
    reserveSelectors[9] = ISpokeConfigurator.addCollateralFactor.selector;
    reserveSelectors[10] = ISpokeConfigurator.updateCollateralFactor.selector;
    reserveSelectors[11] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    reserveSelectors[12] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    reserveSelectors[13] = ISpokeConfigurator.addLiquidationFee.selector;
    reserveSelectors[14] = ISpokeConfigurator.updateLiquidationFee.selector;
    reserveSelectors[15] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    reserveSelectors[16] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
    reserveSelectors[17] = ISpokeConfigurator.pauseAllReserves.selector;
    reserveSelectors[18] = ISpokeConfigurator.freezeAllReserves.selector;
    manager.setTargetFunctionRole(
      address(spokeConfigurator),
      reserveSelectors,
      RESERVE_MANAGER_ROLE
    );

    // Set up LIQUIDATION_CONFIG_MANAGER_ROLE permissions (4 functions)
    bytes4[] memory liqSelectors = new bytes4[](4);
    liqSelectors[0] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
    liqSelectors[1] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
    liqSelectors[2] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
    liqSelectors[3] = ISpokeConfigurator.updateLiquidationConfig.selector;
    manager.setTargetFunctionRole(
      address(spokeConfigurator),
      liqSelectors,
      LIQUIDATION_CONFIG_MANAGER_ROLE
    );

    // Set up POSITION_MANAGER_ADMIN_ROLE permissions (1 function)
    bytes4[] memory pmSelectors = new bytes4[](1);
    pmSelectors[0] = ISpokeConfigurator.updatePositionManager.selector;
    manager.setTargetFunctionRole(
      address(spokeConfigurator),
      pmSelectors,
      POSITION_MANAGER_ADMIN_ROLE
    );

    vm.stopPrank();

    // Set up test data
    spokeAddr = address(spoke1);
    spoke = ISpoke(spokeAddr);
    reserveId = 0;

    // Set max reserves to allow operations
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.updateMaxReserves(spokeAddr, 10);

    // Build calldata arrays for testing
    _buildReserveManagerCalldata();
    _buildLiquidationConfigManagerCalldata();
    _buildPositionManagerAdminCalldata();
  }

  function _buildReserveManagerCalldata() internal {
    address newPriceSource = _deployMockPriceFeed(spoke, 1000e8);
    ISpoke.DynamicReserveConfig memory dynamicConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 110_00,
      liquidationFee: 5_00
    });

    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateReservePriceSource,
        (spokeAddr, reserveId, newPriceSource)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateMaxReserves, (spokeAddr, 20))
    );
    // Skipping addReserve as it requires more complex setup
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updatePaused, (spokeAddr, reserveId, true))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateFrozen, (spokeAddr, reserveId, true))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateBorrowable, (spokeAddr, reserveId, false))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateReceiveSharesEnabled, (spokeAddr, reserveId, false))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateCollateralRisk, (spokeAddr, reserveId, 50_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.addCollateralFactor, (spokeAddr, reserveId, 75_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateCollateralFactor, (spokeAddr, reserveId, 0, 70_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.addMaxLiquidationBonus, (spokeAddr, reserveId, 115_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateMaxLiquidationBonus,
        (spokeAddr, reserveId, 0, 112_00)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.addLiquidationFee, (spokeAddr, reserveId, 8_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateLiquidationFee, (spokeAddr, reserveId, 0, 6_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.addDynamicReserveConfig,
        (spokeAddr, reserveId, dynamicConfig)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateDynamicReserveConfig,
        (spokeAddr, reserveId, 0, dynamicConfig)
      )
    );
    reserveManagerCalldata.push(abi.encodeCall(ISpokeConfigurator.pauseAllReserves, (spokeAddr)));
    reserveManagerCalldata.push(abi.encodeCall(ISpokeConfigurator.freezeAllReserves, (spokeAddr)));
  }

  function _buildLiquidationConfigManagerCalldata() internal {
    ISpoke.LiquidationConfig memory newConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2,
      healthFactorForMaxBonus: Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2,
      liquidationBonusFactor: 50_00
    });

    liquidationConfigManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateLiquidationTargetHealthFactor,
        (spokeAddr, Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2)
      )
    );
    liquidationConfigManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateHealthFactorForMaxBonus,
        (spokeAddr, Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2)
      )
    );
    liquidationConfigManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateLiquidationBonusFactor, (spokeAddr, 50_00))
    );
    liquidationConfigManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateLiquidationConfig, (spokeAddr, newConfig))
    );
  }

  function _buildPositionManagerAdminCalldata() internal {
    address newPM = makeAddr('NEW_POSITION_MANAGER');

    positionManagerAdminCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updatePositionManager, (spokeAddr, newPM, true))
    );
  }

  function test_fuzz_unauthorized_cannotCall_reserveManagerMethods(address caller) public {
    vm.assume(caller != RESERVE_MANAGER);
    vm.assume(caller != address(0));

    for (uint256 i = 0; i < reserveManagerCalldata.length; ++i) {
      vm.prank(caller);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(reserveManagerCalldata[i]);
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
      );
    }
  }

  function test_fuzz_unauthorized_cannotCall_liquidationConfigManagerMethods(
    address caller
  ) public {
    vm.assume(caller != LIQUIDATION_CONFIG_MANAGER);
    vm.assume(caller != address(0));

    for (uint256 i = 0; i < liquidationConfigManagerCalldata.length; ++i) {
      vm.prank(caller);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        liquidationConfigManagerCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
      );
    }
  }

  function test_fuzz_unauthorized_cannotCall_positionManagerAdminMethods(address caller) public {
    vm.assume(caller != POSITION_MANAGER_ADMIN);
    vm.assume(caller != address(0));

    for (uint256 i = 0; i < positionManagerAdminCalldata.length; ++i) {
      vm.prank(caller);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        positionManagerAdminCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
      );
    }
  }

  function test_reserveManager_cannotCall_anyLiquidationConfigMethod() public {
    for (uint256 i = 0; i < liquidationConfigManagerCalldata.length; ++i) {
      vm.prank(RESERVE_MANAGER);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        liquidationConfigManagerCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, RESERVE_MANAGER)
      );
    }
  }

  function test_reserveManager_cannotCall_anyPositionManagerAdminMethod() public {
    for (uint256 i = 0; i < positionManagerAdminCalldata.length; ++i) {
      vm.prank(RESERVE_MANAGER);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        positionManagerAdminCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, RESERVE_MANAGER)
      );
    }
  }

  function test_liquidationConfigManager_cannotCall_anyReserveMethod() public {
    for (uint256 i = 0; i < reserveManagerCalldata.length; ++i) {
      vm.prank(LIQUIDATION_CONFIG_MANAGER);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(reserveManagerCalldata[i]);
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(
          IAccessManaged.AccessManagedUnauthorized.selector,
          LIQUIDATION_CONFIG_MANAGER
        )
      );
    }
  }

  function test_liquidationConfigManager_cannotCall_anyPositionManagerAdminMethod() public {
    for (uint256 i = 0; i < positionManagerAdminCalldata.length; ++i) {
      vm.prank(LIQUIDATION_CONFIG_MANAGER);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        positionManagerAdminCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(
          IAccessManaged.AccessManagedUnauthorized.selector,
          LIQUIDATION_CONFIG_MANAGER
        )
      );
    }
  }

  function test_positionManagerAdmin_cannotCall_anyReserveMethod() public {
    for (uint256 i = 0; i < reserveManagerCalldata.length; ++i) {
      vm.prank(POSITION_MANAGER_ADMIN);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(reserveManagerCalldata[i]);
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(
          IAccessManaged.AccessManagedUnauthorized.selector,
          POSITION_MANAGER_ADMIN
        )
      );
    }
  }

  function test_positionManagerAdmin_cannotCall_anyLiquidationConfigMethod() public {
    for (uint256 i = 0; i < liquidationConfigManagerCalldata.length; ++i) {
      vm.prank(POSITION_MANAGER_ADMIN);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        liquidationConfigManagerCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(
          IAccessManaged.AccessManagedUnauthorized.selector,
          POSITION_MANAGER_ADMIN
        )
      );
    }
  }

  function test_reserveManager_canCall_updatePaused() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.updatePaused(spokeAddr, reserveId, true);

    assertTrue(spoke.getReserveConfig(reserveId).paused);
  }

  function test_reserveManager_canCall_updateFrozen() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.updateFrozen(spokeAddr, reserveId, true);

    assertTrue(spoke.getReserveConfig(reserveId).frozen);
  }

  function test_reserveManager_canCall_pauseAllReserves() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.pauseAllReserves(spokeAddr);

    for (uint256 i = 0; i < spoke.getReserveCount(); ++i) {
      assertTrue(spoke.getReserveConfig(i).paused);
    }
  }

  function test_reserveManager_canCall_freezeAllReserves() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.freezeAllReserves(spokeAddr);

    for (uint256 i = 0; i < spoke.getReserveCount(); ++i) {
      assertTrue(spoke.getReserveConfig(i).frozen);
    }
  }

  function test_liquidationConfigManager_canCall_updateLiquidationTargetHealthFactor() public {
    uint128 newTarget = Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2;

    vm.prank(LIQUIDATION_CONFIG_MANAGER);
    spokeConfigurator.updateLiquidationTargetHealthFactor(spokeAddr, newTarget);

    assertEq(spoke.getLiquidationConfig().targetHealthFactor, newTarget);
  }

  function test_liquidationConfigManager_canCall_updateLiquidationConfig() public {
    ISpoke.LiquidationConfig memory newConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2,
      healthFactorForMaxBonus: Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2,
      liquidationBonusFactor: 50_00
    });

    vm.prank(LIQUIDATION_CONFIG_MANAGER);
    spokeConfigurator.updateLiquidationConfig(spokeAddr, newConfig);

    assertEq(spoke.getLiquidationConfig(), newConfig);
  }

  function test_positionManagerAdmin_canCall_updatePositionManager() public {
    address newPM = makeAddr('NEW_POSITION_MANAGER');

    vm.prank(POSITION_MANAGER_ADMIN);
    spokeConfigurator.updatePositionManager(spokeAddr, newPM, true);

    assertTrue(spoke.isPositionManagerActive(newPM));
  }
}
