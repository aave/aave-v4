// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallValidationTest is SpokeLiquidationBase {
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
    reserveId1 = bound(reserveId1, 0, spoke1.getReserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.getReserveCount() - 1);
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
    reserveId1 = bound(reserveId1, 0, spoke1.getReserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.getReserveCount() - 1);
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
    reserveId1 = bound(reserveId1, 0, spoke1.getReserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.getReserveCount() - 1);
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
    reserveId1 = bound(reserveId1, 0, spoke1.getReserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.getReserveCount() - 1);
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
    reserveId1 = bound(reserveId1, 0, spoke1.getReserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.getReserveCount() - 1);
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
    reserveId1 = bound(reserveId1, 0, spoke1.getReserveCount() - 1);
    reserveId2 = bound(reserveId2, 0, spoke1.getReserveCount() - 1);
    uint256 debtToCover = bound(debtToCover, 1, MAX_SUPPLY_AMOUNT);

    // if even, reserveId1 is collateral, reserveId2 is debt
    // if odd, reserveId1 is debt, reserveId2 is collateral
    (uint256 collateralReserveId, uint256 debtReserveId) = vm.randomUint() % 2 == 0
      ? (reserveId1, reserveId2)
      : (reserveId2, reserveId1);

    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, debtToCover);
  }

  function test_liquidationCall_revertsWith_CollateralCannotBeLiquidated_not_using_as_collateral()
    public
  {
    uint256 debtToCover = 1;
    uint256 wethAmount = 10e18;
    uint256 daiAmount = 10_000e18;
    uint256 newWethPrice = 1e8;

    test_liquidationCall_fuzz_revertsWith_CollateralCannotBeLiquidated_not_using_as_collateral(
      debtToCover,
      wethAmount,
      daiAmount,
      newWethPrice
    );
  }

  function test_liquidationCall_fuzz_revertsWith_CollateralCannotBeLiquidated_not_using_as_collateral(
    uint256 debtToCover,
    uint256 wethAmount,
    uint256 daiAmount,
    uint256 newWethPrice
  ) public {
    debtToCover = bound(debtToCover, 1, MAX_SUPPLY_AMOUNT);
    wethAmount = bound(wethAmount, 1, MAX_SUPPLY_AMOUNT / 10);
    daiAmount = wethAmount * 5; // ensure enough collateral to borrow
    newWethPrice = bound(newWethPrice, 1, spoke1.oracle().getReservePrice(_wethReserveId(spoke1)));
    uint256 usdxAmount = daiAmount * 2; // Another collateral to cover debt while removing weth collateral

    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    _openSupplyPosition(spoke1, daiReserveId, daiAmount);

    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, usdxReserveId, alice, usdxAmount, alice);
    Utils.borrow(spoke1, daiReserveId, alice, daiAmount, alice);

    // no longer set weth as collateral
    setUsingAsCollateral(spoke1, alice, wethReserveId, false);
    assertFalse(spoke1.getUsingAsCollateral(wethReserveId, alice));

    // usdx collateral value drop, make sure that HF < threshold and position is liquidatable
    vm.mockCall(
      address(spoke1.oracle()),
      abi.encodeWithSelector(IPriceOracle.getReservePrice.selector, usdxReserveId),
      abi.encode(0)
    );
    assertLt(
      spoke1.getHealthFactor(alice),
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      'alice HF below threshold'
    );

    vm.expectRevert(ISpoke.CollateralCannotBeLiquidated.selector);
    spoke1.liquidationCall(wethReserveId, daiReserveId, alice, debtToCover);
  }
  // TODO: HF drop due to interest
}
