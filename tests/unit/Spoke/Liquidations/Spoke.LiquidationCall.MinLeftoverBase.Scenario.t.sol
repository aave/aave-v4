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

  function test_liquidationCall_debtBelowThreshold() public {
    test_liquidationCall_fuzz_debtBelowThreshold_deficit({
      daiAmount: 500e18,
      usdxAmount: 1000e6,
      debtToCover: UINT256_MAX
    });
  }

  function test_liquidationCall_fuzz_debtBelowThreshold_deficit(
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
    vm.expectCall(address(hub1), abi.encodeWithSelector(hub1.reportDeficit.selector));
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

  function test_liquidationCall_debtBelowThreshold_revertsWith_MustNotLeaveDust_debtToCover()
    public
  {
    test_liquidationCall_fuzz_debtBelowThreshold_revertsWith_MustNotLeaveDust_debtToCover({
      daiAmount: 500e18,
      usdxAmount: 1000e6,
      debtToCover: 100e6
    });
  }

  function test_liquidationCall_fuzz_debtBelowThreshold_revertsWith_MustNotLeaveDust_debtToCover(
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
        _convertAmountToBaseCurrency(spoke1, _daiReserveId(spoke1), daiAmount).percentMulUp(
          collateralFactor
        )
      ) + 1, // ensure liquidatable
      minLeftoverAmount[_usdxReserveId(spoke1)]
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

  function test_liquidationCall_debtBelowThreshold_revertsWith_MustNotLeaveDust_debtToRestoreCloseFactor()
    public
  {
    test_liquidationCall_fuzz_debtBelowThreshold_revertsWith_MustNotLeaveDust_debtToRestoreCloseFactor({
      daiAmount: 500e18,
      debtToCover: 100e6
    });
  }
  function test_liquidationCall_fuzz_debtBelowThreshold_revertsWith_MustNotLeaveDust_debtToRestoreCloseFactor(
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

  function test_liquidationCall_fuzz_debtBelowThreshold_readjustActualDebtToLiquidate(
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
  }

  function test_liquidationCall_debtAboveThreshold_deficit_scenario1() public {
    test_liquidationCall_fuzz_debtAboveThreshold_deficit({
      daiAmount: 5_000e18,
      usdxAmount: 10_000e6,
      debtToCover: UINT256_MAX
    });
  }

  function test_liquidationCall_debtAboveThreshold_deficit_scenario2() public {
    test_liquidationCall_fuzz_debtAboveThreshold_deficit({
      daiAmount: 5_000e18,
      usdxAmount: 10_000e6,
      debtToCover: 5_000e6
    });
  }

  function test_liquidationCall_fuzz_debtAboveThreshold_deficit(
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

    // console.log(
    //   'coll %e debt %e',
    //   spoke1.getUserSuppliedAmount(_daiReserveId(spoke1), alice),
    //   spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice)
    // );

    // either a valid input amount, or amount is adjusted to cover all debt, resulting in deficit
    // bool shouldReportDeficit = debtToCover > usdxAmount ||
    //   _convertAmountToBaseCurrency(spoke1, _usdxReserveId(spoke1), debtToCover) >=
    //   _convertAmountToBaseCurrency(spoke1, _daiReserveId(spoke1), daiAmount);

    // deficit should be reported
    vm.expectCall(address(hub1), abi.encodeWithSelector(hub1.reportDeficit.selector));
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

  // function test_liquidationCall_debtAboveThreshold_deficit_scenario3() public {
  //   test_liquidationCall_fuzz_debtAboveThreshold_deficit({
  //     daiAmount: 5_000e18,
  //     usdxAmount: 5_500e6,
  //     debtToCover: 4_000e6
  //   });
  // }
}
