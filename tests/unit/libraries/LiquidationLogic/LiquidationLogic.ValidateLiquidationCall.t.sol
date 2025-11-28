// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicValidateLiquidationCallTest is LiquidationLogicBaseTest {
  LiquidationLogic.ValidateLiquidationCallParams params;
  uint256 constant collateralReserveId = 1;

  function setUp() public override {
    super.setUp();
    params = LiquidationLogic.ValidateLiquidationCallParams({
      user: alice,
      liquidator: bob,
      debtToCover: 5e18,
      collateralReservePaused: false,
      debtReservePaused: false,
      receiveShares: false,
      collateralReserveFrozen: false,
      healthFactor: 0.8e18,
      collateralFactor: 75_00,
      collateralReserveBalance: 120e6,
      debtReserveBalance: 100e18,
      isUsingAsCollateral: true
    });
    liquidationLogicWrapper.setBorrower(params.user);
    liquidationLogicWrapper.setLiquidator(params.liquidator);
    liquidationLogicWrapper.setBorrowerCollateralStatus(collateralReserveId, true);
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

  function test_validateLiquidationCall_revertsWith_ReservePaused_CollateralPaused() public {
    params.collateralReservePaused = true;
    vm.expectRevert(ISpoke.ReservePaused.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_CannotReceiveShares() public {
    // receiveShares = false; liquidatorUsingAsCollateral = false; frozen = false; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFrozen = false;
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = true; frozen = false; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFrozen = false;
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = false; frozen = true; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFrozen = true;
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = true; frozen = true; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFrozen = true;
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = false; frozen = false; => allowed
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFrozen = false;
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = true; frozen = false; => allowed
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFrozen = false;
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = false; frozen = true; => revert
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFrozen = true;
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = true; frozen = true; => revert
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFrozen = true;
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
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

  function test_validateLiquidationCall() public view {
    liquidationLogicWrapper.validateLiquidationCall(params);
  }
}
