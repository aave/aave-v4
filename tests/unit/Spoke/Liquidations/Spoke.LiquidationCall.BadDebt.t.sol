// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

/// tests where liquidation results in bad debt (debt > 0, collateral = 0)
/// TODO: realize bad debt into deficit when deficit accounting is implemented, resolve tests
contract LiquidationCallBadDebtTest is SpokeLiquidationBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  /// variable close factor > HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  function test_liquidationCall_fuzz_badDebt(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage,
    uint256 skipTime
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.reserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorBadDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage,
      skipTime
    );

    string memory label = 'test_liquidationCall_fuzz_badDebt';
    _checkLiquidation(state, spoke1, label);
  }

  /// fuzz tests with close factor == HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  function test_liquidationCall_fuzz_badDebt_defaultCloseFactor(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage,
    uint256 skipTime
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_badDebt(
      collateralReserveId,
      debtReserveId,
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationProtocolFeePercentage,
      skipTime
    );
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_badDebt_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: dai with default value of close factor
  function test_liquidationCall_badDebt_defaultValue_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_badDebt_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: usdx with default value of close factor
  function test_liquidationCall_badDebt_defaultValue_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_badDebt_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: weth with default value of close factor
  function test_liquidationCall_badDebt_defaultValue_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_badDebt_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: dai with default value of close factor
  function test_liquidationCall_badDebt_defaultValue_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_badDebt_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);
    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: weth with default value of close factor
  function test_liquidationCall_badDebt_defaultValue_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);
    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_badDebt_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);
    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: usdx with default value of close factor
  function test_liquidationCall_badDebt_defaultValue_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);
    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  /// bound liqConfig close factor, with static liquidation bonus
  /// use constant liquidation bonus to simplify calcs for desiredHf
  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual override returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      MIN_CLOSE_FACTOR,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 10
    );

    // set constant liquidation bonus to simplify calcs for desiredHf
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorBonusThreshold = 0;

    return liqConfig;
  }

  /// fuzz tests to make sure bad debt remains after liquidation
  /// single debt reserve, single collateral reserve
  /// user health factor position is lower than threshold -> liquidating all collateral is insufficient to cover debt
  /// close factor varies across range of values
  /// constant liquidation bonus
  function _execLiqCallCloseFactorBadDebtTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFeePercentage,
    uint256 skipTime
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.debtReserve = spoke1.getReserve(debtReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath.PERCENTAGE_FACTOR.percentDiv(state.collateralReserve.config.collateralFactor)
    );
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, 1e25),
      _min(
        _convertBaseCurrencyToAmount(state.collateralReserve.assetId, MAX_SUPPLY_IN_BASE_CURRENCY),
        MAX_SUPPLY_AMOUNT
      )
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    state.spoke = spoke1;
    state.user = alice;
    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    // set spoke liq config
    state.spoke.updateLiquidationConfig(liqConfig);
    updateLiquidationBonus(state.spoke, collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      state.spoke,
      collateralReserveId,
      state.liquidationProtocolFeePercentage
    );

    Utils.supplyCollateral({
      spoke: state.spoke,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    // set user position under hf threshold so that there is invalid collateral to cover all debt
    // results in bad debt remaining (debt > 0, collateral = 0)
    uint256 desiredHf = _calcLowestHfToRestoreCloseFactor(state.spoke, alice, liqBonus).percentMul(
      99_00
    );

    _increaseCollateralReserveSupplyExchangeRate(
      state.spoke,
      state.collateralReserve.assetId,
      collateralReserveId,
      supplyAmount / 2,
      skipTime,
      bob
    );

    // borrow some amount of debt reserve to end up below hf threshold
    (uint256 hfAfterBorrow, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      state.spoke,
      alice,
      debtReserveId,
      desiredHf
    );

    state.liquidationBonus = _getVariableLiquidationBonus(
      state.spoke,
      collateralReserveId,
      hfAfterBorrow
    );

    state = _getAccountingInfoBeforeLiq(state);
    (
      state.collToLiq,
      state.debtToLiq,
      state.liqProtocolFee,

    ) = _calculateAvailableCollateralToLiquidate(state.spoke, state, requiredDebtAmount);

    // logs to read protocol fee from tmp emitted event
    // TODO: update when treasury accounting is done
    vm.recordLogs();

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitCreated(
      address(state.spoke),
      state.debtReserve.assetId,
      state.debt.balanceBefore - state.debtToLiq // outstanding debt which becomes bad debt reported as deficit
    );
    vm.expectEmit(address(state.spoke));
    emit ISpoke.LiquidationCall(
      state.collateralReserve.asset,
      state.debtReserve.asset,
      alice,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    state = _getAccountingInfoAfterLiq(state);

    return state;
  }
}
