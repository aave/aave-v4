// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidateDebtTest is LiquidationLogicBaseTest {
  using SafeCast for uint256;
  using WadRayMath for uint256;

  LiquidationLogic.LiquidateDebtParams params;

  IHub internal hub;
  ISpoke internal spoke;
  IERC20 internal asset;
  uint256 internal assetId;
  uint256 internal reserveId;
  address internal liquidator;
  uint256 internal realizedPremiumRay;
  address internal user;

  function setUp() public override {
    super.setUp();

    hub = hub1;
    spoke = ISpoke(address(liquidationLogicWrapper));
    assetId = wethAssetId;
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
      IHubBase.PremiumDelta(
        hub.previewRestoreByAssets(assetId, 1e6 * 1e18).toInt256(),
        hub.previewRestoreByAssets(assetId, 1e6 * 1e18).toInt256() * WadRayMath.RAY.toInt256(),
        // 0,
        0
      )
    );
    vm.stopPrank();
    skip(365 days);
    (uint256 spokeDrawnOwed, uint256 spokePremiumOwed) = hub.getSpokeOwed(assetId, address(spoke));
    assertGt(spokeDrawnOwed, 10000e18);
    assertGt(spokePremiumOwed, 10000e18);

    // Refresh premium to realise some premium debt
    // realizedPremiumRay = _calculateAccruedPremiumRay(
    //   hub,
    //   assetId,
    //   1e3 * 1e18,
    //   1e3 * 1e18 * WadRayMath.RAY
    // );
    // assertGt(realizedPremiumRay, 10e18 * WadRayMath.RAY);
    vm.prank(address(spoke));
    hub.refreshPremium(
      assetId,
      IHubBase.PremiumDelta(
        -1e3 * 1e18,
        -1e3 * 1e18 * WadRayMath.RAY.toInt256(),
        // realizedPremiumRay,
        0
      )
    );
    // liquidationLogicWrapper.setDebtPositionRealizedPremiumRay(realizedPremiumRay);

    // Mint tokens to liquidator and approve spoke
    deal(address(asset), liquidator, spokeDrawnOwed + spokePremiumOwed);
    Utils.approve(spoke, address(asset), liquidator, spokeDrawnOwed + spokePremiumOwed);
  }

  function expectCall(
    uint256 drawnDebt,
    uint256 premiumShares,
    uint256 premiumOffsetRay,
    // uint256 accruedPremiumRay,
    uint256 drawnToLiquidate,
    uint256 premiumToLiquidateRay
  ) internal {
    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: -premiumShares.toInt256(),
      offsetDeltaRay: -premiumOffsetRay.toInt256(),
      // accruedPremiumRay: accruedPremiumRay,
      restoredPremiumRay: premiumToLiquidateRay
    });
    vm.expectCall(
      address(hub),
      abi.encodeCall(IHubBase.restore, (assetId, drawnToLiquidate, premiumDelta))
    );
  }

  function test_liquidateDebt_fuzz(uint256) public {
    (uint256 spokeDrawnOwed, ) = hub.getSpokeOwed(assetId, address(spoke));
    IHub.SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke));
    uint256 spokePremiumOwedRay = _calculatePremiumDebtRay(
      hub,
      assetId,
      spokeData.premiumShares,
      spokeData.premiumOffsetRay,
      hub.getAssetDrawnIndex(assetId)
    );

    uint256 drawnDebt = vm.randomUint(0, spokeDrawnOwed);
    uint256 premiumDebtRay = vm.randomUint(0, spokePremiumOwedRay);
    vm.assume(drawnDebt * WadRayMath.RAY + premiumDebtRay > 0);

    uint256 debtToLiquidateRay = vm.randomUint(1, drawnDebt * WadRayMath.RAY + premiumDebtRay);
    (uint256 drawnToLiquidate, uint256 premiumToLiquidateRay) = _calculateLiquidationAmounts(
      drawnDebt,
      premiumDebtRay,
      debtToLiquidateRay
    );
    uint256 drawnSharesLiquidated = hub.previewRestoreByAssets(assetId, drawnToLiquidate);

    // uint256 accruedPremiumRay = premiumToLiquidateRay - realizedPremiumRay;
    ISpoke.UserPosition memory initialPosition = updateStorage(
      drawnDebt,
      premiumDebtRay
      // accruedPremiumRay
    );

    uint256 initialHubBalance = asset.balanceOf(address(hub));
    uint256 initialLiquidatorBalance = asset.balanceOf(liquidator);

    expectCall(
      drawnDebt,
      initialPosition.premiumShares,
      initialPosition.premiumOffsetRay,
      // accruedPremiumRay,
      drawnToLiquidate,
      premiumToLiquidateRay
    );
    bool isPositionEmpty = liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidateRay.fromRayUp(),
        premiumDebtRay: premiumDebtRay,
        // accruedPremiumRay: accruedPremiumRay,
        liquidator: liquidator,
        user: user
      })
    );

    assertEq(isPositionEmpty, debtToLiquidateRay == drawnDebt * WadRayMath.RAY + premiumDebtRay);
    assertEq(liquidationLogicWrapper.getBorrowerBorrowingStatus(reserveId), !isPositionEmpty);
    assertPosition(
      liquidationLogicWrapper.getDebtPosition(user),
      initialPosition,
      drawnSharesLiquidated,
      // accruedPremiumRay,
      premiumToLiquidateRay
    );
    assertEq(asset.balanceOf(address(hub)), initialHubBalance + debtToLiquidateRay.fromRayUp());
    assertEq(
      asset.balanceOf(liquidator),
      initialLiquidatorBalance - debtToLiquidateRay.fromRayUp()
    );
  }

  // reverts with arithmetic underflow if more debt is liquidated than the position has
  function test_liquidateDebt_revertsWith_ArithmeticUnderflow() public {
    uint256 drawnDebt = 100e18;
    uint256 premiumDebtRay = 10e18 * WadRayMath.RAY;
    // uint256 accruedPremiumRay = 5e18 * WadRayMath.RAY;
    updateStorage(drawnDebt, premiumDebtRay);

    uint256 debtToLiquidateRay = drawnDebt * WadRayMath.RAY + premiumDebtRay + WadRayMath.RAY;

    vm.expectRevert(stdError.arithmeticError);
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidateRay.fromRayUp(),
        premiumDebtRay: premiumDebtRay,
        // accruedPremiumRay: accruedPremiumRay,
        liquidator: liquidator,
        user: user
      })
    );
  }

  // reverts when spoke does not have enough allowance from liquidator
  function test_liquidateDebt_revertsWith_InsufficientAllowance() public {
    uint256 drawnDebt = 100e18;
    uint256 premiumDebtRay = 10e18 * WadRayMath.RAY;
    // uint256 accruedPremiumRay = 5e18 * WadRayMath.RAY;
    updateStorage(drawnDebt, premiumDebtRay);

    uint256 debtToLiquidateRay = drawnDebt * WadRayMath.RAY + premiumDebtRay;
    uint256 debtToLiquidate = debtToLiquidateRay.fromRayUp();
    Utils.approve(spoke, address(asset), liquidator, debtToLiquidate - 1);

    vm.expectRevert();
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidate,
        premiumDebtRay: premiumDebtRay,
        // accruedPremiumRay: accruedPremiumRay,
        liquidator: liquidator,
        user: user
      })
    );
  }

  // reverts when liquidator does not have enough balance
  function test_liquidateDebt_revertsWith_InsufficientBalance() public {
    uint256 drawnDebt = 100e18;
    uint256 premiumDebtRay = 10e18 * WadRayMath.RAY;
    // uint256 accruedPremiumRay = 5e18 * WadRayMath.RAY;
    updateStorage(drawnDebt, premiumDebtRay);

    uint256 debtToLiquidateRay = drawnDebt * WadRayMath.RAY + premiumDebtRay;
    uint256 debtToLiquidate = debtToLiquidateRay.fromRayUp();
    deal(address(asset), liquidator, debtToLiquidate - 1);

    vm.expectRevert();
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidate,
        premiumDebtRay: premiumDebtRay,
        // accruedPremiumRay: accruedPremiumRay,
        liquidator: liquidator,
        user: user
      })
    );
  }

  function updateStorage(
    uint256 drawnDebt,
    uint256 premiumDebtRay
    // uint256 accruedPremiumRay
  ) internal returns (ISpoke.UserPosition memory) {
    liquidationLogicWrapper.setDebtPositionDrawnShares(
      hub.previewRestoreByAssets(assetId, drawnDebt)
    );
    uint256 premiumDebtShares = hub.previewDrawByAssets(assetId, premiumDebtRay.fromRayUp());
    liquidationLogicWrapper.setDebtPositionPremiumShares(premiumDebtShares);
    liquidationLogicWrapper.setDebtPositionPremiumOffsetRay(
      _calculatePremiumAssetsRay(hub, assetId, premiumDebtShares)
      // - accruedPremiumRay
    );

    return liquidationLogicWrapper.getDebtPosition(user);
  }

  function assertPosition(
    ISpoke.UserPosition memory newPosition,
    ISpoke.UserPosition memory initialPosition,
    uint256 drawnSharesLiquidated,
    // uint256 accruedPremiumRay,
    uint256 premiumToLiquidateRay
  ) internal {
    initialPosition.drawnShares -= drawnSharesLiquidated.toUint120();
    initialPosition.premiumShares = 0;
    initialPosition.premiumOffsetRay = 0;
    // initialPosition.realizedPremiumRay =
    //   initialPosition.realizedPremiumRay +
    //   accruedPremiumRay -
    //   premiumToLiquidateRay;
    assertEq(newPosition, initialPosition);
  }

  function _calculateLiquidationAmounts(
    uint256 drawnDebt,
    uint256 premiumDebtRay,
    uint256 debtToLiquidateRay
  ) internal returns (uint256, uint256) {
    uint256 premiumToLiquidateRay = _min(premiumDebtRay, debtToLiquidateRay);
    uint256 drawnToLiquidate = (debtToLiquidateRay - premiumToLiquidateRay) / WadRayMath.RAY;
    return (drawnToLiquidate, premiumToLiquidateRay);
  }
}
