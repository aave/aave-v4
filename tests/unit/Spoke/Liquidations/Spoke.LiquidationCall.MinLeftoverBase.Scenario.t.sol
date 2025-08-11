// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallMinLeftoverBaseScenarioTest is SpokeLiquidationBase {
  using PercentageMath for uint256;

  mapping(uint256 => uint256) internal minLeftoverAmount; // reserveId => min leftover amount
  uint256 internal collateralFactor = 90_00;
  uint32 internal liquidationBonus = 100_00;
  uint16 internal liquidationFee = 0;
  uint256 internal closeFactor = 1.05e18;

  function setUp() public override {
    super.setUp();

    // simplify scenario with no liq bonus, no liquidation fee
    // static collateral factor to simplify liquidation threshold calculations
    uint256 reserveCount = spoke1.getReserveCount();
    for (uint256 reserveId; reserveId < reserveCount; ++reserveId) {
      updateLiquidationBonus(spoke1, reserveId, liquidationBonus);
      updateLiquidationFee(spoke1, reserveId, liquidationFee);
      minLeftoverAmount[reserveId] = _convertBaseCurrencyToAmount(
        spoke1,
        reserveId,
        MIN_LEFTOVER_BASE
      );
      updateCollateralFactor(spoke1, reserveId, collateralFactor);
    }
    updateCloseFactor(spoke1, 1.05e18);
  }

  function test_liquidationCall_borrowerReserveDebtBelowThreshold() public {
    test_liquidationCall_fuzz_borrowerReserveDebtBelowThreshold_deficit({
      daiAmount: 500e18,
      usdxAmount: 1000e6,
      debtToCover: UINT256_MAX
    });
  }

  function test_liquidationCall_fuzz_borrowerReserveDebtBelowThreshold_deficit(
    uint256 daiAmount,
    uint256 usdxAmount,
    uint256 debtToCover
  ) public {
    daiAmount = bound(
      daiAmount,
      _convertBaseCurrencyToAmount(spoke1, _daiReserveId(spoke1), 1e26), // $1 - $500
      minLeftoverAmount[_daiReserveId(spoke1)] / 2
    );
    usdxAmount = bound(
      usdxAmount,
      _convertBaseCurrencyToAmount(
        spoke1,
        _usdxReserveId(spoke1),
        _convertAmountToBaseCurrency(spoke1, _daiReserveId(spoke1), daiAmount)
      ) + 1, // ensure deficit
      minLeftoverAmount[_usdxReserveId(spoke1)]
    );
    vm.assume(debtToCover > usdxAmount);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, daiAmount, alice);
    _borrowWithoutHfCheck(spoke1, alice, _usdxReserveId(spoke1), usdxAmount);

    console.log(
      'coll %e debt %e',
      spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice),
      spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice)
    );

    // deficit should be reported
    vm.expectCall(address(hub1), abi.encodeWithSelector(hub1.reportDeficit.selector), 1);
    // liquidation call with max debt to cover, valid as it liquidates all debt
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      user: alice,
      debtToCover: debtToCover
    });
    console.log(
      'coll %e debt %e',
      spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice),
      spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice)
    );

    assertEq(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice), 0, 'collateral');
    assertEq(spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice), 0, 'debt');
  }

  function test_liquidationCall_borrowerReserveDebtBelowThreshold_revertsWith_MustNotLeaveDust_debtToCover()
    public
  {
    test_liquidationCall_fuzz_borrowerReserveDebtBelowThreshold_revertsWith_MustNotLeaveDust_debtToCover({
      daiAmount: 500e18,
      debtToCover: 100e6
    });
  }

  function test_liquidationCall_fuzz_borrowerReserveDebtBelowThreshold_revertsWith_MustNotLeaveDust_debtToCover(
    uint256 daiAmount,
    uint256 debtToCover
  ) public {
    daiAmount = bound(
      daiAmount,
      _convertBaseCurrencyToAmount(spoke1, _daiReserveId(spoke1), 1e26), // $1 - $500
      minLeftoverAmount[_daiReserveId(spoke1)] / 2
    );
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, daiAmount, alice);
    (, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      _usdxReserveId(spoke1),
      0.95e18
    );

    uint256 debtToRestoreCloseFactor = calcDebtToRestoreCloseFactor(
      spoke1,
      _usdxReserveId(spoke1),
      alice,
      liquidationBonus,
      closeFactor
    );
    debtToCover = bound(debtToCover, 1, _min(debtToRestoreCloseFactor, requiredDebtAmount) - 1);

    // console.log('debtToRestoreCloseFactor %e', debtToRestoreCloseFactor);

    // liquidation call with invalid debt to cover
    vm.prank(LIQUIDATOR);
    vm.expectRevert(abi.encodeWithSelector(LiquidationLogic.MustNotLeaveDust.selector));
    spoke1.liquidationCall({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      user: alice,
      debtToCover: debtToCover
    });
  }

  function test_liquidationCall_borrowerReserveDebtBelowThreshold_revertsWith_MustNotLeaveDust_debtToRestoreCloseFactor()
    public
  {
    test_liquidationCall_fuzz_borrowerReserveDebtBelowThreshold_revertsWith_MustNotLeaveDust_debtToRestoreCloseFactor({
      daiAmount: 500e18,
      debtToCover: 100e6
    });
  }
  function test_liquidationCall_fuzz_borrowerReserveDebtBelowThreshold_revertsWith_MustNotLeaveDust_debtToRestoreCloseFactor(
    uint256 daiAmount,
    uint256 debtToCover
  ) public {
    daiAmount = bound(
      daiAmount,
      _convertBaseCurrencyToAmount(spoke1, _daiReserveId(spoke1), 1e26), // $1 - $500
      minLeftoverAmount[_daiReserveId(spoke1)] / 2
    );

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, daiAmount, alice);
    (, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      _usdxReserveId(spoke1),
      0.95e18
    );

    uint256 debtToRestoreCloseFactor = calcDebtToRestoreCloseFactor(
      spoke1,
      _usdxReserveId(spoke1),
      alice,
      liquidationBonus,
      closeFactor
    );
    debtToCover = bound(debtToCover, debtToRestoreCloseFactor + 1, requiredDebtAmount - 1);

    console.log('HF %e', spoke1.getHealthFactor(alice));
    console.log('debtToRestoreCloseFactor %e', debtToRestoreCloseFactor);

    vm.expectRevert(abi.encodeWithSelector(LiquidationLogic.MustNotLeaveDust.selector));
    // liquidation call with invalid debt to cover
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      user: alice,
      debtToCover: debtToCover
    });
  }

  function test_liquidationCall_fuzz_borrowerReserveDebtBelowThreshold_readjustActualDebtToLiquidate(
    uint256 daiAmount,
    uint256 debtToCover
  ) public {
    daiAmount = bound(
      daiAmount,
      _convertBaseCurrencyToAmount(spoke1, _daiReserveId(spoke1), 1e26), // $1 - $500
      minLeftoverAmount[_daiReserveId(spoke1)] / 2
    );

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, daiAmount, alice);
    (, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      _usdxReserveId(spoke1),
      0.95e18
    );

    uint256 debtToRestoreCloseFactor = calcDebtToRestoreCloseFactor(
      spoke1,
      _usdxReserveId(spoke1),
      alice,
      liquidationBonus,
      closeFactor
    );
    vm.assume(debtToCover >= requiredDebtAmount);

    vm.expectCall(address(hub1), abi.encodeWithSelector(hub1.reportDeficit.selector), 0);
    // liquidation call with invalid debt to cover
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      user: alice,
      debtToCover: debtToCover
    });

    // debt is readjusted to max liquidatable debt
    assertEq(spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice), 0, 'debt');
    assertGt(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice), 0, 'collateral');
  }

  /// when debtToCover is greater than collateral amount, results in deficit
  function test_liquidationCall_borrowerReserveDebtThreshold_deficit_scenario1() public {
    test_liquidationCall_fuzz_borrowerReserveDebtThreshold_deficit({
      daiAmount: 5_000e18,
      usdxAmount: 10_000e6,
      debtToCover: UINT256_MAX // greater than collateral amount, results in deficit
    });
  }

  /// when debtToCover exactly covers collateral, results in deficit
  function test_liquidationCall_borrowerReserveDebtThreshold_deficit_scenario2() public {
    test_liquidationCall_fuzz_borrowerReserveDebtThreshold_deficit({
      daiAmount: 5_000e18,
      usdxAmount: 10_000e6,
      debtToCover: 5000e6 // exactly covers collateral, results in deficit
    });
  }

  /// when debtToCover >= borrowerReserveDebt and results in deficit
  function test_liquidationCall_fuzz_borrowerReserveDebtThreshold_deficit(
    uint256 daiAmount,
    uint256 usdxAmount,
    uint256 debtToCover
  ) public {
    daiAmount = bound(
      daiAmount,
      minLeftoverAmount[_daiReserveId(spoke1)],
      minLeftoverAmount[_daiReserveId(spoke1)] * 1e6 // $1M
    );
    usdxAmount = bound(
      usdxAmount,
      _convertBaseCurrencyToAmount(
        spoke1,
        _usdxReserveId(spoke1),
        _convertAmountToBaseCurrency(spoke1, _daiReserveId(spoke1), daiAmount)
      ) + 1, // ensure deficit
      minLeftoverAmount[_usdxReserveId(spoke1)] * 2e6 // $2M
    );
    vm.assume(
      debtToCover > usdxAmount ||
        _convertAmountToBaseCurrency(spoke1, _usdxReserveId(spoke1), debtToCover) >=
        _convertAmountToBaseCurrency(spoke1, _daiReserveId(spoke1), daiAmount)
    );

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, daiAmount, alice);
    _borrowWithoutHfCheck(spoke1, alice, _usdxReserveId(spoke1), usdxAmount);

    // deficit should be reported
    vm.expectCall(address(hub1), abi.encodeWithSelector(hub1.reportDeficit.selector), 1);
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      user: alice,
      debtToCover: debtToCover
    });
    console.log(
      'test remaining coll %e debt %e',
      spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice),
      spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice)
    );

    assertEq(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice), 0, 'collateral');
    assertEq(spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice), 0, 'debt');

    // // if debt to cover is less than collateral amount AND doesn't leave dust, normal liquidation occurs
    // if (
    //   !shouldReportDeficit &&
    //   _convertAmountToBaseCurrency(spoke1, _usdxReserveId(spoke1), debtToCover) <
    //   _convertAmountToBaseCurrency(spoke1, _daiReserveId(spoke1), daiAmount)
    // ) {
    //   assertEq(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice), daiAmount, 'collateral');
    // }

    // //  {
    // //   assertEq(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice), 0, 'collateral');
    // //   assertEq(spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice), 0, 'debt');
    // // }

    // // assertEq(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice), 0, 'collateral');
    // // assertEq(spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice), 0, 'debt');
  }

  function test_liquidationCall_borrowerReserveDebtThreshold_revertsWith_MustNotLeaveDust_debtToCover()
    public
  {
    uint256 daiAmount = 5_000e18;
    uint256 usdxAmount = 7_500e6;
    uint256 debtToCover = 7_000e6;

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, daiAmount, alice);
    _borrowWithoutHfCheck(spoke1, alice, _usdxReserveId(spoke1), usdxAmount);

    // liquidation call with invalid debt to cover
    vm.expectRevert(abi.encodeWithSelector(LiquidationLogic.MustNotLeaveDust.selector));
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      user: alice,
      debtToCover: debtToCover
    });
  }

  function test_liquidationCall_fuzz_borrowerReserveDebtThreshold_revertsWith_MustNotLeaveDust_debtToCover(
    uint256 daiAmount,
    uint256 debtToCover
  ) public {
    daiAmount = bound(
      daiAmount,
      minLeftoverAmount[_daiReserveId(spoke1)],
      minLeftoverAmount[_daiReserveId(spoke1)] * 1e6 // $1M
    );
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, daiAmount, alice);
    (, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      _usdxReserveId(spoke1),
      0.75e18 // low HF to ensure that debtToRestoreCloseFactor is greater than requiredDebtAmount
    );

    uint256 debtToRestoreCloseFactor = calcDebtToRestoreCloseFactor(
      spoke1,
      _usdxReserveId(spoke1),
      alice,
      liquidationBonus,
      closeFactor
    );

    console.log('debtToRestoreCloseFactor %e', debtToRestoreCloseFactor);
    console.log('requiredDebtAmount %e', requiredDebtAmount);

    // bound debtToCover to be an amount that results in dust debt
    debtToCover = bound(
      debtToCover,
      _min(debtToRestoreCloseFactor, requiredDebtAmount) -
        minLeftoverAmount[_usdxReserveId(spoke1)] +
        1,
      _min(debtToRestoreCloseFactor, requiredDebtAmount) - 1
    );

    // liquidation call with invalid debt to cover
    vm.expectRevert(abi.encodeWithSelector(LiquidationLogic.MustNotLeaveDust.selector));
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      user: alice,
      debtToCover: debtToCover
    });
  }

  /// successful liquidation scenario, where debtToCover is valid and results in remaining debt amount > dust
  function test_liquidationCall_borrowerReserveDebtThreshold_valid(
    uint256 daiAmount,
    uint256 usdxAmount,
    uint256 debtToCover
  ) public {
    usdxAmount = bound(
      usdxAmount,
      minLeftoverAmount[_usdxReserveId(spoke1)] + 1,
      minLeftoverAmount[_usdxReserveId(spoke1)] * 1e6 // $1M
    );
    // ensure more collateral than debt, no deficit
    // but not more than allowed by collateral factor, to ensure HF is < 1
    uint256 minDaiAmount = _convertBaseCurrencyToAmount(
      spoke1,
      _daiReserveId(spoke1),
      _convertAmountToBaseCurrency(spoke1, _usdxReserveId(spoke1), usdxAmount)
    );
    daiAmount = bound(
      daiAmount,
      minDaiAmount + 1, // min collateral that prevents deficit
      minDaiAmount.percentDivDown(collateralFactor) - 1 // max collateral allowed that keeps HF < 1
    );
    // ensure debtToCover does not result in dust debt
    debtToCover = bound(
      debtToCover,
      1,
      _min(
        usdxAmount - minLeftoverAmount[_usdxReserveId(spoke1)],
        _convertBaseCurrencyToAmount(
          spoke1,
          _usdxReserveId(spoke1),
          _convertAmountToBaseCurrency(spoke1, _daiReserveId(spoke1), daiAmount)
        )
      )
    );

    // console.log('usdxAmount %e', usdxAmount);
    // console.log('daiAmount %e', daiAmount);
    // console.log('debtToCover %e', debtToCover);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, daiAmount, alice);
    _borrowWithoutHfCheck(spoke1, alice, _usdxReserveId(spoke1), usdxAmount);

    // console.log('HF %e', spoke1.getHealthFactor(alice));
    // uint256 actualDebtToLiquidate = calcDebtToRestoreCloseFactor(
    //   spoke1,
    //   _usdxReserveId(spoke1),
    //   alice,
    //   liquidationBonus,
    //   closeFactor
    // );
    // console.log('actualDebtToLiquidate %e', actualDebtToLiquidate);

    // deficit should not be reported
    vm.expectCall(address(hub1), abi.encodeWithSelector(hub1.reportDeficit.selector), 0);
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      user: alice,
      debtToCover: debtToCover
    });
    console.log(
      'test remaining coll %e debt %e',
      spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice),
      spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice)
    );
    // no deficit, so collateral should remain
    assertGt(spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice), 0, 'collateral');
    // no dust should remain
    assertGe(
      spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice),
      minLeftoverAmount[_usdxReserveId(spoke1)],
      'debt'
    );
  }
}
