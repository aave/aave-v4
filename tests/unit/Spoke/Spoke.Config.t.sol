// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfigTest is SpokeBase {
  function test_spoke_deploy_revertsWith_InvalidHubAddress() public {
    vm.expectRevert(ISpoke.InvalidHubAddress.selector);
    new Spoke(address(0), address(oracle));
  }

  function test_spoke_deploy_revertsWith_InvalidOracleAddress() public {
    vm.expectRevert(ISpoke.InvalidOracleAddress.selector);
    new Spoke(address(hub), address(0));
  }

  function test_updateReserveConfig() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.Reserve memory reserveData = spoke1.getReserve(daiReserveId);

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: 10, // decimals won't get updated
      active: !reserveData.config.active,
      frozen: !reserveData.config.frozen,
      paused: !reserveData.config.paused,
      collateralFactor: reserveData.config.collateralFactor + 1,
      liquidationBonus: reserveData.config.liquidationBonus + 1,
      liquidityPremium: reserveData.config.liquidityPremium + 1,
      liquidationProtocolFee: reserveData.config.liquidationProtocolFee + 1,
      borrowable: !reserveData.config.borrowable,
      collateral: !reserveData.config.collateral
    });
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    reserveData = spoke1.getReserve(daiReserveId);

    assertEq(
      reserveData.config.collateralFactor,
      newReserveConfig.collateralFactor,
      'wrong collateralFactor'
    );
    assertEq(
      reserveData.config.liquidationBonus,
      newReserveConfig.liquidationBonus,
      'wrong liquidationBonus'
    );
    assertEq(
      reserveData.config.liquidityPremium,
      newReserveConfig.liquidityPremium,
      'wrong liquidityPremium'
    );
    assertEq(reserveData.config.borrowable, newReserveConfig.borrowable, 'wrong borrowable');
    assertEq(reserveData.config.collateral, newReserveConfig.collateral, 'wrong collateral');
  }

  function test_updateReserveConfig_fuzz(DataTypes.ReserveConfig memory newReserveConfig) public {
    newReserveConfig.collateralFactor = bound(
      newReserveConfig.collateralFactor,
      0,
      PercentageMath.PERCENTAGE_FACTOR
    );
    newReserveConfig.liquidationBonus = bound(
      newReserveConfig.liquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    );
    newReserveConfig.liquidityPremium = bound(
      newReserveConfig.liquidityPremium,
      0,
      PercentageMath.PERCENTAGE_FACTOR * 10
    );
    newReserveConfig.liquidationProtocolFee = bound(
      newReserveConfig.liquidationProtocolFee,
      0,
      PercentageMath.PERCENTAGE_FACTOR
    );

    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory reserveData = spoke1.getReserve(daiReserveId).config;

    newReserveConfig.decimals = reserveData.decimals; // decimals won't get updated

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    reserveData = spoke1.getReserve(daiReserveId).config;

    _assertReserveConfig(reserveData, newReserveConfig);
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

    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, config);

    config = spoke1.getReserve(daiReserveId).config;
    assertEq(config.decimals, oldDecimals, 'wrong decimals');
  }

  function test_updateReserveConfig_fuzz_cannot_update_decimals(uint256 newDecimals) public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;

    uint256 oldDecimals = config.decimals;
    newDecimals = bound(newDecimals, 0, hub.MAX_ALLOWED_ASSET_DECIMALS());
    vm.assume(newDecimals != oldDecimals);

    // decimals should not update
    config.decimals = newDecimals;

    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, config);

    config = spoke1.getReserve(daiReserveId).config;
    assertEq(config.decimals, oldDecimals, 'wrong decimals');
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
    updateReserveFrozenFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).config.frozen);
    vm.startPrank(SPOKE_ADMIN);

    // disallow when activating
    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    spoke1.setUsingAsCollateral(daiReserveId, true);

    // allow when deactivating
    spoke1.setUsingAsCollateral(daiReserveId, false);
    vm.stopPrank();
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
    assertEq(userData.usingAsCollateral, usingAsCollateral, 'wrong usingAsCollateral');
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

    vm.expectRevert(ISpoke.InvalidReserve.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(reserveId, config);
  }

  function test_updateReserveConfig_revertsWith_InvalidCollateralFactor() public {
    uint256 collateralFactor = PercentageMath.PERCENTAGE_FACTOR + 1;
    test_updateReserveConfig_fuzz_revertsWith_InvalidCollateralFactor(collateralFactor);
  }

  function test_updateReserveConfig_fuzz_revertsWith_InvalidCollateralFactor(
    uint256 collateralFactor
  ) public {
    collateralFactor = bound(
      collateralFactor,
      PercentageMath.PERCENTAGE_FACTOR + 1,
      type(uint256).max
    );

    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserve(daiReserveId).config;
    config.collateralFactor = collateralFactor;

    vm.expectRevert(ISpoke.InvalidCollateralFactor.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, config);
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
      collateralFactor: 10_00,
      liquidationBonus: 110_00,
      liquidityPremium: 10_00,
      liquidationProtocolFee: 10_00,
      borrowable: true,
      collateral: true
    });

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveAdded(reserveId, wethAssetId);
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(wethAssetId, newReserveConfig);

    DataTypes.ReserveConfig memory reserveData = spoke1.getReserve(reserveId).config;

    _assertReserveConfig(reserveData, newReserveConfig);
  }

  function test_addReserve_reverts_invalid_assetId() public {
    uint256 assetId = hub.assetCount(); // invalid assetId

    uint256 reserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: true,
      paused: true,
      collateralFactor: 10_00,
      liquidationBonus: 110_00,
      liquidationProtocolFee: 0,
      liquidityPremium: 10_00,
      borrowable: true,
      collateral: true
    });

    vm.expectRevert(); // error from LH in reading invalid index from assetList array
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(assetId, newReserveConfig);
  }

  function test_addReserve_fuzz_reverts_invalid_assetId(uint256 assetId) public {
    assetId = bound(assetId, hub.assetCount(), type(uint256).max); // invalid assetId

    uint256 reserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: 18,
      active: true,
      frozen: true,
      paused: true,
      collateralFactor: 10_00,
      liquidationBonus: 110_00,
      liquidityPremium: 10_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true
    });

    vm.expectRevert(); // error from LH in reading invalid index from assetList array
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(assetId, newReserveConfig);
  }

  function test_addReserve_revertsWith_InvalidReserveDecimals() public {
    uint256 reserveId = spoke1.reserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: hub.MAX_ALLOWED_ASSET_DECIMALS() + 1, // invalid decimals
      active: true,
      frozen: true,
      paused: true,
      collateralFactor: 10_00,
      liquidationBonus: 110_00,
      liquidityPremium: 10_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true
    });

    vm.expectRevert(ISpoke.InvalidReserveDecimals.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(reserveId, newReserveConfig);
  }

  function test_addReserve_fuzz_revertsWith_InvalidReserveDecimals(
    uint256 reserveId,
    uint256 decimals
  ) public {
    decimals = bound(decimals, hub.MAX_ALLOWED_ASSET_DECIMALS() + 1, type(uint256).max); // invalid decimals
    reserveId = bound(reserveId, 0, spoke1.reserveCount());

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      decimals: decimals,
      active: true,
      frozen: true,
      paused: true,
      collateralFactor: 10_00,
      liquidationBonus: 110_00,
      liquidityPremium: 10_00,
      liquidationProtocolFee: 0,
      borrowable: true,
      collateral: true
    });

    vm.expectRevert(ISpoke.InvalidReserveDecimals.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(reserveId, newReserveConfig);
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

  function _assertReserveConfig(
    DataTypes.ReserveConfig memory reserveConfig,
    DataTypes.ReserveConfig memory newReserveConfig
  ) internal pure {
    assertEq(
      reserveConfig.collateralFactor,
      newReserveConfig.collateralFactor,
      'wrong collateralFactor'
    );
    assertEq(
      reserveConfig.liquidationBonus,
      newReserveConfig.liquidationBonus,
      'wrong liquidationBonus'
    );
    assertEq(
      reserveConfig.liquidityPremium,
      newReserveConfig.liquidityPremium,
      'wrong liquidityPremium'
    );
    assertEq(
      reserveConfig.liquidationProtocolFee,
      newReserveConfig.liquidationProtocolFee,
      'wrong liquidationProtocolFee'
    );
    assertEq(reserveConfig.borrowable, newReserveConfig.borrowable, 'wrong borrowable');
    assertEq(reserveConfig.collateral, newReserveConfig.collateral, 'wrong collateral');
  }
}
