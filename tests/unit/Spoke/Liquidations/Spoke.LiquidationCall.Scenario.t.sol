// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

// todo: tests with liquidator instead of bob

contract LiquidationCallScenarioTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  struct UserTokenBalance {
    TokenBalance alice;
    TokenBalance bob;
    TokenBalance treasury;
  }

  struct TokenBalance {
    uint256 wbtc;
    uint256 weth;
    uint256 dai;
    uint256 usdx;
    uint256 usdy;
  }

  struct Amount {
    uint256 wbtc;
    uint256 weth;
    uint256 dai;
    uint256 usdx;
  }

  struct LiqTestData {
    uint256 daiReserveId;
    uint256 wethReserveId;
    uint256 usdxReserveId;
    uint256 wbtcReserveId;
    Amount[5] colls;
    Amount[5] debts;
    uint256 collateralFactor;
    uint256 closeFactor;
    uint256 liqBonus;
    uint256 initialDebt;
    uint256 liquidatedDebt;
  }

  struct LiqScenarioTestData {
    uint256 daiReserveId;
    uint256 wethReserveId;
    uint256 usdxReserveId;
    uint256 wbtcReserveId;
    Amount collAmount;
    Amount debtAmount;
    Balance debt;
    Balance supply;
    Balance liquidator;
    Balance liquidatorCollateral;
    Balance user;
    uint256 collateralFactor;
    uint256 closeFactor;
    uint256 liqBonus;
    uint256 initialDebt;
    uint256 liquidatedDebt;
    uint256 healthFactor;
    uint256 userRp;
    DataTypes.UserPosition wbtcPosition;
    DataTypes.UserPosition wethPosition;
  }

  /// liquidation with realized premium accounting
  function test_liquidationCall_debt_realized_premium() public {
    LiqScenarioTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    state.liqBonus = spoke1.getReserve(state.wbtcReserveId).config.liquidationBonus;

    // collateral: wbtc/dai
    state.collAmount.wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.collAmount.dai = 10_000 * 10 ** decimals.dai; // $10k dai
    // debt: weth
    state.debtAmount.weth = 20 * 10 ** decimals.weth; // 20 eth, $40k

    // simplify accounting checks with no fee or bonus
    updateLiquidationProtocolFeePercentage(spoke1, state.wbtcReserveId, 0);
    updateLiquidationBonus(spoke1, state.wbtcReserveId, 100_00);

    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.collAmount.wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.collAmount.dai, alice);
    Utils.borrow(spoke1, state.wethReserveId, alice, state.debtAmount.weth, alice);

    // interest accrual
    skip(365 days);

    // borrow action to realize premium
    _borrowWithoutHfCheck(spoke1, alice, state.wethReserveId, state.debtAmount.weth);

    // position must be liquidatable
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    (, uint256 premiumDebt) = spoke1.getUserDebt(state.wethReserveId, alice);

    // premium debt exists and is realized
    assertGt(premiumDebt, 0);
    assertGt(spoke1.getUserPosition(state.wethReserveId, alice).realizedPremium, 0);

    state.liquidatorCollateral.balanceBefore = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    state.liquidator.balanceBefore = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    state.supply.balanceBefore = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    state.debt.balanceBefore = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: MAX_SUPPLY_AMOUNT
    });

    state.liquidatorCollateral.balanceAfter = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    state.liquidator.balanceAfter = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    state.supply.balanceAfter = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    state.debt.balanceAfter = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    assertApproxEqAbs(
      _absDiff(state.liquidator.balanceAfter, state.liquidator.balanceBefore),
      _absDiff(state.debt.balanceAfter, state.debt.balanceBefore),
      2,
      'liquidator repaid debt amount and restored debt accounting'
    );
    assertEq(
      _absDiff(state.liquidatorCollateral.balanceAfter, state.liquidatorCollateral.balanceBefore),
      state.collAmount.wbtc,
      'liquidator collateral earned'
    );

    state.wbtcPosition = spoke1.getUserPosition(state.wbtcReserveId, alice);
    state.wethPosition = spoke1.getUserPosition(state.wethReserveId, alice);
    (state.userRp, , state.healthFactor, , ) = spoke1.getUserAccountData(alice);

    assertEq(
      state.wbtcPosition.baseDrawnShares.percentMul(state.userRp),
      state.wbtcPosition.premiumDrawnShares,
      'collateral reserve accounting refresh'
    );
    assertEq(
      state.wethPosition.baseDrawnShares.percentMul(state.userRp),
      state.wethPosition.premiumDrawnShares,
      'debt reserve accounting refresh'
    );

    assertLe(state.healthFactor, _getCloseFactor(spoke1), 'hf <= close factor');
  }

  /// liquidation with realized premium accounting
  function test_liquidationCall_fuzz_debt_realized_premium(uint256 skipTime) public {
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    LiqScenarioTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    state.liqBonus = spoke1.getReserve(state.wbtcReserveId).config.liquidationBonus;

    // collateral: wbtc/dai
    state.collAmount.wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.collAmount.dai = 10_000 * 10 ** decimals.dai; // $10k dai
    // debt: weth
    state.debtAmount.weth = 20 * 10 ** decimals.weth; // 20 eth, $40k

    // simplify accounting checks with no fee or bonus
    updateLiquidationProtocolFeePercentage(spoke1, state.wbtcReserveId, 0);
    updateLiquidationBonus(spoke1, state.wbtcReserveId, 100_00);

    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.collAmount.wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.collAmount.dai, alice);
    Utils.borrow(spoke1, state.wethReserveId, alice, state.debtAmount.weth, alice);

    // interest accrual
    skip(skipTime);

    // borrow action to realize premium
    _borrowWithoutHfCheck(spoke1, alice, state.wethReserveId, state.debtAmount.weth);

    // position must be liquidatable
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    (, uint256 premiumDebt) = spoke1.getUserDebt(state.wethReserveId, alice);

    // premium debt exists and is realized
    assertGt(premiumDebt, 0);
    assertGt(spoke1.getUserPosition(state.wethReserveId, alice).realizedPremium, 0);

    state.liquidatorCollateral.balanceBefore = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    state.liquidator.balanceBefore = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    state.supply.balanceBefore = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    state.debt.balanceBefore = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: MAX_SUPPLY_AMOUNT
    });

    state.liquidatorCollateral.balanceAfter = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    state.liquidator.balanceAfter = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    state.supply.balanceAfter = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    state.debt.balanceAfter = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    assertApproxEqAbs(
      _absDiff(state.liquidator.balanceAfter, state.liquidator.balanceBefore),
      _absDiff(state.debt.balanceAfter, state.debt.balanceBefore),
      4, // max delta too large?
      'liquidator repaid debt amount and restored debt accounting (donation)'
    );
    assertEq(
      _absDiff(state.liquidatorCollateral.balanceAfter, state.liquidatorCollateral.balanceBefore),
      state.collAmount.wbtc,
      'liquidator collateral earned'
    );

    state.wbtcPosition = spoke1.getUserPosition(state.wbtcReserveId, alice);
    state.wethPosition = spoke1.getUserPosition(state.wethReserveId, alice);
    (state.userRp, , state.healthFactor, , ) = spoke1.getUserAccountData(alice);

    assertEq(
      state.wbtcPosition.baseDrawnShares.percentMul(state.userRp),
      state.wbtcPosition.premiumDrawnShares,
      'collateral reserve accounting refresh'
    );
    assertEq(
      state.wethPosition.baseDrawnShares.percentMul(state.userRp),
      state.wethPosition.premiumDrawnShares,
      'debt reserve accounting refresh'
    );

    assertLe(state.healthFactor, _getCloseFactor(spoke1), 'hf <= close factor');
  }

  /// liquidation call with HF < 1 due to accrued interest
  function test_liquidationCall_accrued_interest() public {
    LiqScenarioTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // collateral: wbtc/dai
    state.collAmount.wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.collAmount.dai = 10_000 * 10 ** decimals.dai; // $10k dai

    state.liqBonus = spoke1.getReserve(state.wbtcReserveId).config.liquidationBonus;

    // simplify accounting checks with no fee or bonus
    updateLiquidationProtocolFeePercentage(spoke1, state.wbtcReserveId, 0);
    updateLiquidationBonus(spoke1, state.wbtcReserveId, 100_00);

    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.collAmount.wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.collAmount.dai, alice);
    _borrowToBeBelowHf(spoke1, alice, state.wethReserveId, 1.001e18);

    // position must initially be healthy
    assertGt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // interest accrual
    skip(365 days);

    // position must be liquidatable after interest accrual
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    state.liquidatorCollateral.balanceBefore = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    state.liquidator.balanceBefore = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    state.supply.balanceBefore = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    state.debt.balanceBefore = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: state.debt.balanceBefore + 1
    });

    state.liquidatorCollateral.balanceAfter = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    state.liquidator.balanceAfter = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    state.supply.balanceAfter = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    state.debt.balanceAfter = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    assertApproxEqAbs(
      _absDiff(state.liquidator.balanceAfter, state.liquidator.balanceBefore),
      _absDiff(state.debt.balanceAfter, state.debt.balanceBefore),
      2,
      'liquidator repaid debt amount and restored debt accounting'
    );

    state.wbtcPosition = spoke1.getUserPosition(state.wbtcReserveId, alice);
    state.wethPosition = spoke1.getUserPosition(state.wethReserveId, alice);
    (state.userRp, , state.healthFactor, , ) = spoke1.getUserAccountData(alice);

    assertEq(
      state.wbtcPosition.baseDrawnShares.percentMul(state.userRp),
      state.wbtcPosition.premiumDrawnShares,
      'collateral reserve accounting refresh'
    );
    assertEq(
      state.wethPosition.baseDrawnShares.percentMul(state.userRp),
      state.wethPosition.premiumDrawnShares,
      'debt reserve accounting is refresh'
    );

    assertLe(state.healthFactor, _getCloseFactor(spoke1), 'hf <= close factor');
  }

  /// liquidation call with HF < 1 due to accrued interest
  function test_liquidationCall_fuzz_accrued_interest(uint256 skipTime) public {
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    LiqScenarioTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // collateral: wbtc/dai
    state.collAmount.wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.collAmount.dai = 10_000 * 10 ** decimals.dai; // $10k dai

    state.liqBonus = spoke1.getReserve(state.wbtcReserveId).config.liquidationBonus;

    // simplify accounting checks with no fee or bonus
    updateLiquidationProtocolFeePercentage(spoke1, state.wbtcReserveId, 0);
    updateLiquidationBonus(spoke1, state.wbtcReserveId, 100_00);

    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.collAmount.wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.collAmount.dai, alice);
    _borrowToBeBelowHf(spoke1, alice, state.wethReserveId, 1.001e18);

    // position must initially be healthy
    assertGt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // interest accrual
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(50_00).bpsToRay())
    );
    skip(skipTime);

    // position must be liquidatable after interest accrual
    vm.assume(spoke1.getHealthFactor(alice) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    state.liquidatorCollateral.balanceBefore = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    state.liquidator.balanceBefore = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    state.supply.balanceBefore = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    state.debt.balanceBefore = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: MAX_SUPPLY_AMOUNT
    });

    state.liquidatorCollateral.balanceAfter = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    state.liquidator.balanceAfter = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    state.supply.balanceAfter = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    state.debt.balanceAfter = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    assertApproxEqAbs(
      _absDiff(state.liquidator.balanceAfter, state.liquidator.balanceBefore),
      _absDiff(state.debt.balanceAfter, state.debt.balanceBefore),
      4, // max delta too large?
      'liquidator repaid debt amount and restored debt accounting'
    );

    state.wbtcPosition = spoke1.getUserPosition(state.wbtcReserveId, alice);
    state.wethPosition = spoke1.getUserPosition(state.wethReserveId, alice);
    (state.userRp, , state.healthFactor, , ) = spoke1.getUserAccountData(alice);

    assertEq(
      state.wbtcPosition.baseDrawnShares.percentMul(state.userRp),
      state.wbtcPosition.premiumDrawnShares,
      'collateral reserve accounting refresh'
    );
    assertEq(
      state.wethPosition.baseDrawnShares.percentMul(state.userRp),
      state.wethPosition.premiumDrawnShares,
      'debt reserve accounting is refresh'
    );

    assertLe(state.healthFactor, _getCloseFactor(spoke1), 'hf <= close factor');
  }

  /// liquidation call does not allow arbitrarily large debtToCover
  function test_liquidationCall_maxDebtToCover() public {
    LiqScenarioTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // collateral: wbtc/dai
    state.collAmount.wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.collAmount.dai = 10_000 * 10 ** decimals.dai; // $10k dai

    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.collAmount.wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.collAmount.dai, alice);
    _borrowToBeBelowHf(spoke1, alice, state.wethReserveId, 1.001e18); // user position is initially healthy

    // position must initially be healthy
    assertGt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    // interest accrual
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(50_00).bpsToRay())
    );
    skip(365 days);

    // position must be liquidatable after interest accrual
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    state.liquidatorCollateral.balanceBefore = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    state.liquidator.balanceBefore = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    state.supply.balanceBefore = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    state.debt.balanceBefore = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: state.debt.balanceBefore + 1
    });

    state.liquidator.balanceAfter = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    state.debt.balanceAfter = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    assertApproxEqAbs(
      _absDiff(state.liquidator.balanceAfter, state.liquidator.balanceBefore),
      _absDiff(state.debt.balanceAfter, state.debt.balanceBefore),
      2,
      'liquidator repaid debt amount and restored debt accounting'
    );
    assertLe(
      _absDiff(state.liquidator.balanceAfter, state.liquidator.balanceBefore),
      state.debt.balanceBefore,
      'liquidator can only liquidate enough debt to cover position'
    );
    assertLe(spoke1.getHealthFactor(alice), _getCloseFactor(spoke1), 'hf <= close factor');
  }

  /// scenario where fully liquidating all collateral still does not improve a position to close factor
  function test_liquidationCall_all_collateral() public {
    LiqTestData memory state;

    Balance memory aliceDai;
    Balance memory liquidatorDai;
    Balance memory aliceWeth;
    Balance memory liquidatorWeth;
    Balance memory aliceWbtc;
    Balance memory liquidatorWbtc;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // collateral: wbtc/dai
    state.colls[0].wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.colls[0].dai = 10_000 * 10 ** decimals.dai; // $10k dai
    // debt: weth
    state.debts[0].weth = 20 * 10 ** decimals.weth; // 20 eth, $40k

    state.liqBonus = spoke1.getReserve(state.wbtcReserveId).config.liquidationBonus;

    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.colls[0].wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.colls[0].dai, alice);
    Utils.borrow(spoke1, state.wethReserveId, alice, state.debts[0].weth, alice);

    // wbtc collateral value drop to reduce HF < 1
    oracle.setAssetPrice(wbtcAssetId, 20_000e8);

    // position is liquidatable
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    state.initialDebt = spoke1.getUserTotalDebt(state.wethReserveId, alice);
    state.liquidatedDebt = _convertAssetAmount(wbtcAssetId, state.colls[0].wbtc, wethAssetId)
      .percentDiv(state.liqBonus);

    aliceDai.balanceBefore = tokenList.dai.balanceOf(alice);
    liquidatorDai.balanceBefore = tokenList.dai.balanceOf(LIQUIDATOR);

    aliceWeth.balanceBefore = tokenList.weth.balanceOf(alice);
    liquidatorWeth.balanceBefore = tokenList.weth.balanceOf(LIQUIDATOR);

    aliceWbtc.balanceBefore = tokenList.wbtc.balanceOf(alice);
    liquidatorWbtc.balanceBefore = tokenList.wbtc.balanceOf(LIQUIDATOR);

    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationCall(
      address(tokenList.wbtc),
      address(tokenList.weth),
      alice,
      state.liquidatedDebt,
      state.colls[0].wbtc,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: state.debts[0].weth
    });

    aliceDai.balanceAfter = tokenList.dai.balanceOf(alice);
    liquidatorDai.balanceAfter = tokenList.dai.balanceOf(LIQUIDATOR);

    aliceWeth.balanceAfter = tokenList.weth.balanceOf(alice);
    liquidatorWeth.balanceAfter = tokenList.weth.balanceOf(LIQUIDATOR);

    aliceWbtc.balanceAfter = tokenList.wbtc.balanceOf(alice);
    liquidatorWbtc.balanceAfter = tokenList.wbtc.balanceOf(LIQUIDATOR);

    // dai collateral
    assertEq(
      spoke1.getUserSuppliedAmount(state.daiReserveId, alice),
      state.colls[0].dai,
      'alice dai coll unchanged'
    );
    assertEq(_absDiff(aliceDai.balanceAfter, aliceDai.balanceBefore), 0, 'alice has no dai change');
    assertEq(
      _absDiff(liquidatorDai.balanceAfter, liquidatorDai.balanceBefore),
      0,
      'liquidator receives 0 dai coll'
    );

    // wbtc collateral
    assertEq(
      spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice),
      0,
      'alice wbtc coll liquidated'
    );
    assertEq(
      _absDiff(aliceWbtc.balanceAfter, aliceWbtc.balanceBefore),
      0,
      'alice has no wbtc change'
    );
    assertEq(
      _absDiff(liquidatorWbtc.balanceAfter, liquidatorWbtc.balanceBefore),
      state.colls[0].wbtc,
      'liquidator receives all wbtc coll'
    );

    // weth debt
    assertEq(
      state.initialDebt - spoke1.getUserTotalDebt(state.wethReserveId, alice),
      state.liquidatedDebt,
      'alice weth debt repaid'
    );
    assertEq(
      _absDiff(aliceWeth.balanceAfter, aliceWeth.balanceBefore),
      0,
      'alice has no weth change'
    );
    assertEq(
      _absDiff(liquidatorWeth.balanceAfter, liquidatorWeth.balanceBefore),
      state.liquidatedDebt,
      'liquidator pays all weth debt'
    );

    (uint256 userRP, uint256 avgCollFactor, uint256 healthFactor, , ) = spoke1.getUserAccountData(
      alice
    );

    // final collateral factor and RP only depends on remaining dai collateral
    assertEq(
      userRP,
      spoke1.getReserve(state.daiReserveId).config.liquidityPremium,
      'userRP matches lp of dai coll'
    );
    assertEq(
      avgCollFactor.dewadify(),
      spoke1.getReserve(state.daiReserveId).config.collateralFactor,
      'avg coll factor matches dai coll factor'
    );
    // hf < 1 after
    assertLt(healthFactor, HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
  }

  function setUpScenario2() internal {
    updateCollateralFactor(spoke1, _daiReserveId(spoke1), 85_00);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 74_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 78_00);

    updateLiquidationBonus(spoke1, _daiReserveId(spoke1), 104_00);
    updateLiquidationBonus(spoke1, _wethReserveId(spoke1), 106_00);
    updateLiquidationBonus(spoke1, _usdxReserveId(spoke1), 108_00);
  }

  function test_liquidationCall_multi_coll() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    // collateral: weth/dai
    uint256 wethAmount = 10 * 10 ** decimals.weth; // $20k wbtc
    uint256 daiAmount = 10_000 * 10 ** decimals.dai; // $10k dai
    // debt: usdx
    uint256 borrowAmount = 15_000 * 10 ** decimals.usdx; // $15k usdx

    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, daiReserveId, alice, daiAmount, alice);
    Utils.borrow(spoke1, usdxReserveId, alice, borrowAmount, alice);

    oracle.setAssetPrice(wethAssetId, 400e8);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(daiReserveId, usdxReserveId, alice, borrowAmount);

    assertLe(spoke1.getHealthFactor(alice), _getCloseFactor(spoke1), 'hf <= close factor');
  }

  // working correctly with usdx=6, dai=18, weth=18, but HF > 1 after
  function test_liquidationCall_multi_coll2() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);

    // collateral: weth/usdx
    uint256 wethAmount = 10 * 10 ** decimals.weth; // $20k wbtc
    uint256 usdxAmount = 10_000 * 10 ** decimals.usdx; // $10k usdx
    // debt: dai
    uint256 borrowAmount = 15_000 * 10 ** decimals.dai; // $15k dai

    uint256 closeFactor = getCloseFactor(spoke1);

    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, usdxReserveId, alice, usdxAmount, alice);
    Utils.borrow(spoke1, daiReserveId, alice, borrowAmount, alice);

    oracle.setAssetPrice(wethAssetId, 800e8);

    vm.prank(bob);
    spoke1.liquidationCall(usdxReserveId, daiReserveId, alice, borrowAmount);

    assertLe(spoke1.getHealthFactor(alice), closeFactor, 'hf <= close factor');
  }

  function test_liquidationCall_restore_closeFactor() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);

    // collateral: weth/usdx
    uint256 wethAmount = 10 * 10 ** decimals.weth; // $20k wbtc
    uint256 usdxAmount = 10_000 * 10 ** decimals.usdx; // $10k usdx
    // debt: dai
    uint256 borrowAmount = 15_000 * 10 ** decimals.dai; // $15k dai

    uint256 closeFactor = 1.05e18;
    updateCloseFactor(spoke1, closeFactor);

    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, usdxReserveId, alice, usdxAmount, alice);
    Utils.borrow(spoke1, daiReserveId, alice, borrowAmount, alice);

    oracle.setAssetPrice(wethAssetId, 800e8);

    vm.prank(bob);
    spoke1.liquidationCall(usdxReserveId, daiReserveId, alice, borrowAmount);

    uint256 healthFactor = spoke1.getHealthFactor(alice);
    assertLe(healthFactor, closeFactor, 'hf <= close factor');
    assertApproxEqRel(
      healthFactor,
      closeFactor,
      _approxRelFromBps(1),
      '.01% diff, hf vs close factor'
    );
  }

  function test_liquidationCall_restore_cf_lpfp_zeroLB() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);

    // collateral: weth/usdx
    uint256 wethAmount = 10 * 10 ** decimals.weth; // $20k wbtc
    uint256 usdxAmount = 10_000 * 10 ** decimals.usdx; // $10k usdx
    // debt: dai
    uint256 borrowAmount = 15_000 * 10 ** decimals.dai; // $15k dai
    uint256 closeFactor = 1.07e18;

    updateCloseFactor(spoke1, closeFactor);
    updateLiquidationProtocolFeePercentage(spoke1, usdxReserveId, 5_00);

    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, usdxReserveId, alice, usdxAmount, alice);
    Utils.borrow(spoke1, daiReserveId, alice, borrowAmount, alice);

    oracle.setAssetPrice(wethAssetId, 800e8);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(usdxReserveId, daiReserveId, alice, borrowAmount);

    uint256 healthFactor = spoke1.getHealthFactor(alice);
    assertLe(healthFactor, closeFactor, 'hf <= close factor');
    assertApproxEqRel(
      healthFactor,
      closeFactor,
      _approxRelFromBps(1),
      '.01% diff, hf vs close factor'
    );
  }
}
