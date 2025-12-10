// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicValidateCalculateLiquidationAmountsTest is LiquidationLogicBaseTest {
  using SafeCast for *;
  using WadRayMath for uint256;

  IHub hub2;

  uint256 usdxReserveId;
  uint256 wethReserveId;

  ISpoke.LiquidationConfig liquidationConfig;
  ISpoke.DynamicReserveConfig dynamicCollateralConfig;
  LiquidationLogic.ValidateCalculateLiquidationAmountsParams params;

  // drawn index is 1.05
  // variable liquidation bonus is max: 120%
  // liquidation penalty: 1.2 * 0.5 = 0.6
  // debtToTarget = $10000 * (1 - 0.8) / (1 - 0.6) / $2000 = 2.5
  // max debt to liquidate = min(2.5, 5, 3) = 2.5
  // collateral to liquidate = 2.5 * 120% * $2000 / $1 = 6000
  // bonus collateral = 6000 - 6000 / 120% = 1000
  // collateral fee = 1000 * 10% = 100
  // collateral to liquidator = 6000 - 100 = 5900
  function setUp() public override {
    super.setUp();
    (hub2, ) = hub2Fixture();

    _mockInterestRateBps(hub2.getAsset(wethAssetId).irStrategy, 5_00);

    // Mock params
    usdxReserveId = _usdxReserveId(spoke1);
    wethReserveId = _wethReserveId(spoke1);
    params = LiquidationLogic.ValidateCalculateLiquidationAmountsParams({
      collateralReserveId: usdxReserveId,
      debtReserveId: wethReserveId,
      oracle: address(oracle1),
      user: makeAddr('user'),
      debtToCover: 3e18,
      healthFactor: 0.8e18,
      drawnDebt: 4.5e18,
      premiumDebtRay: 0.5e18 * WadRayMath.RAY,
      drawnIndex: 1.05e27,
      totalDebtValue: 10_000e26,
      liquidator: makeAddr('liquidator'),
      minLiquidationBonus: 120_00,
      receiveShares: false
    });

    // Set liquidationLogicWrapper as a spoke
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });
    vm.startPrank(HUB_ADMIN);
    hub1.addSpoke(usdxAssetId, address(liquidationLogicWrapper), spokeConfig);
    hub2.addSpoke(wethAssetId, address(liquidationLogicWrapper), spokeConfig);
    vm.stopPrank();

    // set borrower
    liquidationLogicWrapper.setBorrower(params.user);

    // Mock storage for collateral side
    require(hub1.getAsset(usdxAssetId).underlying == address(tokenList.usdx));
    liquidationLogicWrapper.setCollateralReserveId(usdxReserveId);
    liquidationLogicWrapper.setCollateralLiquidatable(true);
    liquidationLogicWrapper.setCollateralReserveHub(hub1);
    liquidationLogicWrapper.setCollateralReserveAssetId(usdxAssetId);
    liquidationLogicWrapper.setCollateralReserveDecimals(6);
    liquidationLogicWrapper.setCollateralPositionSuppliedShares(10_200e6);
    liquidationLogicWrapper.setBorrowerCollateralStatus(usdxReserveId, true);

    // Mock storage for debt side
    require(hub2.getAsset(wethAssetId).underlying == address(tokenList.weth));
    liquidationLogicWrapper.setDebtReserveId(wethReserveId);
    liquidationLogicWrapper.setDebtReserveHub(hub2);
    liquidationLogicWrapper.setDebtReserveAssetId(wethAssetId);
    liquidationLogicWrapper.setDebtReserveUnderlying(address(tokenList.weth));
    liquidationLogicWrapper.setDebtReserveDecimals(18);
    liquidationLogicWrapper.setBorrowerBorrowingStatus(wethReserveId, true);

    // Mock storage for liquidation config
    liquidationConfig = ISpoke.LiquidationConfig({
      healthFactorForMaxBonus: 0.8e18,
      liquidationBonusFactor: 50_00,
      targetHealthFactor: 1e18
    });
    updateStorage(liquidationConfig);

    // Mock storage for dynamic collateral config
    dynamicCollateralConfig = ISpoke.DynamicReserveConfig({
      maxLiquidationBonus: 120_00,
      collateralFactor: 50_00,
      liquidationFee: 10_00
    });
    updateStorage(dynamicCollateralConfig);

    // Mock user debt position
    liquidationLogicWrapper.setDebtPositionDrawnShares(
      hub2.previewRestoreByAssets(wethAssetId, params.drawnDebt)
    );
    liquidationLogicWrapper.setDebtPositionPremiumShares(params.premiumDebtRay.fromRayUp());
    liquidationLogicWrapper.setDebtPositionPremiumOffsetRay(
      _calculatePremiumAssetsRay(hub2, wethAssetId, params.premiumDebtRay.fromRayUp()).toInt256() -
        params.premiumDebtRay.toInt256()
    );
  }

  function test_validateCalculateLiquidationAmounts() public view {
    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = liquidationLogicWrapper
      .validateCalculateLiquidationAmounts(params);
    assertEq(liquidationAmounts.collateralToLiquidate, 6000e6);
    assertEq(liquidationAmounts.collateralToLiquidator, 5900e6);
    assertEq(liquidationAmounts.debtToLiquidate, 2.5e18);
  }

  function test_validateCalculateLiquidationAmounts_revertsWith_InvalidDebtToCover() public {
    params.debtToCover = 0;
    vm.expectRevert(ISpoke.InvalidDebtToCover.selector);
    liquidationLogicWrapper.validateCalculateLiquidationAmounts(params);
  }

  function test_validateCalculateLiquidationAmounts_revertsWith_InvalidLiquidationBonus() public {
    params.minLiquidationBonus = 120_01;
    vm.expectRevert(ISpoke.InvalidLiquidationBonus.selector);
    liquidationLogicWrapper.validateCalculateLiquidationAmounts(params);

    params.minLiquidationBonus = PercentageMath.PERCENTAGE_FACTOR - 1;
    vm.expectRevert(ISpoke.InvalidLiquidationBonus.selector);
    liquidationLogicWrapper.validateCalculateLiquidationAmounts(params);
  }

  function updateStorage(ISpoke.LiquidationConfig memory config) internal {
    liquidationLogicWrapper.setLiquidationConfig(config);
  }

  function updateStorage(ISpoke.DynamicReserveConfig memory config) internal {
    liquidationLogicWrapper.setDynamicCollateralConfig(config);
  }
}
