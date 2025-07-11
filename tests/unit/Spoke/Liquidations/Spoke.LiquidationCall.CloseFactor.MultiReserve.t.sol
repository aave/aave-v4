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

    _execLiqCallCloseFactorTestMulti({
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
      skipTime: 365 days
    });

    assertLe(spoke1.getHealthFactor(alice), _getCloseFactor(spoke1), 'HF <= close factor');
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

    _execLiqCallCloseFactorTestMulti({
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
      skipTime: 365 days
    });

    assertLe(spoke1.getHealthFactor(alice), _getCloseFactor(spoke1), 'HF <= close factor');
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

    _execLiqCallCloseFactorTestMulti({
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
      skipTime: 365 days
    });

    assertLe(spoke1.getHealthFactor(alice), _getCloseFactor(spoke1), 'HF <= close factor');
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

    _execLiqCallCloseFactorTestMulti({
      liqConfig: liqConfig,
      liqBonus: 105_00,
      supplyAmountInBase: supplyAmountInBase,
      liquidationFee: 5_00,
      collateralReserveIds: collateralReserveIds,
      debtReserveIds: debtReserveIds,
      collateralReserveIndex: collateralReserveIndex,
      debtReserveIndex: debtReserveIndex,
      skipTime: skipTime
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

    // set variable bonus config to 0 for simplicity in calculating _borrowMultipleReservesToBeBelowHf
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorForMaxBonus = 0;

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
    uint256 liquidationFee,
    uint256 skipTime
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](collateralReserveIds.length);
    state.collDynConfigs = new DataTypes.DynamicReserveConfig[](collateralReserveIds.length);
    state.debtReserves = new DataTypes.Reserve[](debtReserveIds.length);

    for (uint256 i = 0; i < collateralReserveIds.length; i++) {
      state.collateralReserves[i] = spoke1.getReserve(collateralReserveIds[i]);
      state.collDynConfigs[i] = _getUserDynConfig(spoke1, alice, collateralReserveIds[i]); // utilize user's dynamic config
    }
    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      state.debtReserves[i] = spoke1.getReserve(debtReserveIds[i]);
    }
    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMathExtended
        .PERCENTAGE_FACTOR
        .percentDivDown(state.collDynConfigs[collateralReserveIndex].collateralFactor)
        .percentMulDown(99_00) // add buffer so that not all debt is liquidated
    );
    liquidationFee = bound(liquidationFee, 0, PercentageMathExtended.PERCENTAGE_FACTOR);
    supplyAmountInBase = bound(
      supplyAmountInBase,
      dustInBase * state.debtReserves.length, // enough to cover dust for all debt reserves
      MAX_SUPPLY_IN_BASE_CURRENCY / 10
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    state.liquidationFee = liquidationFee;

    state.collateralReserveId = collateralReserveIds[collateralReserveIndex];
    state.debtReserveId = debtReserveIds[debtReserveIndex];

    vm.prank(SPOKE_ADMIN);
    spoke1.updateLiquidationConfig(liqConfig);
    updateLiquidationBonus(spoke1, state.collateralReserveId, liqBonus);
    updateLiquidationFee(spoke1, state.collateralReserveId, state.liquidationFee);
    state.desiredHf = _calcLowestHfToRestoreCloseFactor(spoke1, state.collateralReserveId, liqBonus)
      .percentMulDown(101_00); // add buffer so that not all debt is liquidated

    for (uint256 i = 0; i < collateralReserveIds.length; i++) {
      uint256 supplyAmount = _convertBaseCurrencyToAmount(
        spoke1,
        state.collateralReserves[i].reserveId,
        supplyAmountInBase
      );

      if (!spoke1.getUsingAsCollateral(collateralReserveIds[i], alice)) {
        Utils.supplyCollateral({
          spoke: spoke1,
          reserveId: collateralReserveIds[i],
          user: alice,
          amount: supplyAmount,
          onBehalfOf: alice
        });
      } else {
        Utils.supply({
          spoke: spoke1,
          reserveId: collateralReserveIds[i],
          user: alice,
          amount: supplyAmount,
          onBehalfOf: alice
        });
      }
    }

    _increaseCollateralReservesSupplyExchangeRate(
      state.collateralReserves,
      supplyAmountInBase,
      skipTime,
      bob
    );

    (, uint256[] memory requiredDebtAmounts) = _borrowMultipleReservesToBeBelowHf(
      spoke1,
      alice,
      debtReserveIds,
      state.desiredHf
    );

    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
      DynamicConfig[] memory configKeysBefore = _getUserDynConfigKeys(spoke1, alice);

      vm.prank(LIQUIDATOR);
      spoke1.liquidationCall(
        collateralReserveIds[i],
        debtReserveIds[i],
        alice,
        requiredDebtAmounts[i]
      );

      // Validate user's dynamic config key unchanged after liquidation
      assertEq(_getUserDynConfigKeys(spoke1, alice), configKeysBefore);
    }

    return state;
  }

  /// @notice Borrow random amounts from multiple reserves to ensure the health factor is below the desired level.
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
    assertLt(finalHf, desiredHf, 'should borrow enough for HF to be below desiredHf');
  }

  function _increaseCollateralReservesSupplyExchangeRate(
    DataTypes.Reserve[] memory collateralReserves,
    uint256 borrowAmount,
    uint256 skipTime,
    address user
  ) internal {
    IPriceOracle oracle = spoke1.oracle();
    _addBorrowableLiquidity(borrowAmount * collateralReserves.length);

    vm.startPrank(user);
    for (uint256 i = 0; i < collateralReserves.length; i++) {
      uint256 assetId = collateralReserves[i].assetId;

      // mock price to 0 to circumvent borrow validation
      vm.mockCall(
        address(oracle),
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
  }
}
