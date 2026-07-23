// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokePositionSaltIsolationTest is Base {
  bytes32 internal constant SALT_A = keccak256('position-salt-a');
  bytes32 internal constant SALT_B = keccak256('position-salt-b');

  function test_supply_isolation() public {
    uint256 reserveId = _daiReserveId(spoke1);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 30e18,
      onBehalfOf: bob
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 50e18,
      onBehalfOf: bob,
      positionSalt: SALT_B
    });
    ISpoke.UserPosition memory defaultBefore = spoke1.getUserPosition(reserveId, bob);
    ISpoke.UserPosition memory saltBBefore = spoke1.getUserPosition(reserveId, bob, SALT_B);

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });

    assertEq(
      spoke1.getUserSuppliedShares(reserveId, bob, SALT_A),
      hub1.previewAddByAssets(daiAssetId, 100e18)
    );
    assertEq(spoke1.getUserPosition(reserveId, bob), defaultBefore);
    assertEq(spoke1.getUserPosition(reserveId, bob, SALT_B), saltBBefore);
  }

  function test_withdraw_isolation() public {
    uint256 reserveId = _daiReserveId(spoke1);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 30e18,
      onBehalfOf: bob
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 50e18,
      onBehalfOf: bob,
      positionSalt: SALT_B
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });
    ISpoke.UserPosition memory defaultBefore = spoke1.getUserPosition(reserveId, bob);
    ISpoke.UserPosition memory saltBBefore = spoke1.getUserPosition(reserveId, bob, SALT_B);

    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });

    assertEq(spoke1.getUserSuppliedShares(reserveId, bob, SALT_A), 0);
    assertEq(spoke1.getUserPosition(reserveId, bob), defaultBefore);
    assertEq(spoke1.getUserPosition(reserveId, bob, SALT_B), saltBBefore);
  }

  function test_borrow_isolation() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: 1000e18,
      onBehalfOf: alice
    });
    _openBorrow(bob, bytes32(0), 100e18);
    _openBorrow(bob, SALT_B, 100e18);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: wethReserveId,
      caller: bob,
      amount: 10e18,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });

    ISpoke.UserPosition memory defaultDai = spoke1.getUserPosition(daiReserveId, bob);
    ISpoke.UserPosition memory defaultWeth = spoke1.getUserPosition(wethReserveId, bob);
    ISpoke.UserPosition memory saltBDai = spoke1.getUserPosition(daiReserveId, bob, SALT_B);
    ISpoke.UserPosition memory saltBWeth = spoke1.getUserPosition(wethReserveId, bob, SALT_B);

    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });

    (uint256 drawnA, ) = spoke1.getUserDebt(daiReserveId, bob, SALT_A);
    assertEq(drawnA, 100e18);
    assertEq(spoke1.getUserPosition(daiReserveId, bob), defaultDai);
    assertEq(spoke1.getUserPosition(wethReserveId, bob), defaultWeth);
    assertEq(spoke1.getUserPosition(daiReserveId, bob, SALT_B), saltBDai);
    assertEq(spoke1.getUserPosition(wethReserveId, bob, SALT_B), saltBWeth);
  }

  function test_repay_isolation() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: 1000e18,
      onBehalfOf: alice
    });
    _openBorrow(bob, bytes32(0), 100e18);
    _openBorrow(bob, SALT_B, 100e18);
    _openBorrow(bob, SALT_A, 100e18);

    ISpoke.UserPosition memory defaultDai = spoke1.getUserPosition(daiReserveId, bob);
    ISpoke.UserPosition memory saltBDai = spoke1.getUserPosition(daiReserveId, bob, SALT_B);

    SpokeActions.repay({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: type(uint256).max,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });

    (uint256 drawnA, ) = spoke1.getUserDebt(daiReserveId, bob, SALT_A);
    assertEq(drawnA, 0);
    assertEq(spoke1.getUserPosition(daiReserveId, bob), defaultDai);
    assertEq(spoke1.getUserPosition(daiReserveId, bob, SALT_B), saltBDai);
    assertEq(
      spoke1.getUserPosition(wethReserveId, bob),
      spoke1.getUserPosition(wethReserveId, bob)
    );
  }

  function test_setUsingAsCollateral_isolation() public {
    uint256 reserveId = _daiReserveId(spoke1);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 30e18,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 50e18,
      onBehalfOf: bob,
      positionSalt: SALT_B
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });
    ISpoke.UserPosition memory defaultBefore = spoke1.getUserPosition(reserveId, bob);
    ISpoke.UserPosition memory saltBBefore = spoke1.getUserPosition(reserveId, bob, SALT_B);

    SpokeActions.setUsingAsCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      usingAsCollateral: true,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });

    (bool usingA, ) = spoke1.getUserReserveStatus(reserveId, bob, SALT_A);
    assertTrue(usingA);
    (bool usingDefault, ) = spoke1.getUserReserveStatus(reserveId, bob);
    (bool usingB, ) = spoke1.getUserReserveStatus(reserveId, bob, SALT_B);
    assertTrue(usingDefault);
    assertTrue(usingB);
    assertEq(spoke1.getUserPosition(reserveId, bob), defaultBefore);
    assertEq(spoke1.getUserPosition(reserveId, bob, SALT_B), saltBBefore);
  }

  function test_updateUserRiskPremium_isolation() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: 1000e18,
      onBehalfOf: alice
    });
    _openBorrow(bob, bytes32(0), 100e18);
    _openBorrow(bob, SALT_A, 100e18);
    skip(100);

    ISpoke.UserPosition memory defaultDai = spoke1.getUserPosition(daiReserveId, bob);
    ISpoke.UserPosition memory defaultWeth = spoke1.getUserPosition(wethReserveId, bob);
    uint256 defaultRiskPremium = spoke1.getUserLastRiskPremium(bob);

    vm.prank(bob);
    spoke1.updateUserRiskPremium(bob, SALT_A);

    assertEq(spoke1.getUserPosition(daiReserveId, bob), defaultDai);
    assertEq(spoke1.getUserPosition(wethReserveId, bob), defaultWeth);
    assertEq(spoke1.getUserLastRiskPremium(bob), defaultRiskPremium);
  }

  function test_updateUserDynamicConfig_isolation() public {
    uint256 reserveId = _usdxReserveId(spoke1);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 1000e6,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 1000e6,
      onBehalfOf: bob,
      positionSalt: SALT_A
    });
    _updateLiquidationFee(spoke1, reserveId, 10_00);
    ISpoke.UserPosition memory defaultBefore = spoke1.getUserPosition(reserveId, bob);

    vm.prank(bob);
    spoke1.updateUserDynamicConfig(bob, SALT_A);

    assertEq(spoke1.getUserPosition(reserveId, bob), defaultBefore);
  }

  function test_liquidationCall_isolation() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    bytes32 liquidatorSalt = keccak256('liquidator-salt');

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      caller: bob,
      amount: 1000e6,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      caller: bob,
      amount: 2000e6,
      onBehalfOf: bob,
      positionSalt: SALT_B
    });
    _seedSaltedLiquidatable(bob, SALT_A);

    deal(address(tokenList.dai), carol, 100_000e18);
    SpokeActions.approve({
      spoke: spoke1,
      reserveId: debtReserveId,
      owner: carol,
      amount: type(uint256).max
    });

    ISpoke.UserPosition memory defaultBefore = spoke1.getUserPosition(collateralReserveId, bob);
    ISpoke.UserPosition memory saltBBefore = spoke1.getUserPosition(
      collateralReserveId,
      bob,
      SALT_B
    );

    SpokeActions.liquidationCall({
      spoke: spoke1,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      user: bob,
      positionSalt: SALT_A,
      liquidatorPositionSalt: liquidatorSalt,
      debtToCover: 50_000e18,
      receiveShares: true,
      caller: carol
    });

    assertEq(spoke1.getUserPosition(collateralReserveId, bob), defaultBefore);
    assertEq(spoke1.getUserPosition(collateralReserveId, bob, SALT_B), saltBBefore);
    assertGt(spoke1.getUserSuppliedShares(collateralReserveId, carol, liquidatorSalt), 0);
    assertEq(
      spoke1.getUserSuppliedShares(collateralReserveId, carol),
      0,
      'liquidator default position untouched'
    );
  }

  function test_supply_isolation_fuzz(
    bytes32 saltA,
    bytes32 saltB,
    uint256 amountA,
    uint256 amountB
  ) public {
    vm.assume(saltA != saltB);
    amountA = bound(amountA, 1, MAX_SUPPLY_AMOUNT / 2);
    amountB = bound(amountB, 1, MAX_SUPPLY_AMOUNT / 2);
    uint256 reserveId = _daiReserveId(spoke1);
    deal(address(tokenList.dai), bob, amountA + amountB);

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: amountB,
      onBehalfOf: bob,
      positionSalt: saltB
    });
    uint256 saltBSharesBefore = spoke1.getUserSuppliedShares(reserveId, bob, saltB);

    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amountA);
    vm.assume(expectedShares > 0);
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: amountA,
      onBehalfOf: bob,
      positionSalt: saltA
    });

    assertEq(spoke1.getUserSuppliedShares(reserveId, bob, saltA), expectedShares);
    assertEq(spoke1.getUserSuppliedShares(reserveId, bob, saltB), saltBSharesBefore);
  }

  function test_successiveSalts_supply_isolation() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 positions = 5;
    deal(address(tokenList.dai), bob, 1000e18);

    uint256[] memory amounts = new uint256[](positions);
    for (uint256 i = 0; i < positions; i++) {
      amounts[i] = (i + 1) * 10e18;
      SpokeActions.supply({
        spoke: spoke1,
        reserveId: reserveId,
        caller: bob,
        amount: amounts[i],
        onBehalfOf: bob,
        positionSalt: bytes32(i)
      });
    }

    ISpoke.UserPosition[] memory before = new ISpoke.UserPosition[](positions);
    for (uint256 i = 0; i < positions; i++) {
      assertApproxEqAbs(spoke1.getUserSuppliedAssets(reserveId, bob, bytes32(i)), amounts[i], 1);
      before[i] = spoke1.getUserPosition(reserveId, bob, bytes32(i));
    }

    uint256 target = 2;
    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: amounts[target],
      onBehalfOf: bob,
      positionSalt: bytes32(target)
    });

    assertEq(spoke1.getUserSuppliedShares(reserveId, bob, bytes32(target)), 0);
    for (uint256 i = 0; i < positions; i++) {
      if (i == target) continue;
      assertEq(spoke1.getUserPosition(reserveId, bob, bytes32(i)), before[i]);
    }
  }

  function test_successiveSalts_borrow_isolation() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 positions = 4;
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: alice,
      amount: 1000e18,
      onBehalfOf: alice
    });

    for (uint256 i = 0; i < positions; i++) {
      _openBorrow(bob, bytes32(i), 50e18);
    }

    ISpoke.UserPosition[] memory before = new ISpoke.UserPosition[](positions);
    for (uint256 i = 0; i < positions; i++) {
      (uint256 drawn, ) = spoke1.getUserDebt(daiReserveId, bob, bytes32(i));
      assertEq(drawn, 50e18);
      before[i] = spoke1.getUserPosition(daiReserveId, bob, bytes32(i));
    }

    uint256 target = 1;
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: daiReserveId,
      caller: bob,
      amount: type(uint256).max,
      onBehalfOf: bob,
      positionSalt: bytes32(target)
    });

    (uint256 drawnTarget, ) = spoke1.getUserDebt(daiReserveId, bob, bytes32(target));
    assertEq(drawnTarget, 0);
    for (uint256 i = 0; i < positions; i++) {
      if (i == target) continue;
      assertEq(spoke1.getUserPosition(daiReserveId, bob, bytes32(i)), before[i]);
    }
  }

  function _openBorrow(address user, bytes32 salt, uint256 borrowAmount) internal {
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
