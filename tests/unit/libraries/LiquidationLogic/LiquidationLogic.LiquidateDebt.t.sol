// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidateDebtTest is LiquidationLogicBaseTest {
  using SafeCast for *;
  using WadRayMath for uint256;

  LiquidationLogic.LiquidateDebtParams params;

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
    liquidationLogicWrapper.setDebtReserveId(reserveId);
    liquidationLogicWrapper.setDebtReserveHub(hub);
    liquidationLogicWrapper.setDebtReserveAssetId(assetId);
    liquidationLogicWrapper.setDebtReserveUnderlying(address(asset));
    liquidationLogicWrapper.setBorrowerBorrowingStatus(reserveId, true);

    // Add liquidation logic wrapper as a spoke
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
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
    (uint256 spokeDrawnOwed, ) = hub.getSpokeOwed(assetId, address(spoke));
    IHub.SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke));
    uint256 spokePremiumOwedRay = _calculatePremiumDebtRay(
      hub,
      assetId,
      spokeData.premiumShares,
      spokeData.premiumOffsetRay
    );

    uint256 drawnDebt = vm.randomUint(0, spokeDrawnOwed);
    uint256 premiumDebtRay = vm.randomUint(0, spokePremiumOwedRay);
    vm.assume(drawnDebt * WadRayMath.RAY + premiumDebtRay > 0);

    uint256 debtToLiquidate = vm.randomUint(1, drawnDebt + premiumDebtRay.fromRayUp());
    (uint256 drawnToLiquidate, uint256 premiumToLiquidateRay) = _calculateLiquidationAmounts(
      premiumDebtRay,
      debtToLiquidate
    );

    ISpoke.UserPosition memory initialPosition = _updateStorage(drawnDebt, premiumDebtRay);

    uint256 initialHubBalance = asset.balanceOf(address(hub));
    uint256 initialLiquidatorBalance = asset.balanceOf(liquidator);

    expectCall(
      initialPosition.premiumShares,
      initialPosition.premiumOffsetRay,
      drawnToLiquidate,
      premiumToLiquidateRay
    );

    (uint256 drawnSharesLiquidated, , bool isPositionEmpty) = liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidate,
        premiumDebtRay: premiumDebtRay,
        drawnIndex: hub.getAssetDrawnIndex(assetId),
        liquidator: liquidator,
        user: user
      })
    );

    assertEq(drawnSharesLiquidated, hub.previewRestoreByAssets(assetId, drawnToLiquidate));
    assertEq(isPositionEmpty, debtToLiquidate == drawnDebt + premiumDebtRay.fromRayUp());
    assertEq(liquidationLogicWrapper.getBorrowerBorrowingStatus(reserveId), !isPositionEmpty);
    assertPosition(
      liquidationLogicWrapper.getDebtPosition(user),
      initialPosition,
      drawnSharesLiquidated,
      premiumToLiquidateRay
    );
    assertEq(asset.balanceOf(address(hub)), initialHubBalance + debtToLiquidate);
    assertEq(asset.balanceOf(liquidator), initialLiquidatorBalance - debtToLiquidate);
  }

  // reverts with arithmetic underflow if more debt is liquidated than the position has
  function test_liquidateDebt_revertsWith_ArithmeticUnderflow() public {
    uint256 drawnDebt = 100e18;
    uint256 premiumDebtRay = 10e18 * WadRayMath.RAY;
    _updateStorage(drawnDebt, premiumDebtRay);

    uint256 debtToLiquidate = drawnDebt + premiumDebtRay.fromRayUp() + 1;

    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);

    vm.expectRevert(stdError.arithmeticError);
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidate,
        premiumDebtRay: premiumDebtRay,
        drawnIndex: drawnIndex,
        liquidator: liquidator,
        user: user
      })
    );
  }

  // reverts when spoke does not have enough allowance from liquidator
  function test_liquidateDebt_revertsWith_InsufficientAllowance() public {
    uint256 drawnDebt = 100e18;
    uint256 premiumDebtRay = 10e18 * WadRayMath.RAY;
    _updateStorage(drawnDebt, premiumDebtRay);

    uint256 debtToLiquidateRay = drawnDebt * WadRayMath.RAY + premiumDebtRay;
    uint256 debtToLiquidate = debtToLiquidateRay.fromRayUp();
    Utils.approve(spoke, address(asset), liquidator, debtToLiquidate - 1);

    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);

    vm.expectRevert();
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidate,
        premiumDebtRay: premiumDebtRay,
        drawnIndex: drawnIndex,
        liquidator: liquidator,
        user: user
      })
    );
  }

  // reverts when liquidator does not have enough balance
  function test_liquidateDebt_revertsWith_InsufficientBalance() public {
    uint256 drawnDebt = 100e18;
    uint256 premiumDebtRay = 10e18 * WadRayMath.RAY;
    _updateStorage(drawnDebt, premiumDebtRay);

    uint256 debtToLiquidateRay = drawnDebt * WadRayMath.RAY + premiumDebtRay;
    uint256 debtToLiquidate = debtToLiquidateRay.fromRayUp();
    deal(address(asset), liquidator, debtToLiquidate - 1);

    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);

    vm.expectRevert();
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidate,
        premiumDebtRay: premiumDebtRay,
        drawnIndex: drawnIndex,
        liquidator: liquidator,
        user: user
      })
    );
  }

  function expectCall(
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnToLiquidate,
    uint256 premiumToLiquidateRay
  ) internal {
    IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      hub: hub,
      assetId: assetId,
      oldPremiumShares: premiumShares,
      oldPremiumOffsetRay: premiumOffsetRay,
      drawnShares: 0,
      riskPremium: 0,
      restoredPremiumRay: premiumToLiquidateRay
    });
    vm.expectCall(
      address(hub),
      abi.encodeCall(IHubBase.restore, (assetId, drawnToLiquidate, premiumDelta))
    );
  }

  function _updateStorage(
    uint256 drawnDebt,
    uint256 premiumDebtRay
  ) internal returns (ISpoke.UserPosition memory) {
    liquidationLogicWrapper.setDebtPositionDrawnShares(
      hub.previewRestoreByAssets(assetId, drawnDebt)
    );
    uint256 premiumDebtShares = hub.previewDrawByAssets(assetId, premiumDebtRay.fromRayUp());
    liquidationLogicWrapper.setDebtPositionPremiumShares(premiumDebtShares);
    liquidationLogicWrapper.setDebtPositionPremiumOffsetRay(
      _calculatePremiumAssetsRay(hub, assetId, premiumDebtShares).toInt256() -
        premiumDebtRay.toInt256()
    );

    return liquidationLogicWrapper.getDebtPosition(user);
  }

  function assertPosition(
    ISpoke.UserPosition memory newPosition,
    ISpoke.UserPosition memory initialPosition,
    uint256 drawnSharesLiquidated,
    uint256 premiumToLiquidateRay
  ) internal view {
    uint256 premiumDebtRay = _calculatePremiumDebtRay(
      hub,
      assetId,
      initialPosition.premiumShares,
      initialPosition.premiumOffsetRay
    );
    initialPosition.drawnShares -= drawnSharesLiquidated.toUint120();
    initialPosition.premiumShares = 0;
    initialPosition.premiumOffsetRay = -(premiumDebtRay - premiumToLiquidateRay)
      .toInt256()
      .toInt200();
    assertEq(newPosition, initialPosition);
  }

  function _calculateLiquidationAmounts(
    uint256 premiumDebtRay,
    uint256 debtToLiquidate
  ) internal pure returns (uint256, uint256) {
    uint256 debtToLiquidateRay = debtToLiquidate.toRay();
    uint256 premiumToLiquidateRay = _min(premiumDebtRay, debtToLiquidateRay);
    uint256 drawnToLiquidate = debtToLiquidate - premiumToLiquidateRay.fromRayUp();
    return (drawnToLiquidate, premiumToLiquidateRay);
  }
}
