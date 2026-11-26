// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeConfiguratorGranularAccessControlTest is Base {
  using SafeCast for uint256;

  // Granular role constants (must not collide with Roles.sol IDs 0-113, 200-309)
  uint64 constant RESERVE_MANAGER_ROLE = 1002;
  uint64 constant LIQUIDATION_CONFIG_MANAGER_ROLE = 1003;
  uint64 constant POSITION_MANAGER_ADMIN_ROLE = 1004;

  // Role holders
  address public RESERVE_MANAGER = makeAddr('RESERVE_MANAGER');
  address public LIQUIDATION_CONFIG_MANAGER = makeAddr('LIQUIDATION_CONFIG_MANAGER');
  address public POSITION_MANAGER_ADMIN = makeAddr('POSITION_MANAGER_ADMIN');

  IAccessManager public manager;

  address public spokeAddr;
  ISpoke public spoke;
  address public hubAddr;
  address public underlying;
  uint256 public reserveId;

  // Arrays storing calldata for each role's functions
  bytes[] internal reserveManagerCalldata;
  bytes[] internal liquidationConfigManagerCalldata;
  bytes[] internal positionManagerAdminCalldata;

  function setUp() public virtual override {
    super.setUp();

    manager = IAccessManager(spoke1.authority());
    spokeConfigurator = _deploySpokeConfigurator(address(manager));

    // Grant SPOKE_CONFIGURATOR_ROLE to spokeConfigurator so it can call spoke functions
    vm.startPrank(ADMIN);
    manager.grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(spokeConfigurator), 0);

    // Grant granular roles to role holders
    manager.grantRole(RESERVE_MANAGER_ROLE, RESERVE_MANAGER, 0);
    manager.grantRole(LIQUIDATION_CONFIG_MANAGER_ROLE, LIQUIDATION_CONFIG_MANAGER, 0);
    manager.grantRole(POSITION_MANAGER_ADMIN_ROLE, POSITION_MANAGER_ADMIN, 0);

    // Set up RESERVE_MANAGER_ROLE permissions (24 functions)
    bytes4[] memory reserveSelectors = new bytes4[](24);
    reserveSelectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
    reserveSelectors[1] = ISpokeConfigurator.addReserve.selector;
    reserveSelectors[2] = ISpokeConfigurator.updatePaused.selector;
    reserveSelectors[3] = ISpokeConfigurator.updateBorrowable.selector;
    reserveSelectors[4] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    reserveSelectors[5] = ISpokeConfigurator.updateCollateralRisk.selector;
    reserveSelectors[6] = ISpokeConfigurator.addCollateralFactor.selector;
    reserveSelectors[7] = ISpokeConfigurator.updateCollateralFactor.selector;
    reserveSelectors[8] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    reserveSelectors[9] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    reserveSelectors[10] = ISpokeConfigurator.addLiquidationFee.selector;
    reserveSelectors[11] = ISpokeConfigurator.updateLiquidationFee.selector;
    reserveSelectors[12] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    reserveSelectors[13] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
    reserveSelectors[14] = ISpokeConfigurator.pauseReserve.selector;
    reserveSelectors[15] = ISpokeConfigurator.freezeReserve.selector;
    reserveSelectors[16] = ISpokeConfigurator.unfreezeReserve.selector;
    reserveSelectors[17] = ISpokeConfigurator.disableBorrowing.selector;
    reserveSelectors[18] = ISpokeConfigurator.holdPaused.selector;
    reserveSelectors[19] = ISpokeConfigurator.releasePaused.selector;
    reserveSelectors[20] = ISpokeConfigurator.holdFrozen.selector;
    reserveSelectors[21] = ISpokeConfigurator.releaseFrozen.selector;
    reserveSelectors[22] = ISpokeConfigurator.zeroCollateralFactor.selector;
    reserveSelectors[23] = ISpokeConfigurator.restoreCollateralFactor.selector;
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
    hubAddr = address(hub1);
    underlying = address(tokenList.weth);
    reserveId = _wethReserveId(spoke);

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
        (spokeAddr, hubAddr, underlying, newPriceSource)
      )
    );
    // Skipping addReserve as it requires more complex setup
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updatePaused, (spokeAddr, hubAddr, underlying, true))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateBorrowable, (spokeAddr, hubAddr, underlying, false))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateReceiveSharesEnabled,
        (spokeAddr, hubAddr, underlying, false)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateCollateralRisk,
        (spokeAddr, hubAddr, underlying, 50_00)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.addCollateralFactor,
        (spokeAddr, hubAddr, underlying, 75_00)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateCollateralFactor,
        (spokeAddr, hubAddr, underlying, 0, 70_00)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.addMaxLiquidationBonus,
        (spokeAddr, hubAddr, underlying, 115_00)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateMaxLiquidationBonus,
        (spokeAddr, hubAddr, underlying, 0, 112_00)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.addLiquidationFee, (spokeAddr, hubAddr, underlying, 8_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateLiquidationFee,
        (spokeAddr, hubAddr, underlying, 0, 6_00)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.addDynamicReserveConfig,
        (spokeAddr, hubAddr, underlying, dynamicConfig)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateDynamicReserveConfig,
        (spokeAddr, hubAddr, underlying, 0, dynamicConfig)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.pauseReserve, (spokeAddr, hubAddr, underlying))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.freezeReserve, (spokeAddr, hubAddr, underlying))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.unfreezeReserve, (spokeAddr, hubAddr, underlying))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.disableBorrowing, (spokeAddr, hubAddr, underlying))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.holdPaused,
        (spokeAddr, hubAddr, underlying, BulkLeversMap.SPOKE_MASK)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.releasePaused,
        (spokeAddr, hubAddr, underlying, BulkLeversMap.SPOKE_MASK)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.holdFrozen,
        (spokeAddr, hubAddr, underlying, BulkLeversMap.SPOKE_MASK)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.releaseFrozen,
        (spokeAddr, hubAddr, underlying, BulkLeversMap.SPOKE_MASK)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.zeroCollateralFactor, (spokeAddr, hubAddr, underlying))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.restoreCollateralFactor, (spokeAddr, hubAddr, underlying))
    );
  }

  function _buildLiquidationConfigManagerCalldata() internal {
    ISpoke.LiquidationConfig memory newConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2,
      healthFactorForMaxBonus: HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2,
      liquidationBonusFactor: 50_00
    });

    liquidationConfigManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateLiquidationTargetHealthFactor,
        (spokeAddr, HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2)
      )
    );
    liquidationConfigManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateHealthFactorForMaxBonus,
        (spokeAddr, HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2)
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
    vm.assume(caller != ADMIN);
    vm.assume(caller != address(0));
    vm.assume(caller != ProxyHelper.getProxyAdmin(address(spokeConfigurator)));

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
    vm.assume(caller != ADMIN);
    vm.assume(caller != address(0));
    vm.assume(caller != ProxyHelper.getProxyAdmin(address(spokeConfigurator)));

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
    vm.assume(caller != ADMIN);
    vm.assume(caller != address(0));
    vm.assume(caller != ProxyHelper.getProxyAdmin(address(spokeConfigurator)));

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
    spokeConfigurator.updatePaused(spokeAddr, hubAddr, underlying, true);

    assertTrue(spoke.getReserveConfig(reserveId).paused);
  }

  function test_reserveManager_canCall_freezeReserve() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.freezeReserve(spokeAddr, hubAddr, underlying);

    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    assertEq(_getLatestDynamicReserveConfig(spoke, reserveId).collateralFactor, 0);
  }

  function test_reserveManager_canCall_disableBorrowing() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.disableBorrowing(spokeAddr, hubAddr, underlying);

    assertFalse(spoke.getReserveConfig(reserveId).borrowable);
  }

  function test_reserveManager_canCall_holdFrozen() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.holdFrozen(spokeAddr, hubAddr, underlying, BulkLeversMap.ASSET_MASK);

    assertTrue(spoke.getReserveConfig(reserveId).frozen);
    (bool frozenByFreezeAsset, ) = spokeConfigurator.getFrozenByBulkLevers(
      spokeAddr,
      hubAddr,
      underlying
    );
    assertTrue(frozenByFreezeAsset);
  }

  function test_reserveManager_canCall_releaseFrozen() public {
    vm.startPrank(RESERVE_MANAGER);
    spokeConfigurator.holdFrozen(spokeAddr, hubAddr, underlying, BulkLeversMap.ASSET_MASK);
    spokeConfigurator.releaseFrozen(spokeAddr, hubAddr, underlying, BulkLeversMap.ASSET_MASK);
    vm.stopPrank();

    assertFalse(spoke.getReserveConfig(reserveId).frozen);
  }

  function test_reserveManager_canCall_holdPaused() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.holdPaused(spokeAddr, hubAddr, underlying, BulkLeversMap.SPOKE_MASK);

    assertTrue(spoke.getReserveConfig(reserveId).paused);
    assertTrue(spokeConfigurator.getPausedByBulkLevers(spokeAddr, hubAddr, underlying));
  }

  function test_reserveManager_canCall_releasePaused() public {
    vm.startPrank(RESERVE_MANAGER);
    spokeConfigurator.holdPaused(spokeAddr, hubAddr, underlying, BulkLeversMap.SPOKE_MASK);
    spokeConfigurator.releasePaused(spokeAddr, hubAddr, underlying, BulkLeversMap.SPOKE_MASK);
    vm.stopPrank();

    assertFalse(spoke.getReserveConfig(reserveId).paused);
  }

  function test_liquidationConfigManager_canCall_updateLiquidationTargetHealthFactor() public {
    uint128 newTarget = HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2;

    vm.prank(LIQUIDATION_CONFIG_MANAGER);
    spokeConfigurator.updateLiquidationTargetHealthFactor(spokeAddr, newTarget);

    assertEq(spoke.getLiquidationConfig().targetHealthFactor, newTarget);
  }

  function test_liquidationConfigManager_canCall_updateLiquidationConfig() public {
    ISpoke.LiquidationConfig memory newConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2,
      healthFactorForMaxBonus: HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2,
      liquidationBonusFactor: 50_00
    });

    vm.prank(LIQUIDATION_CONFIG_MANAGER);
    spokeConfigurator.updateLiquidationConfig(spokeAddr, newConfig);

    assertEq(spoke.getLiquidationConfig(), newConfig);
  }

  function test_positionManagerAdmin_canCall_updatePositionManager() public {
    address newPM = makeAddr('NEW_POSITION_MANAGER');

    vm.prank(POSITION_MANAGER_ADMIN);
    spokeConfigurator.updatePositionManager({
      spoke: spokeAddr,
      positionManager: newPM,
      active: true
    });

    assertTrue(spoke.isPositionManagerActive(newPM));
  }
}
