// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/libraries/babylon-liquidation-logic/BabylonLiquidationLogic.Base.t.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';

contract BabylonLiquidationLogicLiquidateUserTest is BabylonLiquidationLogicBaseTest {
  using SafeCast for *;
  using WadRayMath for uint256;
  using ReserveFlagsMap for ReserveFlags;

  uint256 public usdxReserveId;
  uint256 public wethReserveId;
  IHub public collateralReserveHub;
  IHub public debtReserveHub;
  BabylonLiquidationLogic.LiquidateUserParams params;

  // same position as the executeLiquidation suite, read from the wrapper's storage instead of
  // being passed in: 4800 collateral shares removed, 0.4 premium and 2 drawn shares repaid
  function setUp() public override {
    super.setUp();
    collateralReserveHub = hub1;
    _mockSupplySharePrice({
      hub: collateralReserveHub,
      assetId: usdxAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke1)
    });
    (debtReserveHub, ) = _hub2Fixture();
    _mockDrawnRateBps({
      irStrategy: debtReserveHub.getAsset(wethAssetId).irStrategy,
      drawnRateBps: 5_00
    });

    usdxReserveId = _usdxReserveId(spoke1);
    wethReserveId = _wethReserveId(spoke1);
    params = BabylonLiquidationLogic.LiquidateUserParams({
      collateralReserveId: usdxReserveId,
      debtReserveId: wethReserveId,
      oracle: address(oracle1),
      user: makeAddr('user'),
      liquidationConfig: ISpoke.LiquidationConfig({
        targetHealthFactor: 1e18,
        healthFactorForMaxBonus: 0.8e18,
        liquidationBonusFactor: 50_00
      }),
      debtToCover: 2.5e18,
      maxCollateralToRemove: UINT256_MAX,
      userAccountData: ISpoke.UserAccountData({
        healthFactor: 0.8e18,
        totalDebtValueRay: 0, // not used
        activeCollateralCount: 1,
        borrowCount: 1,
        totalCollateralValue: 0, // not used
        riskPremium: 0, // not used
        avgCollateralFactor: 0 // not used
      }),
      liquidator: makeAddr('liquidator')
    });

    // Mock storage
    babylonLiquidationLogicWrapper.setBorrower(params.user);
    babylonLiquidationLogicWrapper.setLiquidator(params.liquidator);
    babylonLiquidationLogicWrapper.setCollateralReserveId(usdxReserveId);
    babylonLiquidationLogicWrapper.setCollateralReserveHub(collateralReserveHub);
    babylonLiquidationLogicWrapper.setCollateralReserveDecimals(6);
    babylonLiquidationLogicWrapper.setCollateralReserveAssetId(usdxAssetId);
    babylonLiquidationLogicWrapper.setCollateralReserveFlags(
      ReserveFlagsMap.create({
        initPaused: false,
        initFrozen: false,
        initBorrowable: false,
        initReceiveSharesEnabled: true
      })
    );
    babylonLiquidationLogicWrapper.setDynamicCollateralConfig(
      ISpoke.DynamicReserveConfig({
        maxLiquidationBonus: 120_00,
        collateralFactor: 50_00,
        liquidationFee: 0
      })
    );
    babylonLiquidationLogicWrapper.setCollateralPositionSuppliedShares(10_000e6);
    babylonLiquidationLogicWrapper.setDebtReserveId(wethReserveId);
    babylonLiquidationLogicWrapper.setDebtReserveHub(debtReserveHub);
    babylonLiquidationLogicWrapper.setDebtReserveDecimals(18);
    babylonLiquidationLogicWrapper.setDebtReserveAssetId(wethAssetId);
    babylonLiquidationLogicWrapper.setDebtReserveUnderlying(address(tokenList.weth));
    babylonLiquidationLogicWrapper.setDebtReserveFlags(
      ReserveFlagsMap.create({
        initPaused: false,
        initFrozen: false,
        initBorrowable: true,
        initReceiveSharesEnabled: false
      })
    );
    babylonLiquidationLogicWrapper.setDebtPositionDrawnShares(4.4e18);
    babylonLiquidationLogicWrapper.setDebtPositionPremiumShares(1e18);
    babylonLiquidationLogicWrapper.setDebtPositionPremiumOffsetRay(
      (0.65e18 * WadRayMath.RAY).toInt256()
    );
    babylonLiquidationLogicWrapper.setBorrowerCollateralStatus(usdxReserveId, true);
    babylonLiquidationLogicWrapper.setBorrowerBorrowingStatus(wethReserveId, true);

    // Set the wrapper as a spoke, seed liquidity and accrue debt
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
    deal(address(tokenList.weth), params.liquidator, spokeDrawnOwed + spokePremiumOwed);
    SpokeActions.approve({
      spoke: ISpoke(address(babylonLiquidationLogicWrapper)),
      underlying: address(tokenList.weth),
      owner: params.liquidator,
      amount: spokeDrawnOwed + spokePremiumOwed
    });
  }

  function test_liquidateUser() public {
    ISpoke.UserPosition memory debtPosition = babylonLiquidationLogicWrapper.getDebtPosition(
      params.user
    );
    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      hub: debtReserveHub,
      assetId: wethAssetId,
      oldPremiumShares: debtPosition.premiumShares,
      oldPremiumOffsetRay: debtPosition.premiumOffsetRay,
      drawnShares: 0,
      riskPremium: 0,
      restoredPremiumRay: 0.4e18 * WadRayMath.RAY
    });

    vm.expectCall(
      address(collateralReserveHub),
      abi.encodeCall(IHubBase.remove, (usdxAssetId, 6000e6, params.liquidator)),
      1
    );
    vm.expectCall(
      address(debtReserveHub),
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
      .liquidateUser(params);

    assertFalse(result.isUserInDeficit, 'deficit');
    assertEq(result.liquidationBonus, 120_00, 'liquidation bonus');
    assertEq(result.collateralAmountRemoved, 6000e6, 'collateral amount removed');
    assertEq(tokenList.usdx.balanceOf(params.liquidator), 6000e6, 'liquidator collateral');
  }

  /// @dev The cap is applied in asset units of the collateral reserve read from storage.
  function test_liquidateUser_CapEnforced() public {
    params.maxCollateralToRemove = 3480e6;

    BabylonLiquidationLogic.LiquidationResult memory result = babylonLiquidationLogicWrapper
      .liquidateUser(params);

    assertEq(result.collateralAmountRemoved, 3480e6, 'collateral amount removed');
    assertEq(
      babylonLiquidationLogicWrapper.getCollateralPosition(params.user).suppliedShares,
      10_000e6 - 2784e6,
      'user supplied shares'
    );
    assertEq(
      babylonLiquidationLogicWrapper.getDebtPosition(params.user).drawnShares,
      4.4e18 - 1e18,
      'user drawn shares'
    );
  }

  function test_liquidateUser_revertsWith_InvalidDebtToCover() public {
    params.debtToCover = 0;
    vm.expectRevert(ISpoke.InvalidDebtToCover.selector);
    babylonLiquidationLogicWrapper.liquidateUser(params);
  }

  /// @dev The user account data is threaded into the canonical validation.
  function test_liquidateUser_revertsWith_HealthFactorNotBelowThreshold() public {
    params.userAccountData.healthFactor = 1e18;
    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    babylonLiquidationLogicWrapper.liquidateUser(params);
  }

  function test_liquidateUser_revertsWith_ReserveNotEnabledAsCollateral() public {
    babylonLiquidationLogicWrapper.setBorrowerCollateralStatus(usdxReserveId, false);
    vm.expectRevert(ISpoke.ReserveNotEnabledAsCollateral.selector);
    babylonLiquidationLogicWrapper.liquidateUser(params);
  }

  function test_liquidateUser_revertsWith_ReserveNotListed() public {
    params.collateralReserveId = 99;
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    babylonLiquidationLogicWrapper.liquidateUser(params);
  }
}
