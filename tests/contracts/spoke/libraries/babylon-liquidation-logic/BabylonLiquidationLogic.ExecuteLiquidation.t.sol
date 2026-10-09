// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/libraries/babylon-liquidation-logic/BabylonLiquidationLogic.Base.t.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';

contract BabylonLiquidationLogicExecuteLiquidationTest is BabylonLiquidationLogicBaseTest {
  using SafeCast for *;
  using WadRayMath for uint256;
  using ReserveFlagsMap for ReserveFlags;

  uint256 public usdxReserveId;
  uint256 public wethReserveId;

  BabylonLiquidationLogic.ExecuteLiquidationParams params;

  // drawn index is 1.05, supply share price is 1.25
  // variable liquidation bonus is max: 120%
  // user debt: 4.4 drawn shares * 1.05 + 0.4 premium = 5.02
  // debtToCover 2.5: premium 0.4 repaid first, drawn shares = (2.5 - 0.4) / 1.05 = 2
  // collateral to liquidate = 2.5 * 120% * $2000 / $1 = 6000 -> 6000 / 1.25 = 4800 shares
  // no liquidation fee: the liquidator receives the full 6000
  function setUp() public override {
    super.setUp();
    IHub collateralReserveHub = hub1;
    _mockSupplySharePrice({
      hub: collateralReserveHub,
      assetId: usdxAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke1)
    });
    (IHub debtReserveHub, ) = _hub2Fixture();
    _mockDrawnRateBps({
      irStrategy: debtReserveHub.getAsset(wethAssetId).irStrategy,
      drawnRateBps: 5_00
    });

    // Mock params
    usdxReserveId = _usdxReserveId(spoke1);
    wethReserveId = _wethReserveId(spoke1);
    params = BabylonLiquidationLogic.ExecuteLiquidationParams({
      collateralHub: collateralReserveHub,
      collateralAssetId: usdxAssetId,
      collateralAssetDecimals: 6,
      collateralReserveId: usdxReserveId,
      collateralReserveFlags: ReserveFlagsMap.create({
        initPaused: false,
        initFrozen: false,
        initBorrowable: false,
        initReceiveSharesEnabled: true
      }),
      collateralDynConfig: ISpoke.DynamicReserveConfig({
        maxLiquidationBonus: 120_00,
        collateralFactor: 50_00,
        liquidationFee: 0
      }),
      debtHub: debtReserveHub,
      debtAssetId: wethAssetId,
      debtAssetDecimals: 18,
      debtUnderlying: address(tokenList.weth),
      debtReserveId: wethReserveId,
      debtReserveFlags: ReserveFlagsMap.create({
        initPaused: false,
        initFrozen: false,
        initBorrowable: true,
        initReceiveSharesEnabled: false
      }),
      liquidationConfig: ISpoke.LiquidationConfig({
        targetHealthFactor: 1e18,
        healthFactorForMaxBonus: 0.8e18,
        liquidationBonusFactor: 50_00
      }),
      oracle: address(oracle1),
      user: makeAddr('user'),
      debtToCover: 2.5e18,
      maxCollateralToRemove: UINT256_MAX,
      healthFactor: 0.8e18,
      activeCollateralCount: 1,
      borrowCount: 1,
      liquidator: makeAddr('liquidator')
    });

    // Mock storage
    babylonLiquidationLogicWrapper.setBorrower(params.user);
    babylonLiquidationLogicWrapper.setLiquidator(params.liquidator);
    babylonLiquidationLogicWrapper.setCollateralReserveId(usdxReserveId);
    babylonLiquidationLogicWrapper.setDebtReserveId(wethReserveId);
    babylonLiquidationLogicWrapper.setCollateralPositionSuppliedShares(10_000e6);
    babylonLiquidationLogicWrapper.setDebtPositionDrawnShares(4.4e18);
    babylonLiquidationLogicWrapper.setDebtPositionPremiumShares(1e18);
    babylonLiquidationLogicWrapper.setDebtPositionPremiumOffsetRay(
      (0.65e18 * WadRayMath.RAY).toInt256()
    );
    babylonLiquidationLogicWrapper.setBorrowerCollateralStatus(usdxReserveId, true);
    babylonLiquidationLogicWrapper.setBorrowerBorrowingStatus(wethReserveId, true);

    _registerWrapperAsSpoke(collateralReserveHub, debtReserveHub);
  }

  function test_executeLiquidation() public {
    uint256 initialCollateralHubBalance = tokenList.usdx.balanceOf(address(params.collateralHub));
    uint256 initialDebtHubBalance = tokenList.weth.balanceOf(address(params.debtHub));
    uint256 initialLiquidatorWethBalance = tokenList.weth.balanceOf(params.liquidator);
    ISpoke.UserPosition memory debtPosition = babylonLiquidationLogicWrapper.getDebtPosition(
      params.user
    );
    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      hub: IHub(address(params.debtHub)),
      assetId: wethAssetId,
      oldPremiumShares: debtPosition.premiumShares,
      oldPremiumOffsetRay: debtPosition.premiumOffsetRay,
      drawnShares: 0,
      riskPremium: 0,
      restoredPremiumRay: 0.4e18 * WadRayMath.RAY
    });

    // the liquidator receives the full removed collateral, no fee shares are paid
    vm.expectCall(
      address(params.collateralHub),
      abi.encodeCall(IHubBase.remove, (usdxAssetId, 6000e6, params.liquidator)),
      1
    );
    vm.expectCall(
      address(params.collateralHub),
      abi.encodeWithSelector(IHubBase.payFeeShares.selector, usdxAssetId),
      0
    );
    vm.expectCall(
      address(params.debtHub),
      abi.encodeCall(IHubBase.restore, (wethAssetId, 2.1e18, premiumDelta)),
      1
    );
    vm.expectEmit(address(babylonLiquidationLogicWrapper));
    emit IBabylonSpoke.BabylonLiquidationCall({
      collateralReserveId: usdxReserveId,
      debtReserveId: wethReserveId,
      user: params.user,
      liquidator: params.liquidator,
      debtAmountRestored: 2.5e18,
      drawnSharesLiquidated: 2e18,
      premiumDelta: premiumDelta,
      collateralAmountRemoved: 6000e6,
      collateralSharesLiquidated: 4800e6
    });

    BabylonLiquidationLogic.LiquidationResult memory result = babylonLiquidationLogicWrapper
      .executeLiquidation(params);

    assertFalse(result.isUserInDeficit, 'deficit');
    assertEq(result.liquidationBonus, 120_00, 'liquidation bonus');
    assertEq(result.collateralAmountRemoved, 6000e6, 'collateral amount removed');
    assertEq(
      babylonLiquidationLogicWrapper.getCollateralPosition(params.user).suppliedShares,
      10_000e6 - 4800e6,
      'user supplied shares'
    );
    assertEq(
      babylonLiquidationLogicWrapper.getDebtPosition(params.user).drawnShares,
      4.4e18 - 2e18,
      'user drawn shares'
    );
    assertEq(
      tokenList.usdx.balanceOf(address(params.collateralHub)),
      initialCollateralHubBalance - 6000e6,
      'collateral hub balance'
    );
    assertEq(tokenList.usdx.balanceOf(params.liquidator), 6000e6, 'liquidator collateral');
    assertEq(
      tokenList.weth.balanceOf(address(params.debtHub)),
      initialDebtHubBalance + 2.5e18,
      'debt hub balance'
    );
    assertEq(
      tokenList.weth.balanceOf(params.liquidator),
      initialLiquidatorWethBalance - 2.5e18,
      'liquidator debt spent'
    );
  }

  function test_executeLiquidation_CapEnforced() public {
    // cap 3480 assets = 2784 shares, below the 4800 priced removal
    // repayment = 3480 * $1 / (120% * $2000) = 1.45: premium 0.4, drawn shares (1.45 - 0.4) / 1.05 = 1
    params.maxCollateralToRemove = 3480e6;
    ISpoke.UserPosition memory debtPosition = babylonLiquidationLogicWrapper.getDebtPosition(
      params.user
    );
    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      hub: IHub(address(params.debtHub)),
      assetId: wethAssetId,
      oldPremiumShares: debtPosition.premiumShares,
      oldPremiumOffsetRay: debtPosition.premiumOffsetRay,
      drawnShares: 0,
      riskPremium: 0,
      restoredPremiumRay: 0.4e18 * WadRayMath.RAY
    });

    vm.expectCall(
      address(params.collateralHub),
      abi.encodeCall(IHubBase.remove, (usdxAssetId, 3480e6, params.liquidator)),
      1
    );
    vm.expectCall(
      address(params.debtHub),
      abi.encodeCall(IHubBase.restore, (wethAssetId, 1.05e18, premiumDelta)),
      1
    );
    vm.expectEmit(address(babylonLiquidationLogicWrapper));
    emit IBabylonSpoke.BabylonLiquidationCall({
      collateralReserveId: usdxReserveId,
      debtReserveId: wethReserveId,
      user: params.user,
      liquidator: params.liquidator,
      debtAmountRestored: 1.45e18,
      drawnSharesLiquidated: 1e18,
      premiumDelta: premiumDelta,
      collateralAmountRemoved: 3480e6,
      collateralSharesLiquidated: 2784e6
    });

    BabylonLiquidationLogic.LiquidationResult memory result = babylonLiquidationLogicWrapper
      .executeLiquidation(params);

    assertFalse(result.isUserInDeficit, 'deficit');
    assertEq(result.collateralAmountRemoved, 3480e6, 'collateral amount removed');
    assertEq(tokenList.usdx.balanceOf(params.liquidator), 3480e6, 'liquidator collateral');
  }

  /// @dev The cap is bounded by the user's collateral: removing all of it with debt left is a
  /// deficit.
  function test_executeLiquidation_Deficit() public {
    babylonLiquidationLogicWrapper.setCollateralPositionSuppliedShares(4800e6);

    BabylonLiquidationLogic.LiquidationResult memory result = babylonLiquidationLogicWrapper
      .executeLiquidation(params);

    assertTrue(result.isUserInDeficit, 'deficit');
    assertEq(result.collateralAmountRemoved, 6000e6, 'collateral amount removed');
    assertEq(
      babylonLiquidationLogicWrapper.getCollateralPosition(params.user).suppliedShares,
      0,
      'user supplied shares'
    );
    assertGt(
      babylonLiquidationLogicWrapper.getDebtPosition(params.user).drawnShares,
      0,
      'user drawn shares left'
    );
  }

  /// @dev The liquidator always receives underlying assets, so a frozen collateral reserve is
  /// liquidatable.
  function test_executeLiquidation_FrozenCollateral() public {
    params.collateralReserveFlags = ReserveFlagsMap.create({
      initPaused: false,
      initFrozen: true,
      initBorrowable: false,
      initReceiveSharesEnabled: false
    });

    BabylonLiquidationLogic.LiquidationResult memory result = babylonLiquidationLogicWrapper
      .executeLiquidation(params);

    assertEq(result.collateralAmountRemoved, 6000e6, 'collateral amount removed');
  }

  /// @dev A cover whose priced removal floors to zero shares still repays debt, skipping the hub
  /// removal.
  function test_executeLiquidation_ZeroCollateralRemoved() public {
    params.debtToCover = 1;

    vm.expectCall(
      address(params.collateralHub),
      abi.encodeWithSelector(IHubBase.remove.selector, usdxAssetId),
      0
    );
    vm.expectCall(
      address(params.debtHub),
      abi.encodeWithSelector(IHubBase.restore.selector, wethAssetId),
      1
    );

    BabylonLiquidationLogic.LiquidationResult memory result = babylonLiquidationLogicWrapper
      .executeLiquidation(params);

    assertEq(result.collateralAmountRemoved, 0, 'collateral amount removed');
    assertEq(
      babylonLiquidationLogicWrapper.getCollateralPosition(params.user).suppliedShares,
      10_000e6,
      'user supplied shares'
    );
  }

  function test_executeLiquidation_revertsWith_InvalidDebtToCover() public {
    params.debtToCover = 0;
    vm.expectRevert(ISpoke.InvalidDebtToCover.selector);
    babylonLiquidationLogicWrapper.executeLiquidation(params);
  }

  function test_executeLiquidation_revertsWith_ReserveNotSupplied() public {
    babylonLiquidationLogicWrapper.setCollateralPositionSuppliedShares(0);
    vm.expectRevert(ISpoke.ReserveNotSupplied.selector);
    babylonLiquidationLogicWrapper.executeLiquidation(params);
  }

  function test_executeLiquidation_revertsWith_HealthFactorNotBelowThreshold() public {
    params.healthFactor = 1e18;
    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    babylonLiquidationLogicWrapper.executeLiquidation(params);
  }

  /// @dev Registers the wrapper as a spoke on both hubs, seeds liquidity and accrues drawn and
  /// premium debt, then funds the liquidator, mirroring the canonical library test setup.
  function _registerWrapperAsSpoke(IHub collateralReserveHub, IHub debtReserveHub) internal {
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: MAX_ALLOWED_SPOKE_CAP,
      drawCap: MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: MAX_ALLOWED_COLLATERAL_RISK
    });
    vm.startPrank(HUB_ADMIN);
    collateralReserveHub.addSpoke(
      usdxAssetId,
      address(babylonLiquidationLogicWrapper),
      spokeConfig
    );
    debtReserveHub.addSpoke(wethAssetId, address(babylonLiquidationLogicWrapper), spokeConfig);
    vm.stopPrank();

    address tempUser = _makeUser();
    deal(address(tokenList.usdx), tempUser, MAX_SUPPLY_AMOUNT);
    HubActions.add({
      hub: collateralReserveHub,
      assetId: usdxAssetId,
      caller: address(babylonLiquidationLogicWrapper),
      amount: MAX_SUPPLY_AMOUNT,
      user: tempUser
    });

    deal(address(tokenList.weth), tempUser, MAX_SUPPLY_AMOUNT);
    HubActions.add({
      hub: debtReserveHub,
      assetId: wethAssetId,
      caller: address(babylonLiquidationLogicWrapper),
      amount: MAX_SUPPLY_AMOUNT,
      user: tempUser
    });
    HubActions.draw({
      hub: debtReserveHub,
      assetId: wethAssetId,
      caller: address(babylonLiquidationLogicWrapper),
      to: tempUser,
      amount: MAX_SUPPLY_AMOUNT
    });
    vm.startPrank(address(babylonLiquidationLogicWrapper));
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
      address(babylonLiquidationLogicWrapper)
    );
    assertGt(spokeDrawnOwed, 10000e18);
    assertGt(spokePremiumOwed, 10000e18);

    deal(address(tokenList.weth), params.liquidator, spokeDrawnOwed + spokePremiumOwed);
    SpokeActions.approve({
      spoke: ISpoke(address(babylonLiquidationLogicWrapper)),
      underlying: address(tokenList.weth),
      owner: params.liquidator,
      amount: spokeDrawnOwed + spokePremiumOwed
    });
  }
}
