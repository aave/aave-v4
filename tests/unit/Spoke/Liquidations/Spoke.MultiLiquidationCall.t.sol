// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.LiquidationCall.Base.t.sol';

contract SpokeMultiLiquidationCallTest is SpokeLiquidationCallBaseTest {
  address public user = makeAddr('user');
  address public liquidator = makeAddr('liquidator');

  ISpoke public spoke;
  uint256 public collateralReserveId;
  uint256 public wethDebtReserveId;
  uint256 public usdxDebtReserveId;

  function setUp() public virtual override {
    super.setUp();

    spoke = spoke1;
    collateralReserveId = _daiReserveId(spoke);
    wethDebtReserveId = _wethReserveId(spoke);
    usdxDebtReserveId = _usdxReserveId(spoke);

    _updateLiquidationConfig(
      spoke,
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.95e18,
        liquidationBonusFactor: 50_00
      })
    );
    _updateCollateralFactor(spoke, collateralReserveId, 75_00);
    _updateMaxLiquidationBonus(spoke, collateralReserveId, 106_00);

    for (uint256 reserveId = 0; reserveId < spoke.getReserveCount(); reserveId++) {
      deal(spoke, reserveId, liquidator, MAX_SUPPLY_AMOUNT);
      Utils.approve(spoke, reserveId, liquidator, MAX_SUPPLY_AMOUNT);
    }
  }

  /// @dev Supplies dai collateral and borrows weth and usdx in roughly equal value halves,
  /// leaving the user at a health factor of ~0.95.
  function _openMultiReserveDebtPosition() internal {
    _increaseCollateralSupply(spoke, collateralReserveId, 100_000e18, user);
    _makeUserLiquidatable(spoke, user, wethDebtReserveId, 1.9e18);
    _makeUserLiquidatable(spoke, user, usdxDebtReserveId, 0.95e18);
  }

  function _unboundedTargetHealthFactor() internal {
    _updateLiquidationConfig(
      spoke,
      ISpoke.LiquidationConfig({
        targetHealthFactor: uint128(1e27),
        healthFactorForMaxBonus: 0.95e18,
        liquidationBonusFactor: 50_00
      })
    );
  }

  function _fullLiquidationInputs()
    internal
    view
    returns (ISpoke.LiquidationCallInput[] memory inputs)
  {
    inputs = new ISpoke.LiquidationCallInput[](2);
    inputs[0] = ISpoke.LiquidationCallInput({
      collateralReserveId: collateralReserveId,
      debtReserveId: wethDebtReserveId,
      debtToCover: UINT256_MAX,
      receiveShares: false
    });
    inputs[1] = ISpoke.LiquidationCallInput({
      collateralReserveId: collateralReserveId,
      debtReserveId: usdxDebtReserveId,
      debtToCover: UINT256_MAX,
      receiveShares: false
    });
  }

  function test_multiLiquidationCall_revertsWith_EmptyLiquidationCallInputs() public {
    vm.expectRevert(ISpoke.EmptyLiquidationCallInputs.selector);
    vm.prank(liquidator);
    spoke.multiLiquidationCall(user, new ISpoke.LiquidationCallInput[](0));
  }

  function test_multiLiquidationCall_revertsWith_HealthFactorNotBelowThreshold() public {
    _increaseCollateralSupply(spoke, collateralReserveId, 100_000e18, user);
    _makeUserLiquidatable(spoke, user, wethDebtReserveId, 1.9e18);

    ISpoke.LiquidationCallInput[] memory inputs = new ISpoke.LiquidationCallInput[](1);
    inputs[0] = ISpoke.LiquidationCallInput({
      collateralReserveId: collateralReserveId,
      debtReserveId: wethDebtReserveId,
      debtToCover: UINT256_MAX,
      receiveShares: false
    });

    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    vm.prank(liquidator);
    spoke.multiLiquidationCall(user, inputs);
  }

  function test_multiLiquidationCall_singleInput_matchesLiquidationCall() public {
    _openMultiReserveDebtPosition();

    uint256 snapshot = vm.snapshotState();
    vm.prank(liquidator);
    spoke.liquidationCall({
      collateralReserveId: collateralReserveId,
      debtReserveId: wethDebtReserveId,
      user: user,
      debtToCover: UINT256_MAX,
      receiveShares: false
    });
    ISpoke.UserAccountData memory singleCallAccountData = spoke.getUserAccountData(user);
    uint256 singleCallCollateralReceived = tokenList.dai.balanceOf(liquidator);
    uint256 singleCallDebtPaid = tokenList.weth.balanceOf(liquidator);
    vm.revertToState(snapshot);

    ISpoke.LiquidationCallInput[] memory inputs = new ISpoke.LiquidationCallInput[](1);
    inputs[0] = ISpoke.LiquidationCallInput({
      collateralReserveId: collateralReserveId,
      debtReserveId: wethDebtReserveId,
      debtToCover: UINT256_MAX,
      receiveShares: false
    });
    vm.prank(liquidator);
    spoke.multiLiquidationCall(user, inputs);

    ISpoke.UserAccountData memory batchAccountData = spoke.getUserAccountData(user);
    assertEq(
      batchAccountData.healthFactor,
      singleCallAccountData.healthFactor,
      'health factor mismatch'
    );
    assertEq(
      batchAccountData.totalDebtValueRay,
      singleCallAccountData.totalDebtValueRay,
      'debt value mismatch'
    );
    assertEq(
      batchAccountData.totalCollateralValue,
      singleCallAccountData.totalCollateralValue,
      'collateral value mismatch'
    );
    assertEq(
      tokenList.dai.balanceOf(liquidator),
      singleCallCollateralReceived,
      'collateral received mismatch'
    );
    assertEq(tokenList.weth.balanceOf(liquidator), singleCallDebtPaid, 'debt paid mismatch');
  }

  function test_multiLiquidationCall_continuesPastHealthFactorOne() public {
    _openMultiReserveDebtPosition();
    _unboundedTargetHealthFactor();

    // with single liquidation calls, fully repaying the first debt reserve restores the health
    // factor above 1.0 and strands the second debt reserve
    uint256 snapshot = vm.snapshotState();
    vm.prank(liquidator);
    spoke.liquidationCall({
      collateralReserveId: collateralReserveId,
      debtReserveId: wethDebtReserveId,
      user: user,
      debtToCover: UINT256_MAX,
      receiveShares: false
    });
    assertGe(
      spoke.getUserAccountData(user).healthFactor,
      1e18,
      'first full-reserve liquidation should restore health factor above 1.0'
    );
    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    vm.prank(liquidator);
    spoke.liquidationCall({
      collateralReserveId: collateralReserveId,
      debtReserveId: usdxDebtReserveId,
      user: user,
      debtToCover: UINT256_MAX,
      receiveShares: false
    });
    vm.revertToState(snapshot);

    // the batch executes both inputs and clears all debt
    vm.prank(liquidator);
    spoke.multiLiquidationCall(user, _fullLiquidationInputs());

    assertEq(
      spoke.getUserPosition(wethDebtReserveId, user).drawnShares,
      0,
      'weth debt should be fully liquidated'
    );
    assertEq(
      spoke.getUserPosition(usdxDebtReserveId, user).drawnShares,
      0,
      'usdx debt should be fully liquidated'
    );
    assertEq(spoke.getUserAccountData(user).totalDebtValueRay, 0, 'all debt should be cleared');
    assertGt(
      spoke.getUserPosition(collateralReserveId, user).suppliedShares,
      0,
      'user should keep the unseized collateral'
    );
  }

  function test_multiLiquidationCall_stopsAtTargetHealthFactor() public {
    _openMultiReserveDebtPosition();

    uint256 usdxDrawnSharesBefore = spoke.getUserPosition(usdxDebtReserveId, user).drawnShares;
    uint256 liquidatorUsdxBalanceBefore = tokenList.usdx.balanceOf(liquidator);

    vm.prank(liquidator);
    spoke.multiLiquidationCall(user, _fullLiquidationInputs());

    // the first input restores the position to the target health factor, so the second is skipped
    assertGe(
      spoke.getUserAccountData(user).healthFactor,
      1.05e18,
      'health factor should reach the target'
    );
    assertApproxEqRel(
      spoke.getUserAccountData(user).healthFactor,
      1.05e18,
      0.01e18,
      'health factor should stop at the target'
    );
    assertEq(
      spoke.getUserPosition(usdxDebtReserveId, user).drawnShares,
      usdxDrawnSharesBefore,
      'usdx debt should be untouched'
    );
    assertEq(
      tokenList.usdx.balanceOf(liquidator),
      liquidatorUsdxBalanceBefore,
      'liquidator usdx funds should be untouched'
    );
  }

  function test_multiLiquidationCall_stopsOnDeficit() public {
    _openMultiReserveDebtPosition();
    _unboundedTargetHealthFactor();

    // deep collateral price drop: fully liquidating the first debt reserve seizes all collateral
    // and socializes the remainder as deficit
    _mockReservePriceByPercent(spoke, collateralReserveId, 30_00);

    uint256 liquidatorUsdxBalanceBefore = tokenList.usdx.balanceOf(liquidator);
    uint256 usdxAssetId = _reserveAssetId(spoke, usdxDebtReserveId);
    uint256 wethAssetId = _reserveAssetId(spoke, wethDebtReserveId);

    vm.prank(liquidator);
    spoke.multiLiquidationCall(user, _fullLiquidationInputs());

    assertEq(
      spoke.getUserPosition(collateralReserveId, user).suppliedShares,
      0,
      'all collateral should be seized'
    );
    assertEq(
      spoke.getUserPosition(wethDebtReserveId, user).drawnShares,
      0,
      'weth debt should be written off'
    );
    assertEq(
      spoke.getUserPosition(usdxDebtReserveId, user).drawnShares,
      0,
      'usdx debt should be written off'
    );
    assertGt(
      _hub(spoke, wethDebtReserveId).getAssetDeficitRay(wethAssetId),
      0,
      'weth deficit should be reported'
    );
    assertGt(
      _hub(spoke, usdxDebtReserveId).getAssetDeficitRay(usdxAssetId),
      0,
      'usdx deficit should be reported'
    );
    assertEq(
      tokenList.usdx.balanceOf(liquidator),
      liquidatorUsdxBalanceBefore,
      'the input after the deficit should be skipped'
    );
  }

  function test_getLiquidationBonus_clampedAtHealthFactorOneAndAbove() public {
    _increaseCollateralSupply(spoke, collateralReserveId, 100_000e18, user);

    // minLiquidationBonus = (106_00 - 100_00) * 50% + 100_00
    uint256 minLiquidationBonus = 103_00;

    assertEq(
      spoke.getLiquidationBonus(collateralReserveId, user, 1e18),
      minLiquidationBonus,
      'bonus at health factor 1.0 should be the minimum bonus'
    );
    assertEq(
      spoke.getLiquidationBonus(collateralReserveId, user, 2e18),
      minLiquidationBonus,
      'bonus above health factor 1.0 should be the minimum bonus'
    );
    assertEq(
      spoke.getLiquidationBonus(collateralReserveId, user, UINT256_MAX),
      minLiquidationBonus,
      'bonus at unbounded health factor should be the minimum bonus'
    );
    assertApproxEqAbs(
      spoke.getLiquidationBonus(collateralReserveId, user, 1e18 - 1),
      minLiquidationBonus,
      1,
      'bonus should be continuous at the liquidation threshold'
    );
    assertEq(
      spoke.getLiquidationBonus(collateralReserveId, user, 0.95e18),
      106_00,
      'bonus at the max-bonus health factor should be the max bonus'
    );
  }
}
