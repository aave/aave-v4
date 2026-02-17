// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidateDebtTest is LiquidationLogicBaseTest {
  using SafeCast for *;
  using WadRayMath for uint256;

  IHub internal hub;
  ISpoke internal spoke;
  IERC20 internal asset;
  uint256 internal assetId;
  uint256 internal assetDecimals;
  uint256 internal reserveId;
  address internal liquidator;
  address internal user;

  function setUp() public override {
    super.setUp();

    hub = hub1;
    spoke = ISpoke(address(liquidationLogicWrapper));
    assetId = wethAssetId;
    assetDecimals = hub.getAsset(assetId).decimals;
    asset = IERC20(hub.getAsset(assetId).underlying);
    reserveId = 1;
    liquidator = makeAddr('liquidator');
    user = makeAddr('user');

    // Set initial storage values
    liquidationLogicWrapper.setBorrower(user);
    liquidationLogicWrapper.setLiquidator(liquidator);
    liquidationLogicWrapper.setBorrowerBorrowingStatus(reserveId, true);

    // Add liquidation logic wrapper as a spoke
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });
    vm.prank(HUB_ADMIN);
    hub.addSpoke(assetId, address(spoke), spokeConfig);

    // Add liquidity, remove liquidity, refresh premium and skip time to accrue both drawn and premium debt
    address tempUser = makeUser();
    deal(address(asset), tempUser, MAX_SUPPLY_AMOUNT);
    Utils.add(hub, assetId, address(spoke), MAX_SUPPLY_AMOUNT, tempUser);
    Utils.draw(hub, assetId, address(spoke), tempUser, MAX_SUPPLY_AMOUNT);
    vm.startPrank(address(spoke));
    hub.refreshPremium(
      assetId,
      _getExpectedPremiumDelta({
        hub: hub,
        assetId: assetId,
        oldPremiumShares: 0,
        oldPremiumOffsetRay: 0,
        drawnShares: 1e6 * (10 ** assetDecimals),
        riskPremium: 100_00,
        restoredPremiumRay: 0
      })
    );
    vm.stopPrank();
    skip(365 days);
    (uint256 spokeDrawnOwed, uint256 spokePremiumOwed) = hub.getSpokeOwed(assetId, address(spoke));
    assertGt(spokeDrawnOwed, 10000e18);
    assertGt(spokePremiumOwed, 10000e18);

    // Mint tokens to liquidator and approve spoke
    deal(address(asset), liquidator, spokeDrawnOwed + spokePremiumOwed);
    Utils.approve(spoke, address(asset), liquidator, spokeDrawnOwed + spokePremiumOwed);
  }

  function test_liquidateDebt_fuzz(uint256) public {
    IHub.SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke));
    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);

    uint256 spokePremiumOwedRay = _calculatePremiumDebtRay(
      hub,
      assetId,
      spokeData.premiumShares,
      spokeData.premiumOffsetRay
    );

    uint256 drawnShares = vm.randomUint(1, spokeData.drawnShares);
    uint256 premiumDebtRay = vm.randomUint(0, spokePremiumOwedRay);
    ISpoke.UserPosition memory initialPosition = _updateStorage(drawnShares, premiumDebtRay);

    uint256 drawnSharesToLiquidate;
    uint256 premiumDebtRayToLiquidate;
    bool liquidatePremiumOnly = vm.randomBool();
    if (liquidatePremiumOnly) {
      premiumDebtRayToLiquidate = vm.randomUint(1, premiumDebtRay);
    } else {
      premiumDebtRayToLiquidate = premiumDebtRay;
      drawnSharesToLiquidate = vm.randomUint(1, drawnShares);
    }

    uint256 initialHubBalance = asset.balanceOf(address(hub));
    uint256 initialLiquidatorBalance = asset.balanceOf(liquidator);

    expectCall({
      drawnIndex: drawnIndex,
      premiumShares: initialPosition.premiumShares,
      premiumOffsetRay: initialPosition.premiumOffsetRay,
      drawnSharesToLiquidate: drawnSharesToLiquidate,
      premiumDebtRayToLiquidate: premiumDebtRayToLiquidate
    });

    LiquidationLogic.LiquidateDebtResult memory liquidateDebtResult = liquidationLogicWrapper
      .liquidateDebt(
        LiquidationLogic.LiquidateDebtParams({
          hub: hub,
          assetId: assetId,
          underlying: address(asset),
          reserveId: reserveId,
          drawnSharesToLiquidate: drawnSharesToLiquidate,
          premiumDebtRayToLiquidate: premiumDebtRayToLiquidate,
          drawnIndex: drawnIndex,
          liquidator: liquidator
        })
      );

    uint256 amountRestored = drawnSharesToLiquidate.rayMulUp(drawnIndex) +
      premiumDebtRayToLiquidate.fromRayUp();
    assertEq(liquidateDebtResult.amountRestored, amountRestored);
    assertEq(liquidateDebtResult.isDebtPositionEmpty, drawnShares == drawnSharesToLiquidate);
    assertEq(
      liquidationLogicWrapper.getBorrowerBorrowingStatus(reserveId),
      !liquidateDebtResult.isDebtPositionEmpty
    );
    assertPosition(
      liquidationLogicWrapper.getDebtPosition(user),
      initialPosition,
      drawnSharesToLiquidate,
      premiumDebtRayToLiquidate
    );
    assertEq(asset.balanceOf(address(hub)), initialHubBalance + amountRestored);
    assertEq(asset.balanceOf(liquidator), initialLiquidatorBalance - amountRestored);
  }

  // reverts with arithmetic underflow if more debt is liquidated than the position has
  function test_liquidateDebt_revertsWith_ArithmeticUnderflow() public {
    uint256 drawnShares = 100e18;
    uint256 premiumDebtRay = 10e18 * WadRayMath.RAY;
    _updateStorage(drawnShares, premiumDebtRay);

    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);

    vm.expectRevert(stdError.arithmeticError);
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        hub: hub,
        assetId: assetId,
        underlying: address(asset),
        reserveId: reserveId,
        drawnSharesToLiquidate: 0,
        premiumDebtRayToLiquidate: premiumDebtRay + 1,
        drawnIndex: drawnIndex,
        liquidator: liquidator
      })
    );

    vm.expectRevert(stdError.arithmeticError);
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        hub: hub,
        assetId: assetId,
        underlying: address(asset),
        reserveId: reserveId,
        drawnSharesToLiquidate: drawnShares + 1,
        premiumDebtRayToLiquidate: premiumDebtRay,
        drawnIndex: drawnIndex,
        liquidator: liquidator
      })
    );
  }

  // reverts when spoke does not have enough allowance from liquidator
  function test_liquidateDebt_revertsWith_InsufficientAllowance() public {
    uint256 drawnShares = 100e18;
    uint256 premiumDebtRay = 10e18 * WadRayMath.RAY;
    _updateStorage(drawnShares, premiumDebtRay);

    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);

    uint256 amountToRestore = drawnShares.rayMulUp(drawnIndex) + premiumDebtRay.fromRayUp();
    Utils.approve(spoke, address(asset), liquidator, amountToRestore - 1);

    vm.expectRevert();
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        hub: hub,
        assetId: assetId,
        underlying: address(asset),
        reserveId: reserveId,
        drawnSharesToLiquidate: drawnShares,
        premiumDebtRayToLiquidate: premiumDebtRay,
        drawnIndex: drawnIndex,
        liquidator: liquidator
      })
    );
  }

  // reverts when liquidator does not have enough balance
  function test_liquidateDebt_revertsWith_InsufficientBalance() public {
    uint256 drawnShares = 100e18;
    uint256 premiumDebtRay = 10e18 * WadRayMath.RAY;
    _updateStorage(drawnShares, premiumDebtRay);

    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);

    uint256 amountToRestore = drawnShares.rayMulUp(drawnIndex) + premiumDebtRay.fromRayUp();
    deal(address(asset), liquidator, amountToRestore - 1);

    vm.expectRevert();
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        hub: hub,
        assetId: assetId,
        underlying: address(asset),
        reserveId: reserveId,
        drawnSharesToLiquidate: drawnShares,
        premiumDebtRayToLiquidate: premiumDebtRay,
        drawnIndex: drawnIndex,
        liquidator: liquidator
      })
    );
  }

  function expectCall(
    uint256 drawnIndex,
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnSharesToLiquidate,
    uint256 premiumDebtRayToLiquidate
  ) internal {
    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      hub: hub,
      assetId: assetId,
      oldPremiumShares: premiumShares,
      oldPremiumOffsetRay: premiumOffsetRay,
      drawnShares: 0,
      riskPremium: 0,
      restoredPremiumRay: premiumDebtRayToLiquidate
    });

    vm.expectCall(
      address(hub),
      abi.encodeCall(
        IHubBase.restore,
        (assetId, drawnSharesToLiquidate.rayMulUp(drawnIndex), premiumDelta)
      )
    );
  }

  function _updateStorage(
    uint256 drawnShares,
    uint256 premiumDebtRay
  ) internal returns (ISpoke.UserPosition memory) {
    liquidationLogicWrapper.setDebtPositionDrawnShares(drawnShares);
    uint256 premiumShares = hub.previewDrawByAssets(assetId, premiumDebtRay.fromRayUp());
    liquidationLogicWrapper.setDebtPositionPremiumShares(premiumShares);
    liquidationLogicWrapper.setDebtPositionPremiumOffsetRay(
      _calculatePremiumAssetsRay(hub, assetId, premiumShares).toInt256() - premiumDebtRay.toInt256()
    );

    return liquidationLogicWrapper.getDebtPosition(user);
  }

  function assertPosition(
    ISpoke.UserPosition memory newPosition,
    ISpoke.UserPosition memory initialPosition,
    uint256 drawnSharesLiquidated,
    uint256 premiumDebtRayLiquidated
  ) internal view {
    uint256 premiumDebtRay = _calculatePremiumDebtRay(
      hub,
      assetId,
      initialPosition.premiumShares,
      initialPosition.premiumOffsetRay
    );
    initialPosition.drawnShares -= drawnSharesLiquidated.toUint120();
    initialPosition.premiumShares = 0;
    initialPosition.premiumOffsetRay = -(premiumDebtRay - premiumDebtRayLiquidated)
      .toInt256()
      .toInt200();
    assertEq(newPosition, initialPosition);
  }
}
