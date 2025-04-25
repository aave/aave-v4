// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallCloseFactorTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  /// fuzz tests with close factor == HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  function test_liquidationCall_fuzz_closeFactor_defaultCloseFactor(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_closeFactor(
      collateralReserveId,
      debtReserveId,
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationProtocolFeePercentage
    );
  }

  /// variable close factor > HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  function test_liquidationCall_fuzz_closeFactor(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.reserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    string memory label = 'test_liquidationCall_fuzz_closeFactor';
    _assertUserAccountData(state, spoke1, label);
    _assertProtocolFeeEarned(state, label);
    _assertLiquidationBonusEarned(state, label);
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_closeFactor_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 2e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: weth / debt: dai with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_closeFactor_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: weth / debt: usdx with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_closeFactor_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: usdx / debt: weth with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_closeFactor_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: usdx / debt: dai with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_closeFactor_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: dai / debt: weth with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_closeFactor_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// coll: dai / debt: usdx with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId
    });
  }

  /// constant liquidation bonus to simplify calcs for desiredHf
  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual override returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      MIN_CLOSE_FACTOR,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 10
    );

    // set config to 0 so that desiredHf can be easily calculated (dependent on LB)
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorBonusThreshold = 0;

    return liqConfig;
  }

  /// fuzz tests with
  function _execLiqCallCloseFactorTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFeePercentage
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.debtReserve = spoke1.getReserve(debtReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath
        .PERCENTAGE_FACTOR
        .percentDiv(state.collateralReserve.config.collateralFactor)
        .percentMul(90_00) // add buffer so that position is liquidatable
    );

    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, 1e25),
      MAX_SUPPLY_AMOUNT / 1e4
    );

    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    spoke1.updateLiquidationConfig(liqConfig);
    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      spoke1,
      collateralReserveId,
      state.liquidationProtocolFeePercentage
    );
    uint256 desiredHf = _calcMaxAchievableHfToRestoreCloseFactor(collateralReserveId, liqBonus)
      .percentMul(101_00); // add buffer so that not all collateral is seized

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    // borrow enough to be below desiredHf
    (uint256 hfAfterBorrow, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      debtReserveId,
      desiredHf
    );

    state.liquidationBonus = _getVariableLiquidationBonus(
      spoke1,
      collateralReserveId,
      hfAfterBorrow
    );

    state.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.liquidator.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.treasury.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);
    state.supply.balanceBefore = spoke1.getUserSuppliedAmount(collateralReserveId, alice);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    state.liquidator.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.treasury.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);
    state.supply.balanceAfter = spoke1.getUserSuppliedAmount(collateralReserveId, alice);

    // convert
    state.liquidator.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      _absDiff(state.liquidator.balanceAfter, state.liquidator.balanceBefore)
    );
    state.treasury.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      _absDiff(state.treasury.balanceAfter, state.treasury.balanceBefore)
    );
    state.debt.baseChange = _convertAmountToBaseCurrency(
      state.debtReserve.assetId,
      _absDiff(state.debt.balanceBefore, state.debt.balanceAfter)
    );
    state.supply.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      _absDiff(state.supply.balanceBefore, state.supply.balanceAfter)
    );

    // with close factor, it is impossible to liquidate all debt
    assertTrue(_absDiff(state.debt.balanceAfter, state.debt.balanceBefore) < requiredDebtAmount);

    return state;
  }
}
