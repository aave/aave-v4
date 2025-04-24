// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallCloseFactorMultiReserveTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  function test_liquidationCall_closeFactor_multi_reserve_scenario1() public {
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

    assertLe(spoke1.getHealthFactor(alice), _getCloseFactor(spoke1), 'HF <= close factor');
  }

  function test_liquidationCall_closeFactor_multi_reserve_scenario2() public {
    uint256[] memory collateralReserveIds = new uint256[](2);
    uint256[] memory debtReserveIds = new uint256[](2);

    collateralReserveIds[0] = _wethReserveId(spoke1);
    collateralReserveIds[1] = _wbtcReserveId(spoke1);

    debtReserveIds[0] = _usdyReserveId(spoke1);
    debtReserveIds[1] = _usdxReserveId(spoke1);

    _execLiqCallCloseFactorTestMulti({
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
      debtReserveIndex: 1
    });

    assertLe(spoke1.getHealthFactor(alice), _getCloseFactor(spoke1), 'HF <= close factor');
  }

  function test_liquidationCall_closeFactor_multi_reserve_scenario3() public {
    uint256[] memory collateralReserveIds = new uint256[](2);
    uint256[] memory debtReserveIds = new uint256[](2);

    collateralReserveIds[0] = _daiReserveId(spoke1);
    collateralReserveIds[1] = _usdyReserveId(spoke1);

    debtReserveIds[0] = _usdxReserveId(spoke1);
    debtReserveIds[1] = _wbtcReserveId(spoke1);

    _execLiqCallCloseFactorTestMulti({
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
      debtReserveIndex: 1
    });

    assertLe(spoke1.getHealthFactor(alice), _getCloseFactor(spoke1), 'HF <= close factor');
  }

  function test_liquidationCall_closeFactor_fuzz_multi_reserve(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 collateralReserveId1,
    uint256 collateralReserveId2,
    uint256 debtReserveId1,
    uint256 debtReserveId2,
    uint256 collateralReserveIndex,
    uint256 debtReserveIndex,
    uint256 supplyAmountInBase,
    uint256 closeFactor
  ) public {
    collateralReserveId1 = bound(collateralReserveId1, 0, spoke1.reserveCount() - 1);
    collateralReserveId2 = bound(collateralReserveId2, 0, spoke1.reserveCount() - 1);
    debtReserveId1 = bound(debtReserveId1, 0, spoke1.reserveCount() - 1);
    debtReserveId2 = bound(debtReserveId2, 0, spoke1.reserveCount() - 1);

    collateralReserveIndex = bound(collateralReserveIndex, 0, 1);
    debtReserveIndex = bound(debtReserveIndex, 0, 1);

    // simplify borrowing under HF by different mix of coll/debt
    vm.assume(collateralReserveId1 != collateralReserveId2 && debtReserveId1 != debtReserveId2);

    uint256[] memory collateralReserveIds = new uint256[](2);
    uint256[] memory debtReserveIds = new uint256[](2);

    collateralReserveIds[0] = collateralReserveId1;
    collateralReserveIds[1] = collateralReserveId2;

    debtReserveIds[0] = debtReserveId1;
    debtReserveIds[1] = debtReserveId2;

    _execLiqCallCloseFactorTestMulti({
      liqConfig: liqConfig,
      liqBonus: 105_00,
      supplyAmountInBase: supplyAmountInBase,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveIds: collateralReserveIds,
      debtReserveIds: debtReserveIds,
      collateralReserveIndex: collateralReserveIndex,
      debtReserveIndex: debtReserveIndex
    });

    assertLe(spoke1.getHealthFactor(alice), _getCloseFactor(spoke1), 'HF <= close factor');
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

    // set variable bonus config to 0 for simplicity
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
    supplyAmountInBase = bound(supplyAmountInBase, 1_00e26, 1_000_000e26); // $100 - $1M
    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    state.collateralReserveId = collateralReserveIds[collateralReserveIndex];
    state.debtReserveId = debtReserveIds[debtReserveIndex];

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);
    updateLiquidationBonus(spoke1, state.collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      spoke1,
      state.collateralReserveId,
      state.liquidationProtocolFeePercentage
    );
    state.desiredHf = _calcMaxAchievableHfWithinColl(state.collateralReserveId, liqBonus)
      .percentMul(101_00); // add 1% buffer so that not all debt is liquidated

    for (uint256 i = 0; i < collateralReserveIds.length; i++) {
      Utils.supplyCollateral({
        spoke: spoke1,
        reserveId: collateralReserveIds[i],
        user: alice,
        amount: _convertBaseCurrencyToAmount(
          state.collateralReserves[i].assetId,
          supplyAmountInBase
        ),
        onBehalfOf: alice
      });
    }

    console.log('   fuzz inputs');
    console.log('   collateralReserveIds %e', collateralReserveIds[0], collateralReserveIds[1]);
    console.log('   debtReserveIds %e', debtReserveIds[0], debtReserveIds[1]);
    console.log('   supplyAmountInBase %e', supplyAmountInBase);
    console.log('   closeFactor %e', liqConfig.closeFactor);
    console.log('   healthFactorBonusThreshold %e', liqConfig.healthFactorBonusThreshold);
    console.log('   liquidationBonusFactor %e', liqConfig.liquidationBonusFactor);
    console.log('   liqBonus %e', liqBonus);
    console.log('   liquidationProtocolFeePercentage %e', liquidationProtocolFeePercentage);
    console.log('   desiredHf %e', state.desiredHf);

    (
      uint256 hfAfterBorrow,
      uint256[] memory requiredDebtAmounts
    ) = _borrowMultipleReservesToBeBelowHf(spoke1, alice, debtReserveIds, state.desiredHf);

    // state.liquidationBonus = _getVariableLiquidationBonus(
    //   spoke1,
    //   state.collateralReserveId,
    //   hfAfterBorrow
    // );

    // // state.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);
    // // state.liquidator.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    // // state.treasury.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);
    // // state.supply.balanceBefore = spoke1.getUserSuppliedAmount(collateralReserveId, alice);

    // console.log('debt amts: %e %e', requiredDebtAmounts[0], requiredDebtAmounts[1]);

    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

      vm.startPrank(LIQUIDATOR);
      spoke1.liquidationCall(
        collateralReserveIds[i],
        debtReserveIds[i],
        alice,
        requiredDebtAmounts[i]
      );
    }

    // console.log('final hf %e %e', spoke1.getHealthFactor(alice), liqConfig.closeFactor);

    return state;
  }

  function _borrowMultipleReservesToBeBelowHf(
    ISpoke spoke,
    address user,
    uint256[] memory reserveIds,
    uint256 desiredHf
  ) internal returns (uint256 finalHf, uint256[] memory requiredDebts) {
    requiredDebts = new uint256[](reserveIds.length);

    // extra debt to ensure HF below desired
    uint256 requiredDebtInBase = _getRequiredDebtForLtHf(spoke, user, desiredHf).percentMul(100_01);

    uint256 remaining = requiredDebtInBase;
    uint256 dustInBase = 10e26;

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

      console.log('here borrow  %e %e', amountInBase, requiredDebtInBase, reserveIds[i]);
      uint256 amount = _convertBaseCurrencyToAmount(assetId, amountInBase);
      vm.assume(amount < MAX_SUPPLY_AMOUNT);
      // console.log(
      //   'amountInBase %e %e',
      //   amountInBase,
      //   _convertBaseCurrencyToAmount(assetId, amountInBase),
      //   assetId
      // );

      // console.log('final hf %e', finalHf);

      // mock price to 0 to circumvent borrow validation
      vm.mockCall(
        address(oracle),
        abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, assetId),
        abi.encode(0)
      );
      spoke.borrow(reserveIds[i], amount, user);

      // console.log('final hf %e', finalHf);

      remaining -= amountInBase;
      requiredDebts[i] = amount;
    }
    vm.clearMockedCalls();
    vm.stopPrank();

    // console.log('heref');

    finalHf = spoke.getHealthFactor(user);
    console.log('final hf %e | desired hf %e', finalHf, desiredHf);
    assertLt(finalHf, desiredHf);
  }
}
