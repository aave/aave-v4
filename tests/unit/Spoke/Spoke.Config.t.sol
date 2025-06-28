// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfigTest is SpokeBase {
  using SafeCast for uint256;

  function test_spoke_deploy_revertsWith_InvalidOracleAddress() public {
    vm.expectRevert(ISpoke.InvalidOracleAddress.selector);
    new Spoke(address(0));
  }

  function test_updateReserveConfig() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserveConfig(daiReserveId);

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: config.decimals, // decimals won't get updated
      active: !config.active,
      frozen: !config.frozen,
      paused: !config.paused,
      liquidationBonus: config.liquidationBonus + 1,
      liquidityPremium: config.liquidityPremium + 1,
      liquidationProtocolFee: config.liquidationProtocolFee + 1,
      borrowable: !config.borrowable,
      collateral: !config.collateral,
      hub: config.hub
    });
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    assertEq(spoke1.getReserveConfig(daiReserveId), newReserveConfig);
  }

  function test_updateReserveConfig_fuzz(DataTypes.ReserveConfig memory newReserveConfig) public {
    newReserveConfig.liquidationBonus = bound(
      newReserveConfig.liquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    );
    newReserveConfig.liquidityPremium = bound(
      newReserveConfig.liquidityPremium,
      0,
      spoke1.MAX_LIQUIDITY_PREMIUM()
    );
    newReserveConfig.liquidationProtocolFee = bound(
      newReserveConfig.liquidationProtocolFee,
      0,
      PercentageMath.PERCENTAGE_FACTOR
    );

    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory reserveData = spoke1.getReserveConfig(daiReserveId);

    newReserveConfig.decimals = reserveData.decimals; // decimals won't get updated
    newReserveConfig.hub = reserveData.hub; // hub won't get updated

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    assertEq(spoke1.getReserveConfig(daiReserveId), newReserveConfig);
  }

  function test_updateReserveConfig_cannot_update_decimals() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;

    uint256 oldDecimals = config.decimals;
    uint256 newDecimals = 12;
    // new decimals value attempted
    assertNotEq(oldDecimals, newDecimals);

    // decimals should not update
    config.decimals = newDecimals;

    vm.expectRevert(ISpoke.InvalidReserve.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, config);
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

  function test_setUsingAsCollateral_revertsWith_CollateralStatusUnchanged() public {
    uint256 daiReserveId = _daiReserveId(spoke1);

    // ensure DAI is allowed as collateral
    updateCollateralFlag(spoke1, daiReserveId, true);
    // Bob not using DAI as collateral
    assertFalse(spoke1.getUsingAsCollateral(daiReserveId, bob), 'bob not using as collateral');

    vm.startPrank(bob);

    // Bob can't change dai collateral status to false, because already false
    vm.expectRevert(ISpoke.CollateralStatusUnchanged.selector);
    spoke1.setUsingAsCollateral(daiReserveId, false);

    // Bob can change dai collateral status to true
    spoke1.setUsingAsCollateral(daiReserveId, true);
    assertTrue(spoke1.getUsingAsCollateral(daiReserveId, bob), 'bob using as collateral');

    // Bob can't change dai collateral status to true, because already true
    vm.expectRevert(ISpoke.CollateralStatusUnchanged.selector);
    spoke1.setUsingAsCollateral(daiReserveId, true);
    vm.stopPrank();
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
    assertEq(spoke1.getUsingAsCollateral(daiReserveId, bob), usingAsCollateral, 'wrong usingAsCollateral');
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

  function test_updateReserveConfig_revertsWith_InvalidReserve() public {
    uint256 invalidReserveId = spoke1.reserveCount();
    test_updateReserveConfig_fuzz_revertsWith_InvalidReserve(
      invalidReserveId,
      PercentageMath.PERCENTAGE_FACTOR
    );
  }

  function test_updateReserveConfig_fuzz_revertsWith_InvalidReserve(
    uint256 reserveId,
    uint256 liquidationBonus
  ) public {
    reserveId = bound(reserveId, spoke1.reserveCount() + 1, type(uint256).max);
    liquidationBonus = bound(liquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);

    DataTypes.ReserveConfig memory config;
    config.liquidationBonus = PercentageMath.PERCENTAGE_FACTOR;
    config.hub = hub;

    vm.expectRevert(ISpoke.InvalidReserve.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(reserveId, config);
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

  function test_updateReserveConfig_revertsWith_InvalidLiquidationBonus() public {
    uint256 liquidationBonus = PercentageMath.PERCENTAGE_FACTOR + 1;
    test_updateReserveConfig_fuzz_revertsWith_InvalidLiquidationBonus(liquidationBonus);
  }

  function test_updateReserveConfig_fuzz_revertsWith_InvalidLiquidationBonus(
    uint256 liquidationBonus
  ) public {
    liquidationBonus = bound(liquidationBonus, 0, PercentageMath.PERCENTAGE_FACTOR - 1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;
    config.liquidationBonus = PercentageMath.PERCENTAGE_FACTOR - 1;

    vm.expectRevert(ISpoke.InvalidLiquidationBonus.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, config);
  }

  function test_updateReserveConfig_revertsWith_InvalidLiquidationProtocolFee() public {
    uint256 liquidationProtocolFee = PercentageMath.PERCENTAGE_FACTOR + 1;

    test_updateReserveConfig_fuzz_revertsWith_InvalidLiquidationProtocolFee(liquidationProtocolFee);
  }

  function test_updateReserveConfig_fuzz_revertsWith_InvalidLiquidationProtocolFee(
    uint256 liquidationProtocolFee
  ) public {
    liquidationProtocolFee = bound(
      liquidationProtocolFee,
      PercentageMath.PERCENTAGE_FACTOR + 1,
      type(uint256).max
    );

    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;
    config.liquidationProtocolFee = liquidationProtocolFee;

    vm.expectRevert(ISpoke.InvalidLiquidationProtocolFee.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, config);
  }

  function test_addReserve() public {
    uint256 reserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: true,
      paused: true,
      liquidationBonus: 110_00,
      liquidityPremium: 10_00,
      liquidationProtocolFee: 10_00,
      borrowable: true,
      collateral: true,
      hub: hub
    });
    DataTypes.DynamicReserveConfig memory newDynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 10_00
    });

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveAdded(reserveId, wethAssetId);
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(wethAssetId, newReserveConfig, newDynReserveConfig);

    assertEq(spoke1.getReserveConfig(reserveId), newReserveConfig);
    assertEq(spoke1.getDynamicReserveConfig(reserveId), newDynReserveConfig);
  }

  function test_addReserve_reverts_invalid_assetId() public {
    uint256 assetId = hub.assetCount(); // invalid assetId

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: true,
      paused: true,
      liquidationBonus: 110_00,
      liquidationProtocolFee: 0,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true,
      hub: hub
    });
    DataTypes.DynamicReserveConfig memory newDynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 10_00
    });

    vm.expectRevert(); // error from LH in reading invalid index from assetList array
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(assetId, newReserveConfig, newDynReserveConfig);
  }

  function test_addReserve_fuzz_reverts_invalid_assetId(uint256 assetId) public {
    assetId = bound(assetId, hub.assetCount(), type(uint256).max); // invalid assetId

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: true,
      paused: true,
      liquidationBonus: 110_00,
      liquidityPremium: 10_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true,
      hub: hub
    });
    DataTypes.DynamicReserveConfig memory newDynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 10_00
    });

    vm.expectRevert(); // error from LH in reading invalid index from assetList array
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(assetId, newReserveConfig, newDynReserveConfig);
  }

  function test_addReserve_revertsWith_InvalidReserveDecimals() public {
    uint256 reserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: hub.MAX_ALLOWED_ASSET_DECIMALS() + 1, // invalid decimals
      active: true,
      frozen: true,
      paused: true,
      liquidationBonus: 110_00,
      liquidityPremium: 10_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true,
      hub: hub
    });
    DataTypes.DynamicReserveConfig memory newDynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 10_00
    });

    vm.expectRevert(ISpoke.InvalidReserveDecimals.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(reserveId, newReserveConfig, newDynReserveConfig);
  }

  function test_addReserve_revertsWith_InvalidHubAddress() public {
    uint256 reserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      hub: ILiquidityHub(address(0)),
      active: true,
      frozen: true,
      paused: true,
      borrowable: true,
      collateral: true,
      decimals: hub.MAX_ALLOWED_ASSET_DECIMALS(),
      liquidationBonus: 110_00,
      liquidityPremium: 10_00,
      liquidationProtocolFee: 0
    });
    DataTypes.DynamicReserveConfig memory newDynReserveConfig = DataTypes.DynamicReserveConfig({
      collateralFactor: 78_00
    });

    vm.expectRevert(ISpoke.InvalidHubAddress.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(reserveId, newReserveConfig, newDynReserveConfig);
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
