// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokePositionSaltOperationsTest is Base {
  bytes32 internal constant SALT_A = keccak256('position-salt-a');

  function test_supply() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;
    bytes32 positionId = _getPositionId(bob, SALT_A);
    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amount);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply({
      reserveId: reserveId,
      caller: bob,
      positionId: positionId,
      suppliedShares: expectedShares,
      suppliedAmount: amount
    });
    vm.prank(bob);
    (uint256 shares, uint256 suppliedAmount) = spoke1.supply(reserveId, amount, bob, SALT_A);

    assertEq(shares, expectedShares);
    assertEq(suppliedAmount, amount);
    assertEq(spoke1.getUserSuppliedShares(reserveId, bob, SALT_A), expectedShares);
    assertEq(spoke1.getUserSuppliedAssets(reserveId, bob, SALT_A), amount);
    assertEq(spoke1.getUserSuppliedShares(reserveId, bob), 0, 'default position untouched');
  }

  function test_withdraw() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: amount,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });
    bytes32 positionId = _getPositionId(bob, SALT_A);
    uint256 suppliedShares = spoke1.getUserSuppliedShares(reserveId, bob, SALT_A);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Withdraw(reserveId, bob, positionId, suppliedShares, amount);
    vm.prank(bob);
    (uint256 withdrawnShares, uint256 withdrawnAmount) = spoke1.withdraw(
      reserveId,
      amount,
      bob,
      SALT_A
    );

    assertEq(withdrawnShares, suppliedShares);
    assertEq(withdrawnAmount, amount);
    assertEq(spoke1.getUserSuppliedShares(reserveId, bob, SALT_A), 0);
  }

  function test_borrow() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 100e18;
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: 10e18,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });
    bytes32 positionId = _getPositionId(bob, SALT_A);
    uint256 expectedShares = hub1.previewRestoreByAssets(daiAssetId, borrowAmount);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrow({
      reserveId: daiReserveId,
      caller: bob,
      positionId: positionId,
      drawnShares: expectedShares,
      drawnAmount: borrowAmount
    });
    vm.prank(bob);
    (uint256 shares, uint256 amount) = spoke1.borrow(daiReserveId, borrowAmount, bob, SALT_A);

    assertEq(shares, expectedShares);
    assertEq(amount, borrowAmount);
    (uint256 drawn, ) = spoke1.getUserDebt(daiReserveId, bob, SALT_A);
    assertEq(drawn, borrowAmount);
    (uint256 defaultDrawn, ) = spoke1.getUserDebt(daiReserveId, bob);
    assertEq(defaultDrawn, 0, 'default position untouched');
  }

  function test_repay() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 100e18;
    _seedSaltedBorrow(bob, SALT_A, borrowAmount);
    bytes32 positionId = _getPositionId(bob, SALT_A);

    IHubBase.PremiumDelta memory premiumDelta;
    vm.expectEmit(true, true, true, false, address(spoke1));
    emit ISpoke.Repay(daiReserveId, bob, positionId, 0, 0, premiumDelta);
    vm.prank(bob);
    spoke1.repay(daiReserveId, type(uint256).max, bob, SALT_A);

    (uint256 drawn, uint256 premium) = spoke1.getUserDebt(daiReserveId, bob, SALT_A);
    assertEq(drawn, 0);
    assertEq(premium, 0);
    (, bool borrowing) = spoke1.getUserReserveStatus(daiReserveId, bob, SALT_A);
    assertFalse(borrowing);
  }

  function test_setUsingAsCollateral() public {
    uint256 reserveId = _daiReserveId(spoke1);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });
    bytes32 positionId = _getPositionId(bob, SALT_A);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral(reserveId, bob, positionId, true);
    vm.prank(bob);
    spoke1.setUsingAsCollateral(reserveId, true, bob, SALT_A);

    (bool usingAsCollateral, ) = spoke1.getUserReserveStatus(reserveId, bob, SALT_A);
    assertTrue(usingAsCollateral);
    (bool defaultUsing, ) = spoke1.getUserReserveStatus(reserveId, bob);
    assertFalse(defaultUsing, 'default position untouched');
  }

  function test_updateUserRiskPremium() public {
    _seedSaltedBorrow(bob, SALT_A, 100e18);
    skip(100);
    bytes32 positionId = _getPositionId(bob, SALT_A);
    uint256 expectedRiskPremium = spoke1.getUserAccountData(bob, SALT_A).riskPremium;
    assertGt(expectedRiskPremium, 0);

    vm.expectEmit(true, false, false, true, address(spoke1));
    emit ISpoke.UpdateUserRiskPremium(positionId, expectedRiskPremium);
    vm.prank(bob);
    spoke1.updateUserRiskPremium(bob, SALT_A);

    assertEq(spoke1.getUserLastRiskPremium(bob, SALT_A), expectedRiskPremium);
    assertEq(spoke1.getUserLastRiskPremium(bob), 0, 'default position untouched');
  }

  function test_updateUserDynamicConfig() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 1000e6,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });
    bytes32 positionId = _getPositionId(bob, SALT_A);

    vm.expectEmit(true, false, false, false, address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(positionId);
    vm.prank(bob);
    spoke1.updateUserDynamicConfig(bob, SALT_A);
  }

  function test_liquidationCall() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    _seedSaltedLiquidatable(bob, SALT_A);
    bytes32 positionId = _getPositionId(bob, SALT_A);

    (uint256 drawnBefore, ) = spoke1.getUserDebt(debtReserveId, bob, SALT_A);
    uint256 collateralBefore = spoke1.getUserSuppliedShares(collateralReserveId, bob, SALT_A);

    IHubBase.PremiumDelta memory premiumDelta;
    vm.expectEmit(true, true, true, false, address(spoke1));
    emit ISpoke.LiquidationCall({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      positionId: positionId,
      liquidator: carol,
      receiveShares: false,
      debtAmountRestored: 0,
      drawnSharesLiquidated: 0,
      premiumDelta: premiumDelta,
      collateralAmountRemoved: 0,
      collateralSharesLiquidated: 0,
      collateralSharesToLiquidator: 0
    });
    SpokeActions.liquidationCall({
      spoke: spoke1,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      user: bob,
      positionSalt: SALT_A,
      liquidatorPositionSalt: bytes32(0),
      debtToCover: 50_000e18,
      receiveShares: false,
      caller: carol
    });

    (uint256 drawnAfter, ) = spoke1.getUserDebt(debtReserveId, bob, SALT_A);
    assertLt(drawnAfter, drawnBefore, 'debt liquidated on salted position');
    assertLt(
      spoke1.getUserSuppliedShares(collateralReserveId, bob, SALT_A),
      collateralBefore,
      'collateral seized on salted position'
    );
  }

  function test_supply_fuzz(bytes32 positionSalt, uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    deal(address(tokenList.dai), bob, amount);
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amount);
    vm.assume(expectedShares > 0);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply({
      reserveId: reserveId,
      caller: bob,
      positionId: _getPositionId(bob, positionSalt),
      suppliedShares: expectedShares,
      suppliedAmount: amount
    });
    vm.prank(bob);
    (uint256 shares, ) = spoke1.supply(reserveId, amount, bob, positionSalt);

    assertEq(shares, expectedShares);
    assertEq(spoke1.getUserSuppliedShares(reserveId, bob, positionSalt), expectedShares);
  }

  function test_borrow_fuzz(bytes32 positionSalt, uint256 borrowAmount) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethSupply = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      daiReserveId,
      borrowAmount
    );
    vm.assume(wethSupply <= MAX_SUPPLY_AMOUNT);

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupply,
      onBehalfOf: bob,
      positionSalt: positionSalt
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });

    uint256 expectedShares = hub1.previewRestoreByAssets(daiAssetId, borrowAmount);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Borrow({
      reserveId: daiReserveId,
      caller: bob,
      positionId: _getPositionId(bob, positionSalt),
      drawnShares: expectedShares,
      drawnAmount: borrowAmount
    });
    vm.prank(bob);
    (uint256 shares, ) = spoke1.borrow(daiReserveId, borrowAmount, bob, positionSalt);

    assertEq(shares, expectedShares);
    (uint256 drawn, ) = spoke1.getUserDebt(daiReserveId, bob, positionSalt);
    assertEq(drawn, borrowAmount);
  }

  function test_supply_revertsWith_Unauthorized() public {
    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(carol);
    spoke1.supply(_daiReserveId(spoke1), 100e18, bob, SALT_A);
  }

  function test_supply_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.getReserveCount() + 1;
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.supply(reserveId, 100e18, bob, SALT_A);
  }

  function test_withdraw_revertsWith_Unauthorized() public {
    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(carol);
    spoke1.withdraw(_daiReserveId(spoke1), 100e18, bob, SALT_A);
  }

  function test_borrow_revertsWith_Unauthorized() public {
    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(carol);
    spoke1.borrow(_daiReserveId(spoke1), 100e18, bob, SALT_A);
  }

  function test_repay_revertsWith_Unauthorized() public {
    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(carol);
    spoke1.repay(_daiReserveId(spoke1), 100e18, bob, SALT_A);
  }

  function test_setUsingAsCollateral_revertsWith_Unauthorized() public {
    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(carol);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true, bob, SALT_A);
  }

  function _seedSaltedBorrow(address user, bytes32 salt, uint256 borrowAmount) internal {
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: user,
      amount: 10e18,
      onBehalfOf: user,
      positionSalt: salt
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: user,
      amount: borrowAmount,
      onBehalfOf: user,
      positionSalt: salt
    });
  }

  function _seedSaltedLiquidatable(address user, bytes32 salt) internal {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    _updateMaxLiquidationBonus(spoke1, collateralReserveId, 105_00);
    _updateLiquidationFee(spoke1, collateralReserveId, 10_00);

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: alice,
      amount: 1_000_000e18,
      onBehalfOf: alice
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      caller: user,
      amount: 1_000_000e6,
      onBehalfOf: user,
      positionSalt: salt
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: debtReserveId,
      caller: user,
      amount: 500_000e18,
      onBehalfOf: user,
      positionSalt: salt
    });

    _mockReservePriceByPercent(spoke1, collateralReserveId, 50_00);
    assertLt(
      spoke1.getUserAccountData(user, salt).healthFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
  }
}
