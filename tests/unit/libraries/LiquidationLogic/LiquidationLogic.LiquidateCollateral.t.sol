// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicLiquidateCollateralTest is LiquidationLogicBaseTest {
  using SafeCast for uint256;

  LiquidationLogic.LiquidateCollateralParams params;

  IHub hub;
  ISpoke spoke;
  IERC20 asset;
  uint256 assetId;
  uint256 suppliedShares;
  uint256 reserveId;
  address borrower;

  ISpoke.Reserve initialReserve;
  ISpoke.UserPosition initialPosition;

  function setUp() public override {
    super.setUp();

    hub = hub1;
    spoke = ISpoke(address(liquidationLogicWrapper));
    assetId = wethAssetId;
    reserveId = _wethReserveId(spoke);
    asset = IERC20(hub.getAsset(assetId).underlying);
    suppliedShares = 100e18;
    borrower = makeAddr('borrower');

    liquidationLogicWrapper.setCollateralReserveHub(hub);
    liquidationLogicWrapper.setCollateralReserveAssetId(assetId);
    liquidationLogicWrapper.setCollateralReserveId(reserveId);
    liquidationLogicWrapper.setBorrower(borrower);
    liquidationLogicWrapper.setCollateralPositionSuppliedShares(suppliedShares);

    initialReserve = liquidationLogicWrapper.getCollateralReserve();
    initialPosition = liquidationLogicWrapper.getCollateralPosition();

    params.liquidator = makeAddr('liquidator');

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumCap: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });

    vm.prank(HUB_ADMIN);
    hub.addSpoke(assetId, address(spoke), spokeConfig);

    address tempUser = makeUser();
    deal(address(asset), tempUser, MAX_SUPPLY_AMOUNT);
    Utils.add(hub, assetId, address(spoke), MAX_SUPPLY_AMOUNT, tempUser);
  }

  function test_liquidateCollateral_fuzz(
    uint256 collateralToLiquidate,
    uint256 collateralToLiquidator
  ) public {
    params.collateralToLiquidate = bound(
      collateralToLiquidate,
      1,
      hub.previewRemoveByShares(assetId, suppliedShares)
    );
    params.collateralToLiquidator = bound(collateralToLiquidator, 1, params.collateralToLiquidate);
    params.collateralReserveId = reserveId;
    params.user = borrower;

    uint256 initialHubBalance = asset.balanceOf(address(hub));

    uint256 sharesToLiquidate = expectCalls(params);
    bool isPositionEmpty = liquidationLogicWrapper.liquidateCollateral(params);

    assertEq(liquidationLogicWrapper.getCollateralReserve(), initialReserve);
    assertPosition(
      liquidationLogicWrapper.getCollateralPosition(),
      initialPosition,
      suppliedShares - sharesToLiquidate
    );

    assertEq(isPositionEmpty, suppliedShares == sharesToLiquidate);
    assertEq(asset.balanceOf(address(hub)), initialHubBalance - params.collateralToLiquidator);
    assertEq(asset.balanceOf(params.liquidator), params.collateralToLiquidator);
    assertApproxEqAbs(
      hub.getSpokeAddedShares(assetId, address(treasurySpoke)),
      params.collateralToLiquidate - params.collateralToLiquidator,
      1
    );
  }

  // hub reverts on remove when collateralToLiquidator is 0
  function test_liquidateCollateral_fuzz_revertsWith_InvalidAmount(
    uint256 collateralToLiquidate
  ) public {
    params.collateralToLiquidate = bound(
      collateralToLiquidate,
      0,
      hub.previewRemoveByShares(assetId, suppliedShares)
    );
    params.collateralToLiquidator = 0;
    params.user = borrower;

    vm.expectRevert(IHub.InvalidAmount.selector);
    liquidationLogicWrapper.liquidateCollateral(params);
  }

  // reverts with arithmetic underflow when updating user's supplied shares
  function test_liquidateCollateral_fuzz_revertsWith_ArithmeticUnderflow(
    uint256 collateralToLiquidate,
    uint256 collateralToLiquidator
  ) public {
    params.collateralToLiquidate = bound(
      collateralToLiquidate,
      hub.previewRemoveByShares(assetId, suppliedShares) + 1,
      MAX_SUPPLY_AMOUNT
    );
    params.collateralToLiquidator = bound(collateralToLiquidator, 1, params.collateralToLiquidate);

    vm.expectRevert(stdError.arithmeticError);
    liquidationLogicWrapper.liquidateCollateral(params);
  }

  function assertPosition(
    ISpoke.UserPosition memory newPosition,
    ISpoke.UserPosition memory initPosition,
    uint256 newSuppliedShares
  ) internal pure {
    initPosition.suppliedShares = newSuppliedShares.toUint128();
    assertEq(newPosition, initPosition);
  }

  function expectCalls(
    LiquidationLogic.LiquidateCollateralParams memory p
  ) internal returns (uint256) {
    uint256 sharesToLiquidate = hub.previewRemoveByAssets(assetId, p.collateralToLiquidate);
    uint256 sharesToLiquidator = hub.previewRemoveByAssets(assetId, p.collateralToLiquidator);
    uint256 sharesToPayFee = sharesToLiquidate - sharesToLiquidator;

    vm.expectCall(
      address(hub),
      abi.encodeCall(IHubBase.previewRemoveByAssets, (assetId, p.collateralToLiquidate)),
      1
    );
    vm.expectCall(
      address(hub),
      abi.encodeCall(IHubBase.remove, (assetId, p.collateralToLiquidator, p.liquidator)),
      1
    );
    if (sharesToPayFee > 0) {
      vm.expectCall(
        address(hub),
        abi.encodeCall(IHubBase.payFeeShares, (assetId, sharesToPayFee)),
        1
      );
    }

    return sharesToLiquidate;
  }
}
