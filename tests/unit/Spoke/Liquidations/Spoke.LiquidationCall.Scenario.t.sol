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

  /// liquidation call with realized premium
  function test_liquidationCall_debt_realized_premium() public {
    LiquidationTestLocalParams memory test;
    LiqTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // collateral: wbtc/dai
    state.colls[0].wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.colls[0].dai = 10_000 * 10 ** decimals.dai; // $10k dai
    // debt: weth
    state.debts[0].weth = 20 * 10 ** decimals.weth; // 20 eth, $40k

    state.liqBonus = spoke1.getReserve(state.wbtcReserveId).config.liquidationBonus;

    // simplify accounting checks with no fee or bonus
    updateLiquidationProtocolFeePercentage(spoke1, state.wbtcReserveId, 0);
    updateLiquidationBonus(spoke1, state.wbtcReserveId, 100_00);

    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.colls[0].wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.colls[0].dai, alice);
    Utils.borrow(spoke1, state.wethReserveId, alice, state.debts[0].weth, alice);

    // interest accrual
    skip(365 days);

    // borrow action to realize premium
    _borrowWithoutHfCheck(spoke1, alice, state.wethReserveId, state.debts[0].weth);

    // position must be liquidatable
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    (, uint256 premiumDebt) = spoke1.getUserDebt(state.wethReserveId, alice);

    // premium debt exists and is realized
    assertGt(premiumDebt, 0);
    assertGt(spoke1.getUserPosition(state.wethReserveId, alice).realizedPremium, 0);

    test.liquidatorCollateral.balanceBefore = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    test.liquidator.balanceBefore = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    test.supply.balanceBefore = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    test.debt.balanceBefore = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: MAX_SUPPLY_AMOUNT
    });

    test.liquidatorCollateral.balanceAfter = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    test.liquidator.balanceAfter = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    test.supply.balanceAfter = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    test.debt.balanceAfter = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    assertApproxEqAbs(
      _absDiff(test.liquidator.balanceAfter, test.liquidator.balanceBefore),
      _absDiff(test.debt.balanceAfter, test.debt.balanceBefore),
      2,
      'liquidator repaid debt amount and restored debt accounting'
    );
    assertEq(
      _absDiff(test.liquidatorCollateral.balanceAfter, test.liquidatorCollateral.balanceBefore),
      state.colls[0].wbtc,
      'liquidator collateral earned'
    );

    (uint256 newUserRp, , uint256 newHf, , ) = spoke1.getUserAccountData(alice);

    assertEq(
      spoke1.getUserPosition(state.wbtcReserveId, alice).baseDrawnShares.percentMul(newUserRp),
      spoke1.getUserPosition(state.wbtcReserveId, alice).premiumDrawnShares,
      'collateral reserve accounting refresh'
    );
    assertEq(
      spoke1.getUserPosition(state.wethReserveId, alice).baseDrawnShares.percentMul(newUserRp),
      spoke1.getUserPosition(state.wethReserveId, alice).premiumDrawnShares,
      'debt reserve accounting is refresh'
    );

    assertLe(newHf, _getCloseFactor(spoke1), 'hf <= close factor');
  }

  /// liquidation call with HF < 1 due to accrued interest
  function test_liquidationCall_accrued_interest() public {
    LiquidationTestLocalParams memory test;
    LiqTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // collateral: wbtc/dai
    state.colls[0].wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.colls[0].dai = 10_000 * 10 ** decimals.dai; // $10k dai

    state.liqBonus = spoke1.getReserve(state.wbtcReserveId).config.liquidationBonus;

    // simplify accounting checks with no fee or bonus
    updateLiquidationProtocolFeePercentage(spoke1, state.wbtcReserveId, 0);
    updateLiquidationBonus(spoke1, state.wbtcReserveId, 100_00);

    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.colls[0].wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.colls[0].dai, alice);
    _borrowToBeBelowHf(spoke1, alice, state.wethReserveId, 1.001e18);

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

    test.liquidatorCollateral.balanceBefore = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    test.liquidator.balanceBefore = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    test.supply.balanceBefore = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    test.debt.balanceBefore = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: MAX_SUPPLY_AMOUNT
    });

    test.liquidatorCollateral.balanceAfter = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    test.liquidator.balanceAfter = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    test.supply.balanceAfter = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    test.debt.balanceAfter = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    assertApproxEqAbs(
      _absDiff(test.liquidator.balanceAfter, test.liquidator.balanceBefore),
      _absDiff(test.debt.balanceAfter, test.debt.balanceBefore),
      2,
      'liquidator repaid debt amount and restored debt accounting'
    );
    (uint256 newUserRp, , uint256 newHf, , ) = spoke1.getUserAccountData(alice);

    assertEq(
      spoke1.getUserPosition(state.wbtcReserveId, alice).baseDrawnShares.percentMul(newUserRp),
      spoke1.getUserPosition(state.wbtcReserveId, alice).premiumDrawnShares,
      'collateral reserve accounting refresh'
    );
    assertEq(
      spoke1.getUserPosition(state.wethReserveId, alice).baseDrawnShares.percentMul(newUserRp),
      spoke1.getUserPosition(state.wethReserveId, alice).premiumDrawnShares,
      'debt reserve accounting is refresh'
    );

    assertLe(newHf, _getCloseFactor(spoke1), 'hf <= close factor');
  }

  /// liquidation call does not allow arbitrarily large debtToCover
  function test_liquidationCall_maxDebtToCover() public {
    LiquidationTestLocalParams memory test;
    LiqTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // collateral: wbtc/dai
    state.colls[0].wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.colls[0].dai = 10_000 * 10 ** decimals.dai; // $10k dai

    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.colls[0].wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.colls[0].dai, alice);
    _borrowToBeBelowHf(spoke1, alice, state.wethReserveId, 1.001e18);

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

    test.liquidatorCollateral.balanceBefore = IERC20(spoke1.getReserve(state.wbtcReserveId).asset)
      .balanceOf(LIQUIDATOR);
    test.liquidator.balanceBefore = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    test.supply.balanceBefore = spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice);
    test.debt.balanceBefore = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: MAX_SUPPLY_AMOUNT
    });

    test.liquidator.balanceAfter = IERC20(spoke1.getReserve(state.wethReserveId).asset).balanceOf(
      LIQUIDATOR
    );
    test.debt.balanceAfter = spoke1.getUserTotalDebt(state.wethReserveId, alice);

    assertApproxEqAbs(
      _absDiff(test.liquidator.balanceAfter, test.liquidator.balanceBefore),
      _absDiff(test.debt.balanceAfter, test.debt.balanceBefore),
      2,
      'liquidator repaid debt amount and restored debt accounting'
    );
    assertLt(
      _absDiff(test.liquidator.balanceAfter, test.liquidator.balanceBefore),
      MAX_SUPPLY_AMOUNT,
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

  function _convertAssetAmount(
    uint256 assetId,
    uint256 amount,
    uint256 toAssetId
  ) internal returns (uint256) {
    return
      (amount * oracle.getAssetPrice(assetId) * 10 ** hub.getAsset(toAssetId).config.decimals) /
      (oracle.getAssetPrice(toAssetId) * 10 ** hub.getAsset(assetId).config.decimals);
  }

  function _loadUserBalances() internal returns (UserTokenBalance memory userBalances) {
    userBalances.alice.wbtc = tokenList.wbtc.balanceOf(alice);
    userBalances.alice.dai = tokenList.dai.balanceOf(alice);
    userBalances.alice.usdx = tokenList.usdx.balanceOf(alice);
    userBalances.alice.usdy = tokenList.usdy.balanceOf(alice);
    userBalances.alice.weth = tokenList.weth.balanceOf(alice);

    userBalances.bob.wbtc = tokenList.wbtc.balanceOf(bob);
    userBalances.bob.dai = tokenList.dai.balanceOf(bob);
    userBalances.bob.usdx = tokenList.usdx.balanceOf(bob);
    userBalances.bob.usdy = tokenList.usdy.balanceOf(bob);
    userBalances.bob.weth = tokenList.weth.balanceOf(bob);

    userBalances.treasury.wbtc = tokenList.wbtc.balanceOf(TREASURY);
    userBalances.treasury.dai = tokenList.dai.balanceOf(TREASURY);
    userBalances.treasury.usdx = tokenList.usdx.balanceOf(TREASURY);
    userBalances.treasury.usdy = tokenList.usdy.balanceOf(TREASURY);
    userBalances.treasury.weth = tokenList.weth.balanceOf(TREASURY);
  }

  function _calculateBalanceChanges(
    UserTokenBalance memory userBalancesBefore,
    UserTokenBalance memory userBalacesAfter
  ) internal returns (UserTokenBalance memory balanceChanges) {
    balanceChanges.alice.wbtc = userBalacesAfter.alice.wbtc > userBalancesBefore.alice.wbtc
      ? userBalacesAfter.alice.wbtc - userBalancesBefore.alice.wbtc
      : userBalancesBefore.alice.wbtc - userBalacesAfter.alice.wbtc;
    balanceChanges.alice.dai = userBalacesAfter.alice.dai > userBalancesBefore.alice.dai
      ? userBalacesAfter.alice.dai - userBalancesBefore.alice.dai
      : userBalancesBefore.alice.dai - userBalacesAfter.alice.dai;
    balanceChanges.alice.usdx = userBalacesAfter.alice.usdx > userBalancesBefore.alice.usdx
      ? userBalacesAfter.alice.usdx - userBalancesBefore.alice.usdx
      : userBalancesBefore.alice.usdx - userBalacesAfter.alice.usdx;
    balanceChanges.alice.usdy = userBalacesAfter.alice.usdy > userBalancesBefore.alice.usdy
      ? userBalacesAfter.alice.usdy - userBalancesBefore.alice.usdy
      : userBalancesBefore.alice.usdy - userBalacesAfter.alice.usdy;
    balanceChanges.alice.weth = userBalacesAfter.alice.weth > userBalancesBefore.alice.weth
      ? userBalacesAfter.alice.weth - userBalancesBefore.alice.weth
      : userBalancesBefore.alice.weth - userBalacesAfter.alice.weth;

    balanceChanges.bob.wbtc = userBalacesAfter.bob.wbtc > userBalancesBefore.bob.wbtc
      ? userBalacesAfter.bob.wbtc - userBalancesBefore.bob.wbtc
      : userBalancesBefore.bob.wbtc - userBalacesAfter.bob.wbtc;
    balanceChanges.bob.dai = userBalacesAfter.bob.dai > userBalancesBefore.bob.dai
      ? userBalacesAfter.bob.dai - userBalancesBefore.bob.dai
      : userBalancesBefore.bob.dai - userBalacesAfter.bob.dai;
    balanceChanges.bob.usdx = userBalacesAfter.bob.usdx > userBalancesBefore.bob.usdx
      ? userBalacesAfter.bob.usdx - userBalancesBefore.bob.usdx
      : userBalancesBefore.bob.usdx - userBalacesAfter.bob.usdx;
    balanceChanges.bob.usdy = userBalacesAfter.bob.usdy > userBalancesBefore.bob.usdy
      ? userBalacesAfter.bob.usdy - userBalancesBefore.bob.usdy
      : userBalancesBefore.bob.usdy - userBalacesAfter.bob.usdy;
    balanceChanges.bob.weth = userBalacesAfter.bob.weth > userBalancesBefore.bob.weth
      ? userBalacesAfter.bob.weth - userBalancesBefore.bob.weth
      : userBalancesBefore.bob.weth - userBalacesAfter.bob.weth;

    balanceChanges.treasury.wbtc = userBalacesAfter.treasury.wbtc > userBalancesBefore.treasury.wbtc
      ? userBalacesAfter.treasury.wbtc - userBalancesBefore.treasury.wbtc
      : userBalancesBefore.treasury.wbtc - userBalacesAfter.treasury.wbtc;
    balanceChanges.treasury.dai = userBalacesAfter.treasury.dai > userBalancesBefore.treasury.dai
      ? userBalacesAfter.treasury.dai - userBalancesBefore.treasury.dai
      : userBalancesBefore.treasury.dai - userBalacesAfter.treasury.dai;
    balanceChanges.treasury.usdx = userBalacesAfter.treasury.usdx > userBalancesBefore.treasury.usdx
      ? userBalacesAfter.treasury.usdx - userBalancesBefore.treasury.usdx
      : userBalancesBefore.treasury.usdx - userBalacesAfter.treasury.usdx;
    balanceChanges.treasury.usdy = userBalacesAfter.treasury.usdy > userBalancesBefore.treasury.usdy
      ? userBalacesAfter.treasury.usdy - userBalancesBefore.treasury.usdy
      : userBalancesBefore.treasury.usdy - userBalacesAfter.treasury.usdy;
    balanceChanges.treasury.weth = userBalacesAfter.treasury.weth > userBalancesBefore.treasury.weth
      ? userBalacesAfter.treasury.weth - userBalancesBefore.treasury.weth
      : userBalancesBefore.treasury.weth - userBalacesAfter.treasury.weth;
  }

  /// calc threshold at which LB equals close factor
  function _calculateLiqBonusThreshold(
    uint256 closeFactor,
    uint256 collateralFactor
  ) internal returns (uint256) {
    return (closeFactor * PercentageMath.PERCENTAGE_FACTOR).percentDiv(collateralFactor).dewadify();
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

  struct Amount {
    uint256 wbtc;
    uint256 weth;
    uint256 dai;
    uint256 usdx;
  }

  // no liquidationProtocolFeePercentage

  /// scenario where fully liquidating a collateral still does not improve a position to close factor
  /// default close factor of 1; multiple collaterals
  function test_liquidationCall_all_collateral_default_close_factor_multi_coll_max_scaledLiqBonus()
    public
  {
    LiqTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // collateral: wbtc/dai
    state.colls[0].wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.colls[0].dai = 10_000 * 10 ** decimals.dai; // $10k dai
    // debt: weth
    state.debts[0].weth = 20 * 10 ** decimals.weth; // 20 eth, $40k

    state.collateralFactor = 75_00;
    state.closeFactor = 1.05e18;
    // calculate liquidation bonus threshold that results in negative denominator, scaledLiqBonus > closeFactor
    state.liqBonus = _calculateLiqBonusThreshold(state.closeFactor, state.collateralFactor);

    // set spoke params
    updateLiquidationBonus(spoke1, state.wbtcReserveId, state.liqBonus);
    updateCollateralFactor(spoke1, state.wbtcReserveId, state.collateralFactor);
    updateCloseFactor(spoke1, state.closeFactor);

    // create debt position
    _deployLiquidity(spoke1, state.wethReserveId, state.debts[0].weth);
    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.colls[0].wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.colls[0].dai, alice);
    Utils.borrow(spoke1, state.wethReserveId, alice, state.debts[0].weth, alice);

    // wbtc collateral value drop to reduce HF < 1
    oracle.setAssetPrice(wbtcAssetId, 20_000e8);

    // position is liquidatable
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    UserTokenBalance memory balancesBefore = _loadUserBalances();
    state.initialDebt = spoke1.getUserTotalDebt(state.wethReserveId, alice);
    state.liquidatedDebt = _convertAssetAmount(wbtcAssetId, state.colls[0].wbtc, wethAssetId)
      .percentDiv(state.liqBonus);

    // bob liquidates alice
    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationCall(
      address(tokenList.wbtc),
      address(tokenList.weth),
      alice,
      state.liquidatedDebt,
      state.colls[0].wbtc,
      bob
    );
    vm.prank(bob);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: state.debts[0].weth
    });

    UserTokenBalance memory balancesAfter = _loadUserBalances();
    UserTokenBalance memory balanceChanges = _calculateBalanceChanges(
      balancesBefore,
      balancesAfter
    );

    // dai collateral
    assertEq(
      spoke1.getUserSuppliedAmount(state.daiReserveId, alice),
      state.colls[0].dai,
      'alice dai coll unchanged'
    );
    assertEq(balanceChanges.alice.dai, 0, 'alice has no dai change');
    assertEq(balanceChanges.bob.dai, 0, 'bob receives 0 dai coll');
    assertEq(balanceChanges.treasury.dai, 0, 'treasury receives 0 dai coll');

    // wbtc collateral
    assertEq(
      spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice),
      0,
      'alice wbtc coll liquidated'
    );
    assertEq(balanceChanges.alice.wbtc, 0, 'alice has no wbtc change');
    assertEq(balanceChanges.bob.wbtc, state.colls[0].wbtc, 'bob receives all wbtc coll');
    assertEq(balanceChanges.treasury.wbtc, 0, 'treasury receives 0 wbtc coll');

    // weth debt
    assertEq(
      state.initialDebt - spoke1.getUserTotalDebt(state.wethReserveId, alice),
      state.liquidatedDebt,
      'alice weth debt repaid'
    );
    assertEq(balanceChanges.alice.weth, 0, 'alice has no weth change');
    assertEq(balanceChanges.bob.weth, state.liquidatedDebt, 'bob pays all weth debt');
    assertEq(balanceChanges.treasury.weth, 0, 'treasury has no weth change');

    // hf < 1 after
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    console.log(
      'final hf %e | closeFactor %e | percentDiff %e',
      spoke1.getHealthFactor(alice),
      _getCloseFactor(spoke1),
      _percentDiff(_getCloseFactor(spoke1), spoke1.getHealthFactor(alice))
    );
  }

  function testy() public {
    // uint256[] memory collReserveIds = new uint256[](2);
    // collReserveIds[0] = _wbtcReserveId(spoke1);
    // collReserveIds[1] = _daiReserveId(spoke1);

    // uint256[] memory collAmounts = new uint256[](2);
    // collAmounts[0] = 1 * 10 ** decimals.wbtc;
    // collAmounts[1] = 10_000 * 10 ** decimals.dai;

    // uint256 debtReserveId = _wethReserveId(spoke1);
    // _calcMaxDebtAmount(spoke1, collReserveIds, collAmounts, debtReserveId);

    test_liquidationCall_fuzz_all_collateral_default_close_factor_multi_coll_max_scaledLiqBonus(
      421,
      1353702973434268927,
      3463713499169
    );
  }

  function test_liquidationCall_fuzz_all_collateral_default_close_factor_multi_coll_max_scaledLiqBonus(
    uint256 collateralFactor,
    uint256 closeFactor,
    uint256 newPrice
  ) public {
    vm.skip(true, 'fuzz after finishing unit tests');

    LiqTestData memory state;

    // for wbtc coll
    state.collateralFactor = bound(collateralFactor, 1, MAX_COLLATERAL_FACTOR);
    state.closeFactor = bound(closeFactor, HEALTH_FACTOR_LIQUIDATION_THRESHOLD, MAX_CLOSE_FACTOR);
    newPrice = bound(newPrice, 1, oracle.getAssetPrice(wbtcAssetId));

    // calculate liquidation bonus threshold that results in negative denominator, scaledLiqBonus > closeFactor
    state.liqBonus = _calculateLiqBonusThreshold(state.closeFactor, state.collateralFactor);

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // set spoke params
    updateLiquidationBonus(spoke1, state.wbtcReserveId, state.liqBonus);
    updateCollateralFactor(spoke1, state.wbtcReserveId, state.collateralFactor);
    updateCloseFactor(spoke1, state.closeFactor);

    // collateral: wbtc/dai
    state.colls[0].wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.colls[0].dai = 20_000 * 10 ** decimals.dai; // $55k dai
    // debt: weth
    // state.debts[0].weth = 20 * 10 ** decimals.weth; // 20 eth, $40k

    uint256[] memory collReserveIds = new uint256[](2);
    collReserveIds[0] = state.wbtcReserveId;
    collReserveIds[1] = state.daiReserveId;

    uint256[] memory collAmounts = new uint256[](2);
    collAmounts[0] = state.colls[0].wbtc;
    collAmounts[1] = state.colls[0].dai;

    state.debts[0].weth = _calcMaxDebtAmount(
      spoke1,
      collReserveIds,
      collAmounts,
      state.wethReserveId
    );

    console.log('debt %e', state.debts[0].weth);

    // create debt position
    _deployLiquidity(spoke1, state.wethReserveId, state.debts[0].weth);
    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.colls[0].wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.colls[0].dai, alice);
    Utils.borrow(spoke1, state.wethReserveId, alice, state.debts[0].weth, alice);

    // wbtc collateral value drop to reduce HF < 1
    oracle.setAssetPrice(wbtcAssetId, newPrice);

    // ensure position is liquidatable
    vm.assume(spoke1.getHealthFactor(alice) < HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    UserTokenBalance memory balancesBefore = _loadUserBalances();
    state.initialDebt = spoke1.getUserTotalDebt(state.wethReserveId, alice);
    state.liquidatedDebt = _convertAssetAmount(wbtcAssetId, state.colls[0].wbtc, wethAssetId)
      .percentDiv(state.liqBonus);

    // bob liquidates alice
    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationCall(
      address(tokenList.wbtc),
      address(tokenList.weth),
      alice,
      state.liquidatedDebt,
      state.colls[0].wbtc,
      bob
    );
    vm.prank(bob);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: state.debts[0].weth
    });

    UserTokenBalance memory balancesAfter = _loadUserBalances();
    UserTokenBalance memory balanceChanges = _calculateBalanceChanges(
      balancesBefore,
      balancesAfter
    );

    // dai collateral
    assertEq(
      spoke1.getUserSuppliedAmount(state.daiReserveId, alice),
      state.colls[0].dai,
      'alice dai coll unchanged'
    );
    assertEq(balanceChanges.alice.dai, 0, 'alice has no dai change');
    assertEq(balanceChanges.bob.dai, 0, 'bob receives 0 dai coll');
    assertEq(balanceChanges.treasury.dai, 0, 'treasury receives 0 dai coll');

    // wbtc collateral
    assertEq(
      spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice),
      0,
      'alice wbtc coll liquidated'
    );
    assertEq(balanceChanges.alice.wbtc, 0, 'alice has no wbtc change');
    assertEq(balanceChanges.bob.wbtc, state.colls[0].wbtc, 'bob receives all wbtc coll');
    assertEq(balanceChanges.treasury.wbtc, 0, 'treasury receives 0 wbtc coll');

    // weth debt
    assertEq(
      state.initialDebt - spoke1.getUserTotalDebt(state.wethReserveId, alice),
      state.liquidatedDebt,
      'alice weth debt repaid'
    );
    assertEq(balanceChanges.alice.weth, 0, 'alice has no weth change');
    assertEq(balanceChanges.bob.weth, state.liquidatedDebt, 'bob pays all weth debt');
    assertEq(balanceChanges.treasury.weth, 0, 'treasury has no weth change');

    // hf < 1 after
    // assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
  }

  /// scenario where fully liquidating a collateral still does not improve a position to close factor
  function test_liquidationCall_full_collateral_liquidation_newCloseFactor() public {
    // UserTokenBalance memory balances;
    // uint256 wethReserveId = _wethReserveId(spoke1);
    // uint256 daiReserveId = _daiReserveId(spoke1);
    // uint256 wbtcReserveId = _wbtcReserveId(spoke1);
    // // collateral: wbtc/dai
    // uint256 wbtcAmount = 1 * 10 ** decimals.wbtc; // $50k wbtc
    // uint256 daiAmount = 10_000 * 10 ** decimals.dai; // $10k dai
    // // debt: weth
    // uint256 borrowAmount = 20 * 10 ** decimals.weth; // 20 eth, $40k
    // _updateCloseFactor(spoke1, 1.05e18);
    // _deployLiquidity(spoke1, wethReserveId, borrowAmount * 10);
    // Utils.supplyCollateral(spoke1, wbtcReserveId, alice, wbtcAmount, alice);
    // Utils.supplyCollateral(spoke1, daiReserveId, alice, daiAmount, alice);
    // Utils.borrow(spoke1, wethReserveId, alice, borrowAmount, alice);
    // console.log(spoke1.getHealthFactor(alice));
    // console.log(
    //   ' coll wbtc %e, dai %e',
    //   spoke1.getUserSuppliedAmount(wbtcReserveId, alice),
    //   spoke1.getUserSuppliedAmount(daiReserveId, alice)
    // );
    // console.log(' debt %e', spoke1.getUserTotalDebt(wethReserveId, alice));
    // console.log(' hf %e', spoke1.getHealthFactor(alice));
    // // wbtc collateral value drop to reduce HF < 1
    // oracle.setAssetPrice(wbtcAssetId, 20_000e8);
    // balances.bob.pre.wbtc = tokenList.wbtc.balanceOf(bob);
    // balances.treasury.pre.wbtc = tokenList.wbtc.balanceOf(TREASURY);
    // // bob liquidates alice
    // vm.prank(bob);
    // spoke1.liquidationCall({
    //   collateralReserveId: wbtcReserveId,
    //   debtReserveId: wethReserveId,
    //   user: alice,
    //   debtToCover: borrowAmount
    // });
    // balances.bob.wbtc.post = tokenList.wbtc.balanceOf(bob);
    // balances.treasury.wbtc.post = tokenList.wbtc.balanceOf(TREASURY);
    // console.log(
    //   'final coll wbtc %e, dai %e',
    //   spoke1.getUserSuppliedAmount(wbtcReserveId, alice),
    //   spoke1.getUserSuppliedAmount(daiReserveId, alice)
    // );
    // console.log('final weth debt %e', spoke1.getUserTotalDebt(wethReserveId, alice));
    // console.log('final hf %e', spoke1.getHealthFactor(alice));
    // console.log('bob change %e', balances.bob.wbtc.post - balances.bob.wbtc.pre);
    // console.log('treasury change %e', balances.treasury.wbtc.post - balances.treasury.wbtc.pre);
    // // dai collateral
    // assertEq(
    //   spoke1.getUserSuppliedAmount(daiReserveId, alice),
    //   daiAmount,
    //   'alice dai coll unchanged'
    // );
    // // wbtc collateral
    // assertEq(
    //   balances.bob.wbtc.post - balances.bob.wbtc.pre,
    //   wbtcAmount,
    //   'bob receives all wbtc coll'
    // );
    // assertEq(
    //   balances.treasury.wbtc.post - balances.treasury.wbtc.pre,
    //   0,
    //   'treasury receives 0 fee'
    // );
  }

  // working correctly with usdx=6, dai=18, weth=18, but HF < 1 after
  function test_liquidationCall_precision_loss_lt_cf() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);

    // collateral: weth/dai
    uint256 wethAmount = 10 * 10 ** decimals.weth; // $20k wbtc
    uint256 daiAmount = 10_000 * 10 ** decimals.dai; // $10k dai
    // debt: usdx
    uint256 borrowAmount = 15_000 * 10 ** decimals.usdx; // $15k usdx

    _deployLiquidity(spoke1, usdxReserveId, borrowAmount);
    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, daiReserveId, alice, daiAmount, alice);
    Utils.borrow(spoke1, usdxReserveId, alice, borrowAmount, alice);

    oracle.setAssetPrice(wethAssetId, 400e8);

    vm.prank(bob);
    spoke1.liquidationCall(daiReserveId, usdxReserveId, alice, borrowAmount);

    console.log(
      'final hf %e | closeFactor %e | percentDiff %e',
      spoke1.getHealthFactor(alice),
      _getCloseFactor(spoke1),
      _percentDiff(_getCloseFactor(spoke1), spoke1.getHealthFactor(alice))
    );
    assertLt(spoke1.getHealthFactor(alice), 1e18, 'health factor precision loss < 1 ');
  }

  // working correctly with usdx=6, dai=18, weth=18, but HF > 1 after
  function test_liquidationCall_precision_loss_gt_cf() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);

    // collateral: weth/usdx
    uint256 wethAmount = 10 * 10 ** decimals.weth; // $20k wbtc
    uint256 usdxAmount = 10_000 * 10 ** decimals.usdx; // $10k usdx
    // debt: dai
    uint256 borrowAmount = 15_000 * 10 ** decimals.dai; // $15k dai

    uint256 closeFactor = getCloseFactor(spoke1);

    _deployLiquidity(spoke1, daiReserveId, borrowAmount);
    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, usdxReserveId, alice, usdxAmount, alice);
    Utils.borrow(spoke1, daiReserveId, alice, borrowAmount, alice);

    oracle.setAssetPrice(wethAssetId, 800e8);

    vm.prank(bob);
    spoke1.liquidationCall(usdxReserveId, daiReserveId, alice, borrowAmount);

    console.log(
      'final hf %e | closeFactor %e | percentDiff %e',
      spoke1.getHealthFactor(alice),
      _getCloseFactor(spoke1),
      _percentDiff(_getCloseFactor(spoke1), spoke1.getHealthFactor(alice))
    );
    assertLe(spoke1.getHealthFactor(alice), closeFactor, 'health factor precision loss > 1 ');
  }

  function test_liquidationCall_exact() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdyReserveId = _usdyReserveId(spoke1);
    // collateral: weth/dai
    uint256 wethAmount = 10 * 10 ** decimals.weth; // $20k wbtc
    uint256 daiAmount = 10_000 * 10 ** decimals.dai; // $10k dai
    // debt: usdy
    uint256 borrowAmount = 15_000 * 10 ** tokenList.usdy.decimals(); // $15k usdy
    _deployLiquidity(spoke1, usdyReserveId, borrowAmount);
    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, daiReserveId, alice, daiAmount, alice);
    Utils.borrow(spoke1, usdyReserveId, alice, borrowAmount, alice);

    console.log(spoke1.getHealthFactor(alice));
    console.log(' coll %e', spoke1.getUserSuppliedAmount(wethReserveId, alice));
    console.log(' debt %e', spoke1.getUserTotalDebt(usdyReserveId, alice));
    console.log(' hf %e', spoke1.getHealthFactor(alice));
    oracle.setAssetPrice(wethAssetId, 800e8);
    console.log(' hf %e', spoke1.getHealthFactor(alice));
    // _setPriceChange(oracle, wethAssetId, 90_00); // 10% drop
    // console.log(spoke1.getHealthFactor(alice));
    // skip(365 days);
    vm.prank(bob);
    spoke1.liquidationCall(daiReserveId, usdyReserveId, alice, borrowAmount);
    // console.log('final asset coll %e', hub.getAssetSuppliedAmount(wethAssetId));
    // console.log('final asset debt %e', hub.getAssetTotalDebt(daiAssetId));
    // console.log('final coll %e', spoke1.getUserSuppliedAmount(wethReserveId, alice));
    // console.log('final debt %e', spoke1.getUserTotalDebt(daiReserveId, alice));
    console.log(
      'final hf %e | closeFactor %e | percentDiff %e',
      spoke1.getHealthFactor(alice),
      _getCloseFactor(spoke1),
      _percentDiff(_getCloseFactor(spoke1), spoke1.getHealthFactor(alice))
    );
    // 1.000140890169708613e18
    // 1.000140890157372828e18

    // assertEq(spoke1.getHealthFactor(alice), 1e18, 'health factor should be exactly 1');
    assertGe(spoke1.getHealthFactor(alice), 1e18, 'health factor should be exactly 1');
  }

  function test_liquidationCall_all_collateral_negative_denom() public {
    LiqTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // collateral: wbtc/dai
    state.colls[0].wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.colls[0].dai = 10_000 * 10 ** decimals.dai; // $10k dai
    // debt: weth
    state.debts[0].weth = 20 * 10 ** decimals.weth; // 20 eth, $40k

    state.collateralFactor = 75_00;
    state.closeFactor = 1.05e18;
    // calculate liquidation bonus threshold that results in negative denominator, scaledLiqBonus > closeFactor
    state.liqBonus = 140_00;

    // set spoke params
    updateLiquidationBonus(spoke1, state.wbtcReserveId, state.liqBonus);
    updateCollateralFactor(spoke1, state.wbtcReserveId, state.collateralFactor);
    updateCloseFactor(spoke1, state.closeFactor);

    // set liquidationProtocolFeePercentage
    updateLiquidationProtocolFeePercentage(spoke1, state.wbtcReserveId, 0);

    // create debt position
    _deployLiquidity(spoke1, state.wethReserveId, state.debts[0].weth);
    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.colls[0].wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.colls[0].dai, alice);
    Utils.borrow(spoke1, state.wethReserveId, alice, state.debts[0].weth, alice);

    // wbtc collateral value drop to reduce HF < 1
    oracle.setAssetPrice(wbtcAssetId, 20_000e8);

    // position is liquidatable
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    UserTokenBalance memory balancesBefore = _loadUserBalances();
    state.initialDebt = spoke1.getUserTotalDebt(state.wethReserveId, alice);
    state.liquidatedDebt = _convertAssetAmount(wbtcAssetId, state.colls[0].wbtc, wethAssetId)
      .percentDiv(state.liqBonus);

    // // bob liquidates alice
    // vm.expectEmit(address(spoke1));
    // emit ISpoke.LiquidationCall(
    //   address(tokenList.wbtc),
    //   address(tokenList.weth),
    //   alice,
    //   state.liquidatedDebt,
    //   state.colls[0].wbtc,
    //   bob
    // );
    vm.prank(bob);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: state.debts[0].weth
    });

    // console.log();

    UserTokenBalance memory balancesAfter = _loadUserBalances();
    UserTokenBalance memory balanceChanges = _calculateBalanceChanges(
      balancesBefore,
      balancesAfter
    );

    // dai collateral
    assertEq(
      spoke1.getUserSuppliedAmount(state.daiReserveId, alice),
      state.colls[0].dai,
      'alice dai coll unchanged'
    );
    assertEq(balanceChanges.alice.dai, 0, 'alice has no dai change');
    assertEq(balanceChanges.bob.dai, 0, 'bob receives 0 dai coll');
    assertEq(balanceChanges.treasury.dai, 0, 'treasury receives 0 dai coll');

    // wbtc collateral
    assertEq(
      spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice),
      0,
      'alice wbtc coll liquidated'
    );
    assertEq(balanceChanges.alice.wbtc, 0, 'alice has no wbtc change');
    assertEq(balanceChanges.bob.wbtc, state.colls[0].wbtc, 'bob receives all wbtc coll');
    assertEq(balanceChanges.treasury.wbtc, 0, 'treasury receives 0 wbtc coll');

    // weth debt
    assertEq(
      state.initialDebt - spoke1.getUserTotalDebt(state.wethReserveId, alice),
      state.liquidatedDebt,
      'alice weth debt repaid'
    );
    assertEq(balanceChanges.alice.weth, 0, 'alice has no weth change');
    assertEq(balanceChanges.bob.weth, state.liquidatedDebt, 'bob pays all weth debt');
    assertEq(balanceChanges.treasury.weth, 0, 'treasury has no weth change');

    // hf < 1 after
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    console.log(
      'final hf %e | closeFactor %e | percentDiff %e',
      spoke1.getHealthFactor(alice),
      _getCloseFactor(spoke1),
      _percentDiff(_getCloseFactor(spoke1), spoke1.getHealthFactor(alice))
    );
  }

  function test_liquidationCall_all_collateral_nonzero_lpfp() public {
    LiqTestData memory state;

    state.wethReserveId = _wethReserveId(spoke1);
    state.daiReserveId = _daiReserveId(spoke1);
    state.wbtcReserveId = _wbtcReserveId(spoke1);

    // collateral: wbtc/dai
    state.colls[0].wbtc = 1 * 10 ** decimals.wbtc; // $50k wbtc
    state.colls[0].dai = 10_000 * 10 ** decimals.dai; // $10k dai
    // debt: weth
    state.debts[0].weth = 20 * 10 ** decimals.weth; // 20 eth, $40k

    state.collateralFactor = 75_00;
    state.closeFactor = 1.05e18;
    // calculate liquidation bonus threshold that results in negative denominator, scaledLiqBonus > closeFactor
    state.liqBonus = 140_00;

    // set spoke params
    updateLiquidationBonus(spoke1, state.wbtcReserveId, state.liqBonus);
    updateCollateralFactor(spoke1, state.wbtcReserveId, state.collateralFactor);
    updateCloseFactor(spoke1, state.closeFactor);

    // set liquidationProtocolFeePercentage
    updateLiquidationProtocolFeePercentage(spoke1, state.wbtcReserveId, 5_00);

    // create debt position
    _deployLiquidity(spoke1, state.wethReserveId, state.debts[0].weth);
    Utils.supplyCollateral(spoke1, state.wbtcReserveId, alice, state.colls[0].wbtc, alice);
    Utils.supplyCollateral(spoke1, state.daiReserveId, alice, state.colls[0].dai, alice);
    Utils.borrow(spoke1, state.wethReserveId, alice, state.debts[0].weth, alice);

    // wbtc collateral value drop to reduce HF < 1
    oracle.setAssetPrice(wbtcAssetId, 20_000e8);

    // position is liquidatable
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    UserTokenBalance memory balancesBefore = _loadUserBalances();
    state.initialDebt = spoke1.getUserTotalDebt(state.wethReserveId, alice);
    state.liquidatedDebt = _convertAssetAmount(wbtcAssetId, state.colls[0].wbtc, wethAssetId)
      .percentDiv(state.liqBonus);

    // // bob liquidates alice
    // vm.expectEmit(address(spoke1));
    // emit ISpoke.LiquidationCall(
    //   address(tokenList.wbtc),
    //   address(tokenList.weth),
    //   alice,
    //   state.liquidatedDebt,
    //   state.colls[0].wbtc,
    //   bob
    // );
    vm.prank(bob);
    spoke1.liquidationCall({
      collateralReserveId: state.wbtcReserveId,
      debtReserveId: state.wethReserveId,
      user: alice,
      debtToCover: state.debts[0].weth
    });

    // console.log();

    UserTokenBalance memory balancesAfter = _loadUserBalances();
    UserTokenBalance memory balanceChanges = _calculateBalanceChanges(
      balancesBefore,
      balancesAfter
    );

    // dai collateral
    assertEq(
      spoke1.getUserSuppliedAmount(state.daiReserveId, alice),
      state.colls[0].dai,
      'alice dai coll unchanged'
    );
    assertEq(balanceChanges.alice.dai, 0, 'alice has no dai change');
    assertEq(balanceChanges.bob.dai, 0, 'bob receives 0 dai coll');
    assertEq(balanceChanges.treasury.dai, 0, 'treasury receives 0 dai coll');

    // wbtc collateral
    assertEq(
      spoke1.getUserSuppliedAmount(state.wbtcReserveId, alice),
      0,
      'alice wbtc coll liquidated'
    );
    assertEq(balanceChanges.alice.wbtc, 0, 'alice has no wbtc change');
    // TODO: include treasury accounting from hub
    // assertEq(
    //   balanceChanges.bob.wbtc + balanceChanges.treasury.wbtc,
    //   state.colls[0].wbtc,
    //   'bob and treasury receives all wbtc coll'
    // );

    // weth debt
    assertEq(
      state.initialDebt - spoke1.getUserTotalDebt(state.wethReserveId, alice),
      state.liquidatedDebt,
      'alice weth debt repaid'
    );
    assertEq(balanceChanges.alice.weth, 0, 'alice has no weth change');
    assertEq(balanceChanges.bob.weth, state.liquidatedDebt, 'bob pays all weth debt');
    assertEq(balanceChanges.treasury.weth, 0, 'treasury has no weth change');

    // hf < 1 after
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    console.log(
      'final hf %e | closeFactor %e | percentDiff %e',
      spoke1.getHealthFactor(alice),
      _getCloseFactor(spoke1),
      _percentDiff(_getCloseFactor(spoke1), spoke1.getHealthFactor(alice))
    );
  }

  function test_liquidationCall_restore_cf() public {
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

    _deployLiquidity(spoke1, daiReserveId, borrowAmount);
    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, usdxReserveId, alice, usdxAmount, alice);
    Utils.borrow(spoke1, daiReserveId, alice, borrowAmount, alice);

    oracle.setAssetPrice(wethAssetId, 800e8);

    vm.prank(bob);
    spoke1.liquidationCall(usdxReserveId, daiReserveId, alice, borrowAmount);

    console.log(
      'final hf %e | closeFactor %e | percentDiff %e',
      spoke1.getHealthFactor(alice),
      _getCloseFactor(spoke1),
      _percentDiff(_getCloseFactor(spoke1), spoke1.getHealthFactor(alice))
    );
    assertLe(spoke1.getHealthFactor(alice), closeFactor, 'health factor precision loss > 1 ');
  }

  // LB = 0, LPFP > 0, still treasury gets 0
  function test_liquidationCall_restore_cf_lpfp_zeroLB() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);

    // collateral: weth/usdx
    uint256 wethAmount = 10 * 10 ** decimals.weth; // $20k wbtc
    uint256 usdxAmount = 10_000 * 10 ** decimals.usdx; // $10k usdx
    // debt: dai
    uint256 borrowAmount = 15_000 * 10 ** decimals.dai; // $15k dai

    uint256 treasuryBalanceBefore = tokenList.usdx.balanceOf(TREASURY);

    uint256 closeFactor = 1.05e18;

    updateCloseFactor(spoke1, closeFactor);
    updateLiquidationProtocolFeePercentage(spoke1, usdxReserveId, 5_00);

    _deployLiquidity(spoke1, daiReserveId, borrowAmount);
    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, usdxReserveId, alice, usdxAmount, alice);
    Utils.borrow(spoke1, daiReserveId, alice, borrowAmount, alice);

    oracle.setAssetPrice(wethAssetId, 800e8);

    vm.prank(bob);
    spoke1.liquidationCall(usdxReserveId, daiReserveId, alice, borrowAmount);

    console.log(
      'final hf %e | closeFactor %e | percentDiff %e',
      spoke1.getHealthFactor(alice),
      _getCloseFactor(spoke1),
      _percentDiff(_getCloseFactor(spoke1), spoke1.getHealthFactor(alice))
    );
    assertLe(spoke1.getHealthFactor(alice), closeFactor, 'health factor precision loss > 1 ');

    // assertEq(tokenList.usdx.balanceOf(TREASURY) - treasuryBalanceBefore, 0, 'fee is 0');
  }

  function _calcMaxDebtAmount(
    ISpoke spoke,
    uint256[] memory collReserveIds,
    uint256[] memory collAmounts,
    uint256 debtReserveId
  ) internal returns (uint256) {
    (uint256 totalColl, uint256 avgCollFactor) = _previewTotalCollateralInBaseCurrencyAndAvgCF(
      spoke,
      collReserveIds,
      collAmounts
    );

    DataTypes.Reserve memory debtReserve = spoke.getReserve(debtReserveId);

    return
      ((totalColl.wadMul(avgCollFactor).dewadify() * 10 ** debtReserve.config.decimals) /
        oracle.getAssetPrice(debtReserve.assetId)).fromBps();
  }

  /// @return totalCollateralInBaseCurrency total collateral in base currency
  /// @return avgCollateralFactor average liquidation threshold
  function _previewTotalCollateralInBaseCurrencyAndAvgCF(
    ISpoke spoke,
    uint256[] memory collateralReserveIds,
    uint256[] memory collateralAmounts
  ) internal returns (uint256, uint256) {
    uint256 totalCollateralInBaseCurrency;
    uint256 avgCollateralFactor;
    for (uint256 i; i < collateralReserveIds.length; i++) {
      DataTypes.Reserve memory reserve = spoke.getReserve(collateralReserveIds[i]);
      uint256 collateralInBaseCurrency = (collateralAmounts[i] *
        oracle.getAssetPrice(reserve.assetId)).wadify() / 10 ** reserve.config.decimals;
      totalCollateralInBaseCurrency += collateralInBaseCurrency;
      avgCollateralFactor += collateralInBaseCurrency * reserve.config.collateralFactor;
    }
    avgCollateralFactor = totalCollateralInBaseCurrency == 0
      ? 0
      : avgCollateralFactor.wadDiv(totalCollateralInBaseCurrency);
    return (totalCollateralInBaseCurrency, avgCollateralFactor);
  }
}
