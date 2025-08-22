// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeConfigTest is SpokeBase {
  using SafeCast for *;
  using PercentageMath for uint256;

  function test_spoke_deploy() public {
    address predictedSpokeAddress = vm.computeCreateAddress(
      address(this),
      vm.getNonce(address(this))
    );
    vm.expectEmit(predictedSpokeAddress);
    emit ISpoke.LiquidationConfigUpdate(
      DataTypes.LiquidationConfig({
        closeFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
        healthFactorForMaxBonus: 0,
        liquidationBonusFactor: 0
      })
    );
    new Spoke(address(accessManager));
  }

  function test_spoke_deploy_revertsWith_InvalidAddress() public {
    vm.expectRevert(ISpoke.InvalidAddress.selector);
    new Spoke(address(0));
  }

  function test_updateOracle_revertsWith_AccessManagedUnauthorized(address caller) public {
    vm.assume(caller != SPOKE_ADMIN && caller != ADMIN);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
    );
    vm.prank(caller);
    spoke1.updateOracle(vm.randomAddress());
  }

  function test_updateOracle_revertsWith_InvalidOracle_AddressZero() public {
    vm.expectRevert(ISpoke.InvalidOracle.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateOracle(address(0));
  }

  function test_updateOracle_revertsWith_InvalidOracle_DecimalsMismatch() public {
    address newOracle = address(new AaveOracle(SPOKE_ADMIN, 18, 'New Aave Oracle'));
    vm.expectRevert(ISpoke.InvalidOracle.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateOracle(newOracle);
  }

  function test_updateOracle() public {
    address newOracle = address(new AaveOracle(SPOKE_ADMIN, 8, 'New Aave Oracle'));
    vm.expectCall(newOracle, abi.encodeCall(IPriceOracle.DECIMALS, ()));
    vm.expectEmit(address(spoke1));
    emit ISpoke.OracleUpdate(newOracle);
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
    emit ISpoke.ReservePriceSourceUpdate(reserveId, reserveSource);
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
    emit ISpoke.ReserveConfigUpdate(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    assertEq(spoke1.getReserveConfig(daiReserveId), newReserveConfig);
  }

  function test_updateReserveConfig_fuzz(DataTypes.ReserveConfig memory newReserveConfig) public {
    newReserveConfig.collateralRisk = bound(
      newReserveConfig.collateralRisk,
      0,
      Constants.MAX_COLLATERAL_RISK
    ).toUint24();

    uint256 daiReserveId = _daiReserveId(spoke1);

    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdate(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    assertEq(spoke1.getReserveConfig(daiReserveId), newReserveConfig);
  }

  function test_updateReserveConfig_revertsWith_InvalidCollateralRisk() public {
    uint256 reserveId = _randomReserveId(spoke1);
    DataTypes.ReserveConfig memory config = spoke1.getReserveConfig(reserveId);
    config.collateralRisk = vm
      .randomUint(PercentageMath.PERCENTAGE_FACTOR * 10 + 1, type(uint24).max)
      .toUint24();

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

    address reserveSource = _deployMockPriceFeed(spoke1, 1e8);

    vm.expectEmit(address(spoke1));
    emit ISpoke.AddReserve(reserveId, dai2AssetId, address(hub1));
    vm.expectEmit(address(spoke1));
    emit ISpoke.ReserveConfigUpdate(reserveId, newReserveConfig);
    vm.expectEmit(address(spoke1));
    emit ISpoke.AddDynamicReserveConfig({
      reserveId: reserveId,
      configKey: 0,
      config: newDynReserveConfig
    });

    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(
      address(hub1),
      dai2AssetId,
      reserveSource,
      newReserveConfig,
      newDynReserveConfig
    );

    assertEq(spoke1.getReserveConfig(reserveId), newReserveConfig);
    assertEq(spoke1.getDynamicReserveConfig(reserveId), newDynReserveConfig);
  }

  function test_addReserve_fuzz_revertsWith_InvalidAssetId() public {
    uint256 assetId = vm.randomUint(hub1.getAssetCount(), type(uint256).max); // invalid assetId

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
    spoke1.addReserve(address(hub1), assetId, reserveSource, newReserveConfig, newDynReserveConfig);
  }

  function test_addReserve_fuzz_reverts_invalid_assetId(uint256 assetId) public {
    assetId = bound(assetId, hub1.getAssetCount(), UINT256_MAX); // invalid assetId

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
    spoke1.addReserve(address(hub1), assetId, reserveSource, newReserveConfig, newDynReserveConfig);
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
      address(hub1),
      wethAssetId,
      address(0),
      newReserveConfig,
      newDynReserveConfig
    );
  }

  function test_addReserve_revertsWith_ReserveExists() public {
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

    address reserveSource = _deployMockPriceFeed(spoke1, 1e8);

    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(
      address(hub1),
      dai2AssetId,
      reserveSource,
      newReserveConfig,
      newDynReserveConfig
    );

    vm.expectRevert(ISpoke.ReserveExists.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(
      address(hub1),
      dai2AssetId,
      reserveSource,
      newReserveConfig,
      newDynReserveConfig
    );
  }

  function test_updateLiquidationConfig_closeFactor() public {
    uint128 newCloseFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD + 1;

    test_updateLiquidationConfig_fuzz_closeFactor(newCloseFactor);
  }

  function test_updateLiquidationConfig_fuzz_closeFactor(uint128 newCloseFactor) public {
    newCloseFactor = bound(newCloseFactor, HEALTH_FACTOR_LIQUIDATION_THRESHOLD, type(uint128).max)
      .toUint128();

    DataTypes.LiquidationConfig memory liquidationConfig;
    liquidationConfig.closeFactor = newCloseFactor;

    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationConfigUpdate(liquidationConfig);
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
    ).toUint64();
    liquidationConfig.liquidationBonusFactor = bound(
      liquidationConfig.liquidationBonusFactor,
      0,
      MAX_LIQUIDATION_BONUS_FACTOR
    ).toUint16();
    liquidationConfig.closeFactor = bound(
      liquidationConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      type(uint128).max
    ).toUint128();

    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationConfigUpdate(liquidationConfig);
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
      healthFactorForMaxBonus: HEALTH_FACTOR_LIQUIDATION_THRESHOLD.toUint64(),
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
      type(uint64).max
    ).toUint64();
    liquidationConfig.liquidationBonusFactor = bound(
      liquidationConfig.liquidationBonusFactor,
      0,
      MAX_LIQUIDATION_BONUS_FACTOR
    ).toUint16();
    liquidationConfig.closeFactor = bound(
      liquidationConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      type(uint128).max
    ).toUint128(); // valid values

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
    ).toUint64();
    liquidationConfig.liquidationBonusFactor = bound(
      liquidationConfig.liquidationBonusFactor,
      MAX_LIQUIDATION_BONUS_FACTOR + 1,
      type(uint16).max
    ).toUint16();
    liquidationConfig.closeFactor = bound(
      liquidationConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      type(uint128).max
    ).toUint128(); // valid values

    vm.expectRevert(ISpoke.InvalidLiquidationBonusFactor.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(liquidationConfig);
  }
}
