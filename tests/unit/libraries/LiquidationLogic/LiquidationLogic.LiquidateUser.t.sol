// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidateUserTest is LiquidationLogicBaseTest {
  using SafeCast for *;
  using WadRayMath for uint256;

  IHub hub2;

  uint256 usdxReserveId;
  uint256 wethReserveId;

  ISpoke.LiquidationConfig liquidationConfig;
  ISpoke.DynamicReserveConfig dynamicCollateralConfig;
  LiquidationLogic.LiquidateUserParams params;

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
    params = LiquidationLogic.LiquidateUserParams({
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
      activeCollateralCount: 1,
      borrowedCount: 1,
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
    liquidationLogicWrapper.setLiquidator(params.liquidator);

    // Mock storage for collateral side
    require(hub1.getAsset(usdxAssetId).underlying == address(tokenList.usdx));
    liquidationLogicWrapper.setCollateralReserveId(usdxReserveId);
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

    // Collateral hub: Add liquidity
    address tempUser = makeUser();
    deal(address(tokenList.usdx), tempUser, MAX_SUPPLY_AMOUNT);
    Utils.add(hub1, usdxAssetId, address(liquidationLogicWrapper), MAX_SUPPLY_AMOUNT, tempUser);

    // Debt hub: Add liquidity, remove liquidity, refresh premium and skip time to accrue both drawn and premium debt
    deal(address(tokenList.weth), tempUser, MAX_SUPPLY_AMOUNT);
    Utils.add(hub2, wethAssetId, address(liquidationLogicWrapper), MAX_SUPPLY_AMOUNT, tempUser);
    Utils.draw(hub2, wethAssetId, address(liquidationLogicWrapper), tempUser, MAX_SUPPLY_AMOUNT);
    vm.startPrank(address(liquidationLogicWrapper));
    hub2.refreshPremium(
      wethAssetId,
      _getExpectedPremiumDelta({
        hub: hub2,
        assetId: wethAssetId,
        oldPremiumShares: 0,
        oldPremiumOffsetRay: 0,
        drawnShares: 1e6 * 1e18, // risk premium is 100%
        riskPremium: 100_00,
        restoredPremiumRay: 0
      })
    );
    vm.stopPrank();
    skip(365 days);
    (uint256 spokeDrawnOwed, uint256 spokePremiumOwed) = hub2.getSpokeOwed(
      wethAssetId,
      address(liquidationLogicWrapper)
    );
    assertGt(spokeDrawnOwed, 10000e18);
    assertGt(spokePremiumOwed, 10000e18);

    // Mock user debt position
    liquidationLogicWrapper.setDebtPositionDrawnShares(
      hub2.previewRestoreByAssets(wethAssetId, params.drawnDebt)
    );
    liquidationLogicWrapper.setDebtPositionPremiumShares(params.premiumDebtRay.fromRayUp());
    liquidationLogicWrapper.setDebtPositionPremiumOffsetRay(
      _calculatePremiumAssetsRay(hub2, wethAssetId, params.premiumDebtRay.fromRayUp()).toInt256() -
        params.premiumDebtRay.toInt256()
    );

    // Mint tokens to liquidator and approve spoke
    deal(address(tokenList.weth), params.liquidator, spokeDrawnOwed + spokePremiumOwed);
    Utils.approve(
      ISpoke(address(liquidationLogicWrapper)),
      address(tokenList.weth),
      params.liquidator,
      spokeDrawnOwed + spokePremiumOwed
    );
  }

  function test_liquidateUser() public {
    uint256 initialHub1UsdxBalance = tokenList.usdx.balanceOf(address(hub1));
    uint256 initialHub2Balance = tokenList.weth.balanceOf(address(hub2));
    uint256 initialLiquidatorWethBalance = tokenList.weth.balanceOf(address(params.liquidator));

    ISpoke.UserPosition memory debtPosition = liquidationLogicWrapper.getDebtPosition(params.user);

    uint256 feeShares = hub1.previewRemoveByAssets(usdxAssetId, 6000e6) -
      hub1.previewRemoveByAssets(usdxAssetId, 5900e6);

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHubBase.previewRemoveByAssets, (usdxAssetId, 6000e6)),
      1
    );

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHubBase.remove, (usdxAssetId, 5900e6, params.liquidator)),
      1
    );

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHubBase.payFeeShares, (usdxAssetId, feeShares)),
      1
    );

    vm.expectCall(
      address(hub2),
      abi.encodeCall(
        IHubBase.restore,
        (
          wethAssetId,
          2e18,
          _getExpectedPremiumDelta({
            hub: hub2,
            assetId: wethAssetId,
            oldPremiumShares: debtPosition.premiumShares,
            oldPremiumOffsetRay: debtPosition.premiumOffsetRay,
            drawnShares: 0,
            riskPremium: 0,
            restoredPremiumRay: 0.5e18 * WadRayMath.RAY
          })
        )
      ),
      1
    );

    bool hasDeficit = liquidationLogicWrapper.liquidateUser(params);
    assertEq(hasDeficit, false);

    assertEq(tokenList.usdx.balanceOf(address(hub1)), initialHub1UsdxBalance - 5900e6);
    assertEq(tokenList.usdx.balanceOf(address(params.liquidator)), 5900e6);
    assertApproxEqAbs(hub1.getSpokeAddedShares(usdxAssetId, address(treasurySpoke)), 100e6, 1);

    assertEq(tokenList.weth.balanceOf(address(hub2)), initialHub2Balance + 2.5e18);
    assertEq(
      tokenList.weth.balanceOf(address(params.liquidator)),
      initialLiquidatorWethBalance - 2.5e18
    );
  }

  function test_liquidateUser_revertsWith_InvalidDebtToCover() public {
    params.debtToCover = 0;
    vm.expectRevert(ISpoke.InvalidDebtToCover.selector);
    liquidationLogicWrapper.liquidateUser(params);
  }

  function test_liquidateUser_revertsWith_MustNotLeaveDust_Debt() public {
    params.totalDebtValue *= 2;
    params.debtToCover = 4.9e18;
    liquidationLogicWrapper.setCollateralPositionSuppliedShares(
      liquidationLogicWrapper.getCollateralPosition(params.user).suppliedShares * 2
    );
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    liquidationLogicWrapper.liquidateUser(params);
  }

  function test_liquidateUser_revertsWith_MustNotLeaveDust_Collateral() public {
    liquidationLogicWrapper.setCollateralPositionSuppliedShares(6500e6);
    params.debtToCover = 2.6e18;
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    liquidationLogicWrapper.liquidateUser(params);
  }

  function updateStorage(ISpoke.LiquidationConfig memory config) internal {
    liquidationLogicWrapper.setLiquidationConfig(config);
  }

  function updateStorage(ISpoke.DynamicReserveConfig memory config) internal {
    liquidationLogicWrapper.setDynamicCollateralConfig(config);
  }
}
