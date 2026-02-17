// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';
import {HubBase} from 'tests/unit/Hub/HubBase.t.sol';

contract LiquidationLogicLiquidateCollateralTest is LiquidationLogicBaseTest, HubBase {
  using SafeCast for uint256;

  address borrower;
  address liquidator;

  IHub hub;
  ISpoke spoke;
  IERC20 asset;
  uint256 assetId;
  uint256 userSuppliedShares;
  uint256 reserveId;

  ISpoke.UserPosition initialUserPosition;
  ISpoke.UserPosition initialLiquidatorPosition;
  IHub.SpokeData initialTreasurySpokeData;

  function setUp() public override(HubBase, LiquidationLogicBaseTest) {
    LiquidationLogicBaseTest.setUp();

    hub = hub1;
    spoke = ISpoke(address(liquidationLogicWrapper));
    assetId = wethAssetId;
    reserveId = _wethReserveId(spoke);
    asset = IERC20(hub.getAsset(assetId).underlying);
    userSuppliedShares = 100e18;
    borrower = makeAddr('borrower');
    liquidator = makeAddr('liquidator');

    liquidationLogicWrapper.setBorrower(borrower);
    liquidationLogicWrapper.setLiquidator(liquidator);
    liquidationLogicWrapper.setCollateralPositionSuppliedShares(userSuppliedShares);

    initialUserPosition = liquidationLogicWrapper.getCollateralPosition(borrower);
    initialLiquidatorPosition = liquidationLogicWrapper.getCollateralPosition(liquidator);
    initialTreasurySpokeData = hub.getSpoke(assetId, address(treasurySpoke));

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });

    vm.prank(HUB_ADMIN);
    hub.addSpoke(assetId, address(spoke), spokeConfig);

    // add and drawn liquidity to increase supply share price of assetId
    deal(address(asset), alice, MAX_SUPPLY_AMOUNT * 2);
    _addAndDrawLiquidity({
      hub: hub,
      assetId: assetId,
      addUser: alice,
      addSpoke: address(spoke),
      addAmount: userSuppliedShares * 3,
      drawUser: alice,
      drawSpoke: address(spoke),
      drawAmount: userSuppliedShares,
      skipTime: 365 days
    });
  }

  function test_liquidateCollateral_fuzz(
    uint256 sharesToLiquidate,
    uint256 sharesToLiquidator,
    bool receiveShares
  ) public {
    LiquidationLogic.LiquidateCollateralParams memory params = LiquidationLogic
      .LiquidateCollateralParams({
        hub: hub,
        assetId: assetId,
        sharesToLiquidate: bound(sharesToLiquidate, 0, userSuppliedShares),
        sharesToLiquidator: 0, // populated below
        liquidator: liquidator,
        receiveShares: receiveShares
      });
    params.sharesToLiquidator = bound(sharesToLiquidator, 0, params.sharesToLiquidate);

    uint256 initialHubBalance = asset.balanceOf(address(hub));
    uint256 expectedAmountToLiquidator;
    if (!params.receiveShares) {
      expectedAmountToLiquidator = hub.previewRemoveByShares(assetId, params.sharesToLiquidator);
    }
    uint256 expectedAmountRemoved = hub.previewRemoveByShares(assetId, params.sharesToLiquidate);

    _expectCalls(params);
    LiquidationLogic.LiquidateCollateralResult memory result = liquidationLogicWrapper
      .liquidateCollateral(params);

    assertEq(result.amountRemoved, expectedAmountRemoved, 'amountRemoved');
    assertEq(
      result.isCollateralPositionEmpty,
      userSuppliedShares == params.sharesToLiquidate,
      'isCollateralPositionEmpty'
    );

    assertPosition(
      liquidationLogicWrapper.getCollateralPosition(borrower),
      initialUserPosition,
      userSuppliedShares - params.sharesToLiquidate
    );

    assertEq(asset.balanceOf(params.liquidator), expectedAmountToLiquidator);
    assertPosition(
      liquidationLogicWrapper.getCollateralPosition(params.liquidator),
      initialLiquidatorPosition,
      initialLiquidatorPosition.suppliedShares +
        (params.receiveShares ? params.sharesToLiquidator : 0)
    );

    assertEq(asset.balanceOf(address(hub)), initialHubBalance - expectedAmountToLiquidator);
    assertEq(
      hub.getSpokeAddedShares(assetId, address(treasurySpoke)),
      params.sharesToLiquidate - params.sharesToLiquidator
    );
  }

  // reverts with arithmetic underflow when updating user's supplied shares
  function test_liquidateCollateral_revertsWith_ArithmeticUnderflow() public {
    LiquidationLogic.LiquidateCollateralParams memory params = LiquidationLogic
      .LiquidateCollateralParams({
        hub: hub,
        assetId: assetId,
        sharesToLiquidate: userSuppliedShares + 1,
        sharesToLiquidator: userSuppliedShares + 1,
        liquidator: liquidator,
        receiveShares: false
      });

    vm.expectRevert(stdError.arithmeticError);
    liquidationLogicWrapper.liquidateCollateral(params);
  }

  // reverts with arithmetic underflow when computing fee shares
  function test_liquidateCollateral_revertsWith_ArithmeticUnderflow_FeeShares() public {
    LiquidationLogic.LiquidateCollateralParams memory params = LiquidationLogic
      .LiquidateCollateralParams({
        hub: hub,
        assetId: assetId,
        sharesToLiquidate: userSuppliedShares,
        sharesToLiquidator: userSuppliedShares + 1,
        liquidator: liquidator,
        receiveShares: false
      });

    vm.expectRevert(stdError.arithmeticError);
    liquidationLogicWrapper.liquidateCollateral(params);
  }

  function assertPosition(
    ISpoke.UserPosition memory newPosition,
    ISpoke.UserPosition memory initPosition,
    uint256 newSuppliedShares
  ) internal pure {
    initPosition.suppliedShares = newSuppliedShares.toUint120();
    assertEq(newPosition, initPosition);
  }

  function _expectCalls(LiquidationLogic.LiquidateCollateralParams memory p) internal {
    uint256 collateralToLiquidator = hub.previewRemoveByShares(assetId, p.sharesToLiquidator);

    vm.expectCall(
      address(hub),
      abi.encodeCall(IHubBase.previewRemoveByShares, (assetId, p.sharesToLiquidate)),
      1
    );

    if (p.sharesToLiquidator != p.sharesToLiquidate) {
      // otherwise already checked above
      vm.expectCall(
        address(hub),
        abi.encodeCall(IHubBase.previewRemoveByShares, (assetId, p.sharesToLiquidator)),
        (p.sharesToLiquidator > 0 && !p.receiveShares) ? 1 : 0
      );
    }

    vm.expectCall(
      address(hub),
      abi.encodeCall(IHubBase.remove, (assetId, collateralToLiquidator, p.liquidator)),
      (p.sharesToLiquidator > 0 && !p.receiveShares) ? 1 : 0
    );

    uint256 sharesToPayFee = p.sharesToLiquidate - p.sharesToLiquidator;
    vm.expectCall(
      address(hub),
      abi.encodeCall(IHubBase.payFeeShares, (assetId, sharesToPayFee)),
      sharesToPayFee > 0 ? 1 : 0
    );
  }
}
