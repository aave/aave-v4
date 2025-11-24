// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicValidateLiquidationCallTest is LiquidationLogicBaseTest {
  LiquidationLogic.ValidateLiquidationCallParams params;
  ISpoke.Reserve collateralReserve;
  ISpoke.Reserve debtReserve;
  uint256 constant collateralReserveId = 1;
  uint256 constant debtReserveId = 2;

  function setUp() public override {
    super.setUp();
    collateralReserve.paused = false;
    collateralReserve.frozen = false;
    collateralReserve.borrowable = true;
    collateralReserve.canReceiveShares = true;
    debtReserve.paused = false;
    debtReserve.frozen = false;
    params = LiquidationLogic.ValidateLiquidationCallParams({
      user: alice,
      liquidator: bob,
      debtToCover: 5e18,
      receiveShares: false,
      healthFactor: 0.8e18,
      collateralReserveId: collateralReserveId,
      collateralFactor: 75_00,
      collateralReserveBalance: 120e6,
      debtReserveBalance: 100e18
    });
    liquidationLogicWrapper.setBorrower(params.user);
    liquidationLogicWrapper.setLiquidator(params.liquidator);
    liquidationLogicWrapper.setBorrowerCollateralStatus(collateralReserveId, true);
    liquidationLogicWrapper.setCollateralReserveId(collateralReserveId);
    liquidationLogicWrapper.setDebtReserveId(debtReserveId);
    liquidationLogicWrapper.setCollateralReserveConfig(
      ISpoke.ReserveConfig({
        paused: false,
        frozen: false,
        borrowable: true,
        canReceiveShares: true,
        collateralRisk: 0
      })
    );
    liquidationLogicWrapper.setDebtReserveConfig(
      ISpoke.ReserveConfig({
        paused: false,
        frozen: false,
        borrowable: true,
        canReceiveShares: true,
        collateralRisk: 0
      })
    );
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
    liquidationLogicWrapper.setCollateralReserveConfig(
      ISpoke.ReserveConfig({
        paused: true,
        frozen: false,
        borrowable: true,
        canReceiveShares: true,
        collateralRisk: 0
      })
    );
    vm.expectRevert(ISpoke.ReservePaused.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_CannotReceiveShares() public {
    ISpoke.ReserveConfig memory collateralReserveConfig = ISpoke.ReserveConfig({
      paused: false,
      frozen: false,
      borrowable: true,
      canReceiveShares: true,
      collateralRisk: 0
    });

    // receiveShares = false; liquidatorUsingAsCollateral = false; frozen = false; canReceiveShares = true; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    collateralReserveConfig.frozen = false;
    liquidationLogicWrapper.setCollateralReserveConfig(collateralReserveConfig);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = true; frozen = false; canReceiveShares = true; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    collateralReserveConfig.frozen = false;
    liquidationLogicWrapper.setCollateralReserveConfig(collateralReserveConfig);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = false; frozen = true; canReceiveShares = true; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    collateralReserveConfig.frozen = true;
    liquidationLogicWrapper.setCollateralReserveConfig(collateralReserveConfig);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = false; liquidatorUsingAsCollateral = true; frozen = true; canReceiveShares = true; => allowed
    params.receiveShares = false;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    collateralReserveConfig.frozen = true;
    liquidationLogicWrapper.setCollateralReserveConfig(collateralReserveConfig);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = false; frozen = false; canReceiveShares = true; => allowed
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    collateralReserveConfig.frozen = false;
    liquidationLogicWrapper.setCollateralReserveConfig(collateralReserveConfig);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = true; frozen = false; canReceiveShares = true; => allowed
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    collateralReserveConfig.frozen = false;
    liquidationLogicWrapper.setCollateralReserveConfig(collateralReserveConfig);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = false; frozen = true; canReceiveShares = true; => revert
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, false);
    collateralReserveConfig.frozen = true;
    liquidationLogicWrapper.setCollateralReserveConfig(collateralReserveConfig);
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = true; frozen = true; canReceiveShares = true; => revert
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    collateralReserveConfig.frozen = true;
    liquidationLogicWrapper.setCollateralReserveConfig(collateralReserveConfig);
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);

    // receiveShares = true; liquidatorUsingAsCollateral = true; frozen = false; canReceiveShares = false; => revert
    params.receiveShares = true;
    liquidationLogicWrapper.setLiquidatorCollateralStatus(collateralReserveId, true);
    collateralReserveConfig.frozen = false;
    collateralReserveConfig.canReceiveShares = false;
    liquidationLogicWrapper.setCollateralReserveConfig(collateralReserveConfig);
    vm.expectRevert(ISpoke.CannotReceiveShares.selector);
    liquidationLogicWrapper.validateLiquidationCall(params);
  }

  function test_validateLiquidationCall_revertsWith_ReservePaused_DebtPaused() public {
    liquidationLogicWrapper.setDebtReserveConfig(
      ISpoke.ReserveConfig({
        paused: true,
        frozen: false,
        borrowable: true,
        canReceiveShares: true,
        collateralRisk: 0
      })
    );
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
    liquidationLogicWrapper.setBorrowerCollateralStatus(collateralReserveId, false);
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
