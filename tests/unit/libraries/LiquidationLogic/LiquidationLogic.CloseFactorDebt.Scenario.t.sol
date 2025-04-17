// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicCloseFactorDebtScenarioTest is LiquidationLogicBaseTest {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using WadRayMathExtended for uint256;

  uint256 daiUnits = 1e18;
  uint256 usdxUnits = 1e6;
  uint256 wethUnits = 1e18;
  uint256 wbtcUnits = 1e8;

  function setUpScenario1() internal {
    updateCollateralFactor(spoke1, _daiReserveId(spoke1), 75_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 80_00);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 70_00);

    // weth price drops to $800
    oracle.setAssetPrice(wethAssetId, 800e8); // $800

    updateLiquidationBonus(spoke1, _daiReserveId(spoke1), 105_00);
    updateLiquidationBonus(spoke1, _wethReserveId(spoke1), 103_00);
    updateLiquidationBonus(spoke1, _usdxReserveId(spoke1), 104_00);
  }

  // TODO: scenario 1 with bigger CF
  // TODO: secnario 2 with bigger CF

  function test_calculateCloseFactorDebt_scenario1_unit1() public {
    // coll: $10k usdx, $8k weth
    // debt: $15k dai
    // liquidate usdx

    setUpScenario1();

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 10_000 * usdxUnits});
    collaterals[1] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 10 * wethUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 15_000 * daiUnits});

    (DataTypes.LiquidationCallLocalVars memory params, ) = _calcParams({
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

  function test_calculateCloseFactorDebt_scenario1_unit2() public {
    setUpScenario1();

    // coll: $10k dai, $8k weth
    // debt: $15k usdx

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 10_000 * daiUnits});
    collaterals[1] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 10 * wethUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 15_000 * usdxUnits});

    (DataTypes.LiquidationCallLocalVars memory params, ) = _calcParams({
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

  function test_calculateCloseFactorDebt_scenario1_unit3() public {
    setUpScenario1();

    // coll: $10k dai, $8k weth
    // debt: $15k usdx

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 10_000 * daiUnits});
    collaterals[1] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 10 * wethUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 15_000 * usdxUnits});

    (DataTypes.LiquidationCallLocalVars memory params, ) = _calcParams({
      spoke: spoke1,
      collaterals: collaterals,
      collateralIndex: 1,
      debts: debts,
      debtIndex: 0
    });
    params.closeFactor = 1e18;

    uint256 closeFactorDebt = LiquidationLogic.calculateCloseFactorDebt(params);

    assertCloseFactor({
      spoke: spoke1,
      params: params,
      collaterals: collaterals,
      collateralIndex: 1,
      debts: debts,
      debtIndex: 0,
      closeFactorDebt: closeFactorDebt
    });
  }

  function setUpScenario2() internal {
    updateCollateralFactor(spoke1, _daiReserveId(spoke1), 85_00);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 74_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 78_00);

    // dai price drops to $0.5
    oracle.setAssetPrice(daiAssetId, 0.5e8);

    updateLiquidationBonus(spoke1, _daiReserveId(spoke1), 104_00);
    updateLiquidationBonus(spoke1, _wethReserveId(spoke1), 106_00);
    updateLiquidationBonus(spoke1, _usdxReserveId(spoke1), 108_00);
  }

  function test_calculateCloseFactorDebt_scenario2_unit1() public {
    // coll: $10k usdx, $20k dai
    // debt: $16k weth
    // liquidate usdx

    setUpScenario2();

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 20_000 * daiUnits});
    collaterals[1] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 10_000 * usdxUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 8 * wethUnits});

    (DataTypes.LiquidationCallLocalVars memory params, ) = _calcParams({
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

  function test_calculateCloseFactorDebt_scenario2_unit2() public {
    // coll: $10k usdx, $10k dai
    // debt: $16k weth
    // liquidate usdx

    setUpScenario2();

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 20_000 * daiUnits});
    collaterals[1] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 10_000 * usdxUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 8 * wethUnits});

    (DataTypes.LiquidationCallLocalVars memory params, ) = _calcParams({
      spoke: spoke1,
      collaterals: collaterals,
      collateralIndex: 1,
      debts: debts,
      debtIndex: 0
    });
    params.closeFactor = 1e18;

    uint256 closeFactorDebt = LiquidationLogic.calculateCloseFactorDebt(params);
    // console.log('closeFactorDebt %e', closeFactorDebt);
    assertCloseFactor({
      spoke: spoke1,
      params: params,
      collaterals: collaterals,
      collateralIndex: 1,
      debts: debts,
      debtIndex: 0,
      closeFactorDebt: closeFactorDebt
    });
  }

  function setUpScenario3() internal {
    updateCollateralFactor(spoke1, _wbtcReserveId(spoke1), 85_00);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 80_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 95_00);
    updateCollateralFactor(spoke1, _daiReserveId(spoke1), 78_00);

    // wbtc price drops to $40k
    oracle.setAssetPrice(wbtcAssetId, 40_000e8);

    updateLiquidationBonus(spoke1, _daiReserveId(spoke1), 108_00);
    updateLiquidationBonus(spoke1, _wethReserveId(spoke1), 109_00);
    updateLiquidationBonus(spoke1, _usdxReserveId(spoke1), 110_00);
    updateLiquidationBonus(spoke1, _wbtcReserveId(spoke1), 110_00);
  }

  function test_calculateCloseFactorDebt_scenario3_unit1() public {
    // coll: $50k wbtc, $20k dai
    // debt: $30k weth, $40k usdx
    // repay weth, liquidate wbtc

    setUpScenario3();

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 20_000 * daiUnits});
    collaterals[1] = ReserveAmount({reserveId: _wbtcReserveId(spoke1), amount: 1 * wbtcUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](2);
    debts[0] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 5 * wethUnits});
    debts[1] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 40_000 * usdxUnits});

    (DataTypes.LiquidationCallLocalVars memory params, ) = _calcParams({
      spoke: spoke1,
      collaterals: collaterals,
      collateralIndex: 1,
      debts: debts,
      debtIndex: 0
    });
    params.closeFactor = 1e18;

    // console.log(
    //   'initial hf %e',
    //   params.totalCollateralInBaseCurrency.percentMul(params.avgCollateralFactor) /
    //     params.totalDebtInBaseCurrency
    // );

    uint256 closeFactorDebt = LiquidationLogic.calculateCloseFactorDebt(params);

    assertCloseFactor({
      spoke: spoke1,
      params: params,
      collaterals: collaterals,
      collateralIndex: 1,
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

    // console.log('%e %e', closeFactorDebt, debts[debtIndex].amount);

    debts[debtIndex].amount -= closeFactorDebt;
    collaterals[collateralIndex].amount -= _convertBaseCurrencyToAmount(
      _convertDebtToCollAmount(params, debtBaseCurrencyRestored),
      oracle.getAssetPrice(spoke1.getReserve(collaterals[collateralIndex].reserveId).assetId),
      10 ** spoke1.getReserve(collaterals[collateralIndex].reserveId).config.decimals
    );

    uint256 derivedHealthFactor;
    // recalculate params
    (params, derivedHealthFactor) = _calcParams(
      spoke,
      collaterals,
      collateralIndex,
      debts,
      debtIndex
    );

    // uint256 derivedHealthFactor = params.totalCollateralInBaseCurrency.percentMul(
    //   params.avgCollateralFactor
    // ) / params.totalDebtInBaseCurrency;

    console.log('coll amount %e', collaterals[collateralIndex].amount);
    console.log('debt amount %e', debts[debtIndex].amount);
    console.log('avgCollateralFactor %e', params.avgCollateralFactor);
    console.log('final hf %e', derivedHealthFactor);

    assertApproxEqRel(
      derivedHealthFactor,
      closeFactor,
      _approxRelFromBps(1_00), // 1% tolerance
      'hf not matching close factor'
    );
    assertGe(derivedHealthFactor, closeFactor, 'hf must be >= close factor');
  }

  function _convertDebtToCollAmount(
    DataTypes.LiquidationCallLocalVars memory params,
    uint256 debtBaseCurrencyRestored
  ) internal returns (uint256) {
    return debtBaseCurrencyRestored.percentMul(params.liquidationBonus);
  }

  struct ReserveAmount {
    uint256 reserveId;
    uint256 amount;
  }

  function _calcParams(
    ISpoke spoke,
    ReserveAmount[] memory collaterals,
    uint256 collateralIndex, // index of collateral to seize
    ReserveAmount[] memory debts,
    uint256 debtIndex // index of debt to repay
  ) internal returns (DataTypes.LiquidationCallLocalVars memory params, uint256 healthFactor) {
    uint256 totalCollateralFactor;
    uint256 totalAmount;

    for (uint256 i = 0; i < collaterals.length; i++) {
      DataTypes.Reserve memory reserve = spoke.getReserve(collaterals[i].reserveId);
      uint256 amountInBase = _convertAmountToBaseCurrency(
        collaterals[i].amount,
        oracle.getAssetPrice(reserve.assetId),
        10 ** reserve.config.decimals
      );
      totalCollateralFactor += reserve.config.collateralFactor * amountInBase;
      totalAmount += amountInBase;
      console.log(
        'amount: %e, price: %e, units: %e',
        collaterals[i].amount,
        oracle.getAssetPrice(reserve.assetId),
        10 ** reserve.config.decimals
      );
      if (collateralIndex == i) {
        params.liquidationBonus = reserve.config.liquidationBonus;
        params.collateralFactor = reserve.config.collateralFactor;
      }
    }
    params.avgCollateralFactor = totalCollateralFactor.wadDiv(totalAmount);
    params.totalCollateralInBaseCurrency = totalAmount;

    console.log('avgCF %e', params.avgCollateralFactor);
    console.log('totalColl %e', params.totalCollateralInBaseCurrency);

    totalAmount = 0;
    for (uint256 i = 0; i < debts.length; i++) {
      DataTypes.Reserve memory reserve = spoke.getReserve(debts[i].reserveId);
      uint256 debtAssetUnit = 10 ** reserve.config.decimals;
      uint256 debtAssetPrice = oracle.getAssetPrice(reserve.assetId);
      uint256 amountInBase = _convertAmountToBaseCurrency(
        debts[i].amount,
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

    healthFactor = totalCollateralFactor.wadDiv(params.totalDebtInBaseCurrency).fromBps();
    console.log('calc healthFactor %e', healthFactor);
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
    return ((amount * assetUnit) / assetPrice).dewadify();
  }
}
