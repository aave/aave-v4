// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

/// tests with bad debt across multiple reserves that includes accrued premium debt
contract LiquidationCallMultiReserveBadPremiumDebtTest is SpokeLiquidationBase {
  using PercentageMathExtended for uint256;

  struct BorrowMultipleReservesToBeAboveHealthyHf {
    uint256 requiredDebtInBase;
    uint256 remaining;
  }

  /// @dev coll: weth; bad debt: wbtc, dai, usdx
  /// deficit covers base debt and premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario1_base_and_premium() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario1({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4,
      debtReserveIndex: 0
    });
  }

  /// @dev coll: weth; bad debt: wbtc, dai, usdx
  /// deficit only covers premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario1_only_premium() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario1({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days,
      debtReserveIndex: 0
    });
  }

  /// fuzz test - bad debt: wbtc, dai, usdx
  function test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario1(
    uint256 collateralReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFee,
    uint256 skipTime,
    uint256 skipTimeToAccruePremium,
    uint256 debtReserveIndex
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);

    uint256[] memory debtReserveIds = new uint256[](3);
    // debtReserveIds must be in ascending order for event emission assertions
    debtReserveIds[0] = _wbtcReserveId(spoke1);
    debtReserveIds[1] = _daiReserveId(spoke1);
    debtReserveIds[2] = _usdxReserveId(spoke1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorMultiAssetBadPremiumDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveIds,
      debtReserveIndex,
      liquidationProtocolFee,
      skipTime,
      skipTimeToAccruePremium
    );

    string
      memory label = 'test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario1_only_premium';
    console.log(state.hasDeficit);

    _checkLiquidation(state, label);
    _checkDeficits(state, debtReserveIds, alice);
  }

  /// coll: weth; bad debt: wbtc, dai, usdx
  /// deficit covers base debt and premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario2_only_premium() public {
    uint256 collateralReserveId = _wbtcReserveId(spoke1);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario2({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4,
      debtReserveIndex: 0
    });
  }

  /// coll: weth; bad debt: wbtc, dai, usdx
  /// deficit covers only premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario2_base_and_premium() public {
    uint256 collateralReserveId = _wbtcReserveId(spoke1);

    // update to a high liquidity premium so that even after liquidating all collateral, both base/premium debt remains
    updateLiquidityPremium(spoke1, collateralReserveId, 100_00);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario2({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 2,
      debtReserveIndex: 0
    });
  }

  /// fuzz test - bad debt: weth, wbtc, usdy
  function test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario2(
    uint256 collateralReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFee,
    uint256 skipTime,
    uint256 skipTimeToAccruePremium,
    uint256 debtReserveIndex
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);

    uint256[] memory debtReserveIds = new uint256[](3);
    // debtReserveIds must be in ascending order for event emission assertions
    debtReserveIds[0] = _wethReserveId(spoke1);
    debtReserveIds[1] = _wbtcReserveId(spoke1);
    debtReserveIds[2] = _usdyReserveId(spoke1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorMultiAssetBadPremiumDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveIds,
      debtReserveIndex,
      liquidationProtocolFee,
      skipTime,
      skipTimeToAccruePremium
    );

    string memory label = 'test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario2';
    _checkLiquidation(state, label);
    _checkDeficits(state, debtReserveIds, alice);
  }

  /// coll: usdy; bad debt: dai, usdx, usdy
  /// deficit covers base debt and premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario3_base_and_premium() public {
    uint256 collateralReserveId = _usdyReserveId(spoke1);

    // update to a high liquidity premium so that even after liquidating all collateral, both base/premium debt remains
    updateLiquidityPremium(spoke1, collateralReserveId, 100_00);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario3({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4,
      debtReserveIndex: 0
    });
  }

  /// coll: usdy; bad debt: dai, usdx, usdy
  /// deficit covers only premium debt
  function test_liquidationCall_multi_reserve_badPremiumDebt_scenario3_only_premium() public {
    uint256 collateralReserveId = _usdyReserveId(spoke1);

    test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario3({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorForMaxBonus: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFee: 5_00,
      collateralReserveId: collateralReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4,
      debtReserveIndex: 0
    });
  }

  /// fuzz test - bad debt: dai, usdx, usdy
  function test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario3(
    uint256 collateralReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFee,
    uint256 skipTime,
    uint256 skipTimeToAccruePremium,
    uint256 debtReserveIndex
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);

    uint256[] memory debtReserveIds = new uint256[](3);
    // debtReserveIds must be in ascending order for event emission assertions
    debtReserveIds[0] = _daiReserveId(spoke1);
    debtReserveIds[1] = _usdxReserveId(spoke1);
    debtReserveIds[2] = _usdyReserveId(spoke1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorMultiAssetBadPremiumDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveIds,
      debtReserveIndex,
      liquidationProtocolFee,
      skipTime,
      skipTimeToAccruePremium
    );

    string memory label = 'test_liquidationCall_fuzz_multi_reserve_badPremiumDebt_scenario3';
    _checkLiquidation(state, label);
    _checkDeficits(state, debtReserveIds, alice);
  }

  /// execute fuzz tests with bad debt across multiple debt reserves
  /// multiple debt reserves, single collateral reserve
  /// liquidating all collateral is insufficient to cover debt, bad debt remains
  /// close factor varies across range of values
  /// non-variable liquidation bonus
  function _execLiqCallCloseFactorMultiAssetBadPremiumDebtTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256[] memory debtReserveIds,
    uint256 debtReserveIndex,
    uint256 liquidationProtocolFee,
    uint256 skipTime,
    uint256 skipTimeForPremiumAccrual
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](1);

    state.spoke = spoke1;

    state.collateralReserves[state.collateralReserveIndex] = state.spoke.getReserve(
      collateralReserveId
    );
    state.debtReserveIndex = bound(debtReserveIndex, 0, debtReserveIds.length - 1);
    state.debtReserves = new DataTypes.Reserve[](debtReserveIds.length);
    state.collDynConfig = state.spoke.getDynamicReserveConfig(collateralReserveId);

    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      state.debtReserves[i] = state.spoke.getReserve(debtReserveIds[i]);
    }

    liqConfig = _boundCloseFactor(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath.PERCENTAGE_FACTOR.percentDivDown(state.collDynConfig.collateralFactor)
    );
    liquidationProtocolFee = bound(liquidationProtocolFee, 0, 100_00);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(
        state.spoke,
        state.collateralReserves[state.collateralReserveIndex].reserveId,
        10e26
      ),
      _convertBaseCurrencyToAmount(
        state.spoke,
        state.collateralReserves[state.collateralReserveIndex].reserveId,
        1e36
      )
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    skipTimeForPremiumAccrual = bound(skipTimeForPremiumAccrual, 365 days, MAX_SKIP_TIME); // enough time to accrue debt so that HF is liquidatable

    state.liquidationProtocolFee = liquidationProtocolFee;
    state.user = alice;

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
    // calculate lowest HF where there is sufficient collateral to cover debt
    // below this value results in bad debt
    uint256 hfBadDebtThreshold = _calcLowestHfForBadDebt(state.spoke, alice, liqBonus);

    _increaseReserveSupplyExchangeRate(
      state.spoke,
      collateralReserveId,
      supplyAmount / 2,
      skipTime,
      bob
    );

    // borrow some amount of debt reserve to end up below hf threshold
    _borrowMultipleReservesToBeAboveHealthyHf(
      state.spoke,
      alice,
      debtReserveIds,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );
    // skip time to accrue premium debt
    skip(skipTimeForPremiumAccrual);

    state = _getAccountingInfoBeforeLiq(state);

    state.liquidationBonus = _getVariableLiquidationBonus(
      spoke1,
      collateralReserveId,
      state.initialHf
    );

    vm.assume(
      state.spoke.getHealthFactor(alice) < hfBadDebtThreshold &&
        _convertAmountToBaseCurrency(
          state.spoke,
          state.debtReserves[state.debtReserveIndex].reserveId,
          state.spoke.getUserTotalDebt(state.debtReserves[state.debtReserveIndex].reserveId, alice)
        ) >
        state.totalCollateralInBaseCurrency.balanceBefore
    );

    assertGt(state.premiumDebt.balanceBefore, 0, 'premium debt should be > 0 before liquidation');

    (
      state.collToLiq,
      state.debtToLiq,
      state.liqProtocolFee,
      ,

    ) = _calculateAvailableCollateralToLiquidate(state, UINT256_MAX);

    // logs to read protocol fee from tmp emitted event
    // TODO: update when treasury accounting is done
    vm.recordLogs();

    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      if (debtReserveIds[i] != state.debtReserves[state.debtReserveIndex].reserveId) {
        uint256 reserveId = debtReserveIds[i];
        uint256 assetId = state.debtReserves[i].assetId;

        uint256 expectedShares;
        uint256 expectedDeficit;

        // for debt asset being liquidated, some debt is restored prior to deficit creation
        if (reserveId == state.debtReserves[state.debtReserveIndex].reserveId) {
          (uint256 basedDebtRestored, uint256 premDebtRestored) = _calculateExactRestoreAmount(
            state.baseDebt.balanceBefore,
            state.premiumDebt.balanceBefore,
            state.debtToLiq,
            assetId
          );

          // debt asset deficit shares are the initial amount minus the amount restored during liquidation
          expectedShares =
            state.spoke.getUserPosition(reserveId, alice).baseDrawnShares -
            hub.convertToDrawnShares(assetId, basedDebtRestored);
          // total debt asset deficit is the expected base debt and remaining premium debt after settlement during liquidation
          expectedDeficit =
            hub.convertToDrawnAssets(assetId, expectedShares) +
            state.premiumDebt.balanceBefore -
            premDebtRestored;
        } else {
          expectedShares = state.spoke.getUserPosition(reserveId, alice).baseDrawnShares;
          expectedDeficit = state.spoke.getUserTotalDebt(reserveId, alice);
        }

        vm.expectEmit(address(hub));
        emit ILiquidityHub.DeficitCreated(
          assetId,
          address(state.spoke),
          expectedShares,
          expectedDeficit
        );
      }
    }
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
      collateralReserveId,
      debtReserveIds[state.debtReserveIndex],
      alice,
      UINT256_MAX
    );

    state = _getAccountingInfoAfterLiq(state);

    return state;
  }

  /// @notice Borrow random amounts from multiple reserves to ensure the health factor is above the desired HF
  /// validates HF, therefore it must be a healthy HF
  function _borrowMultipleReservesToBeAboveHealthyHf(
    ISpoke spoke,
    address user,
    uint256[] memory reserveIds,
    uint256 desiredHf
  ) internal returns (uint256 finalHf, uint256[] memory requiredDebts) {
    BorrowMultipleReservesToBeAboveHealthyHf memory vars;
    requiredDebts = new uint256[](reserveIds.length);

    // extra debt to ensure HF below desired
    vars.requiredDebtInBase = _getRequiredDebtForGtHf(spoke, user, desiredHf);
    vars.remaining = vars.requiredDebtInBase;
    // make sure that each reserve has at least dustInBase in debt
    uint256 dustInBase = 1e26;

    // mock with high base borrow rate so that less time must be skipped to reach desired HF
    _mockInterestRate(500_00);

    vm.startPrank(user);
    for (uint256 i = 0; i < reserveIds.length; i++) {
      uint256 assetId = spoke.getReserve(reserveIds[i]).assetId;

      uint256 amountInBase;
      // randomly distribute total required debt across debt reserves
      if (i == reserveIds.length - 1) {
        // Last iteration, borrow remaining amount
        amountInBase = vars.remaining;
      } else {
        amountInBase = randomizer(
          dustInBase,
          vars.remaining - dustInBase * (reserveIds.length - i - 1)
        );
      }

      uint256 amount = _convertBaseCurrencyToAmount(spoke, reserveIds[i], amountInBase);
      vm.assume(amount < MAX_SUPPLY_AMOUNT);

      spoke.borrow(reserveIds[i], amount, user);

      vars.remaining -= amountInBase;
      requiredDebts[i] = amount;
    }
    vm.stopPrank();

    (, , finalHf, , ) = spoke.getUserAccountData(user);
    assertGt(finalHf, desiredHf, 'should borrow enough for HF to be above desiredHf');
  }

  /// @notice Check deficit accounting for all debt reserves
  function _checkDeficits(
    LiquidationTestLocalParams memory state,
    uint256[] memory debtReserveIds,
    address user
  ) internal view {
    for (uint256 i = 0; i < debtReserveIds.length; i++) {
      assertEq(
        state.spoke.getUserTotalDebt(debtReserveIds[i], user),
        0,
        'remaining debt should be 0 (reported as deficit)'
      );
      if (i != state.debtReserveIndex) {
        assertEq(
          state.deficits[i].balanceChange,
          state.debts[i].balanceChange,
          'for other debt assets, total debt should be reported as deficit'
        );
      }
    }
  }
}
