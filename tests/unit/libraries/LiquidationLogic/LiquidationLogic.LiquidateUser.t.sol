// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidateUserTest is LiquidationLogicBaseTest {
  using SafeCast for *;
  using WadRayMath for uint256;
  using ReserveFlagsMap for ReserveFlags;

  uint256 usdxReserveId;
  uint256 wethReserveId;
  IHub collateralReserveHub;
  IHub debtReserveHub;
  LiquidationLogic.LiquidateUserParams params;

  // drawn index is 1.05, supply share price is 1.25
  // variable liquidation bonus is max: 120%
  // liquidation penalty: 1.2 * 0.5 = 0.6
  // debtToTarget = $10000 * (1 - 0.8) / (1 - 0.6) / $2000 = 2.5
  // max debt to liquidate = min(2.5, 4.4 * 1.05 + 0.4, 3) = 2.5
  // premiumDebtRayToLiquidate = 0.4
  // drawnSharesToLiquidate = (2.5 - 0.4) / 1.05 = 2
  // collateral to liquidate = 2.5 * 120% * $2000 / $1 = 6000
  // collateral shares to liquidate = 6000 / 1.25 = 4800
  // bonus collateral shares = 4800 - 4800 / 120% = 800
  // collateral fee shares = 800 * 10% = 80
  // collateral shares to liquidator = 4800 - 80 = 4720
  function setUp() public override {
    super.setUp();
    collateralReserveHub = hub1;
    _mockSupplySharePrice(collateralReserveHub, usdxAssetId, 12_500.25e6, 10_000e6);
    (debtReserveHub, ) = hub2Fixture();
    _mockInterestRateBps(debtReserveHub.getAsset(wethAssetId).irStrategy, 5_00);

    // Mock params
    usdxReserveId = _usdxReserveId(spoke1);
    wethReserveId = _wethReserveId(spoke1);
    params = LiquidationLogic.LiquidateUserParams({
      collateralReserveId: usdxReserveId,
      debtReserveId: wethReserveId,
      oracle: address(oracle1),
      user: makeAddr('user'),
      liquidationConfig: ISpoke.LiquidationConfig({
        targetHealthFactor: 1e18,
        healthFactorForMaxBonus: 0.8e18,
        liquidationBonusFactor: 50_00
      }),
      debtToCover: 3e18,
      userAccountData: ISpoke.UserAccountData({
        healthFactor: 0.8e18,
        totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
        activeCollateralCount: 1,
        borrowCount: 1,
        totalCollateralValue: 0, // not used
        riskPremium: 0, // not used
        avgCollateralFactor: 0 // not used
      }),
      liquidator: makeAddr('liquidator'),
      receiveShares: false
    });

    // Mock storage
    liquidationLogicWrapper.setBorrower(params.user);
    liquidationLogicWrapper.setLiquidator(params.liquidator);
    liquidationLogicWrapper.setCollateralReserveId(usdxReserveId);
    liquidationLogicWrapper.setCollateralReserveHub(collateralReserveHub);
    liquidationLogicWrapper.setCollateralReserveDecimals(6);
    liquidationLogicWrapper.setCollateralReserveAssetId(usdxAssetId);
    liquidationLogicWrapper.setCollateralReserveFlags(
      ReserveFlagsMap.create(false, false, false, true)
    );
    liquidationLogicWrapper.setDynamicCollateralConfig(
      ISpoke.DynamicReserveConfig({
        maxLiquidationBonus: 120_00,
        collateralFactor: 50_00,
        liquidationFee: 10_00
      })
    );
    liquidationLogicWrapper.setCollateralPositionSuppliedShares(10_000e6);
    liquidationLogicWrapper.setDebtReserveId(wethReserveId);
    liquidationLogicWrapper.setDebtReserveHub(debtReserveHub);
    liquidationLogicWrapper.setDebtReserveDecimals(18);
    liquidationLogicWrapper.setDebtReserveAssetId(wethAssetId);
    liquidationLogicWrapper.setDebtReserveUnderlying(address(tokenList.weth));
    liquidationLogicWrapper.setDebtReserveFlags(ReserveFlagsMap.create(false, false, false, false));
    liquidationLogicWrapper.setDebtPositionDrawnShares(4.4e18);
    liquidationLogicWrapper.setDebtPositionPremiumShares(1e18);
    liquidationLogicWrapper.setDebtPositionPremiumOffsetRay((0.65e18 * WadRayMath.RAY).toInt256());
    liquidationLogicWrapper.setBorrowerCollateralStatus(usdxReserveId, true);
    liquidationLogicWrapper.setBorrowerBorrowingStatus(wethReserveId, true);

    // Set liquidationLogicWrapper as a spoke
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });
    vm.startPrank(HUB_ADMIN);
    collateralReserveHub.addSpoke(usdxAssetId, address(liquidationLogicWrapper), spokeConfig);
    debtReserveHub.addSpoke(wethAssetId, address(liquidationLogicWrapper), spokeConfig);
    vm.stopPrank();

    // Collateral hub: Add liquidity
    address tempUser = makeUser();
    deal(address(tokenList.usdx), tempUser, MAX_SUPPLY_AMOUNT);
    Utils.add(hub1, usdxAssetId, address(liquidationLogicWrapper), MAX_SUPPLY_AMOUNT, tempUser);

    // Debt hub: Add liquidity, remove liquidity, refresh premium and skip time to accrue both drawn and premium debt
    deal(address(tokenList.weth), tempUser, MAX_SUPPLY_AMOUNT);
    Utils.add(
      debtReserveHub,
      wethAssetId,
      address(liquidationLogicWrapper),
      MAX_SUPPLY_AMOUNT,
      tempUser
    );
    Utils.draw(
      debtReserveHub,
      wethAssetId,
      address(liquidationLogicWrapper),
      tempUser,
      MAX_SUPPLY_AMOUNT
    );
    vm.startPrank(address(liquidationLogicWrapper));
    debtReserveHub.refreshPremium(
      wethAssetId,
      _getExpectedPremiumDelta({
        hub: debtReserveHub,
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
    (uint256 spokeDrawnOwed, uint256 spokePremiumOwed) = debtReserveHub.getSpokeOwed(
      wethAssetId,
      address(liquidationLogicWrapper)
    );
    assertGt(spokeDrawnOwed, 10000e18);
    assertGt(spokePremiumOwed, 10000e18);

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
    uint256 initialCollateralReserveBalance = tokenList.usdx.balanceOf(
      address(collateralReserveHub)
    );
    uint256 initialDebtReserveBalance = tokenList.weth.balanceOf(address(debtReserveHub));
    uint256 initialLiquidatorWethBalance = tokenList.weth.balanceOf(address(params.liquidator));

    ISpoke.UserPosition memory debtPosition = liquidationLogicWrapper.getDebtPosition(params.user);

    vm.expectCall(
      address(collateralReserveHub),
      abi.encodeCall(IHubBase.previewRemoveByShares, (usdxAssetId, 4800e6)),
      1
    );

    vm.expectCall(
      address(collateralReserveHub),
      abi.encodeCall(IHubBase.previewRemoveByShares, (usdxAssetId, 4720e6)),
      1
    );

    vm.expectCall(
      address(collateralReserveHub),
      abi.encodeCall(IHubBase.remove, (usdxAssetId, 5900e6, params.liquidator)),
      1
    );

    vm.expectCall(
      address(collateralReserveHub),
      abi.encodeCall(IHubBase.payFeeShares, (usdxAssetId, 80e6)),
      1
    );

    vm.expectCall(
      address(debtReserveHub),
      abi.encodeCall(
        IHubBase.restore,
        (
          wethAssetId,
          2.1e18,
          _getExpectedPremiumDelta({
            hub: IHub(address(debtReserveHub)),
            assetId: wethAssetId,
            oldPremiumShares: debtPosition.premiumShares,
            oldPremiumOffsetRay: debtPosition.premiumOffsetRay,
            drawnShares: 0,
            riskPremium: 0,
            restoredPremiumRay: 0.4e18 * WadRayMath.RAY
          })
        )
      ),
      1
    );

    bool hasDeficit = liquidationLogicWrapper.liquidateUser(params);
    assertEq(hasDeficit, false);

    assertEq(
      tokenList.usdx.balanceOf(address(collateralReserveHub)),
      initialCollateralReserveBalance - 5900e6
    );
    assertEq(tokenList.usdx.balanceOf(address(params.liquidator)), 5900e6);
    assertApproxEqAbs(
      collateralReserveHub.getSpokeAddedShares(usdxAssetId, address(treasurySpoke)),
      80e6,
      1
    );

    assertEq(tokenList.weth.balanceOf(address(debtReserveHub)), initialDebtReserveBalance + 2.5e18);
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
    params.userAccountData.totalDebtValueRay *= 2;
    params.debtToCover = 4.9e18;
    liquidationLogicWrapper.setCollateralPositionSuppliedShares(
      liquidationLogicWrapper.getCollateralPosition(params.user).suppliedShares * 2
    );
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    liquidationLogicWrapper.liquidateUser(params);
  }

  function test_liquidateUser_revertsWith_MustNotLeaveDust_Collateral() public {
    liquidationLogicWrapper.setCollateralPositionSuppliedShares(5200e6);
    params.debtToCover = 2.6e18;
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    liquidationLogicWrapper.liquidateUser(params);
  }
}
