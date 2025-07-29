// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfigTest is SpokeBase {
  using SafeCast for uint256;
  using PercentageMath for uint256;

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

  function test_updateOracle_revertsWith_AccessManagedUnauthorized(address caller) public {
    vm.assume(caller != SPOKE_ADMIN && caller != ADMIN);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    spoke1.updateOracle(vm.randomAddress());
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

  function test_updateReservePriceSource_revertsWith_AccessManagedUnauthorized(
    address caller
  ) public {
    vm.assume(caller != SPOKE_ADMIN && caller != ADMIN);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    spoke1.updateReservePriceSource(0, address(0));
  }

  function test_updateReservePriceSource_revertsWith_ReserveNotListed() public {
    uint256 reserveId = vm.randomUint(spoke1.getReserveCount(), type(uint256).max);
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReservePriceSource(reserveId, vm.randomAddress());
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
      paused: !config.paused,
      frozen: !config.frozen,
      borrowable: !config.borrowable,
      collateralRisk: config.collateralRisk + 1
    });
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    assertEq(spoke1.getReserveConfig(daiReserveId), newReserveConfig);
  }

  function test_updateReserveConfig_fuzz(DataTypes.ReserveConfig memory newReserveConfig) public {
    newReserveConfig.collateralRisk = bound(
      newReserveConfig.collateralRisk,
      0,
      spoke1.MAX_COLLATERAL_RISK()
    );

    uint256 daiReserveId = _daiReserveId(spoke1);

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdated(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    assertEq(spoke1.getReserveConfig(daiReserveId), newReserveConfig);
  }

  function test_updateReserveConfig_revertsWith_InvalidCollateralRisk() public {
    uint256 reserveId = _randomReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserveConfig(reserveId);
    config.collateralRisk = vm.randomUint(
      PercentageMath.PERCENTAGE_FACTOR * 10 + 1,
      type(uint256).max
    );

    vm.expectRevert(ISpoke.InvalidCollateralRisk.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(reserveId, config);
  }

  function test_updateReserveConfig_revertsWith_ReserveNotListed() public {
    uint256 reserveId = vm.randomUint(spoke1.getReserveCount() + 1, type(uint256).max);
    DataTypes.ReserveConfig memory config;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(reserveId, config);
  }

  function test_addReserve() public {
    uint256 reserveId = spoke1.getReserveCount();
    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      paused: true,
      frozen: true,
      borrowable: true,
      collateralRisk: 10_00
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
    emit ISpoke.DynamicReserveConfigAdded({
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

  function test_addReserve_fuzz_revertsWith_InvalidAssetId() public {
    uint256 assetId = vm.randomUint(hub.getAssetCount(), type(uint256).max); // invalid assetId

    DataTypes.ReserveConfig memory newReserveConfig = DataTypes.ReserveConfig({
      paused: true,
      frozen: true,
      borrowable: true,
      collateralRisk: 10_00
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
      paused: true,
      frozen: true,
      borrowable: true,
      collateralRisk: 10_00
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
      paused: true,
      frozen: true,
      borrowable: true,
      collateralRisk: 10_00
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
