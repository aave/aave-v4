// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicValidateLiquidationCallTest is LiquidationLogicBaseTest {
  LiquidationLogic.ValidateLiquidationCallParams params;

  function setUp() public override {
    super.setUp();

    params = LiquidationLogic.ValidateLiquidationCallParams({
      user: alice,
      liquidator: bob,
      debtToCover: 5e18,
      collateralReserveHub: address(hub1),
      debtReserveHub: address(hub1),
      collateralReservePaused: false,
      debtReservePaused: false,
      receiveShares: false,
      collateralReserveFrozen: false,
      healthFactor: 0.8e18,
      isUsingAsCollateral: true,
      collateralFactor: 75_00,
      collateralReserveBalance: 120e6,
      debtReserveBalance: 100e18
    });
  }

  function test_validateLiquidationCall_revertsWith_SelfLiquidation() public {
    params.liquidator = alice;
    vm.expectRevert(ISpoke.SelfLiquidation.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_InvalidDebtToCover() public {
    params.debtToCover = 0;
    vm.expectRevert(ISpoke.InvalidDebtToCover.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReserveNotListed_ZeroCollateralHub() public {
    params.collateralReserveHub = address(0);
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReserveNotListed_ZeroDebtHub() public {
    params.debtReserveHub = address(0);
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReservePaused_CollateralPaused() public {
    params.collateralReservePaused = true;
    vm.expectRevert(ISpoke.ReservePaused.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_CannotReceiveShares_CollateralFrozen() public {
    // frozen coll reserve; receiveShares false allowed
    params.collateralReserveFrozen = true;
    liquidationLogicWrapper.validateLiquidationCall(params);

    // frozen coll reserve; receiveShares true not allowed
    params.receiveShares = true;
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // non-frozen coll reserve; receiveShares true allowed
    params.collateralReserveFrozen = false;
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReservePaused_DebtPaused() public {
    params.debtReservePaused = true;
    vm.expectRevert(ISpoke.ReservePaused.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_HealthFactorNotBelowThreshold() public {
    params.healthFactor = 1.1e18;
    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_CollateralCannotBeLiquidated_NotUsingAsCollateral()
    public
  {
    params.isUsingAsCollateral = false;
    vm.expectRevert(ISpoke.CollateralCannotBeLiquidated.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_CollateralCannotBeLiquidated_ZeroCollateralFactor()
    public
  {
    params.collateralFactor = 0;
    vm.expectRevert(ISpoke.CollateralCannotBeLiquidated.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReserveNotSupplied() public {
    params.collateralReserveBalance = 0;
    vm.expectRevert(ISpoke.ReserveNotSupplied.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReserveNotBorrowed() public {
    params.debtReserveBalance = 0;
    vm.expectRevert(ISpoke.ReserveNotBorrowed.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall() public {
    liquidationLogicWrapper.validateLiquidationCall(params);
  }
}
