// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfigTest is SpokeBase {
  using SafeCast for uint256;
  using PercentageMathExtended for uint256;

  function test_spoke_deploy() public {
    address predictedSpokeAddress = vm.computeCreateAddress(
      address(this),
      vm.getNonce(address(this))
    );
    vm.expectEmit(predictedSpokeAddress);
    emit ISpoke.LiquidationConfigUpdated(
      DataTypes.LiquidationConfig({
        closeFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
        healthFactorForMaxBonus: 0,
        liquidationBonusFactor: 0
      })
    );
    new Spoke(address(accessManager));
  }

  function test_updateOracle_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spoke1.updateOracle(address(0));
  }

  function test_updateOracle_revertsWith_InvalidOracle() public {
    vm.expectRevert(ISpoke.InvalidOracle.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateOracle(address(0));
  }

  function test_updateOracle() public {
    address newOracle = address(new AaveOracle(SPOKE_ADMIN, 18, 'New Aave Oracle'));
    vm.expectEmit(address(spoke1));
    emit ISpoke.OracleUpdated(newOracle);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateOracle(newOracle);
  }

  function test_updateReservePriceSource_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spoke1.updateReservePriceSource(0, address(0));
  }

  function test_updateReservePriceSource_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.getReserveCount();
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReservePriceSource(reserveId, address(0));
  }

  function test_updateReservePriceSource() public {
    uint256 reserveId = 0;
    address reserveSource = _deployMockPriceFeed(spoke1, 1e8);
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReservePriceSourceUpdated(reserveId, reserveSource);
    vm.expectCall(
      address(oracle1),
      abi.encodeCall(IAaveOracle.setReserveSource, (reserveId, reserveSource))
    );
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReservePriceSource(reserveId, reserveSource);
  }

  function test_updateReserveConfig() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserveConfig(daiReserveId);

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      active: !config.active,
      frozen: !config.frozen,
      paused: !config.paused,
      liquidityPremium: config.liquidityPremium + 1,
      borrowable: !config.borrowable,
      collateral: !config.collateral
    });
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    assertEq(spoke1.getReserveConfig(daiReserveId), newReserveConfig);
  }

  function test_updateReserveConfig_fuzz(DataTypes.ReserveConfig memory newReserveConfig) public {
    newReserveConfig.liquidityPremium = bound(
      newReserveConfig.liquidityPremium,
      0,
      spoke1.MAX_LIQUIDITY_PREMIUM()
    );

    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory reserveData = spoke1.getReserveConfig(daiReserveId);

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    assertEq(spoke1.getReserveConfig(daiReserveId), newReserveConfig);
  }

  function test_updateDynamicReserveConfig_fuzz(
    DataTypes.DynamicReserveConfig memory newConfig
  ) public {
    newConfig.liquidationFee = bound(
      newConfig.liquidationFee,
      0,
      PercentageMathExtended.PERCENTAGE_FACTOR
    );
    newConfig.collateralFactor = uint16(bound(newConfig.collateralFactor, 0, 80_00));
    newConfig.liquidationBonus = bound(
      newConfig.liquidationBonus,
      PercentageMathExtended.PERCENTAGE_FACTOR,
      125_00
    );

    uint256 daiReserveId = _daiReserveId(spoke1);
    uint16 dynamicConfigKey = _nextDynamicConfigKey(spoke1, daiReserveId);

    vm.expectEmit(address(spoke1));
    emit ISpoke.DynamicReserveConfigUpdated(daiReserveId, dynamicConfigKey, newConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(daiReserveId, newConfig);

    assertEq(spoke1.getDynamicReserveConfig(daiReserveId), newConfig);
  }

  function test_setUsingAsCollateral_revertsWith_ReserveCannotBeUsedAsCollateral() public {
    bool newCollateralFlag = false;
    bool usingAsCollateral = true;
    uint256 daiReserveId = _daiReserveId(spoke1);
    updateCollateralFlag(spoke1, daiReserveId, newCollateralFlag);

    vm.expectRevert(
      abi.encodeWithSelector(ISpoke.ReserveCannotBeUsedAsCollateral.selector, daiReserveId)
    );
    vm.prank(SPOKE_ADMIN);
    spoke1.setUsingAsCollateral(daiReserveId, usingAsCollateral);
  }

  function test_setUsingAsCollateral_revertsWith_ReserveFrozen() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    vm.prank(alice);
    spoke1.setUsingAsCollateral(daiReserveId, true);

    assertTrue(spoke1.getUsingAsCollateral(daiReserveId, alice), 'alice using as collateral');
    assertFalse(spoke1.getUsingAsCollateral(daiReserveId, bob), 'bob not using as collateral');

    updateReserveFrozenFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.frozen, 'reserve status frozen');

    // disallow when activating
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    vm.prank(bob);
    spoke1.setUsingAsCollateral(daiReserveId, true);

    // allow when deactivating
    vm.prank(alice);
    spoke1.setUsingAsCollateral(daiReserveId, false);

    assertFalse(
      spoke1.getUsingAsCollateral(daiReserveId, alice),
      'alice deactivated using as collateral frozen reserve'
    );
  }

  function test_setUsingAsCollateral_revertsWith_ReserveNotActive() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    updateReserveActiveFlag(spoke1, daiReserveId, false);
    assertFalse(spoke1.getReserve(daiReserveId).config.active);

    vm.expectRevert(ISpoke.ReserveNotActive.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.setUsingAsCollateral(daiReserveId, true);
  }

  function test_setUsingAsCollateral_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.setUsingAsCollateral(daiReserveId, true);
  }

  /// no action taken when collateral status is unchanged
  function test_setUsingAsCollateral_collateralStatusUnchanged() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    // ensure DAI is allowed as collateral
    updateCollateralFlag(spoke1, daiReserveId, true);

    // slight update in collateral factor so user is subject to dynamic risk config refresh
    updateCollateralFactor(spoke1, daiReserveId, _getCollateralFactor(spoke1, daiReserveId) + 1_00);
    // slight update liquidity premium so user is subject to risk premium refresh
    updateLiquidityPremium(spoke1, daiReserveId, _getLiquidityPremium(spoke1, daiReserveId) + 1_00);

    // Bob not using DAI as collateral
    assertFalse(spoke1.getUsingAsCollateral(daiReserveId, bob), 'bob not using as collateral');

    // No action taken, because collateral status is already false
    DynamicConfig[] memory bobDynConfig = _getUserDynConfigKeys(spoke1, bob);
    uint256 bobRp = _getUserRpStored(spoke1, daiReserveId, bob);

    vm.recordLogs();
    vm.prank(bob);
    spoke1.setUsingAsCollateral(daiReserveId, false);
    _assertEventNotEmitted(ISpoke.UsingAsCollateral.selector);

    assertFalse(spoke1.getUsingAsCollateral(daiReserveId, bob));
    assertEq(_getUserRpStored(spoke1, daiReserveId, bob), bobRp);
    assertEq(_getUserDynConfigKeys(spoke1, bob), bobDynConfig);

    // Bob can change dai collateral status to true
    vm.prank(bob);
    spoke1.setUsingAsCollateral(daiReserveId, true);
    assertTrue(spoke1.getUsingAsCollateral(daiReserveId, bob), 'bob using as collateral');

    // slight update in collateral factor so user is subject to dynamic risk config refresh
    updateCollateralFactor(spoke1, daiReserveId, _getCollateralFactor(spoke1, daiReserveId) + 1_00);
    // slight update liquidity premium so user is subject to risk premium refresh
    updateLiquidityPremium(spoke1, daiReserveId, _getLiquidityPremium(spoke1, daiReserveId) + 1_00);

    // No action taken, because collateral status is already true
    bobDynConfig = _getUserDynConfigKeys(spoke1, bob);
    bobRp = _getUserRpStored(spoke1, daiReserveId, bob);

    vm.recordLogs();
    vm.prank(bob);
    spoke1.setUsingAsCollateral(daiReserveId, true);
    _assertEventNotEmitted(ISpoke.UsingAsCollateral.selector);

    assertTrue(spoke1.getUsingAsCollateral(daiReserveId, bob));
    assertEq(_getUserRpStored(spoke1, daiReserveId, bob), bobRp);
    assertEq(_getUserDynConfigKeys(spoke1, bob), bobDynConfig);
  }

  function test_setUsingAsCollateral() public {
    bool newCollateralFlag = true;
    bool usingAsCollateral = true;
    uint256 daiAmount = 100e18;

    uint256 daiReserveId = _daiReserveId(spoke1);

    // ensure DAI is allowed as collateral
    updateCollateralFlag(spoke1, daiReserveId, newCollateralFlag);

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, daiAmount);
    Utils.supply(spoke1, daiReserveId, bob, daiAmount, bob);

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit ISpoke.UsingAsCollateral(daiReserveId, bob, usingAsCollateral);
    spoke1.setUsingAsCollateral(daiReserveId, usingAsCollateral);

    DataTypes.UserPosition memory userData = spoke1.getUserPosition(daiReserveId, bob);
    assertEq(
      spoke1.getUsingAsCollateral(daiReserveId, bob),
      usingAsCollateral,
      'wrong usingAsCollateral'
    );
  }

  function test_updateReserveConfig_revertsWith_InvalidLiquidityPremium() public {
    uint256 liquidityPremium = PercentageMath.PERCENTAGE_FACTOR * 10 + 1;
    test_updateReserveConfig_fuzz_revertsWith_InvalidLiquidityPremium(liquidityPremium);
  }

  function test_updateReserveConfig_fuzz_revertsWith_InvalidLiquidityPremium(
    uint256 liquidityPremium
  ) public {
    liquidityPremium = bound(
      liquidityPremium,
      PercentageMath.PERCENTAGE_FACTOR * 10 + 1,
      type(uint256).max
    );

    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;

    config.liquidityPremium = liquidityPremium;

    vm.expectRevert(ISpoke.InvalidLiquidityPremium.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, config);
  }

  function test_updateReserveConfig_revertsWith_ReserveNotListed() public {
    uint256 invalidReserveId = spoke1.getReserveCount();
    test_updateReserveConfig_fuzz_revertsWith_ReserveNotListed(invalidReserveId);
  }

  function test_updateReserveConfig_fuzz_revertsWith_ReserveNotListed(uint256 reserveId) public {
    reserveId = bound(reserveId, spoke1.getReserveCount() + 1, type(uint256).max);

    DataTypes.ReserveConfig memory config;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(reserveId, config);
  }

  function test_updateDynamicReserveConfig_revertsWithInvalidLiquidationBonus() public {
    uint256 liquidationBonus = PercentageMath.PERCENTAGE_FACTOR - 1;

    test_updateDynamicReserveConfig_fuzz_revertsWith_InvalidLiquidationBonus(liquidationBonus);
  }

  function test_updateDynamicReserveConfig_fuzz_revertsWith_InvalidLiquidationBonus(
    uint256 liquidationBonus
  ) public {
    liquidationBonus = bound(liquidationBonus, 0, PercentageMath.PERCENTAGE_FACTOR - 1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(daiReserveId);
    config.liquidationBonus = liquidationBonus;

    vm.expectRevert(ISpoke.InvalidLiquidationBonus.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(daiReserveId, config);
  }

  function test_updateDynamicReserveConfig_fuzz_revertsWith_InvalidCollateralFactor(
    uint256 collateralFactor
  ) public {
    collateralFactor = bound(
      collateralFactor,
      PercentageMath.PERCENTAGE_FACTOR + 1,
      type(uint16).max
    );

    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(daiReserveId);
    config.collateralFactor = collateralFactor.toUint16();

    vm.expectRevert(ISpoke.InvalidCollateralFactor.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(daiReserveId, config);
  }

  function test_updateDynamicReserveConfig_revertsWith_IncompatibleCollateralFactorAndLiquidationBonus()
    public
  {
    // This config makes it so cf * lb > 100%
    test_updateDynamicReserveConfig_fuzz_revertsWith_IncompatibleCollateralFactorAndLiquidationBonus({
      collateralFactor: 95_00,
      liquidationBonus: 110_00
    });
  }

  function test_updateDynamicReserveConfig_fuzz_revertsWith_IncompatibleCollateralFactorAndLiquidationBonus(
    uint256 collateralFactor,
    uint256 liquidationBonus
  ) public {
    // Force config such that cf * lb > 100%
    collateralFactor = bound(collateralFactor, 70_00, PercentageMath.PERCENTAGE_FACTOR);
    liquidationBonus = bound(
      liquidationBonus,
      PercentageMath.PERCENTAGE_FACTOR.percentDivUp(collateralFactor) + 1,
      MAX_LIQUIDATION_BONUS
    );

    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(daiReserveId);
    config.collateralFactor = collateralFactor.toUint16();
    config.liquidationBonus = liquidationBonus;

    vm.expectRevert(ISpoke.IncompatibleCollateralFactorAndLiquidationBonus.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(daiReserveId, config);
  }

  function test_updateDynamicReserveConfig_revertsWith_InvalidLiquidationFee() public {
    uint256 liquidationFee = PercentageMath.PERCENTAGE_FACTOR + 1;

    test_updateDynamicReserveConfig_fuzz_revertsWith_InvalidLiquidationFee(liquidationFee);
  }

  function test_updateDynamicReserveConfig_fuzz_revertsWith_InvalidLiquidationFee(
    uint256 liquidationFee
  ) public {
    liquidationFee = bound(liquidationFee, PercentageMath.PERCENTAGE_FACTOR + 1, type(uint256).max);

    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(daiReserveId);
    config.liquidationFee = liquidationFee;

    vm.expectRevert(ISpoke.InvalidLiquidationFee.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(daiReserveId, config);
  }

  function test_addReserve() public {
    uint256 reserveId = spoke1.getReserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: true,
      paused: true,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true
    });
    DataTypes.DynamicReserveConfig memory newDynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 10_00,
      liquidationBonus: 110_00,
      liquidationFee: 10_00
    });

    address reserveSource = _deployMockPriceFeed(spoke1, 2000e8);

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveAdded(reserveId, wethAssetId, address(hub));
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(reserveId, newReserveConfig);
    vm.expectEmit(address(spoke1));
    emit ISpoke.DynamicReserveConfigUpdated({
      reserveId: reserveId,
      configKey: 0,
      config: newDynReserveConfig
    });

    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(
      address(hub),
      wethAssetId,
      reserveSource,
      newReserveConfig,
      newDynReserveConfig
    );

    assertEq(spoke1.getReserveConfig(reserveId), newReserveConfig);
    assertEq(spoke1.getDynamicReserveConfig(reserveId), newDynReserveConfig);
  }

  function test_addReserve_reverts_invalid_assetId() public {
    uint256 assetId = hub.getAssetCount(); // invalid assetId

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: true,
      paused: true,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true
    });
    DataTypes.DynamicReserveConfig memory newDynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 10_00,
      liquidationBonus: 110_00,
      liquidationFee: 0
    });

    address reserveSource = _deployMockPriceFeed(spoke1, 1e8);
    vm.expectRevert(ISpoke.AssetNotListed.selector, address(spoke1));
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(address(hub), assetId, reserveSource, newReserveConfig, newDynReserveConfig);
  }

  function test_addReserve_fuzz_reverts_invalid_assetId(uint256 assetId) public {
    assetId = bound(assetId, hub.getAssetCount(), type(uint256).max); // invalid assetId

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: true,
      paused: true,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true
    });
    DataTypes.DynamicReserveConfig memory newDynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 10_00,
      liquidationBonus: 110_00,
      liquidationFee: 0
    });

    address reserveSource = _deployMockPriceFeed(spoke1, 1e8);

    vm.expectRevert(ISpoke.AssetNotListed.selector, address(spoke1));
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(address(hub), assetId, reserveSource, newReserveConfig, newDynReserveConfig);
  }

  function test_addReserve_revertsWith_InvalidOracle() public {
    Spoke newSpoke = new Spoke(address(accessManager));

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      active: true,
      frozen: true,
      paused: true,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true
    });
    DataTypes.DynamicReserveConfig memory newDynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 10_00,
      liquidationBonus: 110_00,
      liquidationFee: 10_00
    });

    vm.expectRevert(ISpoke.InvalidOracle.selector);
    vm.prank(ADMIN);
    newSpoke.addReserve(
      address(hub),
      wethAssetId,
      address(0),
      newReserveConfig,
      newDynReserveConfig
    );
  }

  function test_updateLiquidationConfig_closeFactor() public {
    uint256 newCloseFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD + 1;

    test_updateLiquidationConfig_fuzz_closeFactor(newCloseFactor);
  }

  function test_updateLiquidationConfig_fuzz_closeFactor(uint256 newCloseFactor) public {
    newCloseFactor = bound(newCloseFactor, HEALTH_FACTOR_LIQUIDATION_THRESHOLD, type(uint256).max);

    DataTypes.LiquidationConfig memory liquidationConfig;
    liquidationConfig.closeFactor = newCloseFactor;

    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationConfigUpdated(liquidationConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(liquidationConfig);

    assertEq(spoke1.getLiquidationConfig().closeFactor, newCloseFactor, 'wrong close factor');
  }

  function test_updateLiquidationConfig_liqBonusConfig() public {
    DataTypes.LiquidationConfig memory liquidationConfig = DataTypes.LiquidationConfig({
      closeFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      healthFactorForMaxBonus: 0.9e18,
      liquidationBonusFactor: 10_00
    });
    test_updateLiquidationConfig_fuzz_liqBonusConfig(liquidationConfig);
  }

  function test_updateLiquidationConfig_fuzz_liqBonusConfig(
    DataTypes.LiquidationConfig memory liquidationConfig
  ) public {
    liquidationConfig.healthFactorForMaxBonus = bound(
      liquidationConfig.healthFactorForMaxBonus,
      0,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    liquidationConfig.liquidationBonusFactor = bound(
      liquidationConfig.liquidationBonusFactor,
      0,
      MAX_LIQUIDATION_BONUS_FACTOR
    );
    liquidationConfig.closeFactor = bound(
      liquidationConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      type(uint256).max
    );

    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationConfigUpdated(liquidationConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(liquidationConfig);

    assertEq(
      spoke1.getLiquidationConfig().healthFactorForMaxBonus,
      liquidationConfig.healthFactorForMaxBonus,
      'wrong healthFactorForMaxBonus'
    );
    assertEq(
      spoke1.getLiquidationConfig().liquidationBonusFactor,
      liquidationConfig.liquidationBonusFactor,
      'wrong liquidationBonusFactor'
    );
  }

  function test_updateLiquidationConfig_revertsWith_InvalidHealthFactorForMaxBonus() public {
    DataTypes.LiquidationConfig memory liquidationConfig = DataTypes.LiquidationConfig({
      closeFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      healthFactorForMaxBonus: HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      liquidationBonusFactor: 10_00
    });

    test_updateLiquidationConfig_fuzz_revertsWith_InvalidHealthFactorForMaxBonus(liquidationConfig);
  }

  function test_updateLiquidationConfig_fuzz_revertsWith_InvalidHealthFactorForMaxBonus(
    DataTypes.LiquidationConfig memory liquidationConfig
  ) public {
    liquidationConfig.healthFactorForMaxBonus = bound(
      liquidationConfig.healthFactorForMaxBonus,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      type(uint256).max
    );
    liquidationConfig.liquidationBonusFactor = bound(
      liquidationConfig.liquidationBonusFactor,
      0,
      MAX_LIQUIDATION_BONUS_FACTOR
    );
    liquidationConfig.closeFactor = bound(
      liquidationConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      type(uint256).max
    ); // valid values

    vm.expectRevert(ISpoke.InvalidHealthFactorForMaxBonus.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(liquidationConfig);
  }

  function test_updateLiquidationConfig_revertsWith_InvalidLiquidationBonusFactor() public {
    DataTypes.LiquidationConfig memory liquidationConfig = DataTypes.LiquidationConfig({
      closeFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      healthFactorForMaxBonus: 0.9e18,
      liquidationBonusFactor: MAX_LIQUIDATION_BONUS_FACTOR + 1
    });

    test_updateVariableLiquidationBonusConfig_fuzz_revertsWith_InvalidLiquidationBonusFactor(
      liquidationConfig
    );
  }

  function test_updateVariableLiquidationBonusConfig_fuzz_revertsWith_InvalidLiquidationBonusFactor(
    DataTypes.LiquidationConfig memory liquidationConfig
  ) public {
    liquidationConfig.healthFactorForMaxBonus = bound(
      liquidationConfig.healthFactorForMaxBonus,
      0,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    liquidationConfig.liquidationBonusFactor = bound(
      liquidationConfig.liquidationBonusFactor,
      MAX_LIQUIDATION_BONUS_FACTOR + 1,
      type(uint256).max
    );
    liquidationConfig.closeFactor = bound(
      liquidationConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      type(uint256).max
    ); // valid values

    vm.expectRevert(ISpoke.InvalidLiquidationBonusFactor.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(liquidationConfig);
  }
}
