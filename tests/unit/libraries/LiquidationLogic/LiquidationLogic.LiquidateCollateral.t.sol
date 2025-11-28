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
  uint256 userSuppliedShares;
  uint256 reserveId;
  address borrower;
  address liquidator;

  ISpoke.Reserve initialReserve;
  ISpoke.UserPosition initialUserPosition;
  ISpoke.UserPosition initialLiquidatorPosition;
  IHub.SpokeData initialTreasurySpokeData;

  function setUp() public override {
    super.setUp();

    hub = hub1;
    spoke = ISpoke(address(liquidationLogicWrapper));
    assetId = wethAssetId;
    reserveId = _wethReserveId(spoke);
    asset = IERC20(hub.getAsset(assetId).underlying);
    userSuppliedShares = 100e18;
    borrower = makeAddr('borrower');
    liquidator = makeAddr('liquidator');

    liquidationLogicWrapper.setCollateralReserveHub(hub);
    liquidationLogicWrapper.setCollateralReserveAssetId(assetId);
    liquidationLogicWrapper.setCollateralReserveId(reserveId);
    liquidationLogicWrapper.setBorrower(borrower);
    liquidationLogicWrapper.setCollateralPositionSuppliedShares(userSuppliedShares);
    liquidationLogicWrapper.setLiquidator(liquidator);

    initialReserve = liquidationLogicWrapper.getCollateralReserve();
    initialUserPosition = liquidationLogicWrapper.getCollateralPosition(borrower);
    initialLiquidatorPosition = liquidationLogicWrapper.getCollateralPosition(liquidator);
    initialTreasurySpokeData = hub.getSpoke(assetId, address(treasurySpoke));

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
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
    params = LiquidationLogic.LiquidateCollateralParams({
      collateralToLiquidate: bound(
        collateralToLiquidate,
        1,
        hub.previewRemoveByShares(assetId, userSuppliedShares)
      ),
      collateralToLiquidator: 0, // populated below
      collateralReserveId: reserveId,
      liquidator: liquidator,
      receiveShares: false
    });
    params.collateralToLiquidator = bound(collateralToLiquidator, 1, params.collateralToLiquidate);

    uint256 initialHubBalance = asset.balanceOf(address(hub));

    uint256 sharesToLiquidate = _expectEventsAndCalls(params);
    (, , bool isPositionEmpty) = liquidationLogicWrapper.liquidateCollateral(params);

    assertEq(liquidationLogicWrapper.getCollateralReserve(), initialReserve);
    assertPosition(
      liquidationLogicWrapper.getCollateralPosition(borrower),
      initialUserPosition,
      userSuppliedShares - sharesToLiquidate
    );

    assertEq(isPositionEmpty, userSuppliedShares == sharesToLiquidate);
    assertEq(asset.balanceOf(address(hub)), initialHubBalance - params.collateralToLiquidator);
    assertEq(asset.balanceOf(params.liquidator), params.collateralToLiquidator);
    assertApproxEqAbs(
      hub.getSpokeAddedShares(assetId, address(treasurySpoke)),
      params.collateralToLiquidate - params.collateralToLiquidator,
      1
    );
  }

  /// on receiveShares, sharesToLiquidator should round down
  function test_liquidateCollateral_receiveShares_sharesToLiquidatorIsZero() public {
    // increase reserve index to ensure sharesToLiquidator rounds to 0 while feeShares rounds up to 1
    _increaseReserveIndex(spoke1, reserveId);

    // supply ex rate is between 1 and 2
    assertGt(hub.previewAddByShares(assetId, WadRayMath.RAY), WadRayMath.RAY);
    assertLt(hub.previewAddByShares(assetId, WadRayMath.RAY), 2 * WadRayMath.RAY);

    params = LiquidationLogic.LiquidateCollateralParams({
      collateralToLiquidate: 1,
      collateralToLiquidator: 1,
      collateralReserveId: reserveId,
      liquidator: liquidator,
      receiveShares: true
    });

    uint256 sharesToLiquidate = hub.previewRemoveByAssets(assetId, params.collateralToLiquidate);
    uint256 sharesToLiquidator = hub.previewAddByAssets(assetId, params.collateralToLiquidator);
    uint256 feeShares = sharesToLiquidate - sharesToLiquidator;

    assertEq(sharesToLiquidate, 1);
    assertEq(sharesToLiquidator, 0);
    assertEq(feeShares, 1);

    _expectEventsAndCalls(params);
    liquidationLogicWrapper.liquidateCollateral(params);

    // sharesToLiquidator should round to 0 and remain unchanged
    assertPosition(
      liquidationLogicWrapper.getCollateralPosition(params.liquidator),
      initialLiquidatorPosition,
      sharesToLiquidator
    );
    assertPosition(
      liquidationLogicWrapper.getCollateralPosition(borrower),
      initialUserPosition,
      userSuppliedShares - sharesToLiquidate
    );
    assertSpokePosition(
      hub.getSpoke(assetId, address(treasurySpoke)),
      initialTreasurySpokeData,
      initialTreasurySpokeData.addedShares + (sharesToLiquidate - sharesToLiquidator).toUint120()
    );
  }

  // on receiveShares, sharesToLiquidator should round down
  function test_liquidateCollateral_fuzz_receiveShares_sharesToLiquidator(
    uint256 collateralToLiquidate,
    uint256 collateralToLiquidator
  ) public {
    params = LiquidationLogic.LiquidateCollateralParams({
      collateralToLiquidate: bound(
        collateralToLiquidate,
        1,
        hub.previewRemoveByShares(assetId, 1e6)
      ),
      collateralToLiquidator: 0, // populated below
      collateralReserveId: reserveId,
      liquidator: liquidator,
      receiveShares: true
    });
    params.collateralToLiquidator = bound(collateralToLiquidator, 1, params.collateralToLiquidate);

    // increase reserve index to ensure sharesToLiquidator rounds to 0 while feeShares rounds up to 1
    _increaseReserveIndex(spoke1, reserveId);

    uint256 sharesToLiquidate = hub.previewRemoveByAssets(assetId, params.collateralToLiquidate);
    uint256 sharesToLiquidator = hub.previewAddByAssets(assetId, params.collateralToLiquidator);

    _expectEventsAndCalls(params);
    liquidationLogicWrapper.liquidateCollateral(params);

    // sharesToLiquidator should round to 0 and remain unchanged
    assertPosition(
      liquidationLogicWrapper.getCollateralPosition(params.liquidator),
      initialLiquidatorPosition,
      sharesToLiquidator
    );
    assertPosition(
      liquidationLogicWrapper.getCollateralPosition(borrower),
      initialUserPosition,
      userSuppliedShares - sharesToLiquidate
    );
    assertSpokePosition(
      hub.getSpoke(assetId, address(treasurySpoke)),
      initialTreasurySpokeData,
      initialTreasurySpokeData.addedShares + (sharesToLiquidate - sharesToLiquidator).toUint120()
    );
  }

  // hub.remove is skipped when collateralToLiquidator is 0 (otherwise it would revert)
  function test_liquidateCollateral_fuzz_CollateralToLiquidatorIsZero(
    uint256 collateralToLiquidate
  ) public {
    params.collateralToLiquidate = bound(
      collateralToLiquidate,
      0,
      hub.previewRemoveByShares(assetId, userSuppliedShares)
    );
    params.collateralToLiquidator = 0;

    vm.expectCall(address(hub), abi.encodeWithSelector(IHubBase.remove.selector), 0);
    liquidationLogicWrapper.liquidateCollateral(params);
  }

  // reverts with arithmetic underflow when updating user's supplied shares
  function test_liquidateCollateral_fuzz_revertsWith_ArithmeticUnderflow(
    uint256 collateralToLiquidate,
    uint256 collateralToLiquidator
  ) public {
    params.collateralToLiquidate = bound(
      collateralToLiquidate,
      hub.previewRemoveByShares(assetId, userSuppliedShares) + 1,
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
    initPosition.suppliedShares = newSuppliedShares.toUint120();
    assertEq(newPosition, initPosition);
  }

  function assertSpokePosition(
    IHub.SpokeData memory newSpokeData,
    IHub.SpokeData memory initSpokeData,
    uint256 newAddedShares
  ) internal pure {
    initSpokeData.addedShares = newAddedShares.toUint120();
    assertEq(newSpokeData, initSpokeData);
  }

  function _expectEventsAndCalls(
    LiquidationLogic.LiquidateCollateralParams memory p
  ) internal returns (uint256) {
    uint256 sharesToLiquidate = hub.previewRemoveByAssets(assetId, p.collateralToLiquidate);
    uint256 sharesToLiquidator = p.receiveShares
      ? hub.previewAddByAssets(assetId, p.collateralToLiquidator)
      : hub.previewRemoveByAssets(assetId, p.collateralToLiquidator);
    uint256 sharesToPayFee = sharesToLiquidate - sharesToLiquidator;

    if (p.collateralToLiquidator > 0 && p.receiveShares) {
      vm.expectCall(
        address(hub),
        abi.encodeCall(IHubBase.previewAddByAssets, (assetId, p.collateralToLiquidator)),
        1
      );
    }
    if (p.collateralToLiquidator > 0 && !p.receiveShares) {
      vm.expectCall(
        address(hub),
        abi.encodeCall(IHubBase.remove, (assetId, p.collateralToLiquidator, p.liquidator)),
        1
      );
    }
    vm.expectCall(
      address(hub),
      abi.encodeCall(IHubBase.previewRemoveByAssets, (assetId, p.collateralToLiquidate)),
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
