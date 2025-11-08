// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeGettersTest is SpokeBase {
  using LiquidationLogic for ISpoke.LiquidationConfig;
  using SafeCast for uint256;

  ISpoke.LiquidationConfig internal _config;

  ISpoke internal spoke;

  function setUp() public virtual override {
    super.setUp();

    // Deploy new spoke without setting the liquidation config
    (spoke, ) = _deploySpokeWithOracle(ADMIN, address(accessManager), 'New Spoke (USD)');
    setUpRoles(hub1, spoke, accessManager);

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });

    spokeInfo[spoke].weth.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 15_00
    });
    spokeInfo[spoke].weth.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 105_00,
      liquidationFee: 10_00
    });
    spokeInfo[spoke].wbtc.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 15_00
    });
    spokeInfo[spoke].wbtc.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 75_00,
      maxLiquidationBonus: 103_00,
      liquidationFee: 15_00
    });
    spokeInfo[spoke].dai.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 20_00
    });
    spokeInfo[spoke].dai.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 78_00,
      maxLiquidationBonus: 102_00,
      liquidationFee: 10_00
    });
    spokeInfo[spoke].usdx.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 50_00
    });
    spokeInfo[spoke].usdx.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 78_00,
      maxLiquidationBonus: 101_00,
      liquidationFee: 12_00
    });
    spokeInfo[spoke].usdy.reserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      collateralRisk: 50_00
    });
    spokeInfo[spoke].usdy.dynReserveConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 78_00,
      maxLiquidationBonus: 101_50,
      liquidationFee: 15_00
    });

    vm.startPrank(ADMIN);

    spokeInfo[spoke].weth.reserveId = spoke.addReserve(
      address(hub1),
      wethAssetId,
      _deployMockPriceFeed(spoke, 2000e8),
      spokeInfo[spoke].weth.reserveConfig,
      spokeInfo[spoke].weth.dynReserveConfig
    );
    spokeInfo[spoke].wbtc.reserveId = spoke.addReserve(
      address(hub1),
      wbtcAssetId,
      _deployMockPriceFeed(spoke, 50_000e8),
      spokeInfo[spoke].wbtc.reserveConfig,
      spokeInfo[spoke].wbtc.dynReserveConfig
    );
    spokeInfo[spoke].dai.reserveId = spoke.addReserve(
      address(hub1),
      daiAssetId,
      _deployMockPriceFeed(spoke, 1e8),
      spokeInfo[spoke].dai.reserveConfig,
      spokeInfo[spoke].dai.dynReserveConfig
    );
    spokeInfo[spoke].usdx.reserveId = spoke.addReserve(
      address(hub1),
      usdxAssetId,
      _deployMockPriceFeed(spoke, 1e8),
      spokeInfo[spoke].usdx.reserveConfig,
      spokeInfo[spoke].usdx.dynReserveConfig
    );
    spokeInfo[spoke].usdy.reserveId = spoke.addReserve(
      address(hub1),
      usdyAssetId,
      _deployMockPriceFeed(spoke, 1e8),
      spokeInfo[spoke].usdy.reserveConfig,
      spokeInfo[spoke].usdy.dynReserveConfig
    );

    hub1.addSpoke(wethAssetId, address(spoke), spokeConfig);
    hub1.addSpoke(wbtcAssetId, address(spoke), spokeConfig);
    hub1.addSpoke(daiAssetId, address(spoke), spokeConfig);
    hub1.addSpoke(usdxAssetId, address(spoke), spokeConfig);
    hub1.addSpoke(usdyAssetId, address(spoke), spokeConfig);

    vm.stopPrank();
  }

  function test_getLiquidationBonus_notConfigured() public {
    uint256 reserveId = _daiReserveId(spoke);
    uint256 healthFactor = WadRayMath.WAD;
    test_getLiquidationBonus_fuzz_notConfigured(reserveId, healthFactor);
  }

  function test_getLiquidationBonus_fuzz_notConfigured(
    uint256 reserveId,
    uint256 healthFactor
  ) public {
    reserveId = bound(reserveId, 0, spoke.getReserveCount() - 1);
    healthFactor = bound(healthFactor, 0, HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    uint256 liqBonus = spoke.getLiquidationBonus(reserveId, bob, healthFactor);

    _config = spoke.getLiquidationConfig();
    assertEq(
      _config,
      ISpoke.LiquidationConfig({
        targetHealthFactor: WadRayMath.WAD.toUint128(),
        healthFactorForMaxBonus: 0,
        liquidationBonusFactor: 0
      })
    );

    assertEq(
      liqBonus,
      LiquidationLogic.calculateLiquidationBonus({
        healthFactorForMaxBonus: 0,
        liquidationBonusFactor: 0,
        healthFactor: healthFactor,
        maxLiquidationBonus: spoke.getDynamicReserveConfig(reserveId).maxLiquidationBonus
      }),
      'calc should match'
    );
  }

  function test_getLiquidationBonus_configured() public {
    uint256 reserveId = _daiReserveId(spoke);
    uint256 healthFactor = WadRayMath.WAD;
    test_getLiquidationBonus_fuzz_configured(reserveId, healthFactor, 40_00, 0.9e18);
  }

  function test_getLiquidationBonus_fuzz_configured(
    uint256 reserveId,
    uint256 healthFactor,
    uint16 liquidationBonusFactor,
    uint64 healthFactorForMaxBonus
  ) public {
    reserveId = bound(reserveId, 0, spoke.getReserveCount() - 1);
    healthFactor = bound(healthFactor, 0, HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();
    healthFactorForMaxBonus = bound(
      healthFactorForMaxBonus,
      0,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    ).toUint64();

    ISpoke.LiquidationConfig memory config = ISpoke.LiquidationConfig({
      targetHealthFactor: WadRayMath.WAD.toUint128(),
      healthFactorForMaxBonus: healthFactorForMaxBonus,
      liquidationBonusFactor: liquidationBonusFactor
    });
    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(config);
    _config = spoke.getLiquidationConfig();

    uint256 liqBonus = spoke.getLiquidationBonus(reserveId, bob, healthFactor);

    assertEq(
      liqBonus,
      LiquidationLogic.calculateLiquidationBonus({
        healthFactorForMaxBonus: healthFactorForMaxBonus,
        liquidationBonusFactor: liquidationBonusFactor,
        healthFactor: healthFactor,
        maxLiquidationBonus: spoke.getDynamicReserveConfig(reserveId).maxLiquidationBonus
      }),
      'calc should match'
    );
  }

  /// @dev Basic user flow and check accounting getters working properly
  function test_protocol_getters() public {
    uint256 reserveId = _daiReserveId(spoke);
    uint256 assetId = daiAssetId;
    uint256 supplyAmount = 10_000e18;
    vm.prank(alice);
    tokenList.dai.approve(address(spoke), supplyAmount);
    Utils.supplyCollateral(spoke, reserveId, alice, supplyAmount, alice);

    // User debts
    (uint256 drawn, uint256 premium) = spoke.getUserDebt(reserveId, alice);
    assertEq(drawn, 0);
    assertEq(premium, 0);

    assertEq(spoke.getUserTotalDebt(reserveId, alice), 0);

    // Reserve debts
    (drawn, premium) = spoke.getReserveDebt(reserveId);
    assertEq(drawn, 0);
    assertEq(premium, 0);
    assertEq(spoke.getReserveTotalDebt(reserveId), 0);

    // User supply
    assertEq(spoke.getUserSuppliedAssets(reserveId, alice), supplyAmount);
    assertEq(
      spoke.getUserSuppliedShares(reserveId, alice),
      hub1.previewAddByAssets(assetId, supplyAmount)
    );

    // Reserve supply
    assertEq(spoke.getReserveSuppliedAssets(reserveId), supplyAmount);
    assertEq(
      spoke.getReserveSuppliedShares(reserveId),
      hub1.previewAddByAssets(assetId, supplyAmount)
    );

    // Spoke debts
    (drawn, premium) = hub1.getSpokeOwed(assetId, address(spoke));
    assertEq(drawn, 0);
    assertEq(premium, 0);
    assertEq(hub1.getSpokeTotalOwed(assetId, address(spoke)), 0);
    assertEq(hub1.getSpokeDrawnShares(assetId, address(spoke)), 0);

    (uint256 premiumShares, uint256 premiumOffset, uint256 realizedPremium) = hub1
      .getSpokePremiumData(assetId, address(spoke));
    assertEq(premiumShares, 0);
    assertEq(premiumOffset, 0);
    assertEq(realizedPremium, 0);

    // Asset debts
    (drawn, premium) = hub1.getAssetOwed(assetId);
    assertEq(drawn, 0);
    assertEq(premium, 0);
    assertEq(hub1.getAssetTotalOwed(assetId), 0);
    assertEq(hub1.getAssetDrawnShares(assetId), 0);

    (premiumShares, premiumOffset, realizedPremium) = hub1.getAssetPremiumData(assetId);
    assertEq(premiumShares, 0);
    assertEq(premiumOffset, 0);
    assertEq(realizedPremium, 0);

    // Spoke supply
    assertEq(hub1.getSpokeAddedAssets(assetId, address(spoke)), supplyAmount);
    assertEq(
      hub1.getSpokeAddedShares(assetId, address(spoke)),
      hub1.previewAddByAssets(assetId, supplyAmount)
    );

    // Asset supply
    assertEq(hub1.getAddedAssets(assetId), supplyAmount);
    assertEq(hub1.getAddedShares(assetId), hub1.previewAddByAssets(assetId, supplyAmount));
  }
}
