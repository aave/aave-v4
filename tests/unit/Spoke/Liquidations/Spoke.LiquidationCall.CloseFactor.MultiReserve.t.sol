// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallCloseFactorMultiReserveTest is SpokeLiquidationBase {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using SafeCast for uint256;

  uint256 internal dustInBase = 10e26; // $10 in base currency

  /// weth/usdx collateral
  /// dai/usdx debt
  /// liquidate weth, repay usdx
  function test_liquidationCall_closeFactor_multi_reserve_scenario1() public {
    uint256[] memory collateralReserveIds = new uint256[](2);
    uint256[] memory debtReserveIds = new uint256[](2);

    collateralReserveIds[0] = _wethReserveId(spoke1);
    collateralReserveIds[1] = _usdxReserveId(spoke1);

    debtReserveIds[0] = _daiReserveId(spoke1);
    debtReserveIds[1] = _usdxReserveId(spoke1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTestMulti({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmountInBase: 10_000e26,
      liquidationFee: 5_00,
      collateralReserveIds: collateralReserveIds,
      debtReserveIds: debtReserveIds,
      collateralReserveIndex: 0,
      debtReserveIndex: 1,
      skipTime: 365 days,
      desiredHf: 0.95e18
    });

    if (!state.hasDustFromAvailableCollateral) {
      _checkLiquidation(state, 'test_liquidationCall_closeFactor_multi_reserve_scenario1');
      assertFalse(state.hasDeficit, 'should not have deficit');
    }
  }

  /// wbtc/weth collateral
  /// usdx/usdy debt
  /// liquidate weth, repay usdx
  function test_liquidationCall_closeFactor_multi_reserve_scenario2() public {
    uint256[] memory collateralReserveIds = new uint256[](2);
    uint256[] memory debtReserveIds = new uint256[](2);

    collateralReserveIds[0] = _wethReserveId(spoke1);
    collateralReserveIds[1] = _wbtcReserveId(spoke1);

    debtReserveIds[0] = _usdyReserveId(spoke1);
    debtReserveIds[1] = _usdxReserveId(spoke1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTestMulti({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmountInBase: 10_000e26,
      liquidationFee: 5_00,
      collateralReserveIds: collateralReserveIds,
      debtReserveIds: debtReserveIds,
      collateralReserveIndex: 0,
      debtReserveIndex: 1,
      skipTime: 365 days,
      desiredHf: 0.95e18
    });

    // if dust remains after accounting for available collateral, tx will have reverted
    if (!state.hasDustFromAvailableCollateral) {
      _checkLiquidation(state, 'test_liquidationCall_closeFactor_multi_reserve_scenario2');
      assertFalse(state.hasDeficit, 'should not have deficit');
    }
  }

  /// dai/usdy collateral
  /// usdx/wbtc debt
  /// liquidate dai, repay wbtc
  function test_liquidationCall_closeFactor_multi_reserve_scenario3() public {
    uint256[] memory collateralReserveIds = new uint256[](2);
    uint256[] memory debtReserveIds = new uint256[](2);

    collateralReserveIds[0] = _daiReserveId(spoke1);
    collateralReserveIds[1] = _usdyReserveId(spoke1);

    debtReserveIds[0] = _usdxReserveId(spoke1);
    debtReserveIds[1] = _wbtcReserveId(spoke1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTestMulti({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.1e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmountInBase: 10_000_000e26,
      liquidationFee: 5_00,
      collateralReserveIds: collateralReserveIds,
      debtReserveIds: debtReserveIds,
      collateralReserveIndex: 0,
      debtReserveIndex: 1,
      skipTime: 365 days,
      desiredHf: 0.95e18
    });

    // if dust remains after accounting for available collateral, tx will have reverted
    if (!state.hasDustFromAvailableCollateral) {
      _checkLiquidation(state, 'test_liquidationCall_closeFactor_multi_reserve_scenario3');
      assertFalse(state.hasDeficit, 'should not have deficit');
    }
  }

  function test_liquidationCall_closeFactor_fuzz_multi_reserve(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 collateralReserveId1,
    uint256 collateralReserveId2,
    uint256 debtReserveId1,
    uint256 debtReserveId2,
    uint256 collateralReserveIndex,
    uint256 debtReserveIndex,
    uint256 supplyAmountInBase,
    uint256 skipTime,
    uint256 desiredHf
  ) public {
    collateralReserveId1 = bound(collateralReserveId1, 0, spoke1.getReserveCount() - 1);
    collateralReserveId2 = bound(collateralReserveId2, 0, spoke1.getReserveCount() - 1);
    debtReserveId1 = bound(debtReserveId1, 0, spoke1.getReserveCount() - 1);
    debtReserveId2 = bound(debtReserveId2, 0, spoke1.getReserveCount() - 1);

    collateralReserveIndex = bound(collateralReserveIndex, 0, 1);
    debtReserveIndex = bound(debtReserveIndex, 0, 1);

    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    // simplify borrowing under HF by different mix of coll/debt
    vm.assume(collateralReserveId1 != collateralReserveId2 && debtReserveId1 != debtReserveId2);

    uint256[] memory collateralReserveIds = new uint256[](2);
    uint256[] memory debtReserveIds = new uint256[](2);

    collateralReserveIds[0] = collateralReserveId1;
    collateralReserveIds[1] = collateralReserveId2;

    debtReserveIds[0] = debtReserveId1;
    debtReserveIds[1] = debtReserveId2;

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorTestMulti({
      liqConfig: liqConfig,
      liqBonus: 105_00,
      supplyAmountInBase: supplyAmountInBase,
      liquidationFee: 5_00,
      collateralReserveIds: collateralReserveIds,
      debtReserveIds: debtReserveIds,
      collateralReserveIndex: collateralReserveIndex,
      debtReserveIndex: debtReserveIndex,
      skipTime: skipTime,
      desiredHf: desiredHf
    });

    if (!state.hasDustFromAvailableCollateral) {
      _checkLiquidation(state, 'test_liquidationCall_closeFactor_fuzz_multi_reserve');
      assertFalse(state.hasDeficit, 'should not have deficit');
    }
  }

  /// fuzz test with multiple collateral/debt reserves
  function _execLiqCallCloseFactorTestMulti(
    DataTypes.LiquidationConfig memory liqConfig,
    uint32 liqBonus,
    uint256 supplyAmountInBase,
    uint256[] memory collateralReserveIds,
    uint256[] memory debtReserveIds,
    uint256 collateralReserveIndex,
    uint256 debtReserveIndex,
    uint16 liquidationFee,
    uint256 skipTime,
    uint256 desiredHf
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new Reserve[](collateralReserveIds.length);
    state.collDynConfigs = new DataTypes.DynamicReserveConfig[](collateralReserveIds.length);
    state.debtReserves = new Reserve[](debtReserveIds.length);
    state.collateralReserveIndex = collateralReserveIndex;
    state.debtReserveIndex = debtReserveIndex;
    state.isMultiDebtReserve = debtReserveIds.length > 1;
    for (uint256 i = 0; i < collateralReserveIds.length; i++) {
      state.collateralReserves[i] = _getReserve(spoke1, collateralReserveIds[i]);
      state.collDynConfigs[i] = _getUserDynConfig(spoke1, alice, collateralReserveIds[i]); // utilize user's dynamic config
    }
    state.collDynConfig = state.collDynConfigs[collateralReserveIndex];
    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      state.debtReserves[i] = _getReserve(spoke1, debtReserveIds[i]);
    }
    liqConfig = _boundCloseFactor(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath.PERCENTAGE_FACTOR.percentDivDown(
        state.collDynConfigs[collateralReserveIndex].collateralFactor
      )
    ).toUint32();
    liquidationFee = bound(liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR).toUint16();
    supplyAmountInBase = bound(
      supplyAmountInBase,
      dustInBase * state.debtReserves.length, // enough to cover dust for all debt reserves
      MAX_SUPPLY_IN_BASE_CURRENCY / 10
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    state.collateralReserve = state.collateralReserves[state.collateralReserveIndex];
    state.debtReserve = state.debtReserves[state.debtReserveIndex];

    state.liquidationFee = liquidationFee;
    state.spoke = spoke1;
    state.user = alice;

    updateLiquidationConfig(state.spoke, liqConfig);
    updateLiquidationBonus(state.spoke, collateralReserveIds[collateralReserveIndex], liqBonus);
    updateLiquidationFee(
      state.spoke,
      collateralReserveIds[collateralReserveIndex],
      state.liquidationFee
    );

    for (uint256 i = 0; i < collateralReserveIds.length; i++) {
      uint256 supplyAmount = _convertBaseCurrencyToAmount(
        spoke1,
        state.collateralReserves[i].reserveId,
        supplyAmountInBase
      );

      Utils.supplyCollateral({
        spoke: state.spoke,
        reserveId: collateralReserveIds[i],
        caller: alice,
        amount: supplyAmount,
        onBehalfOf: alice
      });
    }

    state.hfBadDebtThreshold = _calcLowestHfForBadDebt(state.spoke, alice, liqBonus).percentMulUp(
      101_00
    ); // add buffer to have HF remain above lowest allowed HF
    // desiredHF is within range of a liquidation that does not result in bad debt
    state.desiredHf = bound(
      desiredHf,
      _min(state.hfBadDebtThreshold, HEALTH_FACTOR_LIQUIDATION_THRESHOLD),
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    _increaseReservesSupplyExchangeRate(
      state.spoke,
      state.collateralReserves,
      supplyAmountInBase,
      skipTime,
      bob
    );

    (uint256 hfAfterBorrow, ) = _borrowMultipleReservesToBeBelowHf(
      state.spoke,
      alice,
      debtReserveIds,
      state.desiredHf
    );

    state.liquidationBonus = state.spoke.getVariableLiquidationBonus(
      state.collateralReserves[collateralReserveIndex].reserveId,
      state.user,
      hfAfterBorrow
    );

    // ensure position is liquidatable
    assertLt(state.spoke.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
    state = _getAccountingInfoBeforeLiquidation(
      collateralReserveIds[collateralReserveIndex],
      debtReserveIds[debtReserveIndex],
      state
    );
    DynamicConfig[] memory configKeysBefore = _getUserDynConfigKeys(spoke1, alice);

    (
      state.collToLiq,
      state.debtToLiq,
      state.liquidationFeeAmount,
      ,
      state.hasDustFromDebt
    ) = _calculateCollateralAndDebtToLiquidate(state, UINT256_MAX);

    state.naiveLeftoverDebtAmount = state.userTotalReserveDebt.balanceBefore - state.debtToLiq;
    // conditions for dust remaining that results in revert:
    // 1. naiveLeftoverDebtAmount < minLeftoverAmount threshold
    // 2. naiveLeftoverDebtAmount != 0 (non-zero dust)
    // 3. total collateral seized (incl liq fee) != userSuppliedAmount.balanceBefore (collateral reserve is not fully liquidated)
    state.hasDustFromAvailableCollateral = (state.naiveLeftoverDebtAmount <
      state.minLeftoverAmount &&
      state.naiveLeftoverDebtAmount != 0 &&
      state.collToLiq + state.liquidationFeeAmount != state.userSuppliedAmount.balanceBefore);
    // if debt dust remains after accounting for available collateral, revert
    if (state.hasDustFromAvailableCollateral) {
      vm.expectRevert(LiquidationLogic.MustNotLeaveDust.selector);
    } else {
      vm.expectEmit(address(state.spoke));
      emit ISpokeBase.LiquidationCall(
        collateralReserveIds[collateralReserveIndex],
        debtReserveIds[debtReserveIndex],
        alice,
        state.debtToLiq,
        state.collToLiq,
        LIQUIDATOR
      );
    }
    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCall(
      collateralReserveIds[collateralReserveIndex],
      debtReserveIds[debtReserveIndex],
      alice,
      UINT256_MAX
    );

    _getAccountingInfoAfterLiquidation(state);

    // Validate user's dynamic config key unchanged after liquidation
    assertEq(_getUserDynConfigKeys(state.spoke, alice), configKeysBefore);

    return state;
  }

  /// @notice Borrow random amounts from multiple reserves to be below a certain health factor, without HF validation
  /// user RP will be 0 due to mocking price to 0
  function _borrowMultipleReservesToBeBelowHf(
    ISpoke spoke,
    address user,
    uint256[] memory reserveIds,
    uint256 desiredHf
  ) internal returns (uint256 finalHf, uint256[] memory requiredDebts) {
    IPriceOracle oracle = spoke.oracle();
    requiredDebts = new uint256[](reserveIds.length);

    // extra debt to ensure HF below desired
    uint256 requiredDebtInBase = _getRequiredDebtInBaseCurrencyForLtHf(spoke, user, desiredHf);

    uint256 remaining = requiredDebtInBase;
    // make sure that each reserve has at least dustInBase in debt

    vm.startPrank(user);
    for (uint256 i = 0; i < reserveIds.length; i++) {
      uint256 amountInBase;
      // randomly distribute total required debt across debt reserves
      if (i == reserveIds.length - 1) {
        // Last iteration, borrow remaining amount
        amountInBase = remaining;
      } else {
        amountInBase = randomizer(dustInBase, remaining - dustInBase * (reserveIds.length - i - 1));
      }

      uint256 amount = _convertBaseCurrencyToAmount(spoke, reserveIds[i], amountInBase) + 1;
      vm.assume(amount < MAX_SUPPLY_AMOUNT);

      // mock price to 0 to circumvent borrow validation
      vm.mockCall(
        address(oracle),
        abi.encodeWithSelector(IPriceOracle.getReservePrice.selector, reserveIds[i]),
        abi.encode(0)
      );
      spoke.borrow(reserveIds[i], amount, user);
      remaining -= amountInBase;
      requiredDebts[i] = amount;
    }
    vm.clearMockedCalls();
    vm.stopPrank();

    finalHf = spoke.getHealthFactor(user);
    assertLt(
      finalHf,
      desiredHf,
      '_borrowMultipleReservesToBeBelowHf: should borrow enough for HF to be below desiredHf'
    );
  }

  // increase supply exchange rate across multiple reserves
  function _increaseReservesSupplyExchangeRate(
    ISpoke spoke,
    Reserve[] memory collateralReserves,
    uint256 borrowAmount,
    uint256 skipTime,
    address user
  ) internal {
    _addBorrowableLiquidities(borrowAmount * collateralReserves.length);
    uint256[] memory initialExRate = new uint256[](collateralReserves.length);
    uint256[] memory finalExRate = new uint256[](collateralReserves.length);

    vm.startPrank(user);
    for (uint256 i = 0; i < collateralReserves.length; i++) {
      uint256 assetId = spoke.getReserve(collateralReserves[i].reserveId).assetId;
      initialExRate[i] = hub1.convertToAddedAssets(assetId, WadRayMath.RAY.toWad());
      // mock price to 0 to circumvent borrow validation
      vm.mockCall(
        address(oracle1),
        abi.encodeWithSelector(
          IPriceOracle.getReservePrice.selector,
          collateralReserves[i].reserveId
        ),
        abi.encode(0)
      );
      // user borrows some collateral reserve to inflate collateral supply ex rate
      spoke1.borrow(collateralReserves[i].reserveId, borrowAmount, user);
    }
    vm.clearMockedCalls();
    vm.stopPrank();
    skip(skipTime);

    for (uint256 i = 0; i < collateralReserves.length; i++) {
      finalExRate[i] = hub1.convertToAddedAssets(
        spoke.getReserve(collateralReserves[i].reserveId).assetId,
        WadRayMath.RAY.toWad()
      );
      assertGt(finalExRate[i], initialExRate[i]);
    }
  }
}
