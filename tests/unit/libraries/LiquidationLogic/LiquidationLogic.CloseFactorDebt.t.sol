// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicCloseFactorDebtTest is LiquidationLogicBaseTest {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using WadRayMathExtended for uint256;

  function test_calculateCloseFactorDebt_fuzz_non_negative(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_NONE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    assertGe(
      LiquidationLogic.calculateCloseFactorDebt(args),
      0,
      'closeFactorDebt cannot underflow'
    );
  }

  /// if debtAssetUnit == 0, then result is 0 (should not happen in practice as unit is 10**decimals)
  function test_calculateCloseFactorDebt_fuzz_debtAssetUnit_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    // params = _bound(params);
    FieldsToSkip memory skips = _skipOnly(SKIP_DEBT_ASSET_UNIT);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    args.debtAssetUnit = 0;

    assertEq(LiquidationLogic.calculateCloseFactorDebt(args), 0, 'closeFactorDebt is 0');
  }

  function test_calculateCloseFactorDebt_fuzz_debtAssetPrice_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_DEBT_ASSET_PRICE);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    args.debtAssetPrice = 0;

    assertEq(
      LiquidationLogic.calculateCloseFactorDebt(args),
      type(uint256).max,
      'closeFactorDebt is 0'
    );
  }

  /// if denom is ever negative, default to uint max
  function test_calculateCloseFactorDebt_fuzz_closeFactor_lte_effectiveLiquidationPenalty_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_CLOSE_FACTOR);
    TestCloseFactorDebtParams memory params = _bound(params, skips);
    params.closeFactor = bound(
      params.closeFactor,
      1, // in practice CF >= 1e18
      _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor) - 1
    );
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    assertEq(
      LiquidationLogic.calculateCloseFactorDebt(args),
      type(uint256).max,
      'closeFactorDebt is max uint'
    );
  }

  function test_calculateCloseFactorDebt_fuzz_avgCollateralFactor_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    FieldsToSkip memory skips = _skipOnly(SKIP_AVG_COLLATERAL_FACTOR);
    params = _bound(params, skips);

    params.avgCollateralFactor = 0;
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    assertEq(
      LiquidationLogic.calculateCloseFactorDebt(args),
      _calcCloseFactorDebtZeroAvgCollateralFactor(params),
      'closeFactorDebt is incorrect'
    );
  }

  function setUpScenario1() internal {
    // DAI CollateralFactor: 0.75
    // WETH CollateralFactor: 0.8
    // USDX CollateralFactor: 0.7

    updateCollateralFactor(spoke1, _daiReserveId(spoke1), 75_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 80_00);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 70_00);

    // weth price drops to $800
    oracle.setAssetPrice(wethAssetId, 800e8); // $800

    updateLiquidationBonus(spoke1, _daiReserveId(spoke1), 105_00);
    updateLiquidationBonus(spoke1, _wethReserveId(spoke1), 103_00);
    updateLiquidationBonus(spoke1, _usdxReserveId(spoke1), 104_00);
  }

  function test_calculateCloseFactorDebt_unit1() public {
    // coll: $10k usdx, $8k weth
    // debt: $15k dai
    // liquidate usdx

    setUpScenario1();

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 10e3});
    collaterals[1] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 10});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 15e3});

    DataTypes.LiquidationCallLocalVars memory params = _calcParams({
      spoke: spoke1,
      collaterals: collaterals,
      collateralIndex: 0,
      debts: debts,
      debtIndex: 0
    });
    params.closeFactor = 1e18;

    uint256 closeFactorDebt = LiquidationLogic.calculateCloseFactorDebt(params);

    assertCloseFactor({
      spoke: spoke1,
      params: params,
      collaterals: collaterals,
      collateralIndex: 0,
      debts: debts,
      debtIndex: 0,
      closeFactorDebt: closeFactorDebt
    });
  }

  function test_calculateCloseFactorDebt_unit2() public {
    setUpScenario1();

    // coll: $10k dai, $8k weth
    // debt: $15k usdx

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 10e3});
    collaterals[1] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 10});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 15e3});

    DataTypes.LiquidationCallLocalVars memory params = _calcParams({
      spoke: spoke1,
      collaterals: collaterals,
      collateralIndex: 0,
      debts: debts,
      debtIndex: 0
    });
    params.closeFactor = 1e18;

    uint256 closeFactorDebt = LiquidationLogic.calculateCloseFactorDebt(params);

    assertCloseFactor({
      spoke: spoke1,
      params: params,
      collaterals: collaterals,
      collateralIndex: 0,
      debts: debts,
      debtIndex: 0,
      closeFactorDebt: closeFactorDebt
    });
  }

  function assertCloseFactor(
    ISpoke spoke,
    DataTypes.LiquidationCallLocalVars memory params,
    ReserveAmount[] memory collaterals,
    uint256 collateralIndex, // index of collateral to seize
    ReserveAmount[] memory debts,
    uint256 debtIndex, // index of debt to repay,
    uint256 closeFactorDebt
  ) internal returns (DataTypes.LiquidationCallLocalVars memory) {
    uint256 closeFactor = params.closeFactor;

    uint256 debtBaseCurrencyRestored = _convertAmountToBaseCurrency(
      closeFactorDebt,
      params.debtAssetPrice,
      params.debtAssetUnit
    );

    debts[debtIndex].amount -=
      _convertBaseCurrencyToAmount(
        debtBaseCurrencyRestored,
        params.debtAssetPrice,
        params.debtAssetUnit
      ) /
      params.debtAssetUnit;
    collaterals[collateralIndex].amount -=
      _convertBaseCurrencyToAmount(
        _convertDebtToCollAmount(params, debtBaseCurrencyRestored),
        oracle.getAssetPrice(spoke1.getReserve(collaterals[collateralIndex].reserveId).assetId),
        10 ** spoke1.getReserve(collaterals[collateralIndex].reserveId).config.decimals
      ) /
      10 ** spoke1.getReserve(collaterals[collateralIndex].reserveId).config.decimals;
    params.totalDebtInBaseCurrency -= debtBaseCurrencyRestored;

    // recalculate params
    params = _calcParams(spoke, collaterals, collateralIndex, debts, debtIndex);

    uint256 healthFactor = params.totalCollateralInBaseCurrency.percentMul(
      params.avgCollateralFactor
    ) / params.totalDebtInBaseCurrency;

    assertApproxEqRel(
      healthFactor,
      closeFactor,
      _approxRelFromBps(10),
      'hf not matching close factor'
    );
  }

  function _convertDebtToCollAmount(
    DataTypes.LiquidationCallLocalVars memory params,
    uint256 debtBaseCurrencyRestored
  ) internal returns (uint256) {
    return debtBaseCurrencyRestored.percentMul(params.liquidationBonus);
  }

  // function test_calculateCloseFactorDebt_unit3() public {
  //   // coll: $18k usdx/dai
  //   // debt: $15k weth

  //   DataTypes.LiquidationCallLocalVars memory params;
  //   params.liquidationBonus = 105_00;
  //   params.collateralFactor = 75_00;
  //   params.closeFactor = 1e18;
  //   params.totalDebtInBaseCurrency = 15e3 * 1e8 * 1e18; // ie $15k dai
  //   params.totalCollateralInBaseCurrency = 18e3 * 1e8 * 1e18; // ie $18k
  //   params.debtAssetPrice = 800e8; // weth
  //   params.avgCollateralFactor = uint256(13.9e18 * 1e4).wadDiv(18e18);
  //   params.debtAssetUnit = 1e18;

  //   uint256 closeFactorDebt = LiquidationLogic.calculateCloseFactorDebt(params);

  //   assertApproxEqRel(
  //     closeFactorDebt,
  //     5176 * params.debtAssetUnit, // calculated off-chain
  //     _approxRelFromBps(10),
  //     'closeFactorDebt is incorrect'
  //   ); // 0.1%
  // }

  struct ReserveAmount {
    uint256 reserveId;
    uint256 amount; // full amount without units, ie 1 full weth
  }

  function _calcParams(
    ISpoke spoke,
    ReserveAmount[] memory collaterals,
    uint256 collateralIndex, // index of collateral to seize
    ReserveAmount[] memory debts,
    uint256 debtIndex // index of debt to repay
  ) internal returns (DataTypes.LiquidationCallLocalVars memory params) {
    uint256 totalCollateralFactor;
    uint256 totalAmount;

    for (uint256 i = 0; i < collaterals.length; i++) {
      DataTypes.Reserve memory reserve = spoke.getReserve(collaterals[i].reserveId);
      uint256 amountInBase = _convertAmountToBaseCurrency(
        collaterals[i].amount * 10 ** reserve.config.decimals,
        oracle.getAssetPrice(reserve.assetId),
        10 ** reserve.config.decimals
      );
      totalCollateralFactor += reserve.config.collateralFactor * amountInBase;
      totalAmount += amountInBase;
      if (collateralIndex == i) {
        params.liquidationBonus = reserve.config.liquidationBonus;
        params.collateralFactor = reserve.config.collateralFactor;
      }
    }
    params.avgCollateralFactor = totalCollateralFactor.wadDiv(totalAmount);
    params.totalCollateralInBaseCurrency = totalAmount;

    totalAmount = 0;
    for (uint256 i = 0; i < debts.length; i++) {
      DataTypes.Reserve memory reserve = spoke.getReserve(debts[i].reserveId);
      uint256 debtAssetUnit = 10 ** reserve.config.decimals;
      uint256 debtAssetPrice = oracle.getAssetPrice(reserve.assetId);
      uint256 amountInBase = _convertAmountToBaseCurrency(
        debts[i].amount * debtAssetUnit,
        debtAssetPrice,
        debtAssetUnit
      );
      totalAmount += amountInBase;
      if (debtIndex == i) {
        params.debtAssetUnit = debtAssetUnit;
        params.debtAssetPrice = debtAssetPrice;
      }
    }
    params.totalDebtInBaseCurrency = totalAmount;
  }

  function _approxRelFromBps(uint256 bps) internal returns (uint256) {
    return (bps * 1e18) / 100_00;
  }

  function _convertAmountToBaseCurrency(
    uint256 amount,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    return (amount * assetPrice).wadify() / assetUnit;
  }

  function _convertBaseCurrencyToAmount(
    uint256 amount,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    return (amount * assetUnit).dewadify() / assetPrice;
  }
}
