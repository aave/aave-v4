// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallBadPremiumDebtTest is SpokeLiquidationBase {
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  /// tests where liquidation results in bad debt with premium debt > 0
  function test_liquidationCall_fuzz_badPremiumDebt(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 liquidationProtocolFeePercentage,
    uint256 skipTime,
    uint256 skipTimeToAccruePremium
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.reserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallCloseFactorBadPremiumDebtTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage,
      skipTime,
      skipTimeToAccruePremium
    );

    string memory label = 'test_liquidationCall_fuzz_badPremiumDebt';
    _checkLiquidation(state, spoke1, label);
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_badPremiumDebt_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_badPremiumDebt_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1.5e18,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_badPremiumDebt_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_badPremiumDebt_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 10e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_badPremiumDebt_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_badPremiumDebt_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_badPremiumDebt({
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1.5e18,
        liquidationBonusFactor: 0,
        healthFactorBonusThreshold: 0
      }),
      liqBonus: 105_00,
      supplyAmount: 1_000e6,
      liquidationProtocolFeePercentage: 5_00,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      skipTime: 365 days,
      skipTimeToAccruePremium: 365 days * 4
    });
  }

  /// bound liqConfig close factor, with static liquidation bonus
  /// use constant liquidation bonus to simplify calcs for desiredHf
  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual override returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      MIN_CLOSE_FACTOR,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 10
    );

    // set constant liquidation bonus to simplify calcs for desiredHf
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorBonusThreshold = 0;

    return liqConfig;
  }

  /// fuzz tests to make sure bad debt remains after liquidation
  /// single debt reserve, single collateral reserve
  /// user health factor position is lower than threshold -> liquidating all collateral is insufficient to cover debt
  /// close factor varies across range of values
  /// constant liquidation bonus
  function _execLiqCallCloseFactorBadPremiumDebtTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFeePercentage,
    uint256 skipTime,
    uint256 skipTimeForPremiumAccrual
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](1);
    state.debtReserves = new DataTypes.Reserve[](1);

    state.collateralReserves[state.collateralReserveIndex] = spoke1.getReserve(collateralReserveId);
    state.debtReserves[state.debtReserveIndex] = spoke1.getReserve(debtReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath.PERCENTAGE_FACTOR.percentDiv(
        state.collateralReserves[state.collateralReserveIndex].config.collateralFactor
      )
    );
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(
        state.collateralReserves[state.collateralReserveIndex].assetId,
        10e26
      ),
      _convertBaseCurrencyToAmount(
        state.collateralReserves[state.collateralReserveIndex].assetId,
        1e36
      )
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    skipTimeForPremiumAccrual = bound(skipTimeForPremiumAccrual, 5 * 365 days, MAX_SKIP_TIME); // enough time to accrue debt so that HF is liquidatable

    state.spoke = spoke1;
    state.user = alice;
    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    // set spoke liq config
    state.spoke.updateLiquidationConfig(liqConfig);
    updateLiquidationBonus(state.spoke, collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      state.spoke,
      collateralReserveId,
      state.liquidationProtocolFeePercentage
    );

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

    _increaseCollateralReserveSupplyExchangeRate(
      state.spoke,
      state.collateralReserves[state.collateralReserveIndex].assetId,
      collateralReserveId,
      supplyAmount / 2,
      skipTime,
      bob
    );

    // borrow some amount of debt reserve to end up below hf threshold
    (uint256 hfAfterBorrow, uint256 requiredDebtAmount) = _borrowToBeAboveHealthyHf(
      state.spoke,
      alice,
      debtReserveId,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    state.liquidationBonus = _getVariableLiquidationBonus(
      state.spoke,
      collateralReserveId,
      hfAfterBorrow
    );

    skip(skipTimeForPremiumAccrual);
    // ensure that debt accrued causes liquidatable position
    vm.assume(state.spoke.getHealthFactor(alice) < hfBadDebtThreshold);

    // (uint256 rp, , uint256 hf, , ) = state.spoke.getUserAccountData(alice);
    // (uint256 baseDebt, uint256 premiumDebt) = state.spoke.getUserDebt(debtReserveId, alice);

    // console.log('rp %e debt %e %e', rp, baseDebt, premiumDebt);
    // console.log('hf %e', hf);

    // assertLt(hf, hfBadDebtThreshold, 'HF should result in bad debt');
    state = _getAccountingInfoBeforeLiq(state);

    assertGt(state.premiumDebt.balanceBefore, 0, 'premium debt should be > 0 before liquidation');

    (
      state.collToLiq,
      state.debtToLiq,
      state.liqProtocolFee,

    ) = _calculateAvailableCollateralToLiquidate(state.spoke, state, UINT256_MAX);

    // logs to read protocol fee from tmp emitted event
    // TODO: update when treasury accounting is done
    vm.recordLogs();

    console.log(
      'emit deficit %s %s %e',
      address(state.spoke),
      state.debtReserves[state.debtReserveIndex].assetId,
      state.totalDebt.balanceBefore - state.debtToLiq
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DeficitCreated(
      address(state.spoke),
      state.debtReserves[state.debtReserveIndex].assetId,
      state.totalDebt.balanceBefore - state.debtToLiq // outstanding debt which becomes bad debt reported as deficit
    );
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
