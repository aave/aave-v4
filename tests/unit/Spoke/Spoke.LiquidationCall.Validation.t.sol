// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract LiquidationCallValidationTest is SpokeBase {
  function test_liquidationCall_revertsWith_ReserveNotActive_collateralReserve() public {
    uint256 wethAssetId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 debtToCover = 1;

    test_liquidationCall_fuzz_revertsWith_ReserveNotActive_collateralReserve(
      wethAssetId,
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
    uint256 wethAssetId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 debtToCover = 1;

    test_liquidationCall_fuzz_revertsWith_ReserveNotActive_debtReserve(
      wethAssetId,
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
    uint256 wethAssetId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 debtToCover = 1;

    test_liquidationCall_fuzz_revertsWith_ReservePaused_collateralReserve(
      wethAssetId,
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
    uint256 wethAssetId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 debtToCover = 1;

    test_liquidationCall_fuzz_revertsWith_ReservePaused_debtReserve(
      wethAssetId,
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
}
