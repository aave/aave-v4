// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicWrapper {
  function calculateActualDebtToLiquidate(
    DataTypes.LiquidationCallLocalVars memory params,
    uint256 debtToCover
  ) external returns (uint256) {
    console.log('debtToCover %e', debtToCover);
    console.log('params.totalBorrowerReserveDebt %e', params.totalBorrowerReserveDebt);
    console.log('params.debtToRestoreCloseFactor %e', params.debtToRestoreCloseFactor);
    console.log('params.debtAssetPrice %e', params.debtAssetPrice);
    console.log('params.debtAssetUnit %e', params.debtAssetUnit);
    console.log('params.debtAssetPrice %e', params.debtAssetPrice);
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
  function test_calculateActualDebtToLiquidate_fuzz_debtToCover_dust(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    vm.assume(
      params.totalBorrowerReserveDebt > MIN_LEFTOVER_BASE &&
        params.debtToRestoreCloseFactor > MIN_LEFTOVER_BASE
    );
    uint256 maxLiquidatableDebt = _min(
      params.totalBorrowerReserveDebt,
      params.debtToRestoreCloseFactor
    );
    debtToCover = bound(
      debtToCover,
      maxLiquidatableDebt - MIN_LEFTOVER_BASE + 1,
      maxLiquidatableDebt - 1
    );

    vm.expectRevert();
    wrapper.calculateActualDebtToLiquidate(params, debtToCover);
  }

  function test_calculateActualDebtToLiquidate_fuzz_debtToCover_dustdebug(
    uint256 debtToCover,
    TestDebtToRestoreCloseFactorParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory params = _setStructFields(params);
    params.totalBorrowerReserveDebt = 100;
    params.debtToRestoreCloseFactor = 100;
    debtToCover = 90;

    vm.expectRevert(LiquidationLogic.MustNotLeaveDust.selector);
    wrapper.calculateActualDebtToLiquidate(params, debtToCover);
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

  /// bound fuzz inputs
  // function _bound(
  //   TestDebtToRestoreCloseFactorParams memory params
  // ) internal override returns (TestDebtToRestoreCloseFactorParams memory) {
  //   params = super._bound(params);
  //   params.totalBorrowerReserveDebt = bound(
  //     params.totalBorrowerReserveDebt,
  //     1,
  //     _max(
  //       _convertBaseCurrencyToAmount(
  //         LiquidationLogic.MIN_LEFTOVER_BASE * 100,
  //         params.debtAssetPrice,
  //         params.debtAssetUnit
  //       ),
  //       1
  //     ) // ensure reserve debt is at least 1
  //   );
  //   return params;
  // }
}
