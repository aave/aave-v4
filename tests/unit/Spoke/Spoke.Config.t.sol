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
    address oracle = makeAddr('AaveOracle');
    vm.expectCall(oracle, abi.encodeCall(IPriceOracle.DECIMALS, ()), 1);
    vm.mockCall(oracle, abi.encodeCall(IPriceOracle.DECIMALS, ()), abi.encode(8));
    SpokeInstance instance = new SpokeInstance(oracle);
    assertEq(address(instance), predictedSpokeAddress, 'predictedSpokeAddress');
    assertEq(instance.ORACLE(), oracle);
    assertNotEq(instance.getLiquidationLogic(), address(0));
  }

  function test_spoke_deploy_reverts_on_InvalidConstructorInput() public {
    vm.expectRevert();
    new SpokeInstance(address(0));
  }

  function test_spoke_deploy_revertsWith_InvalidOracleDecimals() public {
    address oracle = makeAddr('AaveOracle');
    vm.mockCall(oracle, abi.encodeCall(IPriceOracle.DECIMALS, ()), abi.encode(7));
    vm.expectRevert(ISpoke.InvalidOracleDecimals.selector);
    new SpokeInstance(oracle);
  }

  function test_updateReservePriceSource_revertsWith_AccessManagedUnauthorized(
    address caller
  ) public {
    vm.assume(
      caller != SPOKE_ADMIN && caller != ADMIN && caller != _getProxyAdminAddress(address(spoke1))
    );
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
    emit ISpoke.UpdateReservePriceSource(reserveId, reserveSource);
    vm.expectCall(
      address(oracle1),
      abi.encodeCall(IAaveOracle.setReserveSource, (reserveId, reserveSource))
    );
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReservePriceSource(reserveId, reserveSource);
  }

  function test_updateReserveConfig() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    ISpoke.ReserveConfig memory config = spoke1.getReserveConfig(daiReserveId);

    ISpoke.ReserveConfig memory newReserveConfig = ISpoke.ReserveConfig({
      paused: !config.paused,
      frozen: !config.frozen,
      borrowable: !config.borrowable,
      collateralRisk: config.collateralRisk + 1
    });
    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateReserveConfig(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    assertEq(spoke1.getReserveConfig(daiReserveId), newReserveConfig);
  }

  function test_updateReserveConfig_fuzz(ISpoke.ReserveConfig memory newReserveConfig) public {
    newReserveConfig.collateralRisk = bound(
      newReserveConfig.collateralRisk,
      0,
      Constants.MAX_ALLOWED_COLLATERAL_RISK
    ).toUint24();

    uint256 daiReserveId = _daiReserveId(spoke1);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateReserveConfig(daiReserveId, newReserveConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(daiReserveId, newReserveConfig);

    assertEq(spoke1.getReserveConfig(daiReserveId), newReserveConfig);
  }

  function test_updateReserveConfig_revertsWith_InvalidCollateralRisk() public {
    uint256 reserveId = _randomReserveId(spoke1);
    ISpoke.ReserveConfig memory config = spoke1.getReserveConfig(reserveId);
    config.collateralRisk = vm
      .randomUint(PercentageMath.PERCENTAGE_FACTOR * 10 + 1, type(uint24).max)
      .toUint24();

    vm.expectRevert(ISpoke.InvalidCollateralRisk.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(reserveId, config);
  }

  function test_updateReserveConfig_revertsWith_ReserveNotListed() public {
    uint256 reserveId = vm.randomUint(spoke1.getReserveCount() + 1, type(uint256).max);
    ISpoke.ReserveConfig memory config;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateReserveConfig(reserveId, config);
  }

  function test_addReserve() public {
    uint256 reserveId = spoke1.getReserveCount();
    ISpoke.ReserveConfig memory newReserveConfig = ISpoke.ReserveConfig({
      paused: true,
      frozen: true,
      borrowable: true,
      collateralRisk: 10_00
    });
    ISpoke.DynamicReserveConfig memory newDynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 10_00,
      maxLiquidationBonus: 110_00,
      liquidationFee: 10_00
    });

    address reserveSource = _deployMockPriceFeed(spoke1, 1e8);

    vm.expectEmit(address(spoke1));
    emit ISpoke.AddReserve(reserveId, dai2AssetId, address(hub1));
    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateReserveConfig(reserveId, newReserveConfig);
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

  function test_addReserve_fuzz_revertsWith_AssetNotListed() public {
    uint256 assetId = vm.randomUint(hub1.getAssetCount(), Constants.MAX_ALLOWED_ASSET_ID); // non-existing asset id

    ISpoke.ReserveConfig memory newReserveConfig = ISpoke.ReserveConfig({
      paused: true,
      frozen: true,
      borrowable: true,
      collateralRisk: 10_00
    });
    ISpoke.DynamicReserveConfig memory newDynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 10_00,
      maxLiquidationBonus: 110_00,
      liquidationFee: 0
    });

    address reserveSource = _deployMockPriceFeed(spoke1, 1e8);
    vm.expectRevert(ISpoke.AssetNotListed.selector, address(spoke1));
    vm.prank(SPOKE_ADMIN);
    spoke1.addReserve(address(hub1), assetId, reserveSource, newReserveConfig, newDynReserveConfig);
  }

  function test_addReserve_revertsWith_InvalidAddress_oracle() public {
    (ISpoke newSpoke, ) = _deploySpokeWithOracle(ADMIN, address(accessManager), 'New Spoke (USD)');

    ISpoke.ReserveConfig memory newReserveConfig = ISpoke.ReserveConfig({
      paused: true,
      frozen: true,
      borrowable: true,
      collateralRisk: 10_00
    });
    ISpoke.DynamicReserveConfig memory newDynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 10_00,
      maxLiquidationBonus: 110_00,
      liquidationFee: 10_00
    });

    vm.expectRevert(ISpoke.InvalidAddress.selector, address(newSpoke));
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
    ISpoke.ReserveConfig memory newReserveConfig = ISpoke.ReserveConfig({
      paused: true,
      frozen: true,
      borrowable: true,
      collateralRisk: 10_00
    });
    ISpoke.DynamicReserveConfig memory newDynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 10_00,
      maxLiquidationBonus: 110_00,
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

  function test_addReserve_revertsWith_InvalidAssetId() public {
    ISpoke.ReserveConfig memory newReserveConfig = ISpoke.ReserveConfig({
      paused: true,
      frozen: true,
      borrowable: true,
      collateralRisk: 10_00
    });
    ISpoke.DynamicReserveConfig memory newDynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 10_00,
      maxLiquidationBonus: 110_00,
      liquidationFee: 10_00
    });

    vm.expectRevert(ISpoke.InvalidAssetId.selector, address(spoke1));
    vm.prank(ADMIN);
    spoke1.addReserve(
      address(hub1),
      Constants.MAX_ALLOWED_ASSET_ID + 1, // invalid assetId
      address(0),
      newReserveConfig,
      newDynReserveConfig
    );
  }

  function test_updateLiquidationConfig_targetHealthFactor() public {
    uint128 newTargetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD + 1;

    test_updateLiquidationConfig_fuzz_targetHealthFactor(newTargetHealthFactor);
  }

  function test_updateLiquidationConfig_fuzz_targetHealthFactor(
    uint128 newTargetHealthFactor
  ) public {
    newTargetHealthFactor = bound(
      newTargetHealthFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      type(uint128).max
    ).toUint128();

    ISpoke.LiquidationConfig memory liquidationConfig;
    liquidationConfig.targetHealthFactor = newTargetHealthFactor;

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateLiquidationConfig(liquidationConfig);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(liquidationConfig);

    assertEq(
      spoke1.getLiquidationConfig().targetHealthFactor,
      newTargetHealthFactor,
      'wrong target health factor'
    );
  }

  function test_updateLiquidationConfig_liqBonusConfig() public {
    ISpoke.LiquidationConfig memory liquidationConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      healthFactorForMaxBonus: 0.9e18,
      liquidationBonusFactor: 10_00
    });
    test_updateLiquidationConfig_fuzz_liqBonusConfig(liquidationConfig);
  }

  function test_updateLiquidationConfig_fuzz_liqBonusConfig(
    ISpoke.LiquidationConfig memory liquidationConfig
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
    liquidationConfig.targetHealthFactor = bound(
      liquidationConfig.targetHealthFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      type(uint128).max
    ).toUint128();

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateLiquidationConfig(liquidationConfig);
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

  function test_updateLiquidationConfig_revertsWith_InvalidLiquidationConfig_healthFactorForMaxBonus()
    public
  {
    ISpoke.LiquidationConfig memory liquidationConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      healthFactorForMaxBonus: HEALTH_FACTOR_LIQUIDATION_THRESHOLD.toUint64(),
      liquidationBonusFactor: 10_00
    });

    test_updateLiquidationConfig_fuzz_revertsWith_InvalidLiquidationConfig_healthFactorForMaxBonus(
      liquidationConfig
    );
  }

  function test_updateLiquidationConfig_fuzz_revertsWith_InvalidLiquidationConfig_healthFactorForMaxBonus(
    ISpoke.LiquidationConfig memory liquidationConfig
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
    liquidationConfig.targetHealthFactor = bound(
      liquidationConfig.targetHealthFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      type(uint128).max
    ).toUint128(); // valid values

    vm.expectRevert(ISpoke.InvalidLiquidationConfig.selector, address(spoke1));
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(liquidationConfig);
  }

  function test_updateLiquidationConfig_revertsWith_InvalidLiquidationConfig_liquidationBonusFactor()
    public
  {
    ISpoke.LiquidationConfig memory liquidationConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      healthFactorForMaxBonus: 0.9e18,
      liquidationBonusFactor: MAX_LIQUIDATION_BONUS_FACTOR + 1
    });

    test_updateLiquidationConfig_fuzz_revertsWith_InvalidLiquidationConfig_liquidationBonusFactor(
      liquidationConfig
    );
  }

  function test_updateLiquidationConfig_fuzz_revertsWith_InvalidLiquidationConfig_liquidationBonusFactor(
    ISpoke.LiquidationConfig memory liquidationConfig
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
    liquidationConfig.targetHealthFactor = bound(
      liquidationConfig.targetHealthFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      type(uint128).max
    ).toUint128(); // valid values

    vm.expectRevert(ISpoke.InvalidLiquidationConfig.selector, address(spoke1));
    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(liquidationConfig);
  }
}
