// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

/// tests where liquidation results in bad debt (debt remaining > 0, collateral remaining = 0)
contract LiquidationCallsTest is SpokeLiquidationBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  /// coll: weth / debt: dai
  function test_liquidationCall_badDebt_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);
    test_liquidationCalls_fuzz({
      supplyAmount: 1.5e18,
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
    uint256 supplyAmount,
    // uint256 liquidationProtocolFee,
    uint256 skipTime
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.reserveCount() - 1);

    uint256 liqBonus = 105_00;
    uint256 liquidationProtocolFee = 5_00;
    DataTypes.LiquidationConfig memory liqConfig = DataTypes.LiquidationConfig({
      closeFactor: 1.05e18,
      liquidationBonusFactor: 0,
      healthFactorForMaxBonus: 0
    });

    LiquidationTestLocalParams memory state = _execLiqCallsTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFee,
      skipTime
    );

    string memory label = 'test_liquidationCalls_fuzz';
    // _checkLiquidation(state, spoke1, label);
  }

  /// execute fuzz tests to ensure bad debt remains post-liquidation
  /// single debt reserve, single collateral reserve
  /// liquidating all collateral is insufficient to cover debt
  function _execLiqCallsTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFee,
    uint256 skipTime
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](1);
    state.debtReserves = new DataTypes.Reserve[](1);

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
    liquidationProtocolFee = bound(liquidationProtocolFee, 0, 100_00);
    supplyAmount = bound(
      supplyAmount,
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
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    state.spoke = spoke1;
    state.user = alice;
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

    Utils.supplyCollateral({
      spoke: state.spoke,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    // set user position under hf threshold so that there is invalid collateral to cover all debt
    // ensure 1% buffer under threshold
    uint256 desiredHf = _calcLowestHfForBadDebt(state.spoke, alice, liqBonus);

    // increase supply exchange rate of collateral reserve
    _increaseReserveSupplyExchangeRate(
      state.spoke,
      collateralReserveId,
      supplyAmount / 2,
      skipTime,
      bob
    );

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
      hfAfterBorrow
    );

    state = _getAccountingInfoBeforeLiq(state);
    (
      state.collToLiq,
      state.debtToLiq,
      state.liqProtocolFee,

    ) = _calculateAvailableCollateralToLiquidate(state.spoke, state, UINT256_MAX);

    // logs to read protocol fee from tmp emitted event
    // TODO: update when treasury accounting is done
    vm.recordLogs();

    // vm.expectEmit(address(hub));
    // emit ILiquidityHub.DeficitCreated(
    //   state.debtReserves[state.debtReserveIndex].assetId,
    //   address(state.spoke),
    //   state.totalDebt.balanceBefore - state.debtToLiq // outstanding debt which becomes bad debt reported as deficit
    // );
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
    state.spoke.liquidationCall(collateralReserveId, debtReserveId, alice, UINT256_MAX);

    state = _getAccountingInfoAfterLiq(state);

    return state;
  }
}
