// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicActualDebtToLiquidateDustTest is LiquidationLogicBaseTest {
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;

  uint256 constant MIN_LEFTOVER_BASE = LiquidationLogic.MIN_LEFTOVER_BASE;
  uint256 constant DEBT_ASSET_PRICE = 1e8; // hardcode values to simplify test
  uint256 constant DEBT_ASSET_UNIT = 1e18; // hardcode values to simplify test
  uint256 internal minLeftoverAmount;

  function setUp() public override {
    super.setUp();
    minLeftoverAmount = _convertBaseCurrencyToAmount(
      MIN_LEFTOVER_BASE,
      DEBT_ASSET_PRICE,
      DEBT_ASSET_UNIT
    );
  }

  /// if totalBorrowerReserveDebt is the lowest value, then it is always returned, and unaffected by dust prevention
  function test_calculateActualDebtToLiquidate_fuzz_totalBorrowerReserveDebt_lowest(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    vm.assume(debtToCover > params.totalBorrowerReserveDebt);
    vm.assume(params.debtToRestoreCloseFactor > params.totalBorrowerReserveDebt);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      params,
      debtToCover
    );

    assertEq(
      actualDebtToLiquidate,
      params.totalBorrowerReserveDebt,
      'should return totalBorrowerReserveDebt'
    );
  }

  /// debtToCover is the lowest value, and would leave dust
  /// scenario where totalBorrowerReserveDebt starts off greater than minLeftoverAmount
  /// forge-config: default.allow_internal_expect_revert = true
  function test_calculateActualDebtToLiquidate_fuzz_debtToCover_dust(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    vm.assume(params.totalBorrowerReserveDebt > minLeftoverAmount);
    // ensure that liquidating debtToCover will leave dust
    uint256 debtToCover = bound(
      debtToCover,
      params.totalBorrowerReserveDebt - minLeftoverAmount + 1,
      params.totalBorrowerReserveDebt - 1
    );
    // ensure debtToCover is lowest value
    vm.assume(params.debtToRestoreCloseFactor > debtToCover);

    (bool isDustAmountExpected, , uint256 naiveDebtToLiquidate) = isDustAmountExpected(
      debtToCover,
      params
    );

    assertTrue(isDustAmountExpected);
    assertEq(naiveDebtToLiquidate, debtToCover);

    vm.expectRevert(LiquidationLogic.MustNotLeaveDust.selector);
    LiquidationLogic.calculateActualDebtToLiquidate(params, debtToCover);
  }

  /// debtToCover is the lowest value, and would leave dust
  /// scenario where totalBorrowerReserveDebt starts off already <= minLeftoverAmount
  /// forge-config: default.allow_internal_expect_revert = true
  function test_calculateActualDebtToLiquidate_fuzz_debtToCover_dust_totalBorrowerReserveDebt_lte_minLeftoverAmount(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    params.totalBorrowerReserveDebt = bound(params.totalBorrowerReserveDebt, 2, minLeftoverAmount); // start from 2 so that dust guaranteed when debtToCover is subtracted
    // ensure that liquidating debtToCover will leave dust
    uint256 debtToCover = bound(debtToCover, 1, params.totalBorrowerReserveDebt - 1);
    // ensure debtToCover is lowest value
    vm.assume(params.debtToRestoreCloseFactor > debtToCover);

    (bool isDustAmountExpected, , uint256 naiveDebtToLiquidate) = isDustAmountExpected(
      debtToCover,
      params
    );

    assertTrue(isDustAmountExpected);
    assertEq(naiveDebtToLiquidate, debtToCover);

    vm.expectRevert(LiquidationLogic.MustNotLeaveDust.selector);
    LiquidationLogic.calculateActualDebtToLiquidate(params, debtToCover);
  }

  /// forge-config: default.allow_internal_expect_revert = true
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_dust(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    vm.assume(params.totalBorrowerReserveDebt > minLeftoverAmount);
    // ensure that liquidating debtToCover will leave dust
    params.debtToRestoreCloseFactor = bound(
      params.debtToRestoreCloseFactor,
      params.totalBorrowerReserveDebt - minLeftoverAmount + 1,
      params.totalBorrowerReserveDebt - 1
    );
    // ensure debtToRestoreCloseFactor is lowest value
    vm.assume(debtToCover > params.totalBorrowerReserveDebt);

    (bool isDustAmountExpected, , uint256 naiveDebtToLiquidate) = isDustAmountExpected(
      debtToCover,
      params
    );

    assertTrue(isDustAmountExpected);
    assertEq(naiveDebtToLiquidate, params.debtToRestoreCloseFactor);

    // should return min(debtToCover, totalBorrowerReserveDebt)
    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      params,
      debtToCover
    );
    assertEq(
      actualDebtToLiquidate,
      params.totalBorrowerReserveDebt,
      'should return totalBorrowerReserveDebt'
    );
  }

  // function test_calculateActualDebtToLiquidate_fuzz(
  //   uint256 debtToCover,
  //   TestDebtToRestoreCloseFactorParams memory params
  // ) public {
  //   params = _bound(params);
  //   DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);

  //   vm.assume(debtToCover > 0);

  //   (
  //     bool isDustAmountExpected,
  //     uint256 remainingDebtInBaseCurrency,
  //     uint256 naiveDebtToLiquidate
  //   ) = isDustAmountExpected(debtToCover, params);
  //   vm.assume(isDustAmountExpected);

  //   uint256 actualDebtToLiquidate = params.calculateActualDebtToLiquidate(debtToCover);

  //   assertEq(actualDebtToLiquidate, naiveDebtToLiquidate, 'should return naive debt to liquidate');
  // }

  // bound fuzz inputs
  function _bound(
    TestDebtToRestoreCloseFactorParams memory params
  ) internal override returns (TestDebtToRestoreCloseFactorParams memory) {
    params = super._bound(params);
    params.debtAssetPrice = DEBT_ASSET_PRICE;
    params.debtAssetUnit = DEBT_ASSET_UNIT;
    return params;
  }
}
