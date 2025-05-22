// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallCloseFactorMultiReserveTest is SpokeLiquidationBase {
  using PercentageMathExtended for uint256;
  using WadRayMathExtended for uint256;

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
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmountInBase: 10_000e26,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveIds: collateralReserveIds,
      debtReserveIds: debtReserveIds,
      collateralReserveIndex: 0,
      debtReserveIndex: 1,
      skipTime: 365 days
    });
    _checkLiquidation(state, spoke1, 'test_liquidationCall_closeFactor_multi_reserve_scenario1');
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
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmountInBase: 10_000e26,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveIds: collateralReserveIds,
      debtReserveIds: debtReserveIds,
      collateralReserveIndex: 0,
      debtReserveIndex: 1,
      skipTime: 365 days
    });

    _checkLiquidation(state, spoke1, 'test_liquidationCall_closeFactor_multi_reserve_scenario2');
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
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmountInBase: 10_000_000e26,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveIds: collateralReserveIds,
      debtReserveIds: debtReserveIds,
      collateralReserveIndex: 0,
      debtReserveIndex: 1,
      skipTime: 365 days
    });

    _checkLiquidation(state, spoke1, 'test_liquidationCall_closeFactor_multi_reserve_scenario3');
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
    uint256 skipTime
  ) public {
    collateralReserveId1 = bound(collateralReserveId1, 0, spoke1.reserveCount() - 1);
    collateralReserveId2 = bound(collateralReserveId2, 0, spoke1.reserveCount() - 1);
    debtReserveId1 = bound(debtReserveId1, 0, spoke1.reserveCount() - 1);
    debtReserveId2 = bound(debtReserveId2, 0, spoke1.reserveCount() - 1);

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
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveIds: collateralReserveIds,
      debtReserveIds: debtReserveIds,
      collateralReserveIndex: collateralReserveIndex,
      debtReserveIndex: debtReserveIndex,
      skipTime: skipTime
    });

    _checkLiquidation(state, spoke1, 'test_liquidationCall_closeFactor_fuzz_multi_reserve');
  }

  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual override returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      MIN_CLOSE_FACTOR,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 10
    );

    // set variable bonus config to 0 for simplicity in calculating _borrowMultipleReservesToBeBelowHf
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorBonusThreshold = 0;

    return liqConfig;
  }

  /// fuzz test with multiple collateral/debt reserves
  function _execLiqCallCloseFactorTestMulti(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmountInBase,
    uint256[] memory collateralReserveIds,
    uint256[] memory debtReserveIds,
    uint256 collateralReserveIndex,
    uint256 debtReserveIndex,
    uint256 liquidationProtocolFeePercentage,
    uint256 skipTime
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](collateralReserveIds.length);
    state.debtReserves = new DataTypes.Reserve[](debtReserveIds.length);
    state.collateralReserveIndex = collateralReserveIndex;
    state.debtReserveIndex = debtReserveIndex;

    console.log(' fuzz inputs');
    for (uint256 i = 0; i < collateralReserveIds.length; i++) {
      state.collateralReserves[i] = spoke1.getReserve(collateralReserveIds[i]);
      console.log('  collateralReserveId %e', collateralReserveIds[i]);
    }
    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      state.debtReserves[i] = spoke1.getReserve(debtReserveIds[i]);
      console.log('  debtReserveId %e', debtReserveIds[i]);
    }
    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMathExtended
        .PERCENTAGE_FACTOR
        .percentDivDown(state.collateralReserves[collateralReserveIndex].config.collateralFactor)
        .percentMulDown(99_00) // add buffer so that not all debt is liquidated
    );
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);
    supplyAmountInBase = bound(
      supplyAmountInBase,
      dustInBase * state.debtReserves.length, // enough to cover dust for all debt reserves
      MAX_SUPPLY_IN_BASE_CURRENCY / 10
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    state.spoke = spoke1;
    state.user = alice;

    state.spoke.updateLiquidationConfig(liqConfig);
    updateLiquidationBonus(
      state.spoke,
      state.collateralReserves[collateralReserveIndex].reserveId,
      liqBonus
    );
    updateLiquidationProtocolFeePercentage(
      state.spoke,
      state.collateralReserves[collateralReserveIndex].reserveId,
      state.liquidationProtocolFeePercentage
    );

    console.log('  liqConfig.closeFactor %e', liqConfig.closeFactor);
    console.log('  liqConfig.healthFactorBonusThreshold %e', liqConfig.healthFactorBonusThreshold);
    console.log('  liqConfig.liquidationBonusFactor %e', liqConfig.liquidationBonusFactor);
    console.log('  liqBonus %e', liqBonus);
    // console.log('  desiredHf %e', state.desiredHf);

    console.log('  skipTime %e', skipTime);
    console.log('  liquidationProtocolFeePercentage %e', liquidationProtocolFeePercentage);

    for (uint256 i = 0; i < collateralReserveIds.length; i++) {
      uint256 supplyAmount = _convertBaseCurrencyToAmount(
        state.collateralReserves[i].assetId,
        supplyAmountInBase
      );
      console.log(
        '  resId %s, supplyAmount %e',
        state.collateralReserves[i].reserveId,
        supplyAmount
      );

      Utils.supplyCollateral({
        spoke: state.spoke,
        reserveId: collateralReserveIds[i],
        user: alice,
        amount: supplyAmount,
        onBehalfOf: alice
      });
    }

    state.desiredHf = _calcLowestHfForBadDebt(state.spoke, alice, liqBonus).percentMulUp(101_00); // add buffer to have HF remain above lowest allowed HF

    // TODO: can just use inflate on normal coll reserve
    _increaseCollateralReservesSupplyExchangeRate(
      state.collateralReserves,
      supplyAmountInBase,
      skipTime,
      bob
    );

    (
      uint256 hfAfterBorrow,
      uint256[] memory requiredDebtAmounts
    ) = _borrowMultipleReservesToBeBelowHf(state.spoke, alice, debtReserveIds, state.desiredHf);

    state.liquidationBonus = _getVariableLiquidationBonus(
      state.spoke,
      state.collateralReserves[collateralReserveIndex].reserveId,
      hfAfterBorrow
    );

    console.log('state.desiredHf %e %e', state.desiredHf, hfAfterBorrow);

    // console.log('alice', alice);
    console.log(' debt id1 id2', debtReserveIds[0], debtReserveIds[1]);
    console.log(' coll id1 id2', collateralReserveIds[0], collateralReserveIds[1]);
    console.log(
      ' alice initial debts %e %e',
      state.spoke.getUserTotalDebt(debtReserveIds[0], alice),
      state.spoke.getUserTotalDebt(debtReserveIds[1], alice)
    );
    console.log(
      ' alice initial supplied %e %e',
      state.spoke.getUserSuppliedAmount(collateralReserveIds[0], alice),
      state.spoke.getUserSuppliedAmount(collateralReserveIds[1], alice)
    );

    // for (uint256 i = 0; i < debtReserveIds.length; i++) {
    //   assertLt(state.spoke.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    //   console.log('liquidate ', debtReserveIds[i]);
    //   vm.prank(LIQUIDATOR);
    //   state.spoke.liquidationCall(
    //     collateralReserveIds[i],
    //     debtReserveIds[i],
    //     alice,
    //     requiredDebtAmounts[i]
    //   );
    // }

    assertLt(state.spoke.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    console.log(
      'liquidate %e %e',
      debtReserveIds[debtReserveIndex],
      requiredDebtAmounts[debtReserveIndex]
    );

    _getAccountingInfoBeforeLiq(state);

    (
      state.collToLiq,
      state.debtToLiq,
      state.liqProtocolFee,

    ) = _calculateAvailableCollateralToLiquidate(
      state.spoke,
      state,
      requiredDebtAmounts[debtReserveIndex]
    );

    // logs to read protocol fee from tmp emitted event
    // TODO: update when treasury accounting is done
    vm.recordLogs();

    vm.expectEmit(address(state.spoke));
    emit ISpoke.LiquidationCall(
      state.collateralReserves[state.collateralReserveIndex].asset,
      state.debtReserves[state.debtReserveIndex].asset,
      alice,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCall(
      collateralReserveIds[collateralReserveIndex],
      debtReserveIds[debtReserveIndex],
      alice,
      requiredDebtAmounts[debtReserveIndex]
    );

    _getAccountingInfoAfterLiq(state);

    console.log('hf after liq %e', spoke1.getHealthFactor(alice));
    console.log(
      ' alice final debts id: %e %e',
      spoke1.getUserTotalDebt(debtReserveIds[0], alice),
      spoke1.getUserTotalDebt(debtReserveIds[1], alice)
    );
    console.log(
      ' alice final supplied %e %e',
      spoke1.getUserSuppliedAmount(collateralReserveIds[0], alice),
      spoke1.getUserSuppliedAmount(collateralReserveIds[1], alice)
    );

    return state;
  }

  /// @notice Borrow random amounts from multiple reserves to ensure the health factor is below the desired level.
  function _borrowMultipleReservesToBeBelowHf(
    ISpoke spoke,
    address user,
    uint256[] memory reserveIds,
    uint256 desiredHf
  ) internal returns (uint256 finalHf, uint256[] memory requiredDebts) {
    requiredDebts = new uint256[](reserveIds.length);

    // extra debt to ensure HF below desired
    uint256 requiredDebtInBase = _getRequiredDebtForLtHf(spoke, user, desiredHf);

    uint256 remaining = requiredDebtInBase;
    // make sure that each reserve has at least dustInBase in debt

    vm.startPrank(user);
    for (uint256 i = 0; i < reserveIds.length; i++) {
      uint256 assetId = spoke.getReserve(reserveIds[i]).assetId;

      uint256 amountInBase;
      // randomly distribute total required debt across debt reserves
      if (i == reserveIds.length - 1) {
        // Last iteration, borrow remaining amount
        amountInBase = remaining;
      } else {
        amountInBase = randomizer(dustInBase, remaining - dustInBase * (reserveIds.length - i - 1));
      }

      uint256 amount = _convertBaseCurrencyToAmount(assetId, amountInBase) + 1;
      vm.assume(amount < MAX_SUPPLY_AMOUNT);

      // mock price to 0 to circumvent borrow validation
      vm.mockCall(
        address(oracle),
        abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, assetId),
        abi.encode(0)
      );
      spoke.borrow(reserveIds[i], amount, user);
      console.log('borrow %e %e', reserveIds[i], amount);
      console.log('borrowSh %e', spoke.getUserTotalDebt(reserveIds[i], user));

      remaining -= amountInBase;
      requiredDebts[i] = amount;
    }
    vm.clearMockedCalls();
    vm.stopPrank();

    finalHf = spoke.getHealthFactor(user);
    assertLt(finalHf, desiredHf, 'should borrow enough for HF to be below desiredHf');
  }

  function _increaseCollateralReservesSupplyExchangeRate(
    DataTypes.Reserve[] memory collateralReserves,
    uint256 borrowAmount,
    uint256 skipTime,
    address user
  ) internal {
    _deployBorrowableLiquidities(borrowAmount * collateralReserves.length);

    vm.startPrank(user);
    for (uint256 i = 0; i < collateralReserves.length; i++) {
      // mock price to 0 to circumvent borrow validation
      vm.mockCall(
        address(oracle),
        abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, collateralReserves[i].assetId),
        abi.encode(0)
      );
      // user borrows some collateral reserve to inflate collateral supply ex rate
      spoke1.borrow(collateralReserves[i].reserveId, borrowAmount, user);
    }
    vm.clearMockedCalls();
    vm.stopPrank();
    skip(skipTime);
  }
}
