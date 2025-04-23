// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallCloseFactorMultiReserveTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  uint256 minSupplyInBaseCurrency = 10e26; // $10 in base currency
  uint256 remainingBaseCurrencyBound = 1e26; // $1 in base currency units

  // todo: multi coll/debt

  /// coll: weth / debt: dai
  function test_liquidationCall_closeFactor_multi_coll_scenario1() public {
    uint256[] memory collateralReserveIds = new uint256[](2);
    uint256[] memory debtReserveIds = new uint256[](2);

    collateralReserveIds[0] = _wethReserveId(spoke1);
    collateralReserveIds[1] = _usdxReserveId(spoke1);

    debtReserveIds[0] = _daiReserveId(spoke1);
    debtReserveIds[1] = _usdxReserveId(spoke1);

    _execLiqCallCloseFactorTestMulti({
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
      debtReserveIndex: 1
    });
  }

  function _assertHealthFactor(
    LiquidationTestLocalParams memory state,
    ISpoke spoke
  ) internal view {
    uint256 finalHf = spoke.getHealthFactor(alice);

    console.log('hf %e cf %e', finalHf, _getCloseFactor(spoke));

    // ensure HF is above close factor
    assertGe(finalHf, _getCloseFactor(spoke), 'Health factor >= close factor');
    // at low amounts of coll/debt, HF can diverge from close factor due to rounding/precision
    if (
      _convertAmountToBaseCurrency(state.debtReserve.assetId, state.debt.balanceAfter) >
      remainingBaseCurrencyBound &&
      _convertAmountToBaseCurrency(state.collateralReserve.assetId, state.supply.balanceAfter) >
      remainingBaseCurrencyBound
    ) {
      assertApproxEqRel(
        finalHf,
        _getCloseFactor(spoke),
        _approxRelFromBps(10),
        'HF matches closeFactor within 0.1%'
      );

      // 2.79304204108631032637e21
      // 2.793042041086310326368e21
    }
  }

  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual override returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      MIN_CLOSE_FACTOR,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 10
    );
    // uint256 increment = WadRayMath.WAD / 1e2; // assume close factor set as increments of 100 BPS

    // uint256 minTick = HEALTH_FACTOR_LIQUIDATION_THRESHOLD / increment;
    // uint256 maxTick = (5 * HEALTH_FACTOR_LIQUIDATION_THRESHOLD) / increment - 1;

    // // Bound in number of ticks
    // uint256 tick = bound(liqConfig.closeFactor / increment, minTick, maxTick);

    // Reconstruct the actual value
    // liqConfig.closeFactor = tick * increment;
    // console.log('liqConfig.closeFactor %e', liqConfig.closeFactor);
    // liqConfig.healthFactorBonusThreshold = bound(
    //   liqConfig.healthFactorBonusThreshold,
    //   1,
    //   HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    // );
    // liqConfig.liquidationBonusFactor = bound(liqConfig.liquidationBonusFactor, 0, 100_00);

    // set config to 0 so that desiredHf can be easily calculated (dependent on LB)
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorBonusThreshold = 0;

    return liqConfig;
  }

  function _execLiqCallCloseFactorTestMulti(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmountInBase,
    uint256[] memory collateralReserveIds,
    uint256[] memory debtReserveIds,
    uint256 collateralReserveIndex,
    uint256 debtReserveIndex,
    uint256 liquidationProtocolFeePercentage
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](collateralReserveIds.length);
    state.debtReserves = new DataTypes.Reserve[](debtReserveIds.length);

    for (uint256 i = 0; i < collateralReserveIds.length; i++) {
      state.collateralReserves[i] = spoke1.getReserve(collateralReserveIds[i]);
    }
    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      state.debtReserves[i] = spoke1.getReserve(debtReserveIds[i]);
    }
    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath
        .PERCENTAGE_FACTOR
        .percentDiv(state.collateralReserves[collateralReserveIndex].config.collateralFactor)
        .percentMul(90_00) // add 10% buffer so that not all debt is liquidated
    );
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);
    supplyAmountInBase = bound(supplyAmountInBase, 0.1e26, 1_000_000e26);
    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    uint256 collateralReserveId = collateralReserveIds[collateralReserveIndex];
    uint256 debtReserveId = debtReserveIds[debtReserveIndex];

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);
    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      spoke1,
      collateralReserveId,
      state.liquidationProtocolFeePercentage
    );
    uint256 desiredHf = _calcMaxAchievableHf(collateralReserveId, liqBonus).percentMul(101_00); // add 1% buffer so that not all debt is liquidated

    for (uint256 i = 0; i < collateralReserveIds.length; i++) {
      Utils.supplyCollateral({
        spoke: spoke1,
        reserveId: collateralReserveIds[i],
        user: alice,
        amount: _convertBaseCurrencyToAmount(state.collateralReserves[i].assetId, 1000e26),
        onBehalfOf: alice
      });
    }

    (
      uint256 hfAfterBorrow,
      uint256[] memory requiredDebtAmounts
    ) = _borrowMultipleReservesToBeBelowHf(spoke1, alice, debtReserveIds, desiredHf);

    state.liquidationBonus = _getVariableLiquidationBonus(
      spoke1,
      collateralReserveId,
      hfAfterBorrow
    );

    // state.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);
    // state.liquidator.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    // state.treasury.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);
    // state.supply.balanceBefore = spoke1.getUserSuppliedAmount(collateralReserveId, alice);

    console.log('debt amts: %e %e', requiredDebtAmounts[0], requiredDebtAmounts[1]);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveIds[0], alice, requiredDebtAmounts[0]);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(
      collateralReserveIds[1],
      debtReserveIds[1],
      alice,
      requiredDebtAmounts[1]
    );

    console.log('hf %e', spoke1.getHealthFactor(alice));

    // state.liquidator.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    // state.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);
    // state.treasury.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);
    // state.supply.balanceAfter = spoke1.getUserSuppliedAmount(collateralReserveId, alice);

    // vm.assume(state.supply.balanceAfter > 0 && state.debt.balanceAfter > 0);

    // // convert
    // state.liquidator.baseChange = _convertAmountToBaseCurrency(
    //   state.collateralReserve.assetId,
    //   _absDiff(state.liquidator.balanceAfter, state.liquidator.balanceBefore)
    // );
    // state.treasury.baseChange = _convertAmountToBaseCurrency(
    //   state.collateralReserve.assetId,
    //   _absDiff(state.treasury.balanceAfter, state.treasury.balanceBefore)
    // );
    // state.debt.baseChange = _convertAmountToBaseCurrency(
    //   state.debtReserve.assetId,
    //   _absDiff(state.debt.balanceBefore, state.debt.balanceAfter)
    // );
    // state.supply.baseChange = _convertAmountToBaseCurrency(
    //   state.collateralReserve.assetId,
    //   _absDiff(state.supply.balanceBefore, state.supply.balanceAfter)
    // );

    return state;
  }

  /// @notice Calc max achievable hf to be able to repay all debt and have remaining collateral
  /// allows close factor to be up to max uint
  /// @return healthFactor in WAD
  function _calcMaxAchievableHf(
    uint256 collateralReserveId,
    uint256 liquidationBonus
  ) internal view returns (uint256) {
    return
      _calcMaxAchievableHfFromCollateralFactor(
        spoke1.getCollateralFactor(collateralReserveId),
        liquidationBonus
      );
  }

  function _calcMaxAchievableHfFromCollateralFactor(
    uint256 collateralFactor,
    uint256 liquidationBonus
  ) internal view returns (uint256 healthFactor) {
    healthFactor = uint256(1e18).percentMul(collateralFactor).percentMul(liquidationBonus + 1);
  }

  function _borrowMultipleReservesToBeBelowHf(
    ISpoke spoke,
    address user,
    uint256[] memory reserveIds,
    uint256 desiredHf
  ) internal returns (uint256 finalHf, uint256[] memory requiredDebts) {
    requiredDebts = new uint256[](reserveIds.length);

    uint256 requiredDebtInBase = _getRequiredDebtForLtHf(spoke, user, desiredHf);

    uint256 remaining = requiredDebtInBase;
    uint256 dustInBase = 1e24;

    console.log('requiredDebtInBase %e', requiredDebtInBase);

    vm.startPrank(user);
    for (uint256 i = 0; i < reserveIds.length; i++) {
      uint256 assetId = spoke.getReserve(reserveIds[i]).assetId;

      uint256 amountInBase;
      // randomly find how much of each reserve to borrow
      if (i == reserveIds.length - 1) {
        // Last iteration gets whatever is left
        amountInBase = remaining;
      } else {
        amountInBase = randomizer(dustInBase, remaining - dustInBase * (reserveIds.length - i - 1));
      }

      uint256 amount = _convertBaseCurrencyToAmount(assetId, amountInBase);
      vm.assume(amount < MAX_SUPPLY_AMOUNT);
      // console.log(
      //   'amountInBase %e %e',
      //   amountInBase,
      //   _convertBaseCurrencyToAmount(assetId, amountInBase),
      //   assetId
      // );

      // mock price to 0 to circumvent borrow validation
      vm.mockCall(
        address(oracle),
        abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, assetId),
        abi.encode(0)
      );
      spoke.borrow(reserveIds[i], amount, user);
      remaining -= amountInBase;
      requiredDebts[i] = amount;
    }
    vm.stopPrank();
    vm.clearMockedCalls();

    finalHf = spoke.getHealthFactor(user);
    console.log('final hf %e | desired hf %e', finalHf, desiredHf);
    assertLt(finalHf, desiredHf);
  }
}
