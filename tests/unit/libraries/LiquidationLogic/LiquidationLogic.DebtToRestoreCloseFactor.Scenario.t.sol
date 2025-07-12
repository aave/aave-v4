// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationLogicDebtToRestoreCloseFactorScenarioTest is LiquidationLogicBaseTest {
  using WadRayMath for uint256;
  using WadRayMathExtended for uint256;
  using PercentageMathExtended for uint256;

  struct ReserveAmount {
    uint256 reserveId;
    uint256 amount;
  }

  /// coll: $10k usdx, $8k weth
  /// debt: $15k dai
  /// liquidate usdx
  function test_calculateDebtToRestoreCloseFactor_setUp1_scenario1() public {
    _setUp1();

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 10_000 * usdxUnits});
    collaterals[1] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 10 * wethUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 15_000 * daiUnits});

    DataTypes.LiquidationCallLocalVars memory params = _calcExpectedUserAccountData({
      spoke: spoke1,
      collaterals: collaterals,
      collateralIndex: 0,
      debts: debts,
      debtIndex: 0
    });
    params.closeFactor = 1e18;
    uint256 closeFactorDebt = LiquidationLogic.calculateDebtToRestoreCloseFactor(params);

    // assert that final health factor is equal to close factor
    _assertCloseFactor({
      spoke: spoke1,
      params: params,
      collaterals: collaterals,
      collateralIndex: 0,
      debts: debts,
      debtIndex: 0,
      closeFactorDebt: closeFactorDebt
    });
  }

  /// coll: $10k dai, $8k weth
  /// debt: $15k dai
  /// liquidate da'i
  function test_calculateDebtToRestoreCloseFactor_setUp1_scenario2() public {
    _setUp1();

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 10_000 * daiUnits});
    collaterals[1] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 10 * wethUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 15_000 * usdxUnits});

    DataTypes.LiquidationCallLocalVars memory params = _calcExpectedUserAccountData({
      spoke: spoke1,
      collaterals: collaterals,
      collateralIndex: 0,
      debts: debts,
      debtIndex: 0
    });
    params.closeFactor = 1e18;

    uint256 closeFactorDebt = LiquidationLogic.calculateDebtToRestoreCloseFactor(params);

    // assert that final health factor is equal to close factor
    _assertCloseFactor({
      spoke: spoke1,
      params: params,
      collaterals: collaterals,
      collateralIndex: 0,
      debts: debts,
      debtIndex: 0,
      closeFactorDebt: closeFactorDebt
    });
  }

  // coll: $10k dai, $8k weth
  // debt: $15k usdx
  /// liquidate weth
  function test_calculateDebtToRestoreCloseFactor_setUp1_scenario3() public {
    _setUp1();

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 10_000 * daiUnits});
    collaterals[1] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 10 * wethUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 15_000 * usdxUnits});

    DataTypes.LiquidationCallLocalVars memory params = _calcExpectedUserAccountData({
      spoke: spoke1,
      collaterals: collaterals,
      collateralIndex: 1,
      debts: debts,
      debtIndex: 0
    });
    params.closeFactor = 1e18;

    uint256 closeFactorDebt = LiquidationLogic.calculateDebtToRestoreCloseFactor(params);

    // assert that final health factor is equal to close factor
    _assertCloseFactor({
      spoke: spoke1,
      params: params,
      collaterals: collaterals,
      collateralIndex: 1,
      debts: debts,
      debtIndex: 0,
      closeFactorDebt: closeFactorDebt
    });
  }

  // coll: $20k dai, $5k usdx
  // debt: $16k weth
  // liquidate dai
  function test_calculateDebtToRestoreCloseFactor_setup2_scenario1() public {
    setUpScenario2();

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 20_000 * daiUnits});
    collaterals[1] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 10_000 * usdxUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 8 * wethUnits});

    DataTypes.LiquidationCallLocalVars memory params = _calcExpectedUserAccountData({
      spoke: spoke1,
      collaterals: collaterals,
      collateralIndex: 0,
      debts: debts,
      debtIndex: 0
    });
    params.closeFactor = 1e18;
    uint256 closeFactorDebt = LiquidationLogic.calculateDebtToRestoreCloseFactor(params);

    _assertCloseFactor({
      spoke: spoke1,
      params: params,
      collaterals: collaterals,
      collateralIndex: 0,
      debts: debts,
      debtIndex: 0,
      closeFactorDebt: closeFactorDebt
    });
  }

  // coll: $10k usdx, $20k dai
  // debt: $16k weth
  // liquidate usdx
  function test_calculateDebtToRestoreCloseFactor_setup2_scenario2() public {
    setUpScenario2();

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 20_000 * daiUnits});
    collaterals[1] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 10_000 * usdxUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](1);
    debts[0] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 8 * wethUnits});

    DataTypes.LiquidationCallLocalVars memory params = _calcExpectedUserAccountData({
      spoke: spoke1,
      collaterals: collaterals,
      collateralIndex: 1,
      debts: debts,
      debtIndex: 0
    });
    params.closeFactor = 1e18;

    uint256 closeFactorDebt = LiquidationLogic.calculateDebtToRestoreCloseFactor(params);
    _assertCloseFactor({
      spoke: spoke1,
      params: params,
      collaterals: collaterals,
      collateralIndex: 1,
      debts: debts,
      debtIndex: 0,
      closeFactorDebt: closeFactorDebt
    });
  }

  // coll: $40k wbtc, $20k dai
  // debt: $10k weth, $40k usdx
  // liquidate wbtc, repay weth
  function test_calculateDebtToRestoreCloseFactor_setup3_scenario1() public {
    setUpScenario3();

    ReserveAmount[] memory collaterals = new ReserveAmount[](2);
    collaterals[0] = ReserveAmount({reserveId: _daiReserveId(spoke1), amount: 20_000 * daiUnits});
    collaterals[1] = ReserveAmount({reserveId: _wbtcReserveId(spoke1), amount: 1 * wbtcUnits});

    ReserveAmount[] memory debts = new ReserveAmount[](2);
    debts[0] = ReserveAmount({reserveId: _wethReserveId(spoke1), amount: 5 * wethUnits});
    debts[1] = ReserveAmount({reserveId: _usdxReserveId(spoke1), amount: 40_000 * usdxUnits});

    DataTypes.LiquidationCallLocalVars memory params = _calcExpectedUserAccountData({
      spoke: spoke1,
      collaterals: collaterals,
      collateralIndex: 1,
      debts: debts,
      debtIndex: 0
    });
    params.closeFactor = 1e18;

    uint256 closeFactorDebt = LiquidationLogic.calculateDebtToRestoreCloseFactor(params);

    _assertCloseFactor({
      spoke: spoke1,
      params: params,
      collaterals: collaterals,
      collateralIndex: 1,
      debts: debts,
      debtIndex: 0,
      closeFactorDebt: closeFactorDebt
    });
  }

  /// assert expected derived health factor vs close factor after liquidation
  function _assertCloseFactor(
    ISpoke spoke,
    DataTypes.LiquidationCallLocalVars memory params,
    ReserveAmount[] memory collaterals,
    uint256 collateralIndex, // index of collateral to seize
    ReserveAmount[] memory debts,
    uint256 debtIndex, // index of debt to repay
    uint256 closeFactorDebt
  ) internal view {
    uint256 closeFactor = params.closeFactor;

    // separately derive health factor to compare vs close factor
    uint256 debtBaseCurrencyRestored = _convertAmountToBaseCurrency(
      closeFactorDebt,
      params.debtAssetPrice,
      params.debtAssetUnit
    );

    IPriceOracle oracle = spoke.oracle();
    debts[debtIndex].amount -= closeFactorDebt;
    collaterals[collateralIndex].amount -=
      _convertBaseCurrencyToAmount(
        _convertDebtToCollBaseCurrency(params.liquidationBonus, debtBaseCurrencyRestored),
        oracle.getReservePrice(collaterals[collateralIndex].reserveId),
        10 ** spoke1.getReserve(collaterals[collateralIndex].reserveId).decimals
      ) +
      1; // add 1 to round up coll seized as in LiquidationLogic calculateAvailableCollateralToLiquidate

    // recalculate params assuming liquidated debt/coll
    params = _calcExpectedUserAccountData(spoke, collaterals, collateralIndex, debts, debtIndex);

    assertLe(params.healthFactor, closeFactor, 'hf must be <= close factor');
    assertApproxEqRel(
      params.healthFactor,
      closeFactor,
      _approxRelFromBps(1), // 1 BPS tolerance
      'hf not matching close factor'
    );
  }

  /// convert debt in base currency to collateral in base currency
  /// scaled by a factor of liquidation bonus
  function _convertDebtToCollBaseCurrency(
    uint256 liquidationBonus,
    uint256 debtBaseCurrencyRestored
  ) internal pure returns (uint256) {
    return debtBaseCurrencyRestored.percentMulUp(liquidationBonus);
  }

  /// test helper to derive user account data during *liquidations only*
  /// note: this helper is statically used to predict user account data, without
  // actual user operations and positions, hence we use the latest spoke dynamic
  // reserve configuration
  function _calcExpectedUserAccountData(
    ISpoke spoke,
    ReserveAmount[] memory collaterals,
    uint256 collateralIndex, // index of collateral to seize
    ReserveAmount[] memory debts,
    uint256 debtIndex // index of debt to repay
  ) internal view returns (DataTypes.LiquidationCallLocalVars memory params) {
    uint256 totalCollateralFactor;
    uint256 totalAmount;
    IPriceOracle oracle = spoke.oracle();

    for (uint256 i = 0; i < collaterals.length; i++) {
      DataTypes.Reserve memory reserve = spoke.getReserve(collaterals[i].reserveId);
      DataTypes.DynamicReserveConfig memory dynConfig = spoke.getDynamicReserveConfig(
        collaterals[i].reserveId,
        reserve.dynamicConfigKey
      );
      uint256 amountInBase = _convertAmountToBaseCurrency(
        collaterals[i].amount,
        oracle.getReservePrice(reserve.reserveId),
        10 ** reserve.decimals
      );
      totalCollateralFactor += dynConfig.collateralFactor * amountInBase;
      totalAmount += amountInBase;
      if (collateralIndex == i) {
        params.liquidationBonus = dynConfig.liquidationBonus;
        params.collateralFactor = dynConfig.collateralFactor;
      }
    }
    params.totalCollateralInBaseCurrency = totalAmount;

    totalAmount = 0;
    for (uint256 i = 0; i < debts.length; i++) {
      DataTypes.Reserve memory reserve = spoke.getReserve(debts[i].reserveId);
      uint256 debtAssetUnit = 10 ** reserve.decimals;
      uint256 debtAssetPrice = oracle.getReservePrice(reserve.reserveId);
      uint256 amountInBase = _convertAmountToBaseCurrency(
        debts[i].amount,
        debtAssetPrice,
        debtAssetUnit
      );
      totalAmount += amountInBase;
      if (debtIndex == i) {
        params.debtAssetUnit = debtAssetUnit;
        params.debtAssetPrice = debtAssetPrice;
        params.totalDebt += debts[i].amount;
      }
    }
    params.totalDebtInBaseCurrency = totalAmount;
    params.healthFactor = totalCollateralFactor.wadDiv(params.totalDebtInBaseCurrency).fromBps();
  }

  /// set up collateral factors and liquidation bonuses with price drop for weth collateral
  function _setUp1() internal {
    updateCollateralFactor(spoke1, _daiReserveId(spoke1), 75_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 80_00);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 70_00);

    // weth price drops to $800
    _mockReservePrice(spoke1, _wethReserveId(spoke1), 800e8); // $800

    updateLiquidationBonus(spoke1, _daiReserveId(spoke1), 105_00);
    updateLiquidationBonus(spoke1, _wethReserveId(spoke1), 103_00);
    updateLiquidationBonus(spoke1, _usdxReserveId(spoke1), 104_00);
  }

  /// set up collateral factors and liquidation bonuses with price drop for dai collateral
  function setUpScenario2() internal {
    updateCollateralFactor(spoke1, _daiReserveId(spoke1), 85_00);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 74_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 78_00);

    // dai price drops to $0.5
    _mockReservePrice(spoke1, _daiReserveId(spoke1), 0.5e8);

    updateLiquidationBonus(spoke1, _daiReserveId(spoke1), 104_00);
    updateLiquidationBonus(spoke1, _wethReserveId(spoke1), 106_00);
    updateLiquidationBonus(spoke1, _usdxReserveId(spoke1), 108_00);
  }

  /// set up collateral factors and liquidation bonuses with price drop for wbtc collateral
  function setUpScenario3() internal {
    updateCollateralFactor(spoke1, _wbtcReserveId(spoke1), 85_00);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 80_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 95_00);
    updateCollateralFactor(spoke1, _daiReserveId(spoke1), 78_00);

    // wbtc price drops to $40k
    _mockReservePrice(spoke1, _wbtcReserveId(spoke1), 40_000e8);

    updateLiquidationBonus(spoke1, _daiReserveId(spoke1), 108_00);
    updateLiquidationBonus(spoke1, _wethReserveId(spoke1), 105_00);
    updateLiquidationBonus(spoke1, _usdxReserveId(spoke1), 110_00);
    updateLiquidationBonus(spoke1, _wbtcReserveId(spoke1), 110_00);
  }
}
