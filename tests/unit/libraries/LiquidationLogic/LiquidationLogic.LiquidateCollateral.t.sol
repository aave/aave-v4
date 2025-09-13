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

  DataTypes.Reserve initialReserve;
  DataTypes.UserPosition initialPosition;

  function setUp() public override {
    super.setUp();

    hub = hub1;
    spoke = ISpoke(address(liquidationLogicWrapper));
    assetId = wethAssetId;
    asset = IERC20(hub.getAsset(assetId).underlying);
    suppliedShares = 100e18;

    liquidationLogicWrapper.setCollateralReserveHub(hub);
    liquidationLogicWrapper.setCollateralReserveAssetId(assetId);
    liquidationLogicWrapper.setCollateralPositionSuppliedShares(suppliedShares);

    initialReserve = liquidationLogicWrapper.getCollateralReserve();
    initialPosition = liquidationLogicWrapper.getCollateralPosition();

    params.liquidator = makeAddr('liquidator');

    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      active: true,
      addCap: Constants.MAX_CAP,
      drawCap: Constants.MAX_CAP
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
    DataTypes.UserPosition memory newPosition,
    DataTypes.UserPosition memory initialPosition,
    uint256 newSuppliedShares
  ) internal {
    initialPosition.suppliedShares = newSuppliedShares.toUint128();
    assertEq(newPosition, initialPosition);
  }

  function expectCalls(
    LiquidationLogic.LiquidateCollateralParams memory params
  ) internal returns (uint256) {
    uint256 sharesToLiquidate = hub.previewRemoveByAssets(assetId, params.collateralToLiquidate);
    uint256 sharesToLiquidator = hub.previewRemoveByAssets(assetId, params.collateralToLiquidator);
    uint256 sharesToPayFee = sharesToLiquidate - sharesToLiquidator;

    vm.expectCall(
      address(hub),
      abi.encodeCall(IHubBase.previewRemoveByAssets, (assetId, params.collateralToLiquidate)),
      1
    );
    vm.expectCall(
      address(hub),
      abi.encodeCall(IHubBase.remove, (assetId, params.collateralToLiquidator, params.liquidator)),
      1
    );
    if (sharesToPayFee > 0) {
      vm.expectCall(address(hub), abi.encodeCall(IHubBase.payFee, (assetId, sharesToPayFee)), 1);
    }

    return sharesToLiquidate;
  }
}
