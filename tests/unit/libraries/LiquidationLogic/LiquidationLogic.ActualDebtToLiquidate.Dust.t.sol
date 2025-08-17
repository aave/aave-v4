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
    params = bound(params);
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
  function test_calculateActualDebtToLiquidate_fuzz_debtToCover_revertsWith_MustNotLeaveDust(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    vm.assume(params.totalBorrowerReserveDebt >= minLeftoverAmount);
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
  function test_calculateActualDebtToLiquidate_fuzz_debtToCover_totalBorrowerReserveDebt_le_minLeftoverAmount_revertsWith_MustNotLeaveDust(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
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

  /// debtToCover is min value but would not leave dust
  function test_calculateActualDebtToLiquidate_fuzz_debtToCover_valid(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    vm.assume(params.totalBorrowerReserveDebt > minLeftoverAmount + 1);
    uint256 debtToCover = bound(
      debtToCover,
      1,
      params.totalBorrowerReserveDebt - minLeftoverAmount
    );
    vm.assume(params.debtToRestoreCloseFactor > debtToCover);

    (bool isDustAmountExpected, , uint256 naiveDebtToLiquidate) = isDustAmountExpected(
      debtToCover,
      params
    );

    assertFalse(isDustAmountExpected);
    assertEq(naiveDebtToLiquidate, debtToCover);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      params,
      debtToCover
    );
    assertEq(actualDebtToLiquidate, debtToCover, 'should return debtToCover');
  }

  /// debtToRestoreCloseFactor results in dust, so it is adjusted to totalBorrowerReserveDebt
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_adjusted(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    vm.assume(params.totalBorrowerReserveDebt >= minLeftoverAmount);
    // ensure that liquidating debtToRestoreCloseFactor will leave dust
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

  /// totalBorrowerReserveDebt is below threshold and debtToCover is valid
  /// actualDebtToLiquidate is adjusted to totalBorrowerReserveDebt
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_dust_totalBorrowerReserveDebt_le_minLeftoverAmount(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    params.totalBorrowerReserveDebt = bound(params.totalBorrowerReserveDebt, 2, minLeftoverAmount);
    // ensure that liquidating debtToRestoreCloseFactor will leave dust
    params.debtToRestoreCloseFactor = bound(
      params.debtToRestoreCloseFactor,
      1,
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

  /// totalBorrowerReserveDebt is below threshold and debtToCover is invalid, so reverts
  /// forge-config: default.allow_internal_expect_revert = true
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_totalBorrowerReserveDebt_le_minLeftoverAmount_revertsWith_MustNotLeaveDust(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    params.totalBorrowerReserveDebt = bound(params.totalBorrowerReserveDebt, 2, minLeftoverAmount);
    params.debtToRestoreCloseFactor = bound(
      params.debtToRestoreCloseFactor,
      1,
      params.totalBorrowerReserveDebt - 1
    );
    debtToCover = bound(debtToCover, 1, params.totalBorrowerReserveDebt - 1);

    (bool isDustAmountExpected, , uint256 naiveDebtToLiquidate) = isDustAmountExpected(
      debtToCover,
      params
    );

    assertTrue(isDustAmountExpected);
    assertEq(naiveDebtToLiquidate, _min(params.debtToRestoreCloseFactor, debtToCover));

    vm.expectRevert(LiquidationLogic.MustNotLeaveDust.selector);
    LiquidationLogic.calculateActualDebtToLiquidate(params, debtToCover);
  }

  /// debtToRestoreCloseFactor results in dust, and debtToCover is less than totalBorrowerReserveDebt
  /// forge-config: default.allow_internal_expect_revert = true
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_dust_revertsWith_MustNotLeaveDust(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    vm.assume(params.totalBorrowerReserveDebt >= minLeftoverAmount);
    // ensure that liquidating debtToRestoreCloseFactor will leave dust
    params.debtToRestoreCloseFactor = bound(
      params.debtToRestoreCloseFactor,
      params.totalBorrowerReserveDebt - minLeftoverAmount + 1,
      params.totalBorrowerReserveDebt - 1
    );
    // ensure debtToRestoreCloseFactor is lowest value
    debtToCover = bound(
      debtToCover,
      params.debtToRestoreCloseFactor,
      params.totalBorrowerReserveDebt - 1
    );

    (bool isDustAmountExpected, , uint256 naiveDebtToLiquidate) = isDustAmountExpected(
      debtToCover,
      params
    );

    assertTrue(isDustAmountExpected);
    assertEq(naiveDebtToLiquidate, params.debtToRestoreCloseFactor);

    vm.expectRevert(LiquidationLogic.MustNotLeaveDust.selector);
    LiquidationLogic.calculateActualDebtToLiquidate(params, debtToCover);
  }

  /// happy path, where the min value never results in dust
  /// defaults to min value without adjustment
  function test_calculateActualDebtToLiquidate_fuzz_default(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    vm.assume(params.totalBorrowerReserveDebt > minLeftoverAmount);
    uint256 minValue = _min(
      params.totalBorrowerReserveDebt,
      _min(params.debtToRestoreCloseFactor, debtToCover)
    );
    // the min value never results in dust
    vm.assume(minValue < params.totalBorrowerReserveDebt - minLeftoverAmount);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      params,
      debtToCover
    );
    assertEq(actualDebtToLiquidate, minValue);
    assertLe(
      actualDebtToLiquidate,
      params.totalBorrowerReserveDebt,
      'totalBorrowerReserveDebt is the hard max cap'
    );
  }

  /// if totalBorrowerReserveDebt starts off below threshold and debtToCover is valid, then debt is fully liquidated
  /// regardless of debtToRestoreCloseFactor
  function test_calculateActualDebtToLiquidate_fuzz_totalBorrowerReserveDebt_le_minLeftoverAmount(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    vm.assume(params.totalBorrowerReserveDebt <= minLeftoverAmount);
    vm.assume(debtToCover >= params.totalBorrowerReserveDebt);

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      params,
      debtToCover
    );
    assertEq(actualDebtToLiquidate, params.totalBorrowerReserveDebt);
  }

  /// if totalBorrowerReserveDebt starts off below threshold and debtToCover is invalid, then debt is fully liquidated
  /// regardless of debtToRestoreCloseFactor
  /// forge-config: default.allow_internal_expect_revert = true
  function test_calculateActualDebtToLiquidate_fuzz_totalBorrowerReserveDebt_le_minLeftoverAmount_revertsWith_MustNotLeaveDust(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    params.totalBorrowerReserveDebt = bound(params.totalBorrowerReserveDebt, 2, minLeftoverAmount);
    debtToCover = bound(debtToCover, 1, params.totalBorrowerReserveDebt - 1);

    vm.expectRevert(LiquidationLogic.MustNotLeaveDust.selector);
    LiquidationLogic.calculateActualDebtToLiquidate(params, debtToCover);
  }

  /// if all values match, then totalBorrowerReserveDebt is returned
  function test_calculateActualDebtToLiquidate_fuzz_matching_values(
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    params.debtToRestoreCloseFactor = params.totalBorrowerReserveDebt;
    uint256 debtToCover = params.totalBorrowerReserveDebt;

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      params,
      debtToCover
    );
    assertEq(actualDebtToLiquidate, params.totalBorrowerReserveDebt);
  }

  /// if debtToCover > totalBorrowerReserveDebt and debtToRestoreCloseFactor is equal to totalBorrowerReserveDebt, then totalBorrowerReserveDebt is returned
  function test_calculateActualDebtToLiquidate_fuzz_debtToRestoreCloseFactor_eq_totalBorrowerReserveDebt(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    vm.assume(debtToCover > params.totalBorrowerReserveDebt);
    params.debtToRestoreCloseFactor = params.totalBorrowerReserveDebt;

    uint256 actualDebtToLiquidate = LiquidationLogic.calculateActualDebtToLiquidate(
      params,
      debtToCover
    );
    assertEq(actualDebtToLiquidate, params.totalBorrowerReserveDebt);
  }

  // bound fuzz inputs
  function bound(
    TestDebtToRestoreCloseFactorParams memory params
  ) internal returns (TestDebtToRestoreCloseFactorParams memory) {
    params = super._bound(params);
    // hardcode debt params for simplicity
    params.debtAssetPrice = DEBT_ASSET_PRICE;
    params.debtAssetUnit = DEBT_ASSET_UNIT;
    return params;
  }
}
