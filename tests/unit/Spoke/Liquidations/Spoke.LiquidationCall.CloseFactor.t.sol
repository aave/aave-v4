// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallCloseFactorTest is SpokeLiquidationBase {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  /// fuzz tests with close factor == HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  /// single debt reserve, single collateral reserve
  /// user health factor position is higher than threshold, so that close factor can be achieved post-liquidation
  /// close factor varies across range of values
  /// non-variable liquidation bonus
  function test_liquidationCall_fuzz_closeFactor_defaultCloseFactor(
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
    test_liquidationCall_fuzz_closeFactor(
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

  /// variable close factor > HEALTH_FACTOR_LIQUIDATION_THRESHOLD
  function test_liquidationCall_fuzz_closeFactor(
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

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationFee,
      skipTime,
      desiredHf
    );

    _checkLiquidation(state, 'test_liquidationCall_fuzz_closeFactor');
    assertFalse(state.hasDeficit, 'should not have deficit');
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_closeFactor_scenario1() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 2e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: weth / debt: dai with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario1() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_closeFactor_scenario2() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: weth / debt: usdx with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario2() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_closeFactor_scenario3() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: usdx / debt: weth with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario3() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      liquidationFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_closeFactor_scenario4() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: usdx / debt: dai with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario4() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_closeFactor_scenario5() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: dai / debt: weth with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario5() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_closeFactor_scenario6() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: dai / debt: usdx with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario6() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationFee: 5_00,
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: weth / debt: weth, both 18 decimals
  function test_liquidationCall_closeFactor_scenario7() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e18,
      liquidationFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: dai / debt: weth, both 18 decimals, with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario7() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e18,
      liquidationFee: 5_00,
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: usdx / debt: usdx, both 6 decimals
  function test_liquidationCall_closeFactor_scenario8() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e18,
      liquidationFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// coll: usdx / debt: usdx, both 18 decimals, with default value of close factor
  function test_liquidationCall_closeFactor_defaultValue_scenario8() public {
    test_liquidationCall_fuzz_closeFactor({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e18,
      liquidationFee: 5_00,
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      skipTime: 365 days,
      desiredHf: 0.95e18
    });
  }

  /// fuzz tests for supply ex rate increase
  /// can only increase by 1 wei due to rounding in withdraw
  function test_liquidationCall_fuzz_closeFactor_supply_ex_rate_incr(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 supplyAmount,
    uint256 skipTime,
    uint256 liqBonus,
    uint256 desiredHf
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.getReserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.getReserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTest({
      liqConfig: liqConfig,
      liqBonus: liqBonus,
      supplyAmount: supplyAmount,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liquidationFee: 0,
      skipTime: skipTime,
      desiredHf: desiredHf
    });

    // supply rate can be greater than previous due to rounding on hub remove, only by 1 wei
    assertGe(state.rate.rateAfter, state.rate.rateBefore, 'supply rate');
    assertApproxEqAbs(state.rate.rateAfter, state.rate.rateBefore, 1, 'supply rate precision');
  }

  /// fuzz tests where liquidation results in health factor = close factor
  function _execLiqCallCloseFactorTest(
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
    state.spoke = spoke1;
    state.user = alice;
    state.collDynConfig = _getUserDynConfig(state.spoke, state.user, collateralReserveId);

    state.collateralReserves[state.collateralReserveIndex] = state.spoke.getReserve(
      collateralReserveId
    );
    state.debtReserves[state.debtReserveIndex] = state.spoke.getReserve(debtReserveId);
    state.collateralReserve = state.collateralReserves[state.collateralReserveIndex];
    state.debtReserve = state.debtReserves[state.debtReserveIndex];

    liqConfig = _boundCloseFactor(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath
        .PERCENTAGE_FACTOR
        .percentDivDown(state.collDynConfig.collateralFactor)
        .percentMulDown(99_00) // add buffer so that amount to restore is > 0
    );

    liquidationFee = bound(liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.spoke, state.collateralReserve.reserveId, 1e26),
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

    updateLiquidationConfig(state.spoke, liqConfig);
    updateLiquidationBonus(state.spoke, collateralReserveId, liqBonus);
    updateLiquidationFee(state.spoke, collateralReserveId, state.liquidationFee);

    Utils.supplyCollateral({
      spoke: state.spoke,
      reserveId: collateralReserveId,
      caller: state.user,
      amount: supplyAmount,
      onBehalfOf: state.user
    });

    uint256 hfBadDebtThreshold = _calcLowestHfForBadDebt(state.spoke, state.user, liqBonus)
      .percentMulUp(101_00); // add buffer so that not all collateral is seized

    // desiredHF is within range of a liquidation that does not result in bad debt
    desiredHf = bound(
      desiredHf,
      _min(hfBadDebtThreshold, HEALTH_FACTOR_LIQUIDATION_THRESHOLD),
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    _borrowWithoutHfCheck({
      spoke: spoke1,
      user: bob,
      reserveId: collateralReserveId,
      debtAmount: supplyAmount / 2
    });
    skip(skipTime);

    vm.assume(
      _getRequiredDebtAmountForLtHf(spoke1, state.user, debtReserveId, desiredHf) <=
        MAX_SUPPLY_AMOUNT
    );
    // borrow some amount of debt reserve to end up below hf threshold
    (uint256 hfAfterBorrow, ) = _borrowToBeBelowHf(state.spoke, alice, debtReserveId, desiredHf);
    state.liquidationBonus = state.spoke.getVariableLiquidationBonus(
      collateralReserveId,
      state.user,
      hfAfterBorrow
    );
    state = _getAccountingInfoBeforeLiquidation(state);

    uint16 configKeyBefore = spoke1.getUserPosition(collateralReserveId, state.user).configKey;
    (
      state.collToLiq,
      state.debtToLiq,
      state.liquidationFeeAmount,

    ) = _calculateAvailableCollateralToLiquidate(state, UINT256_MAX);

    state.liquidationFeeShares =
      hub1.previewRemoveByAssets(
        state.collateralReserve.assetId,
        state.collToLiq + state.liquidationFeeAmount
      ) -
      hub1.previewRemoveByAssets(state.collateralReserve.assetId, state.collToLiq);

    if (collateralReserveId != debtReserveId) {
      vm.expectCall(
        address(hub1),
        abi.encodeWithSelector(
          hub1.payFee.selector,
          state.collateralReserve.assetId,
          state.liquidationFeeShares
        ),
        state.liquidationFeeShares > 0 ? 1 : 0
      );
    } else {
      // precision loss can occur when coll and debt reserve are the same
      // during a restore action that includes donation
      vm.expectCall(
        address(hub1),
        abi.encodeWithSelector(IHub.payFee.selector),
        state.liquidationFeeShares > 0 ? 1 : 0
      );
    }

    vm.expectEmit(address(state.spoke));
    emit ISpokeBase.LiquidationCall(
      state.collateralReserve.underlying,
      state.debtReserve.underlying,
      state.user,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCall(collateralReserveId, debtReserveId, state.user, UINT256_MAX);

    state = _getAccountingInfoAfterLiquidation(state);

    assertEq(
      spoke1.getUserPosition(collateralReserveId, state.user).configKey,
      configKeyBefore,
      'User dynamic config key changed after liquidation'
    );
    return state;
  }
}
