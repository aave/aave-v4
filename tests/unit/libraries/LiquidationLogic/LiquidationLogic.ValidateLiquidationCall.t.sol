// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicValidateLiquidationCallTest is LiquidationLogicBaseTest {
  using ReserveFlagsMap for ReserveFlags;

  LiquidationLogic.ValidateLiquidationCallParams params;
  uint256 constant collateralReserveId = 1;

  function setUp() public override {
    super.setUp();
    ReserveFlags collateralReserveFlags = ReserveFlagsMap.create(false, false, true, true);
    ReserveFlags debtReserveFlags = ReserveFlagsMap.create(false, false, true, true);
    params = LiquidationLogic.ValidateLiquidationCallParams({
      user: alice,
      liquidator: bob,
      collateralReserveFlags: collateralReserveFlags,
      debtReserveFlags: debtReserveFlags,
      suppliedShares: 120e6,
      drawnShares: 100e18,
      debtToCover: 5e18,
      collateralFactor: 75_00,
      isUsingAsCollateral: true,
      healthFactor: 0.8e18,
      receiveShares: false
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
    params.collateralReserveFlags = params.collateralReserveFlags.setPaused(true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReservePaused_DebtPaused() public {
    params.debtReserveFlags = params.debtReserveFlags.setPaused(true);
    vm.expectRevert(ISpoke.ReservePaused.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_CannotReceiveShares() public {
    // receiveShares = false; liquidatorUsingAsCollateral = false; frozen = false; receiveSharesEnabled = true; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(false);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = true; frozen = false; receiveSharesEnabled = true; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(false);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = false; frozen = true; receiveSharesEnabled = true; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(true);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = true; frozen = true; receiveSharesEnabled = true; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(true);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = false; frozen = false; receiveSharesEnabled = true; => allowed
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(false);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = true; frozen = false; receiveSharesEnabled = true; => allowed
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(false);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = false; frozen = true; receiveSharesEnabled = true; => revert
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(true);
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = true; frozen = true; receiveSharesEnabled = true; => revert
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(true);
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = false; frozen = false; receiveSharesEnabled = false; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(false);
    params.collateralReserveFlags = params.collateralReserveFlags.setReceiveSharesEnabled(false);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = true; frozen = false; receiveSharesEnabled = false; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(false);
    params.collateralReserveFlags = params.collateralReserveFlags.setReceiveSharesEnabled(false);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = false; frozen = true; receiveSharesEnabled = false; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(true);
    params.collateralReserveFlags = params.collateralReserveFlags.setReceiveSharesEnabled(false);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = true; frozen = true; receiveSharesEnabled = false; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(true);
    params.collateralReserveFlags = params.collateralReserveFlags.setReceiveSharesEnabled(false);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = false; frozen = false; receiveSharesEnabled = false; => revert
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(false);
    params.collateralReserveFlags = params.collateralReserveFlags.setReceiveSharesEnabled(false);
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = true; frozen = false; receiveSharesEnabled = false; => revert
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(false);
    params.collateralReserveFlags = params.collateralReserveFlags.setReceiveSharesEnabled(false);
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = false; frozen = true; receiveSharesEnabled = false; => revert
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(true);
    params.collateralReserveFlags = params.collateralReserveFlags.setReceiveSharesEnabled(false);
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = true; frozen = true; receiveSharesEnabled = false; => revert
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    params.collateralReserveFlags = params.collateralReserveFlags.setFrozen(true);
    params.collateralReserveFlags = params.collateralReserveFlags.setReceiveSharesEnabled(false);
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_HealthFactorNotBelowThreshold() public {
    params.healthFactor = 1.1e18;
    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReserveNotEnabledAsCollateral_NotUsingAsCollateral()
    public
  {
    params.isUsingAsCollateral = false;
    vm.expectRevert(ISpoke.ReserveNotEnabledAsCollateral.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReserveNotEnabledAsCollateral_ZeroCollateralFactor()
    public
  {
    params.collateralFactor = 0;
    vm.expectRevert(ISpoke.ReserveNotEnabledAsCollateral.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReserveNotSupplied() public {
    params.suppliedShares = 0;
    vm.expectRevert(ISpoke.ReserveNotSupplied.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReserveNotBorrowed() public {
    params.drawnShares = 0;
    vm.expectRevert(ISpoke.ReserveNotBorrowed.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall() public view {
    liquidationLogicWrapper.validateLiquidationCall(params);
  }
}
