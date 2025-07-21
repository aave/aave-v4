// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

/// tests where liquidation results in bad debt (debt remaining > 0, collateral remaining = 0)
contract LiquidationCallBadDebtTest is SpokeLiquidationBase {
  using PercentageMathExtended for uint256;

  /// coll: weth / debt: dai
  function test_liquidationCall_badDebt_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCall_fuzz_badDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
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
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
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
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
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
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
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
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
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
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
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
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
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
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
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
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
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
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
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
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
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
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      desiredHf: 0.5e18
    });
  }

  /// variable close factor > HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  function test_liquidationCall_fuzz_badDebt(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationFee,
    uint256 skipTime,
    uint256 desiredHf
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.getReserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.getReserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorBadDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationFee,
      skipTime,
      desiredHf
    );

    string memory label = 'test_liquidationCall_fuzz_badDebt';
    _checkLiquidation(state, label);
  }

  /// fuzz tests with close factor == HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  function test_liquidationCall_fuzz_badDebt_defaultCloseFactor(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationFee,
    uint256 skipTime,
    uint256 desiredHf
  ) public {
    liqConfig.closeFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    test_liquidationCall_fuzz_badDebt(
      collateralReserveId,
      debtReserveId,
      liqConfig,
      liqBonus,
      supplyAmount,
      liquidationFee,
      skipTime,
      desiredHf
    );
  }

  /// execute fuzz tests to ensure bad debt remains post-liquidation
  /// single debt reserve, single collateral reserve
  /// liquidating all collateral is insufficient to cover debt
  function _execLiqCallCloseFactorBadDebtTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationFee,
    uint256 skipTime,
    uint256 desiredHf
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](1);
    state.debtReserves = new DataTypes.Reserve[](1);
    state.user = alice;
    state.spoke = spoke1;

    state.collateralReserves[state.collateralReserveIndex] = state.spoke.getReserve(
      collateralReserveId
    );
    state.debtReserves[state.debtReserveIndex] = state.spoke.getReserve(debtReserveId);
    state.collateralReserve = state.collateralReserves[state.collateralReserveIndex];
    state.debtReserve = state.debtReserves[state.debtReserveIndex];
    state.collDynConfig = _getUserDynConfig(state.spoke, state.user, collateralReserveId);

    // bound close factor, with a static liq bonus
    liqConfig = _boundCloseFactor(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMathExtended.PERCENTAGE_FACTOR.percentDivDown(state.collDynConfig.collateralFactor)
    );

    liquidationFee = bound(liquidationFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.spoke, state.collateralReserve.reserveId, 1e25),
      _min(
        _convertBaseCurrencyToAmount(
          state.spoke,
          state.collateralReserve.reserveId,
          MAX_SUPPLY_IN_BASE_CURRENCY
        ),
        MAX_SUPPLY_AMOUNT / 10
      )
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    state.liquidationFee = liquidationFee;

    // set spoke liq config
    updateLiquidationConfig(state.spoke, liqConfig);
    updateLiquidationBonus(state.spoke, collateralReserveId, liqBonus);
    updateLiquidationFee(state.spoke, collateralReserveId, state.liquidationFee);

    Utils.supplyCollateral({
      spoke: state.spoke,
      reserveId: collateralReserveId,
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    // set user position under hf threshold so that there is invalid collateral to cover all debt
    desiredHf = bound(desiredHf, 0.1e18, _calcLowestHfForBadDebt(state.spoke, alice, liqBonus));
    _borrowWithoutHfCheck({
      spoke: spoke1,
      user: bob,
      reserveId: collateralReserveId,
      debtAmount: supplyAmount / 2
    });
    skip(skipTime);

    vm.assume(
      _getRequiredDebtAmountForLtHf(spoke1, alice, debtReserveId, desiredHf) <= MAX_SUPPLY_AMOUNT
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
      alice,
      hfAfterBorrow
    );

    state = _getAccountingInfoBeforeLiquidation(state);
    (
      state.collToLiq,
      state.debtToLiq,
      state.liquidationFeeAmount,

    ) = _calculateAvailableCollateralToLiquidate(state, UINT256_MAX);

    uint256 debtAssetId = state.debtReserve.assetId;
    (uint256 basedDebtRestored, uint256 premDebtRestored) = _calculateExactRestoreAmount(
      state.userBaseDebt.balanceBefore,
      state.userPremiumDebt.balanceBefore,
      state.debtToLiq,
      debtAssetId
    );

    // debt asset deficit shares are the initial amount minus the amount restored during liquidation
    uint256 expectedShares = state.spoke.getUserPosition(debtReserveId, alice).baseDrawnShares -
      hub.convertToDrawnShares(debtAssetId, basedDebtRestored);
    // total debt asset deficit is the expected base debt and remaining premium debt after settlement during liquidation
    uint256 expectedDeficit = hub.convertToDrawnAssets(debtAssetId, expectedShares) +
      state.userPremiumDebt.balanceBefore -
      premDebtRestored;

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitCreated(
      debtAssetId,
      address(state.spoke),
      expectedShares,
      expectedDeficit
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.Restore(debtAssetId, address(state.spoke), expectedShares, expectedDeficit);

    vm.expectEmit(address(state.spoke));
    emit ISpoke.LiquidationCall(
      state.collateralReserve.underlying,
      state.debtReserve.underlying,
      alice,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCall(collateralReserveId, debtReserveId, alice, UINT256_MAX);

    state = _getAccountingInfoAfterLiquidation(state);

    return state;
  }
}
