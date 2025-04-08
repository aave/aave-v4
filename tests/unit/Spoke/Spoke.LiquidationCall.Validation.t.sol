// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract LiquidationCallValidationTest is SpokeBase {
  function test_liquidationCall_revertsWith_ReserveNotActive_collateralReserve() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 debtToCover = 1;

    test_liquidationCall_fuzz_revertsWith_ReserveNotActive_collateralReserve(
      wethReserveId,
      daiReserveId,
      debtToCover
    );
  }

  function test_liquidationCall_fuzz_revertsWith_ReserveNotActive_collateralReserve(
    uint256 reserveId1,
    uint256 reserveId2,
    uint256 debtToCover
  ) public {
    reserveId1 = bound(reserveId1, 0, spoke1.reserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.reserveCount() - 1);
    debtToCover = bound(debtToCover, 1, MAX_SUPPLY_AMOUNT);

    // if even, reserveId1 is collateral, reserveId2 is debt
    // if odd, reserveId1 is debt, reserveId2 is collateral
    (uint256 collateralReserveId, uint256 debtReserveId) = vm.randomUint() % 2 == 0
      ? (reserveId1, reserveId2)
      : (reserveId2, reserveId1);

    updateReserveActiveFlag(spoke1, collateralReserveId, false);
    assertFalse(spoke1.getReserve(collateralReserveId).config.active);

    vm.expectRevert(ISpoke.ReserveNotActive.selector);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, debtToCover);
  }

  function test_liquidationCall_revertsWith_ReserveNotActive_debtReserve() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 debtToCover = 1;

    test_liquidationCall_fuzz_revertsWith_ReserveNotActive_debtReserve(
      wethReserveId,
      daiReserveId,
      debtToCover
    );
  }

  function test_liquidationCall_fuzz_revertsWith_ReserveNotActive_debtReserve(
    uint256 reserveId1,
    uint256 reserveId2,
    uint256 debtToCover
  ) public {
    reserveId1 = bound(reserveId1, 0, spoke1.reserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.reserveCount() - 1);
    debtToCover = bound(debtToCover, 1, MAX_SUPPLY_AMOUNT);

    // if even, reserveId1 is collateral, reserveId2 is debt
    // if odd, reserveId1 is debt, reserveId2 is collateral
    (uint256 collateralReserveId, uint256 debtReserveId) = vm.randomUint() % 2 == 0
      ? (reserveId1, reserveId2)
      : (reserveId2, reserveId1);

    updateReserveActiveFlag(spoke1, debtReserveId, false);
    assertFalse(spoke1.getReserve(debtReserveId).config.active);

    vm.expectRevert(ISpoke.ReserveNotActive.selector);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, debtToCover);
  }

  function test_liquidationCall_revertsWith_ReservePaused_collateralReserve() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 debtToCover = 1;

    test_liquidationCall_fuzz_revertsWith_ReservePaused_collateralReserve(
      wethReserveId,
      daiReserveId,
      debtToCover
    );
  }

  function test_liquidationCall_fuzz_revertsWith_ReservePaused_collateralReserve(
    uint256 reserveId1,
    uint256 reserveId2,
    uint256 debtToCover
  ) public {
    reserveId1 = bound(reserveId1, 0, spoke1.reserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.reserveCount() - 1);
    debtToCover = bound(debtToCover, 1, MAX_SUPPLY_AMOUNT);

    // if even, reserveId1 is collateral, reserveId2 is debt
    // if odd, reserveId1 is debt, reserveId2 is collateral
    (uint256 collateralReserveId, uint256 debtReserveId) = vm.randomUint() % 2 == 0
      ? (reserveId1, reserveId2)
      : (reserveId2, reserveId1);

    updateReservePausedFlag(spoke1, collateralReserveId, true);
    assertTrue(spoke1.getReserve(collateralReserveId).config.paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, debtToCover);
  }
  function test_liquidationCall_revertsWith_ReservePaused_debtReserve() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 debtToCover = 1;

    test_liquidationCall_fuzz_revertsWith_ReservePaused_debtReserve(
      wethReserveId,
      daiReserveId,
      debtToCover
    );
  }

  function test_liquidationCall_fuzz_revertsWith_ReservePaused_debtReserve(
    uint256 reserveId1,
    uint256 reserveId2,
    uint256 debtToCover
  ) public {
    reserveId1 = bound(reserveId1, 0, spoke1.reserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.reserveCount() - 1);
    debtToCover = bound(debtToCover, 1, MAX_SUPPLY_AMOUNT);

    // if even, reserveId1 is collateral, reserveId2 is debt
    // if odd, reserveId1 is debt, reserveId2 is collateral
    (uint256 collateralReserveId, uint256 debtReserveId) = vm.randomUint() % 2 == 0
      ? (reserveId1, reserveId2)
      : (reserveId2, reserveId1);

    updateReservePausedFlag(spoke1, debtReserveId, true);
    assertTrue(spoke1.getReserve(debtReserveId).config.paused);

    vm.expectRevert(ISpoke.ReservePaused.selector);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, debtToCover);
  }

  function test_liquidationCall_revertsWith_InvalidDebtToCover() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);

    test_liquidationCall_fuzz_revertsWith_InvalidDebtToCover(wethReserveId, daiReserveId);
  }

  function test_liquidationCall_fuzz_revertsWith_InvalidDebtToCover(
    uint256 reserveId1,
    uint256 reserveId2
  ) public {
    reserveId1 = bound(reserveId1, 0, spoke1.reserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.reserveCount() - 1);
    uint256 debtToCover = 0;

    // if even, reserveId1 is collateral, reserveId2 is debt
    // if odd, reserveId1 is debt, reserveId2 is collateral
    (uint256 collateralReserveId, uint256 debtReserveId) = vm.randomUint() % 2 == 0
      ? (reserveId1, reserveId2)
      : (reserveId2, reserveId1);

    vm.expectRevert(ISpoke.InvalidDebtToCover.selector);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, debtToCover);
  }

  function test_liquidationCall_revertsWith_HealthFactorNotBelowThreshold_no_supply() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 debtToCover = 1;

    test_liquidationCall_fuzz_revertsWith_HealthFactorNotBelowThreshold_no_supply(
      wethReserveId,
      daiReserveId,
      debtToCover
    );
  }

  function test_liquidationCall_fuzz_revertsWith_HealthFactorNotBelowThreshold_no_supply(
    uint256 reserveId1,
    uint256 reserveId2,
    uint256 debtToCover
  ) public {
    reserveId1 = bound(reserveId1, 0, spoke1.reserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.reserveCount() - 1);
    uint256 debtToCover = bound(debtToCover, 1, MAX_SUPPLY_AMOUNT);

    // if even, reserveId1 is collateral, reserveId2 is debt
    // if odd, reserveId1 is debt, reserveId2 is collateral
    (uint256 collateralReserveId, uint256 debtReserveId) = vm.randomUint() % 2 == 0
      ? (reserveId1, reserveId2)
      : (reserveId2, reserveId1);

    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, debtToCover);
  }

  function test_liquidationCall_revertsWith_CollateralCannotBeLiquidated() public {
    uint256 debtToCover = 1;
    uint256 wethAmount = 10e18;
    uint256 daiAmount = 10_000e18;

    test_liquidationCall_fuzz_revertsWith_CollateralCannotBeLiquidated(
      debtToCover,
      wethAmount,
      daiAmount
    );
  }

  function test_liquidationCall_fuzz_revertsWith_CollateralCannotBeLiquidated(
    uint256 debtToCover,
    uint256 wethAmount,
    uint256 daiAmount
  ) public {
    debtToCover = bound(debtToCover, 1, MAX_SUPPLY_AMOUNT);
    wethAmount = bound(wethAmount, 1, MAX_SUPPLY_AMOUNT / 10);
    daiAmount = wethAmount * 10; // ensure enough collateral to borrow

    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);

    _deployLiquidity(spoke1, daiReserveId, daiAmount);

    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.borrow(spoke1, daiReserveId, alice, daiAmount, alice);

    // collateral value drop, so that HF < threshold
    oracle.setAssetPrice(wethAssetId, 0);

    vm.expectRevert(ISpoke.CollateralCannotBeLiquidated.selector);
    spoke1.liquidationCall(wethReserveId, daiReserveId, alice, debtToCover);
  }

  // TODO: HF drop due to interest
}
