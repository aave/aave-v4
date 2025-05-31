// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

/// tests where liquidation results in bad debt (debt remaining > 0, collateral remaining = 0)
contract LiquidationCallsTest is SpokeLiquidationBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  /// coll: weth / debt: dai
  function test_liquidationCalls_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    uint256[] memory supplyAmounts = new uint256[](2);
    supplyAmounts[0] = 1.5e18;
    supplyAmounts[1] = 1e18;

    test_liquidationCalls_fuzz({
      supplyAmounts: supplyAmounts,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days
    });
  }

  function test_liquidationCalls_fuzz(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    // DataTypes.LiquidationConfig memory liqConfig,
    // uint256 liqBonus,
    uint256[] memory supplyAmounts,
    // uint256 liquidationProtocolFee,
    uint256 skipTime
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.reserveCount() - 1);

    uint256 liqBonus = 105_00;
    uint256 liquidationProtocolFee = 0;
    DataTypes.LiquidationConfig memory liqConfig = DataTypes.LiquidationConfig({
      closeFactor: 1.05e18,
      liquidationBonusFactor: 0,
      healthFactorForMaxBonus: 0
    });

    ParallelLiquidationsTestLocalParams memory state = _execLiqCallsTest(
      liqConfig,
      liqBonus,
      supplyAmounts,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFee,
      skipTime
    );

    string memory label = 'test_liquidationCalls_fuzz';
    // _checkLiquidation(state, spoke1, label);
  }

  function _boundSupplyAmounts(
    ParallelLiquidationsTestLocalParams memory state,
    uint256[] memory supplyAmounts_
  ) internal returns (uint256[] memory supplyAmounts) {
    supplyAmounts = new uint256[](supplyAmounts_.length);
    for (uint256 i = 0; i < supplyAmounts_.length; i++) {
      uint256 supplyAmount = bound(
        supplyAmounts_[i],
        _convertBaseCurrencyToAmount(
          state.collateralReserves[state.collateralReserveIndex].assetId,
          1e25
        ),
        _min(
          _convertBaseCurrencyToAmount(
            state.collateralReserves[state.collateralReserveIndex].assetId,
            MAX_SUPPLY_IN_BASE_CURRENCY
          ),
          MAX_SUPPLY_AMOUNT
        )
      );
      supplyAmounts[i] = supplyAmount;
    }
  }

  /// execute fuzz tests to ensure bad debt remains post-liquidation
  /// single debt reserve, single collateral reserve
  /// liquidating all collateral is insufficient to cover debt
  function _execLiqCallsTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256[] memory supplyAmounts,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFee,
    uint256 skipTime
  ) internal returns (ParallelLiquidationsTestLocalParams memory) {
    ParallelLiquidationsTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](1);
    state.debtReserves = new DataTypes.Reserve[](1);
    state.users = new address[](2);

    state.collateralReserves[state.collateralReserveIndex] = spoke1.getReserve(collateralReserveId);
    state.debtReserves[state.debtReserveIndex] = spoke1.getReserve(debtReserveId);

    // bound close factor, with a static liq bonus
    // liqConfig = _boundCloseFactor(liqConfig);
    // liqBonus = bound(
    //   liqBonus,
    //   MIN_LIQUIDATION_BONUS,
    //   PercentageMath.PERCENTAGE_FACTOR.percentDiv(
    //     state.collateralReserves[state.collateralReserveIndex].config.collateralFactor
    //   )
    // );
    // liquidationProtocolFee = bound(liquidationProtocolFee, 0, 100_00);
    // supplyAmount = bound(
    //   supplyAmount,
    //   _convertBaseCurrencyToAmount(
    //     state.collateralReserves[state.collateralReserveIndex].assetId,
    //     1e25
    //   ),
    //   _min(
    //     _convertBaseCurrencyToAmount(
    //       state.collateralReserves[state.collateralReserveIndex].assetId,
    //       MAX_SUPPLY_IN_BASE_CURRENCY
    //     ),
    //     MAX_SUPPLY_AMOUNT
    //   )
    // );
    state.supplyAmounts = _boundSupplyAmounts(state, supplyAmounts);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    state.spoke = spoke1;
    state.users[0] = alice;
    state.users[1] = carol;
    state.liquidationProtocolFee = liquidationProtocolFee;

    // tests:
    // - create premium debt borrow position for 2 users
    //

    // - 2 normal ones without bad debt
    // - with 1 having deficit at least
    // -

    // set spoke liq config
    state.spoke.updateLiquidationConfig(liqConfig);
    updateLiquidationBonus(state.spoke, collateralReserveId, liqBonus);
    updateLiquidationProtocolFee(state.spoke, collateralReserveId, state.liquidationProtocolFee);

    // set user position under hf threshold so that there is invalid collateral to cover all debt
    uint256 desiredHf = _calcLowestHfForBadDebt(
      state.spoke.getReserve(collateralReserveId).config.collateralFactor,
      liqBonus
    ).percentMul(105_00);

    // use bob to increase supply exchange rate of collateral reserve
    _increaseReserveSupplyExchangeRate(
      state.spoke,
      collateralReserveId,
      state.supplyAmounts[0],
      skipTime,
      bob
    );

    Balance[] memory userSupplies = new Balance[](2);
    Balance[] memory userDebts = new Balance[](2);

    Balance memory totalUserSupply;
    Balance memory totalUserDebt;

    for (uint256 i = 0; i < state.users.length; i++) {
      Utils.supplyCollateral({
        spoke: state.spoke,
        reserveId: collateralReserveId,
        user: state.users[i],
        amount: state.supplyAmounts[i],
        onBehalfOf: state.users[i]
      });

      _borrowToBeBelowHf(state.spoke, state.users[i], debtReserveId, desiredHf);

      // console.log('hfAfterBorrow %e', hfAfterBorrow, state.users[i]);

      // console.log(
      //   ' supplied initial %e',
      //   state.spoke.getUserSuppliedAmount(collateralReserveId, state.users[i])
      // );
      // console.log(' debt initial %e', state.spoke.getUserTotalDebt(debtReserveId, state.users[i]));

      userSupplies[i].balanceBefore = state.spoke.getUserSuppliedAmount(
        collateralReserveId,
        state.users[i]
      );
      userDebts[i].balanceBefore = state.spoke.getUserTotalDebt(debtReserveId, state.users[i]);
    }

    state.liqColl.balanceBefore = IERC20(
      state.collateralReserves[state.collateralReserveIndex].asset
    ).balanceOf(LIQUIDATOR);
    state.liqDebt.balanceBefore = IERC20(state.debtReserves[state.debtReserveIndex].asset)
      .balanceOf(LIQUIDATOR);

    // vm.assume(
    //   _getRequiredDebtAmountForLtHf(spoke1, alice, debtReserveId, desiredHf) <= MAX_SUPPLY_AMOUNT
    // );
    // // borrow some amount of debt reserve to end up below hf threshold

    // state.liquidationBonus = _getVariableLiquidationBonus(
    //   state.spoke,
    //   collateralReserveId,
    //   hfAfterBorrow
    // );

    // state = _getAccountingInfoBeforeLiq(state);
    // (
    //   state.collToLiq,
    //   state.debtToLiq,
    //   state.liqProtocolFee,

    // ) = _calculateAvailableCollateralToLiquidate(state.spoke, state, UINT256_MAX);

    // // logs to read protocol fee from tmp emitted event
    // // TODO: update when treasury accounting is done
    // vm.recordLogs();

    uint256[] memory debtAmounts = new uint256[](2);
    debtAmounts[0] = UINT256_MAX;
    debtAmounts[1] = UINT256_MAX;

    // // vm.expectEmit(address(hub));
    // // emit ILiquidityHub.DeficitCreated(
    // //   state.debtReserves[state.debtReserveIndex].assetId,
    // //   address(state.spoke),
    // //   state.totalDebt.balanceBefore - state.debtToLiq // outstanding debt which becomes bad debt reported as deficit
    // // );
    // vm.expectEmit(address(state.spoke));
    // emit ISpoke.LiquidationCall(
    //   state.collateralReserves[state.collateralReserveIndex].asset,
    //   state.debtReserves[state.debtReserveIndex].asset,
    //   alice,
    //   state.debtToLiq,
    //   state.collToLiq,
    //   LIQUIDATOR
    // );
    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCalls(collateralReserveId, debtReserveId, state.users, debtAmounts);

    for (uint256 i = 0; i < state.users.length; i++) {
      // console.log(
      //   ' supplied final %e',
      //   state.spoke.getUserSuppliedAmount(collateralReserveId, state.users[i])
      // );
      // console.log(' debt final %e', state.spoke.getUserTotalDebt(debtReserveId, state.users[i]));

      userSupplies[i].balanceAfter = state.spoke.getUserSuppliedAmount(
        collateralReserveId,
        state.users[i]
      );
      userDebts[i].balanceAfter = state.spoke.getUserTotalDebt(debtReserveId, state.users[i]);

      // console.log(
      //   'supply diff %e',
      //   stdMath.delta(userSupplies[i].balanceAfter, userSupplies[i].balanceBefore),
      //   state.users[i]
      // );
      // console.log(
      //   'debt diff %e',
      //   stdMath.delta(userDebts[i].balanceAfter, userDebts[i].balanceBefore),
      //   state.users[i]
      // );

      totalUserSupply.balanceChange += stdMath.delta(
        userSupplies[i].balanceAfter,
        userSupplies[i].balanceBefore
      );
      totalUserDebt.balanceChange += stdMath.delta(
        userDebts[i].balanceAfter,
        userDebts[i].balanceBefore
      );
    }

    state.liqColl.balanceAfter = IERC20(
      state.collateralReserves[state.collateralReserveIndex].asset
    ).balanceOf(LIQUIDATOR);
    state.liqDebt.balanceAfter = IERC20(state.debtReserves[state.debtReserveIndex].asset).balanceOf(
      LIQUIDATOR
    );

    console.log(
      'liq coll diff %e %e',
      stdMath.delta(state.liqColl.balanceAfter, state.liqColl.balanceBefore),
      totalUserSupply.balanceChange
    );
    console.log(
      'liq debt diff %e %e',
      stdMath.delta(state.liqDebt.balanceAfter, state.liqDebt.balanceBefore),
      totalUserDebt.balanceChange
    );

    assertEq(
      stdMath.delta(state.liqColl.balanceAfter, state.liqColl.balanceBefore),
      totalUserSupply.balanceChange
    );
    assertEq(
      stdMath.delta(state.liqDebt.balanceAfter, state.liqDebt.balanceBefore),
      totalUserDebt.balanceChange
    );

    // state = _getAccountingInfoAfterLiq(state);

    // return state;
  }

  // function _getAccountingInfoBeforeParallelLiqs(
  //   LiquidationTestLocalParams memory state
  // ) internal view returns (LiquidationTestLocalParams memory) {
  //   (state.baseDebt.balanceBefore, state.premiumDebt.balanceBefore) = state.spoke.getUserDebt(
  //     state.debtReserves[state.debtReserveIndex].reserveId,
  //     state.user
  //   );
  //   state.totalDebt.balanceBefore = state.baseDebt.balanceBefore + state.premiumDebt.balanceBefore;
  //   state.liquidatorCollateral.balanceBefore = IERC20(
  //     state.collateralReserves[state.collateralReserveIndex].asset
  //   ).balanceOf(LIQUIDATOR);
  //   state.liquidatorDebt.balanceBefore = IERC20(state.debtReserves[state.debtReserveIndex].asset)
  //     .balanceOf(LIQUIDATOR);
  //   state.supply.balanceBefore = state.spoke.getUserSuppliedAmount(
  //     state.collateralReserves[state.collateralReserveIndex].reserveId,
  //     state.user
  //   );
  //   state.supplyShares.balanceBefore = state.spoke.getUserSuppliedShares(
  //     state.collateralReserves[state.collateralReserveIndex].reserveId,
  //     state.user
  //   );
  //   state.rate.rateBefore = hub.convertToSuppliedAssets(
  //     state.collateralReserves[state.collateralReserveIndex].assetId,
  //     WadRayMathExtended.RAY
  //   );
  //   state.deficit.balanceBefore = hub.getDeficit(
  //     state.debtReserves[state.debtReserveIndex].assetId
  //   );

  //   (
  //     ,
  //     ,
  //     state.initialHf,
  //     state.initialTotalCollateralInBaseCurrency,
  //     state.initialTotalDebtInBaseCurrency
  //   ) = state.spoke.getUserAccountData(state.user);

  //   // multi reserve accounting
  //   state.debts = new Balance[](state.debtReserves.length);
  //   state.deficits = new Balance[](state.debtReserves.length);
  //   for (uint256 i = 0; i < state.debtReserves.length; i++) {
  //     state.deficits[i].balanceBefore = hub.getDeficit(state.debtReserves[i].assetId);
  //     state.debts[i].balanceBefore = state.spoke.getUserTotalDebt(
  //       state.debtReserves[i].reserveId,
  //       state.user
  //     );
  //   }

  //   return state;
  // }
}
