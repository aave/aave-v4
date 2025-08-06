// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicWrapper {
  function calculateActualDebtToLiquidate(
    DataTypes.LiquidationCallLocalVars memory params,
    uint256 debtToCover
  ) external returns (uint256) {
    // console.log('debtToCover %e', debtToCover);
    // console.log('params.totalBorrowerReserveDebt %e', params.totalBorrowerReserveDebt);
    // console.log('params.debtToRestoreCloseFactor %e', params.debtToRestoreCloseFactor);
    // console.log('params.debtAssetPrice %e', params.debtAssetPrice);
    // console.log('params.debtAssetUnit %e', params.debtAssetUnit);
    // console.log('params.debtAssetPrice %e', params.debtAssetPrice);
    return LiquidationLogic.calculateActualDebtToLiquidate(params, debtToCover);
  }
}

contract LiquidationLogicActualDebtToLiquidateDustTest is LiquidationLogicBaseTest {
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;

  uint256 constant MIN_LEFTOVER_BASE = LiquidationLogic.MIN_LEFTOVER_BASE;

  LiquidationLogicWrapper internal wrapper;

  function setUp() public override {
    super.setUp();
    wrapper = new LiquidationLogicWrapper();
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
    uint256 minLeftoverAmount = _convertBaseCurrencyToAmount(
      MIN_LEFTOVER_BASE,
      params.debtAssetPrice,
      params.debtAssetUnit
    );
    vm.assume(params.totalBorrowerReserveDebt > minLeftoverAmount);
    // uint256 maxLiquidatableDebt = _min(
    //   params.totalBorrowerReserveDebt,
    //   params.debtToRestoreCloseFactor
    // );
    // uint256 maxLiquidatableDebtInBaseCurrency = _convertAmountToBaseCurrency(
    //   maxLiquidatableDebt,
    //   params.debtAssetPrice,
    //   params.debtAssetUnit
    // );
    uint256 debtToCover = bound(
      debtToCover,
      params.totalBorrowerReserveDebt - minLeftoverAmount + 1,
      params.totalBorrowerReserveDebt - 1
    );
    vm.assume(params.debtToRestoreCloseFactor > debtToCover);
    // ensure debtToCover is less than totalBorrowerReserveDebt and debtToRestoreCloseFactor
    // and that liquidating debtToCover will leave dust

    // assertLe(
    //   debtToCover,
    //   params.totalBorrowerReserveDebt,
    //   'debtToCover <= totalBorrowerReserveDebt'
    // );
    // assertLe(
    //   debtToCover,
    //   params.debtToRestoreCloseFactor,
    //   'debtToCover <= debtToRestoreCloseFactor'
    // );

    (bool isDustAmountExpected, , uint256 naiveDebtToLiquidate) = isDustAmountExpected(
      debtToCover,
      params
    );

    console.log('isDustAmountExpected', isDustAmountExpected);
    console.log('naiveDebtToLiquidate %e', naiveDebtToLiquidate);

    // console.log('debtToCover %e', debtToCover);
    // console.log('params.totalBorrowerReserveDebt %e', params.totalBorrowerReserveDebt);
    // console.log('params.debtToRestoreCloseFactor %e', params.debtToRestoreCloseFactor);

    // calculate

    assertTrue(isDustAmountExpected);
    assertEq(naiveDebtToLiquidate, debtToCover);

    vm.expectRevert(LiquidationLogic.MustNotLeaveDust.selector);
    LiquidationLogic.calculateActualDebtToLiquidate(params, debtToCover);
  }

  // /// forge-config: default.allow_internal_expect_revert = true
  // function test_calculateActualDebtToLiquidate_fuzz_debtToCover_dustdebug() public {
  //   TestDebtToRestoreCloseFactorParams memory params2;
  //   params2 = _bound(params2);
  //   DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params2);
  //   params.totalBorrowerReserveDebt = 100;
  //   params.debtToRestoreCloseFactor = 100;
  //   uint256 debtToCover = 90;

  //   // vm.expectRevert(abi.encodeWithSelector(LiquidationLogic.MustNotLeaveDust.selector));
  //   vm.expectRevert(LiquidationLogic.MustNotLeaveDust.selector);
  //   LiquidationLogic.calculateActualDebtToLiquidate(params, debtToCover);

  //   // try this.calculateActualDebtToLiquidateWrapper(params, debtToCover) {
  //   //   console.log('Should have reverted');
  //   // } catch (bytes memory reason) {
  //   //   console.log('Actual revert selector:');
  //   //   console.logBytes4(bytes4(reason));
  //   //   assertEq(bytes4(reason), LiquidationLogic.MustNotLeaveDust.selector);
  //   // }
  // }

  function calculateActualDebtToLiquidateWrapper(
    DataTypes.LiquidationCallLocalVars memory params,
    uint256 debtToCover
  ) external returns (uint256) {
    // console.log('debtToCover %e', debtToCover);
    // console.log('params.totalBorrowerReserveDebt %e', params.totalBorrowerReserveDebt);
    // console.log('params.debtToRestoreCloseFactor %e', params.debtToRestoreCloseFactor);
    // console.log('params.debtAssetPrice %e', params.debtAssetPrice);
    // console.log('params.debtAssetUnit %e', params.debtAssetUnit);
    // console.log('params.debtAssetPrice %e', params.debtAssetPrice);
    return LiquidationLogic.calculateActualDebtToLiquidate(params, debtToCover);
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
    params.debtAssetPrice = 1e8;
    params.debtAssetUnit = 1e18;
    return params;
  }
}
