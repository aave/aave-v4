// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfiguratorTest is SpokeBase {
  using SafeCast for uint256;

  SpokeConfigurator public spokeConfigurator;
  address public SPOKE_CONFIGURATOR_ADMIN = makeAddr('SPOKE_CONFIGURATOR_ADMIN');

  address public spokeAddr;
  ISpoke public spoke;
  uint256 public reserveId;
  uint256 public invalidReserveId;

  function setUp() public virtual override {
    super.setUp();

    spokeConfigurator = new SpokeConfigurator(SPOKE_CONFIGURATOR_ADMIN);
    spokeAddr = address(spoke1);
    spoke = ISpoke(spokeAddr);
    reserveId = 0;
    invalidReserveId = spoke.getReserveCount();

    // Grant spokeConfigurator spoke admin role with 0 delay
    vm.startPrank(ADMIN);
    IAccessManager(spoke1.authority()).grantRole(
      Roles.SPOKE_ADMIN_ROLE,
      address(spokeConfigurator),
      0
    );
    vm.stopPrank();
  }

  function test_updateOracle_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateOracle(spokeAddr, address(0));
  }

  function test_updateOracle() public {
    address newOracle = makeAddr('NEW_ORACLE');
    vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateOracle, (newOracle)));
    vm.expectEmit(address(spoke));
    emit ISpoke.OracleUpdated(newOracle);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateOracle(spokeAddr, newOracle);
  }

  function test_updateReservePriceSource_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateReservePriceSource(spokeAddr, reserveId, address(0));
  }

  function test_updateReservePriceSource() public {
    address newPriceSource = _deployMockPriceFeed(spoke, 1000e8);
    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReservePriceSource, (reserveId, newPriceSource))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReservePriceSourceUpdated(reserveId, newPriceSource);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateReservePriceSource(spokeAddr, reserveId, newPriceSource);
  }

  function test_updateLiquidationCloseFactor_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateLiquidationCloseFactor(spokeAddr, 0);
  }

  function test_updateLiquidationCloseFactor() public {
    uint256 newCloseFactor = ISpoke(spoke).HEALTH_FACTOR_LIQUIDATION_THRESHOLD() * 2;

    DataTypes.LiquidationConfig memory expectedLiquidationConfig = spoke.getLiquidationConfig();
    expectedLiquidationConfig.closeFactor = newCloseFactor;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.LiquidationConfigUpdated(expectedLiquidationConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationCloseFactor(spokeAddr, newCloseFactor);

    assertEq(spoke.getLiquidationConfig(), expectedLiquidationConfig);
  }

  function test_updateHealthFactorForMaxBonus_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateHealthFactorForMaxBonus(spokeAddr, 0);
  }

  function test_updateHealthFactorForMaxBonus() public {
    uint256 newHealthFactorForMaxBonus = spoke.HEALTH_FACTOR_LIQUIDATION_THRESHOLD() / 2;

    DataTypes.LiquidationConfig memory expectedLiquidationConfig = spoke.getLiquidationConfig();
    expectedLiquidationConfig.healthFactorForMaxBonus = newHealthFactorForMaxBonus;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.LiquidationConfigUpdated(expectedLiquidationConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateHealthFactorForMaxBonus(spokeAddr, newHealthFactorForMaxBonus);

    assertEq(spoke.getLiquidationConfig().healthFactorForMaxBonus, newHealthFactorForMaxBonus);
  }

  function test_updateLiquidationBonusFactor_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateLiquidationBonusFactor(spokeAddr, 0);
  }

  function test_updateLiquidationBonusFactor() public {
    uint256 newLiquidationBonusFactor = PercentageMath.PERCENTAGE_FACTOR / 2;

    DataTypes.LiquidationConfig memory expectedLiquidationConfig = spoke.getLiquidationConfig();
    expectedLiquidationConfig.liquidationBonusFactor = newLiquidationBonusFactor;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateLiquidationConfig, (expectedLiquidationConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.LiquidationConfigUpdated(expectedLiquidationConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationBonusFactor(spokeAddr, newLiquidationBonusFactor);

    assertEq(spoke.getLiquidationConfig(), expectedLiquidationConfig);
  }

  function test_addReserve_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.addReserve({
      spoke: spokeAddr,
      hub: address(hub),
      assetId: 0,
      priceSource: address(0),
      config: DataTypes.ReserveConfig({
        paused: false,
        frozen: false,
        borrowable: true,
        collateralRisk: 15_00
      }),
      dynamicConfig: DataTypes.DynamicReserveConfig({
        collateralFactor: 80_00,
        liquidationBonus: 100_00,
        liquidationFee: 0
      })
    });
  }

  function test_addReserve() public {
    address newPriceSource = _deployMockPriceFeed(spoke, 1000e8);
    DataTypes.ReserveConfig memory config = DataTypes.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 15_00
    });
    DataTypes.DynamicReserveConfig memory dynamicConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 80_00,
      liquidationBonus: 100_00,
      liquidationFee: 0
    });

    uint256 expectedReserveId = spoke.getReserveCount();

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(
        ISpoke.addReserve,
        (address(hub), daiAssetId, newPriceSource, config, dynamicConfig)
      )
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveAdded(expectedReserveId, daiAssetId, address(hub));
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveConfigUpdated(expectedReserveId, config);
    vm.expectEmit(address(spoke));
    emit ISpoke.DynamicReserveConfigAdded(expectedReserveId, 0, dynamicConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    uint256 actualReserveId = spokeConfigurator.addReserve({
      spoke: spokeAddr,
      hub: address(hub),
      assetId: daiAssetId,
      priceSource: newPriceSource,
      config: config,
      dynamicConfig: dynamicConfig
    });

    assertEq(actualReserveId, expectedReserveId);
  }

  function test_updatePaused_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updatePaused(spokeAddr, reserveId, true);
  }

  function test_updatePaused() public {
    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);

    for (uint256 i = 0; i < 2; i += 1) {
      expectedReserveConfig.paused = (i == 0) ? false : true;

      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
      vm.prank(SPOKE_CONFIGURATOR_ADMIN);
      spokeConfigurator.updatePaused(spokeAddr, reserveId, expectedReserveConfig.paused);

      assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
    }
  }

  function test_updateFrozen_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateFrozen(spokeAddr, reserveId, true);
  }

  function test_updateFrozen() public {
    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);

    for (uint256 i = 0; i < 2; i += 1) {
      expectedReserveConfig.frozen = (i == 0) ? false : true;

      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
      vm.prank(SPOKE_CONFIGURATOR_ADMIN);
      spokeConfigurator.updateFrozen(spokeAddr, reserveId, expectedReserveConfig.frozen);

      assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
    }
  }

  function test_updateBorrowable_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateBorrowable(spokeAddr, reserveId, true);
  }

  function test_updateBorrowable() public {
    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);

    for (uint256 i = 0; i < 2; i += 1) {
      expectedReserveConfig.borrowable = (i == 0) ? false : true;

      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
      vm.prank(SPOKE_CONFIGURATOR_ADMIN);
      spokeConfigurator.updateBorrowable(spokeAddr, reserveId, expectedReserveConfig.borrowable);

      assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
    }
  }

  function test_updateCollateralRisk_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateCollateralRisk(spokeAddr, reserveId, 0);
  }

  function test_updateCollateralRisk() public {
    uint256 newCollateralRisk = spoke.MAX_COLLATERAL_RISK() / 2;

    DataTypes.ReserveConfig memory expectedReserveConfig = spoke.getReserveConfig(reserveId);
    expectedReserveConfig.collateralRisk = newCollateralRisk;

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, expectedReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveConfigUpdated(reserveId, expectedReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateralRisk(spokeAddr, reserveId, newCollateralRisk);

    assertEq(spoke.getReserveConfig(reserveId), expectedReserveConfig);
  }

  function test_updateCollateralFactor_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateCollateralFactor(spokeAddr, reserveId, 0);
  }

  function test_updateCollateralFactor() public {
    uint16 newCollateralFactor = uint16(PercentageMath.PERCENTAGE_FACTOR / 2);

    DataTypes.DynamicReserveConfig memory expectedDynamicReserveConfig = spoke
      .getDynamicReserveConfig(reserveId);
    expectedDynamicReserveConfig.collateralFactor = newCollateralFactor;

    uint16 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, expectedDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.DynamicReserveConfigAdded(
      reserveId,
      expectedConfigKey,
      expectedDynamicReserveConfig
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateCollateralFactor(spokeAddr, reserveId, newCollateralFactor);

    assertEq(spoke.getDynamicReserveConfig(reserveId), expectedDynamicReserveConfig);
    assertEq(spoke.getReserve(reserveId).dynamicConfigKey, expectedConfigKey);
  }

  function test_updateLiquidationBonus_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateLiquidationBonus(spokeAddr, reserveId, 0);
  }

  function test_updateLiquidationBonus() public {
    uint256 newLiquidationBonus = PercentageMath.PERCENTAGE_FACTOR + 1;

    DataTypes.DynamicReserveConfig memory expectedDynamicReserveConfig = spoke
      .getDynamicReserveConfig(reserveId);
    expectedDynamicReserveConfig.liquidationBonus = newLiquidationBonus;

    uint16 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, expectedDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.DynamicReserveConfigAdded(
      reserveId,
      expectedConfigKey,
      expectedDynamicReserveConfig
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationBonus(spokeAddr, reserveId, newLiquidationBonus);

    assertEq(spoke.getDynamicReserveConfig(reserveId), expectedDynamicReserveConfig);
  }

  function test_updateLiquidationFee_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateLiquidationFee(spokeAddr, reserveId, 0);
  }

  function test_updateLiquidationFee() public {
    uint256 newLiquidationFee = PercentageMath.PERCENTAGE_FACTOR / 2;

    DataTypes.DynamicReserveConfig memory expectedDynamicReserveConfig = spoke
      .getDynamicReserveConfig(reserveId);
    expectedDynamicReserveConfig.liquidationFee = newLiquidationFee;

    uint16 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, expectedDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.DynamicReserveConfigAdded(
      reserveId,
      expectedConfigKey,
      expectedDynamicReserveConfig
    );
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateLiquidationFee(spokeAddr, reserveId, newLiquidationFee);

    assertEq(spoke.getDynamicReserveConfig(reserveId), expectedDynamicReserveConfig);
  }

  function test_updateReserveConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateReserveConfig(
      spokeAddr,
      reserveId,
      DataTypes.ReserveConfig({
        frozen: false,
        paused: false,
        borrowable: true,
        collateralRisk: 15_00
      })
    );
  }

  function test_updateReserveConfig() public {
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      frozen: false,
      paused: false,
      borrowable: true,
      collateralRisk: 15_00
    });

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, newReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.ReserveConfigUpdated(reserveId, newReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateReserveConfig(spokeAddr, reserveId, newReserveConfig);

    assertEq(spoke.getReserveConfig(reserveId), newReserveConfig);
  }

  function test_addDynamicReserveConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.addDynamicReserveConfig(
      spokeAddr,
      reserveId,
      DataTypes.DynamicReserveConfig({
        collateralFactor: 20_00,
        liquidationBonus: 130_00,
        liquidationFee: 15_00
      })
    );
  }

  function test_addDynamicReserveConfig() public {
    DataTypes.DynamicReserveConfig memory newDynamicReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 20_00,
      liquidationBonus: 130_00,
      liquidationFee: 15_00
    });

    uint16 expectedConfigKey = _nextDynamicConfigKey(spoke, reserveId);

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(ISpoke.addDynamicReserveConfig, (reserveId, newDynamicReserveConfig))
    );
    vm.expectEmit(address(spoke));
    emit ISpoke.DynamicReserveConfigAdded(reserveId, expectedConfigKey, newDynamicReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    uint16 actualConfigKey = spokeConfigurator.addDynamicReserveConfig(
      spokeAddr,
      reserveId,
      newDynamicReserveConfig
    );

    assertEq(spoke.getDynamicReserveConfig(reserveId), newDynamicReserveConfig);
    assertEq(actualConfigKey, expectedConfigKey);
  }

  function test_updateDynamicReserveConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.updateDynamicReserveConfig(
      spokeAddr,
      reserveId,
      0,
      DataTypes.DynamicReserveConfig({
        collateralFactor: 10_00,
        liquidationBonus: 150_00,
        liquidationFee: 12_00
      })
    );
  }

  function test_updateDynamicReserveConfig() public {
    uint256 count = vm.randomUint(1, 50);
    for (uint256 i; i < count; ++i) test_addDynamicReserveConfig();
    assertEq(spoke.getReserve(reserveId).dynamicConfigKey, count);

    DataTypes.DynamicReserveConfig memory newDynamicReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 10_00,
      liquidationBonus: 150_00,
      liquidationFee: 12_00
    });
    uint16 configKeyToUpdate = vm.randomUint(0, count).toUint16();

    vm.expectCall(
      spokeAddr,
      abi.encodeCall(
        ISpoke.updateDynamicReserveConfig,
        (reserveId, configKeyToUpdate, newDynamicReserveConfig)
      )
    );

    vm.expectEmit(address(spoke));
    emit ISpoke.DynamicReserveConfigUpdated(reserveId, configKeyToUpdate, newDynamicReserveConfig);
    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.updateDynamicReserveConfig(
      spokeAddr,
      reserveId,
      configKeyToUpdate,
      newDynamicReserveConfig
    );

    assertEq(spoke.getDynamicReserveConfig(reserveId, configKeyToUpdate), newDynamicReserveConfig);
  }

  function test_pauseAllReserves_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.pauseAllReserves(spokeAddr);
  }

  function test_pauseAllReserves() public {
    for (uint256 reserveId = 0; reserveId < spoke.getReserveCount(); ++reserveId) {
      DataTypes.ReserveConfig memory reserveConfig = spoke.getReserveConfig(reserveId);
      reserveConfig.paused = true;
      vm.expectCall(
        spokeAddr,
        abi.encodeCall(ISpoke.updateReserveConfig, (reserveId, reserveConfig))
      );
      vm.expectEmit(address(spoke));
      emit ISpoke.ReserveConfigUpdated(reserveId, reserveConfig);
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.pauseAllReserves(spokeAddr);

    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      assertEq(spoke.getReserveConfig(id).paused, true);
    }
  }

  function test_freezeAllReserves_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    spokeConfigurator.freezeAllReserves(spokeAddr);
  }

  function test_freezeAllReserves() public {
    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      DataTypes.ReserveConfig memory reserveConfig = spoke.getReserveConfig(id);
      reserveConfig.frozen = true;
      vm.expectCall(spokeAddr, abi.encodeCall(ISpoke.updateReserveConfig, (id, reserveConfig)));
      vm.expectEmit(address(spoke));
      emit ISpoke.ReserveConfigUpdated(id, reserveConfig);
    }

    vm.prank(SPOKE_CONFIGURATOR_ADMIN);
    spokeConfigurator.freezeAllReserves(spokeAddr);

    for (uint256 id; id < spoke.getReserveCount(); ++id) {
      assertEq(spoke.getReserveConfig(id).frozen, true);
    }
  }
}
