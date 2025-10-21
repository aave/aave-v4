// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidateDebtTest is LiquidationLogicBaseTest {
  using SafeCast for uint256;

  LiquidationLogic.LiquidateDebtParams params;

  IHub internal hub;
  ISpoke internal spoke;
  IERC20 internal asset;
  uint256 internal assetId;
  uint256 internal reserveId;
  address internal liquidator;
  uint256 internal realizedPremium;
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
    liquidationLogicWrapper.setDebtReserveId(reserveId);
    liquidationLogicWrapper.setDebtReserveHub(hub);
    liquidationLogicWrapper.setDebtReserveAssetId(assetId);
    liquidationLogicWrapper.setBorrowingStatus(reserveId, true);
    liquidationLogicWrapper.setBorrower(user);

    // Add liquidation logic wrapper as a spoke
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumCap: Constants.MAX_ALLOWED_COLLATERAL_RISK
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
        1e6 * 1e18,
        0
      )
    );
    vm.stopPrank();
    skip(365 days);
    (uint256 spokeDrawnOwed, uint256 spokePremiumOwed) = hub.getSpokeOwed(assetId, address(spoke));
    assertGt(spokeDrawnOwed, 10000e18);
    assertGt(spokePremiumOwed, 10000e18);

    // Refresh premium to realise some premium debt
    realizedPremium = hub.previewRestoreByShares(assetId, 1e3 * 1e18) - 1e3 * 1e18;
    assertGt(realizedPremium, 10e18);
    vm.prank(address(spoke));
    hub.refreshPremium(
      assetId,
      IHubBase.PremiumDelta(-1e3 * 1e18, -1e3 * 1e18, realizedPremium.toInt256())
    );
    liquidationLogicWrapper.setDebtPositionRealizedPremium(realizedPremium);

    // Mint tokens to liquidator and approve hub
    deal(address(asset), liquidator, spokeDrawnOwed + spokePremiumOwed);
    Utils.approve(hub, assetId, liquidator, spokeDrawnOwed + spokePremiumOwed);
  }

  function expectCall(
    uint256 drawnDebt,
    uint256 premiumDebt,
    uint256 accruedPremium,
    uint256 debtToLiquidate
  ) internal returns (uint256, uint256) {
    uint256 premiumDebtToLiquidate = _min(debtToLiquidate, premiumDebt);
    uint256 drawnDebtToLiquidate = _min(drawnDebt, debtToLiquidate - premiumDebtToLiquidate);

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: -hub.previewRestoreByAssets(assetId, premiumDebt).toInt256(),
      offsetDelta: -(premiumDebt - accruedPremium).toInt256(),
      realizedDelta: accruedPremium.toInt256() - premiumDebtToLiquidate.toInt256()
    });
    vm.expectCall(
      address(hub),
      abi.encodeCall(
        IHubBase.restore,
        (assetId, drawnDebtToLiquidate, premiumDebtToLiquidate, premiumDelta, liquidator)
      )
    );

    return (hub.previewRestoreByAssets(assetId, drawnDebtToLiquidate), premiumDebtToLiquidate);
  }

  function test_liquidateDebt_fuzz(uint256) public {
    (uint256 spokeDrawnOwed, uint256 spokePremiumOwed) = hub.getSpokeOwed(assetId, address(spoke));
    uint256 drawnDebt = vm.randomUint(0, spokeDrawnOwed);
    uint256 premiumDebt = vm.randomUint(0, spokePremiumOwed);
    vm.assume(drawnDebt + premiumDebt > 0);

    uint256 debtToLiquidate = vm.randomUint(1, drawnDebt + premiumDebt);
    uint256 accruedPremium = vm.randomUint(
      _min(premiumDebt, debtToLiquidate) - realizedPremium,
      premiumDebt
    );

    ISpoke.UserPosition memory initialPosition = updateStorage(
      drawnDebt,
      premiumDebt,
      accruedPremium
    );
    uint256 initialHubBalance = asset.balanceOf(address(hub));
    uint256 initialLiquidatorBalance = asset.balanceOf(liquidator);

    (uint256 drawnDebtToLiquidate, uint256 premiumDebtToLiquidate) = expectCall(
      drawnDebt,
      premiumDebt,
      accruedPremium,
      debtToLiquidate
    );
    bool isPositionEmpty = liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidate,
        premiumDebt: premiumDebt,
        accruedPremium: accruedPremium,
        liquidator: liquidator,
        user: user
      })
    );

    assertEq(isPositionEmpty, debtToLiquidate == drawnDebt + premiumDebt);
    assertEq(liquidationLogicWrapper.getBorrowingStatus(reserveId), !isPositionEmpty);
    assertPosition(
      liquidationLogicWrapper.getDebtPosition(),
      initialPosition,
      drawnDebtToLiquidate,
      accruedPremium,
      premiumDebtToLiquidate
    );
    assertEq(asset.balanceOf(address(hub)), initialHubBalance + debtToLiquidate);
    assertEq(asset.balanceOf(liquidator), initialLiquidatorBalance - debtToLiquidate);
  }

  // reverts with arithmetic underflow if more debt is liquidated than the position has
  function test_liquidateDebt_revertsWith_ArithmeticUnderflow() public {
    uint256 drawnDebt = 100e18;
    uint256 premiumDebt = 10e18;
    uint256 accruedPremium = 5e18;
    updateStorage(drawnDebt, premiumDebt, accruedPremium);

    uint256 debtToLiquidate = drawnDebt + premiumDebt + 1;

    vm.expectRevert(stdError.arithmeticError);
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidate,
        premiumDebt: premiumDebt,
        accruedPremium: accruedPremium,
        liquidator: liquidator,
        user: user
      })
    );
  }

  // reverts when hub does not have enough allowance from liquidator
  function test_liquidateDebt_revertsWith_InsufficientAllowance() public {
    uint256 drawnDebt = 100e18;
    uint256 premiumDebt = 10e18;
    uint256 accruedPremium = 5e18;
    updateStorage(drawnDebt, premiumDebt, accruedPremium);

    uint256 debtToLiquidate = drawnDebt + premiumDebt;
    Utils.approve(hub, assetId, liquidator, debtToLiquidate - 1);

    vm.expectRevert();
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidate,
        premiumDebt: premiumDebt,
        accruedPremium: accruedPremium,
        liquidator: liquidator,
        user: user
      })
    );
  }

  // reverts when liquidator does not have enough balance
  function test_liquidateDebt_revertsWith_InsufficientBalance() public {
    uint256 drawnDebt = 100e18;
    uint256 premiumDebt = 10e18;
    uint256 accruedPremium = 5e18;
    updateStorage(drawnDebt, premiumDebt, accruedPremium);

    uint256 debtToLiquidate = drawnDebt + premiumDebt;
    deal(address(asset), liquidator, debtToLiquidate - 1);

    vm.expectRevert();
    liquidationLogicWrapper.liquidateDebt(
      LiquidationLogic.LiquidateDebtParams({
        debtReserveId: reserveId,
        debtToLiquidate: debtToLiquidate,
        premiumDebt: premiumDebt,
        accruedPremium: accruedPremium,
        liquidator: liquidator,
        user: user
      })
    );
  }

  function updateStorage(
    uint256 drawnDebt,
    uint256 premiumDebt,
    uint256 accruedPremium
  ) internal returns (ISpoke.UserPosition memory) {
    liquidationLogicWrapper.setDebtPositionDrawnShares(
      hub.previewRestoreByAssets(assetId, drawnDebt)
    );
    liquidationLogicWrapper.setDebtPositionPremiumShares(
      hub.previewRestoreByAssets(assetId, premiumDebt)
    );
    liquidationLogicWrapper.setDebtPositionPremiumOffset(premiumDebt - accruedPremium);

    return liquidationLogicWrapper.getDebtPosition();
  }

  function assertPosition(
    ISpoke.UserPosition memory newPosition,
    ISpoke.UserPosition memory initialPosition,
    uint256 drawnSharesLiquidated,
    uint256 accruedPremium,
    uint256 premiumDebtToLiquidate
  ) internal {
    initialPosition.drawnShares -= drawnSharesLiquidated.toUint128();
    initialPosition.premiumShares = 0;
    initialPosition.premiumOffset = 0;
    initialPosition.realizedPremium = (initialPosition.realizedPremium +
      accruedPremium -
      premiumDebtToLiquidate).toUint128();
    assertEq(newPosition, initialPosition);
  }
}
