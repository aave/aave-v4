// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
// import '../mocks/MockSpokeExposedMethods.sol';

contract LiquidationCallTest is SpokeBase {
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

  /// scenario where fully liquidating a collateral still does not improve a position to close factor
  /// default close factor of 1
  function test_liquidationCall_all_collateral_default_close_factor() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 wbtcReserveId = _wbtcReserveId(spoke1);

    // // collateral: wbtc/dai
    // uint256 wbtcAmount = 1 * 10 ** tokenList.wbtc.decimals(); // $50k wbtc
    // debt: weth
    uint256 borrowAmount = 20 * 10 ** tokenList.weth.decimals(); // 20 eth, $40k

    uint256 wbtcAmount = _createMinCollateralPosition(
      spoke1,
      alice,
      wbtcReserveId,
      wethReserveId,
      borrowAmount
    );

    // wbtc collateral value drop to reduce HF < 1
    oracle.setAssetPrice(wbtcAssetId, 20_000e8);

    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    UserTokenBalance memory balancesBefore = _loadUserBalances();

    uint256 initialDebt = spoke1.getUserTotalDebt(wethReserveId, alice);
    uint256 liquidatedDebt = _convertAssetAmount(wbtcAssetId, wbtcAmount, wethAssetId);

    // bob liquidates alice
    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationCall(
      address(tokenList.wbtc),
      address(tokenList.weth),
      alice,
      liquidatedDebt,
      wbtcAmount,
      bob
    );
    vm.prank(bob);
    spoke1.liquidationCall({
      collateralReserveId: wbtcReserveId,
      debtReserveId: wethReserveId,
      user: alice,
      debtToCover: borrowAmount
    });

    UserTokenBalance memory balancesAfter = _loadUserBalances();
    UserTokenBalance memory balanceChanges = _calculateBalanceChanges(
      balancesBefore,
      balancesAfter
    );

    // wbtc collateral
    assertEq(spoke1.getUserSuppliedAmount(wbtcReserveId, alice), 0, 'alice wbtc coll liquidated');
    assertEq(balanceChanges.alice.wbtc, 0, 'alice has no wbtc change');
    assertEq(balanceChanges.bob.wbtc, wbtcAmount, 'bob receives all wbtc coll');
    assertEq(balanceChanges.treasury.wbtc, 0, 'treasury receives 0 wbtc coll');

    // weth debt
    assertEq(
      initialDebt - spoke1.getUserTotalDebt(wethReserveId, alice),
      _convertAssetAmount(wbtcAssetId, wbtcAmount, wethAssetId),
      'alice weth debt repaid'
    );
    assertEq(balanceChanges.alice.weth, 0, 'alice has no weth change');
    assertEq(
      balanceChanges.bob.weth,
      _convertAssetAmount(wbtcAssetId, wbtcAmount, wethAssetId),
      'bob pays all weth debt'
    );
    assertEq(balanceChanges.treasury.weth, 0, 'treasury has no weth change');

    // hf < 1 after
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
  }

  /// scenario where fully liquidating a collateral still does not improve a position to close factor
  /// default close factor of 1; multiple collaterals
  function test_liquidationCall_all_collateral_default_close_factor_multi_coll() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 wbtcReserveId = _wbtcReserveId(spoke1);

    // collateral: wbtc/dai
    uint256 wbtcAmount = 1 * 10 ** tokenList.wbtc.decimals(); // $50k wbtc
    uint256 daiAmount = 10_000 * 10 ** tokenList.dai.decimals(); // $10k dai
    // debt: weth
    uint256 borrowAmount = 20 * 10 ** tokenList.weth.decimals(); // 20 eth, $40k

    uint256 liqBonus = spoke1.getReserve(wbtcReserveId).config.liquidationBonus;

    _deployLiquidity(spoke1, wethReserveId, borrowAmount);
    Utils.supplyCollateral(spoke1, wbtcReserveId, alice, wbtcAmount, alice);
    Utils.supplyCollateral(spoke1, daiReserveId, alice, daiAmount, alice);
    Utils.borrow(spoke1, wethReserveId, alice, borrowAmount, alice);

    // wbtc collateral value drop to reduce HF < 1
    oracle.setAssetPrice(wbtcAssetId, 20_000e8);

    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    UserTokenBalance memory balancesBefore = _loadUserBalances();

    uint256 initialDebt = spoke1.getUserTotalDebt(wethReserveId, alice);
    uint256 liquidatedDebt = _convertAssetAmount(wbtcAssetId, wbtcAmount, wethAssetId).percentDiv(
      liqBonus
    );

    // bob liquidates alice
    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationCall(
      address(tokenList.wbtc),
      address(tokenList.weth),
      alice,
      liquidatedDebt,
      wbtcAmount,
      bob
    );
    vm.prank(bob);
    spoke1.liquidationCall({
      collateralReserveId: wbtcReserveId,
      debtReserveId: wethReserveId,
      user: alice,
      debtToCover: borrowAmount
    });

    UserTokenBalance memory balancesAfter = _loadUserBalances();
    UserTokenBalance memory balanceChanges = _calculateBalanceChanges(
      balancesBefore,
      balancesAfter
    );

    // dai collateral
    assertEq(
      spoke1.getUserSuppliedAmount(daiReserveId, alice),
      daiAmount,
      'alice dai coll unchanged'
    );
    assertEq(balanceChanges.alice.dai, 0, 'alice has no dai change');
    assertEq(balanceChanges.bob.dai, 0, 'bob receives 0 dai coll');
    assertEq(balanceChanges.treasury.dai, 0, 'treasury receives 0 dai coll');

    // wbtc collateral
    assertEq(spoke1.getUserSuppliedAmount(wbtcReserveId, alice), 0, 'alice wbtc coll liquidated');
    assertEq(balanceChanges.alice.wbtc, 0, 'alice has no wbtc change');
    assertEq(balanceChanges.bob.wbtc, wbtcAmount, 'bob receives all wbtc coll');
    assertEq(balanceChanges.treasury.wbtc, 0, 'treasury receives 0 wbtc coll');

    // weth debt
    assertEq(
      initialDebt - spoke1.getUserTotalDebt(wethReserveId, alice),
      _convertAssetAmount(wbtcAssetId, wbtcAmount, wethAssetId),
      'alice weth debt repaid'
    );
    assertEq(balanceChanges.alice.weth, 0, 'alice has no weth change');
    assertEq(
      balanceChanges.bob.weth,
      _convertAssetAmount(wbtcAssetId, wbtcAmount, wethAssetId),
      'bob pays all weth debt'
    );
    assertEq(balanceChanges.treasury.weth, 0, 'treasury has no weth change');

    // hf < 1 after
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);
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
    state.colls[0].wbtc = 1 * 10 ** tokenList.wbtc.decimals(); // $50k wbtc
    state.colls[0].dai = 10_000 * 10 ** tokenList.dai.decimals(); // $10k dai
    // debt: weth
    state.debts[0].weth = 20 * 10 ** tokenList.weth.decimals(); // 20 eth, $40k

    // calculate liquidation bonus threshold that results in negative denominator, scaledLiqBonus > closeFactor
    state.collateralFactor = 75_00;
    state.closeFactor = 1.05e18;
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
  }

  /// scenario where fully liquidating a collateral still does not improve a position to close factor
  function test_liquidationCall_full_collateral_liquidation_newCloseFactor() public {
    // UserTokenBalance memory balances;
    // uint256 wethReserveId = _wethReserveId(spoke1);
    // uint256 daiReserveId = _daiReserveId(spoke1);
    // uint256 wbtcReserveId = _wbtcReserveId(spoke1);
    // // collateral: wbtc/dai
    // uint256 wbtcAmount = 1 * 10 ** tokenList.wbtc.decimals(); // $50k wbtc
    // uint256 daiAmount = 10_000 * 10 ** tokenList.dai.decimals(); // $10k dai
    // // debt: weth
    // uint256 borrowAmount = 20 * 10 ** tokenList.weth.decimals(); // 20 eth, $40k
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
    uint256 wethAmount = 10 * 10 ** tokenList.weth.decimals(); // $20k wbtc
    uint256 daiAmount = 10_000 * 10 ** tokenList.dai.decimals(); // $10k dai
    // debt: usdx
    uint256 borrowAmount = 15_000 * 10 ** tokenList.usdx.decimals(); // $15k usdx

    _deployLiquidity(spoke1, usdxReserveId, borrowAmount);
    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, daiReserveId, alice, daiAmount, alice);
    Utils.borrow(spoke1, usdxReserveId, alice, borrowAmount, alice);

    oracle.setAssetPrice(wethAssetId, 400e8);

    vm.prank(bob);
    spoke1.liquidationCall(daiReserveId, usdxReserveId, alice, borrowAmount);

    console.log('final hf %e', spoke1.getHealthFactor(alice));
    assertLt(spoke1.getHealthFactor(alice), 1e18, 'health factor precision loss < 1 ');
  }

  // working correctly with usdx=6, dai=18, weth=18, but HF > 1 after
  function test_liquidationCall_precision_loss_gt_cf() public {
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 usdxReserveId = _usdxReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);

    // collateral: weth/usdx
    uint256 wethAmount = 10 * 10 ** tokenList.weth.decimals(); // $20k wbtc
    uint256 usdxAmount = 10_000 * 10 ** tokenList.usdx.decimals(); // $10k usdx
    // debt: dai
    uint256 borrowAmount = 15_000 * 10 ** tokenList.dai.decimals(); // $15k dai

    _deployLiquidity(spoke1, daiReserveId, borrowAmount);
    Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
    Utils.supplyCollateral(spoke1, usdxReserveId, alice, usdxAmount, alice);
    Utils.borrow(spoke1, daiReserveId, alice, borrowAmount, alice);

    oracle.setAssetPrice(wethAssetId, 800e8);

    vm.prank(bob);
    spoke1.liquidationCall(usdxReserveId, daiReserveId, alice, borrowAmount);

    console.log('final hf %e', spoke1.getHealthFactor(alice));
    assertGt(spoke1.getHealthFactor(alice), 1e18, 'health factor precision loss > 1 ');
  }

  function test_liquidationCall_exact() public {
    vm.skip(true, 'not exact');
    uint256 wethReserveId = _wethReserveId(spoke1);
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 usdyReserveId = _usdyReserveId(spoke1);
    // collateral: weth/dai
    uint256 wethAmount = 10 * 10 ** tokenList.weth.decimals(); // $20k wbtc
    uint256 daiAmount = 10_000 * 10 ** tokenList.dai.decimals(); // $10k dai
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
    console.log('final hf - exact %e', spoke1.getHealthFactor(alice));

    assertEq(spoke1.getHealthFactor(alice), 1e18, 'health factor should be exactly 1');
  }

  // // test with different decimals
  // function test_liquidationCall_case1() public {
  //   uint256 wethReserveId = _wethReserveId(spoke1);
  //   uint256 daiReserveId = _daiReserveId(spoke1);
  //   uint256 usdxReserveId = _usdxReserveId(spoke1);
  //   // uint256 daiDebtAmount = 100e18;

  //   uint256 borrowAmount = 15_000 * 10 ** tokenList.usdx.decimals();

  //   uint256 wethAmount = 10 * 10 ** tokenList.weth.decimals();
  //   uint256 daiAmount = 10_000 * 10 ** tokenList.dai.decimals();

  //   console.log('tests coll: dai %e, weth %e', daiAmount, wethAmount);
  //   console.log('tests usdx %e', borrowAmount);

  //   // _createDebtPosition(spoke1, alice, wethReserveId, daiReserveId, daiDebtAmount);

  //   // _updateCloseFactor(spoke1, 1.05e18);

  //   _deployLiquidity(spoke1, usdxReserveId, borrowAmount * 10);
  //   Utils.supplyCollateral(spoke1, wethReserveId, alice, wethAmount, alice);
  //   Utils.supplyCollateral(spoke1, daiReserveId, alice, daiAmount, alice);
  //   Utils.borrow(spoke1, usdxReserveId, alice, borrowAmount, alice);

  //   console.log(spoke1.getHealthFactor(alice));

  //   console.log(' coll %e', spoke1.getUserSuppliedAmount(wethReserveId, alice));
  //   console.log(' debt %e', spoke1.getUserTotalDebt(usdxReserveId, alice));
  //   console.log(' hf %e', spoke1.getHealthFactor(alice));

  //   oracle.setAssetPrice(wethAssetId, 800e8);

  //   console.log(' hf %e', spoke1.getHealthFactor(alice));

  //   // _setPriceChange(oracle, wethAssetId, 90_00); // 10% drop
  //   // console.log(spoke1.getHealthFactor(alice));

  //   // skip(365 days);

  //   vm.prank(bob);
  //   spoke1.liquidationCall(daiReserveId, usdxReserveId, alice, borrowAmount * 2);

  //   // console.log('final asset coll %e', hub.getAssetSuppliedAmount(wethAssetId));
  //   // console.log('final asset debt %e', hub.getAssetTotalDebt(daiAssetId));

  //   // console.log('final coll %e', spoke1.getUserSuppliedAmount(wethReserveId, alice));
  //   // console.log('final debt %e', spoke1.getUserTotalDebt(daiReserveId, alice));
  //   console.log('final hf %e', spoke1.getHealthFactor(alice));
  // }

  // function test_liquidationCall_default() public {
  //   uint256 wethReserveId = _wethReserveId(spoke1);
  //   uint256 daiReserveId = _daiReserveId(spoke1);
  //   uint256 daiDebtAmount = 100e18;

  //   _createMinCollateralPosition(spoke1, alice, wethReserveId, daiReserveId, daiDebtAmount);

  //   console.log(spoke1.getHealthFactor(alice));

  //   console.log(' coll %e', spoke1.getUserSuppliedAmount(wethReserveId, alice));
  //   console.log(' debt %e', spoke1.getUserTotalDebt(daiReserveId, alice));
  //   console.log(' hf %e', spoke1.getHealthFactor(alice));

  //   _setPriceChange(oracle, wethAssetId, 90_00); // 10% drop
  //   console.log(spoke1.getHealthFactor(alice));

  //   // skip(365 days);

  //   vm.prank(bob);
  //   spoke1.liquidationCall(wethReserveId, daiReserveId, alice, daiDebtAmount);

  //   console.log('final asset coll %e', hub.getAssetSuppliedAmount(wethAssetId));
  //   console.log('final asset debt %e', hub.getAssetTotalDebt(daiAssetId));

  //   console.log('final coll %e', spoke1.getUserSuppliedAmount(wethReserveId, alice));
  //   console.log('final debt %e', spoke1.getUserTotalDebt(daiReserveId, alice));
  //   console.log('final hf %e', spoke1.getHealthFactor(alice));
  // }

  //   MockSpokeExposedMethods mockSpoke1;
  //   MockSpokeExposedMethods mockSpoke2;

  //   function setUp() public override {
  //     super.setUp();

  //     mockSpoke1 = new MockSpokeExposedMethods(address(hub), address(oracle));
  //     mockSpoke2 = new MockSpokeExposedMethods(address(hub), address(oracle));

  //     address[] memory spokes = new address[](2);
  //     spokes[0] = address(mockSpoke1);
  //     spokes[1] = address(mockSpoke2);
  //     DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
  //     spokeConfigs[0] = DataTypes.SpokeConfig({
  //       supplyCap: type(uint256).max,
  //       drawCap: type(uint256).max
  //     });
  //     spokeConfigs[1] = DataTypes.SpokeConfig({
  //       supplyCap: type(uint256).max,
  //       drawCap: type(uint256).max
  //     });

  //     Spoke.ReserveConfig[] memory reserveConfigs = new Spoke.ReserveConfig[](2);

  //     // Add dai
  //     uint256 daiAssetId = 0;
  //     reserveConfigs[0] = Spoke.ReserveConfig({
  //       lt: 0.75e4,
  //       lb: 1.05e4,
  //       lpfp: 0,
  //       borrowable: true,
  //       collateral: true
  //     });
  //     reserveConfigs[1] = Spoke.ReserveConfig({
  //       lt: 0.8e4,
  //       lb: 1.03e4,
  //       lpfp: 0,
  //       borrowable: true,
  //       collateral: true
  //     });
  //     Utils.addAssetAndSpokes(
  //       hub,
  //       address(dai),
  //       DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
  //       spokes,
  //       spokeConfigs,
  //       reserveConfigs
  //     );
  //     MockPriceOracle(address(oracle)).setAssetPrice(daiAssetId, 1e8);
  //     irStrategy.setInterestRateParams(
  //       daiAssetId,
  //       IDefaultInterestRateStrategy.InterestRateData({
  //         optimalUsageRatio: 9000, // 90.00%
  //         baseVariableBorrowRate: 500, // 5.00%
  //         variableRateSlope1: 500, // 5.00%
  //         variableRateSlope2: 500 // 5.00%
  //       })
  //     );

  //     // Add eth
  //     uint256 ethAssetId = 1;
  //     reserveConfigs[0] = Spoke.ReserveConfig({
  //       lt: 0.8e4,
  //       lb: 1.02e4,
  //       lpfp: 0,
  //       borrowable: true,
  //       collateral: true
  //     });
  //     reserveConfigs[1] = Spoke.ReserveConfig({
  //       lt: 0.76e4,
  //       lb: 1.01e4,
  //       lpfp: 0,
  //       borrowable: true,
  //       collateral: true
  //     });
  //     Utils.addAssetAndSpokes(
  //       hub,
  //       address(eth),
  //       DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
  //       spokes,
  //       spokeConfigs,
  //       reserveConfigs
  //     );
  //     MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 2000e8);
  //     irStrategy.setInterestRateParams(
  //       ethAssetId,
  //       IDefaultInterestRateStrategy.InterestRateData({
  //         optimalUsageRatio: 9000, // 90.00%
  //         baseVariableBorrowRate: 500, // 5.00%
  //         variableRateSlope1: 500, // 5.00%
  //         variableRateSlope2: 500 // 5.00%
  //       })
  //     );

  //     // Add USDC
  //     uint256 usdcAssetId = 2;
  //     reserveConfigs[0] = Spoke.ReserveConfig({
  //       lt: 0.78e4,
  //       lb: 1.06e4,
  //       lpfp: 0,
  //       borrowable: true,
  //       collateral: true
  //     });
  //     reserveConfigs[1] = Spoke.ReserveConfig({
  //       lt: 0.72e4,
  //       lb: 1.08e4,
  //       lpfp: 0,
  //       borrowable: true,
  //       collateral: true
  //     });
  //     Utils.addAssetAndSpokes(
  //       hub,
  //       address(usdc),
  //       DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
  //       spokes,
  //       spokeConfigs,
  //       reserveConfigs
  //     );
  //     MockPriceOracle(address(oracle)).setAssetPrice(usdcAssetId, 1e8);
  //     irStrategy.setInterestRateParams(
  //       usdcAssetId,
  //       IDefaultInterestRateStrategy.InterestRateData({
  //         optimalUsageRatio: 9000, // 90.00%
  //         baseVariableBorrowRate: 500, // 5.00%
  //         variableRateSlope1: 500, // 5.00%
  //         variableRateSlope2: 500 // 5.00%
  //       })
  //     );

  //     // Add WBTC
  //     uint256 wbtcAssetId = 3;
  //     reserveConfigs[0] = Spoke.ReserveConfig({
  //       lt: 0.85e4,
  //       lb: 1.05e4,
  //       lpfp: 0,
  //       borrowable: true,
  //       collateral: true
  //     });
  //     reserveConfigs[1] = Spoke.ReserveConfig({
  //       lt: 0.84e4,
  //       lb: 1.025e4,
  //       lpfp: 0,
  //       borrowable: true,
  //       collateral: true
  //     });
  //     Utils.addAssetAndSpokes(
  //       hub,
  //       address(wbtc),
  //       DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
  //       spokes,
  //       spokeConfigs,
  //       reserveConfigs
  //     );
  //     MockPriceOracle(address(oracle)).setAssetPrice(wbtcAssetId, 50_000e8);
  //     irStrategy.setInterestRateParams(
  //       wbtcAssetId,
  //       IDefaultInterestRateStrategy.InterestRateData({
  //         optimalUsageRatio: 9000, // 90.00%
  //         baseVariableBorrowRate: 500, // 5.00%
  //         variableRateSlope1: 500, // 5.00%
  //         variableRateSlope2: 500 // 5.00%
  //       })
  //     );
  //   }

  //   function test_liquidationCall_revertsWith_invalid_debt_to_cover() public {
  //     uint256 ethAssetId = 1; // collateral asset
  //     uint256 daiAssetId = 0; // debt asset
  //     uint256 debtToCover = 0;

  //     vm.prank(LIQUIDATOR);
  //     vm.expectRevert(TestErrors.INVALID_DEBT_TO_COVER);
  //     mockSpoke1.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  //   }

  //   function test_liquidationCall_no_supply_revertsWith_health_factor_not_below_threshold() public {
  //     uint256 ethAssetId = 1; // collateral asset
  //     uint256 daiAssetId = 0; // debt asset
  //     uint256 debtToCover = 1;

  //     vm.expectRevert(TestErrors.HEALTH_FACTOR_NOT_BELOW_THRESHOLD);
  //     vm.prank(LIQUIDATOR);
  //     mockSpoke1.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  //   }

  //   function test_liquidationCall_revertsWith_health_factor_not_below_threshold() public {
  //     uint256 debtToCover = 1;
  //     uint256 daiAssetId = 0;
  //     uint256 ethAssetId = 1;
  //     uint256 usdcAssetId = 2;
  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k
  //     uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
  //     bool usingAsCollateral = true;

  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //     vm.prank(LIQUIDATOR);
  //     vm.expectRevert(TestErrors.HEALTH_FACTOR_NOT_BELOW_THRESHOLD);
  //     mockSpoke1.liquidationCall(ethAssetId, daiAssetId, USER1, debtToCover);
  //   }

  //   function test_liquidationCall_revertsWith_collateral_cannot_be_liquidated() public {
  //     uint256 debtToCover = 1;

  //     uint256 daiAssetId = 0;
  //     uint256 ethAssetId = 1;
  //     uint256 usdcAssetId = 2;
  //     uint256 wbtcAssetId = 3;

  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k
  //     uint256 wbtcAmount = 1e18; // 1 wbtc -> $50k
  //     uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
  //     bool usingAsCollateral = true;

  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

  //     // USER1 supply wbtc into mockSpoke1, NOT as collateral
  //     deal(address(wbtc), USER1, wbtcAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER1, wbtcAmount, USER1);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //     // HF drops below threshold, eth -> 0
  //     MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0);

  //     // wbtc is not set usingAsCollateral
  //     vm.prank(LIQUIDATOR);
  //     vm.expectRevert(TestErrors.COLLATERAL_CANNOT_BE_LIQUIDATED);
  //     mockSpoke1.liquidationCall(wbtcAssetId, daiAssetId, USER1, debtToCover);
  //   }

  //   function test_liquidationCall_lt0_revertsWith_collateral_cannot_be_liquidated() public {
  //     uint256 debtToCover = 1;

  //     uint256 daiAssetId = 0;
  //     uint256 ethAssetId = 1;
  //     uint256 usdcAssetId = 2;
  //     uint256 wbtcAssetId = 3;

  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k
  //     uint256 wbtcAmount = 1e18; // 1 wbtc -> $50k
  //     uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
  //     bool usingAsCollateral = true;

  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

  //     // USER1 supply wbtc into mockSpoke1
  //     deal(address(wbtc), USER1, wbtcAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, wbtcAssetId, USER1, wbtcAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, wbtcAssetId, usingAsCollateral);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //     // HF drops below threshold, eth -> 0
  //     MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0);

  //     // set LT to 0 for wbtc
  //     Utils.updateLiquidationThreshold(mockSpoke1, wbtcAssetId, 0);

  //     // wbtc is not set usingAsCollateral
  //     vm.prank(LIQUIDATOR);
  //     vm.expectRevert(TestErrors.COLLATERAL_CANNOT_BE_LIQUIDATED);
  //     mockSpoke1.liquidationCall(usdcAssetId, daiAssetId, USER1, debtToCover);
  //   }

  //   function test_liquidationCall_revertsWith_specified_currency_not_borrowed_by_user() public {
  //     uint256 debtToCover = 1;

  //     uint256 daiAssetId = 0;
  //     uint256 ethAssetId = 1;
  //     uint256 usdcAssetId = 2;
  //     uint256 wbtcAssetId = 3;

  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k
  //     uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
  //     bool usingAsCollateral = true;

  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, daiAssetId, usingAsCollateral);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, ethAssetId, usingAsCollateral);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //     // HF drops below threshold, eth -> 0
  //     MockPriceOracle(address(oracle)).setAssetPrice(ethAssetId, 0);

  //     // wbtc is not set usingAsCollateral
  //     vm.prank(LIQUIDATOR);
  //     vm.expectRevert(TestErrors.SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER);
  //     mockSpoke1.liquidationCall(daiAssetId, wbtcAssetId, USER1, debtToCover);
  //   }

  //   struct TestLiquidationCallLocalParams {
  //     Spoke.UserConfig user1DaiData1;
  //     Spoke.UserConfig user1EthData1;
  //     Spoke.UserConfig user1UsdcData1;
  //     Spoke.UserConfig user2UsdcData1;
  //     Spoke.UserConfig user1WbtcData1;
  //     Spoke.UserConfig user2WbtcData1;
  //     Spoke.UserConfig user1WbtcData2;
  //     Spoke.Reserve reserveDaiData1;
  //     Spoke.Reserve reserveEthData1;
  //     LiquidityHub.Spoke mockSpoke1DaiData1;
  //     LiquidityHub.Spoke mockSpoke1EthData1;
  //     LiquidityHub.Spoke mockSpoke1UsdcData1;
  //     LiquidityHub.Spoke mockSpoke1WbtcData1;
  //     Spoke.UserConfig user1DaiData2;
  //     Spoke.UserConfig user1EthData2;
  //     Spoke.UserConfig user1UsdcData2;
  //     LiquidityHub.Spoke mockSpoke1DaiData2;
  //     LiquidityHub.Spoke mockSpoke1EthData2;
  //     LiquidityHub.Spoke mockSpoke1UsdcData2;
  //     LiquidityHub.Spoke mockSpoke1WbtcData2;
  //     Spoke.Reserve collateralReserve;
  //     Spoke.Reserve debtReserve;
  //     uint256 actualDebtCovered;
  //     uint256 totalCollateralInBaseCurrency;
  //     uint256 totalDebtInBaseCurrency;
  //     uint256 avgLiquidationThreshold;
  //     uint256 userCollateralBalance;
  //     uint256 actualCollateralToLiquidate;
  //     uint256 actualDebtToLiquidate;
  //     uint256 liquidationProtocolFeeAmount;
  //     uint256 expectedDaiTotalSharesRemaining;
  //     uint256 expectedEthTotalSharesRemaining;
  //     uint256 expectedUsdcDrawnSharesRemaining;
  //     uint256 newLpfp;
  //     uint256 debtToCover;
  //     uint256 debtAssetPrice;
  //     uint256 daiAssetId;
  //     uint256 ethAssetId;
  //     uint256 usdcAssetId;
  //     uint256 wbtcAssetId;
  //     uint256 hf0;
  //     uint256 hf1;
  //     uint256 hf2;
  //   }

  //   /// @dev Test liquidation call with liquidated amount >= user collateral balance; liquidation protocol fee = 0; liquidation bonus = 0
  //   function test_liquidationCall_gteUserCollateralBalance_zeroLiquidationProtocolFeeZeroLiqBonus()
  //     public
  //   {
  //     TestLiquidationCallLocalParams memory vars;

  //     vars.debtToCover = 15_000e18;
  //     vars.daiAssetId = 0;
  //     vars.ethAssetId = 1;
  //     vars.usdcAssetId = 2;

  //     // total collateral: $30k
  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k

  //     // total borrowed: $15k
  //     uint256 usdcBorrowAmount = vars.debtToCover; // 15k usdc -> $15k
  //     bool usingAsCollateral = true;

  //     // T0: supply/borrow
  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //     vars.hf0 = mockSpoke1.getHealthFactor(USER1);
  //     assertTrue(
  //       vars.hf0 > mockHEALTH_FACTOR_LIQUIDATION_THRESHOLD,
  //       'Unexpected T1 health factor'
  //     );

  //     // T1: eth price drops from $2000 -> $800/eth
  //     MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);
  //     vars.hf1 = mockSpoke1.getHealthFactor(USER1);
  //     assertTrue(vars.hf1 < vars.hf0, 'Unexpected change in user1 hf at T1');

  //     Utils.updateLiquidationBonus(mockSpoke1, vars.daiAssetId, 1e4); // set 0% liq bonus

  //     // pre-liquidation
  //     vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));

  //     vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

  //     vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
  //     vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

  //     // dai
  //     assertEq(
  //       vars.user1DaiData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 dai usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1DaiData1.supplyShares,
  //       vars.mockSpoke1DaiData1.totalShares,
  //       'Unexpected T1 user1 dai supplyShares'
  //     );
  //     assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
  //     assertEq(
  //       vars.mockSpoke1DaiData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
  //       'Unexpected T1 mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(
  //       vars.user1EthData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 eth usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1EthData1.supplyShares,
  //       vars.mockSpoke1EthData1.totalShares,
  //       'Unexpected T1 user1 eth supplyShares'
  //     );
  //     assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
  //     assertEq(
  //       vars.mockSpoke1EthData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected T1 mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(
  //       vars.user1UsdcData1.usingAsCollateral,
  //       false,
  //       'Unexpected T1 user1 usdc usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user2UsdcData1.supplyShares,
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       'Unexpected T1 user2 usdc supplyShares'
  //     );
  //     assertEq(
  //       vars.user1UsdcData1.debtShares,
  //       vars.user2UsdcData1.supplyShares,
  //       'Unexpected T1 user1 usdc debtShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.drawnShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc drawnShares'
  //     );

  //     // T2 / T_final
  //     // action: liquidation
  //     deal(address(usdc), LIQUIDATOR, vars.debtToCover);
  //     vm.startPrank(LIQUIDATOR);
  //     usdc.approve(address(mockSpoke1), vars.debtToCover);

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

  //     (
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       ,

  //     ) = mockSpoke1.calculateUserAccountData(USER1);

  //     vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtToCover,
  //       USER1,
  //       vars.usdcAssetId,
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       vars.debtAssetPrice
  //     );

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
  //     vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

  //     (
  //       vars.actualCollateralToLiquidate,
  //       vars.actualDebtToLiquidate,
  //       vars.liquidationProtocolFeeAmount
  //     ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtReserve,
  //       vars.actualDebtToLiquidate,
  //       vars.userCollateralBalance,
  //       vars.debtAssetPrice
  //     );

  //     vm.expectEmit(address(mockSpoke1));
  //     emit LiquidationCall({
  //       collateralAssetId: vars.daiAssetId,
  //       debtAssetId: vars.usdcAssetId,
  //       user: USER1,
  //       actualDebtToLiquidate: vars.actualDebtToLiquidate,
  //       actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
  //       liquidator: LIQUIDATOR
  //     });
  //     mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
  //     vm.stopPrank();

  //     // post-liquidation
  //     vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
  //     vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
  //     vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
  //     vars.expectedDaiTotalSharesRemaining =
  //       vars.mockSpoke1DaiData1.totalShares -
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, vars.actualCollateralToLiquidate);
  //     vars.expectedUsdcDrawnSharesRemaining =
  //       vars.mockSpoke1UsdcData1.drawnShares -
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
  //     vars.hf2 = mockSpoke1.getHealthFactor(USER1);

  //     // dai
  //     assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1DaiData2.totalShares,
  //       vars.expectedDaiTotalSharesRemaining,
  //       'Unexpected mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1EthData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.drawnShares,
  //       vars.mockSpoke1UsdcData2.totalShares -
  //         hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
  //       'Unexpected mockSpoke1 usdc drawnShares'
  //     );
  //     // hf assertions
  //     assertEq(
  //       vars.hf2,
  //       mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
  //       'Unexpected user1 Tf health factor'
  //     );
  //     assertTrue(vars.hf2 > vars.hf1, 'Unexpected final decrease in user1 health factor');

  //     // liquidator
  //     assertEq(
  //       usdc.balanceOf(LIQUIDATOR),
  //       vars.debtToCover - vars.actualDebtToLiquidate,
  //       'Unexpected liquidator debt asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(LIQUIDATOR),
  //       vars.actualCollateralToLiquidate,
  //       'Unexpected liquidator collateral asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
  //       0,
  //       'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
  //     );
  //   }

  //   function test_liquidationCall_gteUserCollateralBalance_zeroLiquidationProtocolFee() public {
  //     TestLiquidationCallLocalParams memory vars;

  //     vars.debtToCover = 15_000e18;
  //     vars.daiAssetId = 0;
  //     vars.ethAssetId = 1;
  //     vars.usdcAssetId = 2;

  //     // total collateral: $30k
  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k

  //     // total borrowed: $15k
  //     uint256 usdcBorrowAmount = vars.debtToCover; // 15k usdc -> $15k
  //     bool usingAsCollateral = true;

  //     // T0
  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //     vars.hf0 = mockSpoke1.getHealthFactor(USER1);
  //     assertTrue(
  //       vars.hf0 > mockHEALTH_FACTOR_LIQUIDATION_THRESHOLD,
  //       'Unexpected T1 health factor'
  //     );

  //     // T1: eth price drops from $2000 -> $800/eth
  //     MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);

  //     vars.hf1 = mockSpoke1.getHealthFactor(USER1);
  //     assertTrue(vars.hf1 < vars.hf0, 'Unexpected change in user1 hf at T1');

  //     // pre-liquidation
  //     vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));

  //     vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

  //     vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
  //     vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

  //     // dai
  //     assertEq(
  //       vars.user1DaiData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 dai usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1DaiData1.supplyShares,
  //       vars.mockSpoke1DaiData1.totalShares,
  //       'Unexpected T1 user1 dai supplyShares'
  //     );
  //     assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
  //     assertEq(
  //       vars.mockSpoke1DaiData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
  //       'Unexpected T1 mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(
  //       vars.user1EthData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 eth usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1EthData1.supplyShares,
  //       vars.mockSpoke1EthData1.totalShares,
  //       'Unexpected T1 user1 eth supplyShares'
  //     );
  //     assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
  //     assertEq(
  //       vars.mockSpoke1EthData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected T1 mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(
  //       vars.user1UsdcData1.usingAsCollateral,
  //       false,
  //       'Unexpected T1 user1 usdc usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user2UsdcData1.supplyShares,
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       'Unexpected T1 user2 usdc supplyShares'
  //     );
  //     assertEq(
  //       vars.user1UsdcData1.debtShares,
  //       vars.user2UsdcData1.supplyShares,
  //       'Unexpected T1 user1 usdc debtShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.drawnShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc drawnShares'
  //     );

  //     // T2 / T_final
  //     // action: liquidation
  //     deal(address(usdc), LIQUIDATOR, vars.debtToCover);
  //     vm.startPrank(LIQUIDATOR);
  //     usdc.approve(address(mockSpoke1), vars.debtToCover);

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

  //     (
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       ,

  //     ) = mockSpoke1.calculateUserAccountData(USER1);

  //     vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtToCover,
  //       USER1,
  //       vars.usdcAssetId,
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       vars.debtAssetPrice
  //     );

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
  //     vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

  //     (
  //       vars.actualCollateralToLiquidate,
  //       vars.actualDebtToLiquidate,
  //       vars.liquidationProtocolFeeAmount
  //     ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtReserve,
  //       vars.actualDebtToLiquidate,
  //       vars.userCollateralBalance,
  //       vars.debtAssetPrice
  //     );

  //     vm.expectEmit(address(mockSpoke1));
  //     emit LiquidationCall({
  //       collateralAssetId: vars.daiAssetId,
  //       debtAssetId: vars.usdcAssetId,
  //       user: USER1,
  //       actualDebtToLiquidate: vars.actualDebtToLiquidate,
  //       actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
  //       liquidator: LIQUIDATOR
  //     });
  //     mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
  //     vm.stopPrank();

  //     // post-liquidation
  //     vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
  //     vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
  //     vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
  //     vars.expectedDaiTotalSharesRemaining =
  //       vars.mockSpoke1DaiData1.totalShares -
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, vars.actualCollateralToLiquidate);
  //     vars.expectedUsdcDrawnSharesRemaining =
  //       vars.mockSpoke1UsdcData1.drawnShares -
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
  //     vars.hf2 = mockSpoke1.getHealthFactor(USER1);

  //     // dai
  //     assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1DaiData2.totalShares,
  //       vars.expectedDaiTotalSharesRemaining,
  //       'Unexpected mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1EthData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.drawnShares,
  //       vars.mockSpoke1UsdcData2.totalShares -
  //         hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
  //       'Unexpected mockSpoke1 usdc drawnShares'
  //     );
  //     assertEq(
  //       mockSpoke1.getHealthFactor(USER1),
  //       mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
  //       'Unexpected user1 final health factor'
  //     );
  //     // health factor
  //     assertEq(
  //       vars.hf2,
  //       mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
  //       'Unexpected user1 final health factor'
  //     );
  //     assertTrue(vars.hf2 > vars.hf1, 'Unexpected final decrease in user1 health factor');

  //     // liquidator
  //     assertEq(
  //       usdc.balanceOf(LIQUIDATOR),
  //       vars.debtToCover - vars.actualDebtToLiquidate,
  //       'Unexpected liquidator debt asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(LIQUIDATOR),
  //       vars.actualCollateralToLiquidate,
  //       'Unexpected liquidator collateral asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
  //       vars.liquidationProtocolFeeAmount,
  //       'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
  //     );
  //   }

  //   function test_liquidationCall_gteUserCollateralBalance() public {
  //     TestLiquidationCallLocalParams memory vars;

  //     vars.debtToCover = 15_000e18;
  //     vars.daiAssetId = 0;
  //     vars.ethAssetId = 1;
  //     vars.usdcAssetId = 2;
  //     vars.newLpfp = 200;

  //     // total collateral: $30k
  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k

  //     // total borrowed: $15k
  //     uint256 usdcBorrowAmount = vars.debtToCover; // 15k usdc -> $15k
  //     bool usingAsCollateral = true;

  //     // T0
  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);
  //     Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.daiAssetId, vars.newLpfp);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //     vars.hf0 = mockSpoke1.getHealthFactor(USER1);

  //     assertTrue(
  //       vars.hf0 > mockHEALTH_FACTOR_LIQUIDATION_THRESHOLD,
  //       'Unexpected T1 health factor'
  //     );

  //     // T1: eth price drops from $2000 -> $800/eth
  //     MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);
  //     vars.hf1 = mockSpoke1.getHealthFactor(USER1);
  //     assertTrue(vars.hf1 < vars.hf0, 'Unexpected change in user1 hf at T1');

  //     // pre-liquidation
  //     vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.reserveDaiData1 = mockSpoke1.getReserve(vars.daiAssetId);

  //     vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

  //     vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
  //     vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

  //     assertEq(
  //       vars.reserveDaiData1.config.lpfp,
  //       vars.newLpfp,
  //       'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
  //     );

  //     // dai
  //     assertEq(
  //       vars.user1DaiData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 dai usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1DaiData1.supplyShares,
  //       vars.mockSpoke1DaiData1.totalShares,
  //       'Unexpected T1 user1 dai supplyShares'
  //     );
  //     assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
  //     assertEq(
  //       vars.mockSpoke1DaiData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
  //       'Unexpected T1 mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(
  //       vars.user1EthData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 eth usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1EthData1.supplyShares,
  //       vars.mockSpoke1EthData1.totalShares,
  //       'Unexpected T1 user1 eth supplyShares'
  //     );
  //     assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
  //     assertEq(
  //       vars.mockSpoke1EthData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected T1 mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(
  //       vars.user1UsdcData1.usingAsCollateral,
  //       false,
  //       'Unexpected T1 user1 usdc usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user2UsdcData1.supplyShares,
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       'Unexpected T1 user2 usdc supplyShares'
  //     );
  //     assertEq(
  //       vars.user1UsdcData1.debtShares,
  //       vars.user2UsdcData1.supplyShares,
  //       'Unexpected T1 user1 usdc debtShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.drawnShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc drawnShares'
  //     );

  //     // action: liquidation
  //     deal(address(usdc), LIQUIDATOR, vars.debtToCover);
  //     vm.startPrank(LIQUIDATOR);
  //     usdc.approve(address(mockSpoke1), vars.debtToCover);

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

  //     (
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       ,

  //     ) = mockSpoke1.calculateUserAccountData(USER1);

  //     vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtToCover,
  //       USER1,
  //       vars.usdcAssetId,
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       vars.debtAssetPrice
  //     );

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
  //     vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

  //     (
  //       vars.actualCollateralToLiquidate,
  //       vars.actualDebtToLiquidate,
  //       vars.liquidationProtocolFeeAmount
  //     ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtReserve,
  //       vars.actualDebtToLiquidate,
  //       vars.userCollateralBalance,
  //       vars.debtAssetPrice
  //     );

  //     vm.expectEmit(address(mockSpoke1));
  //     emit LiquidationCall({
  //       collateralAssetId: vars.daiAssetId,
  //       debtAssetId: vars.usdcAssetId,
  //       user: USER1,
  //       actualDebtToLiquidate: vars.actualDebtToLiquidate,
  //       actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
  //       liquidator: LIQUIDATOR
  //     });
  //     mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
  //     vm.stopPrank();

  //     // post-liquidation
  //     vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));

  //     vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

  //     vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

  //     vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
  //     vars.expectedDaiTotalSharesRemaining =
  //       vars.mockSpoke1DaiData1.totalShares -
  //       hub.convertAssetsToSharesDown(
  //         vars.daiAssetId,
  //         vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
  //       );
  //     vars.expectedUsdcDrawnSharesRemaining =
  //       vars.mockSpoke1UsdcData1.drawnShares -
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
  //     vars.hf2 = mockSpoke1.getHealthFactor(USER1);

  //     // dai
  //     assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1DaiData2.totalShares,
  //       vars.expectedDaiTotalSharesRemaining,
  //       'Unexpected mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1EthData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.drawnShares,
  //       vars.mockSpoke1UsdcData2.totalShares -
  //         hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
  //       'Unexpected mockSpoke1 usdc drawnShares'
  //     );
  //     // health factor
  //     assertEq(
  //       vars.hf2,
  //       mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
  //       'Unexpected user1 final health factor'
  //     );
  //     assertTrue(vars.hf2 > vars.hf1, 'Unexpected final decrease in user1 health factor');

  //     // liquidator
  //     assertEq(
  //       usdc.balanceOf(LIQUIDATOR),
  //       vars.debtToCover - vars.actualDebtToLiquidate,
  //       'Unexpected liquidator debt asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(LIQUIDATOR),
  //       vars.actualCollateralToLiquidate,
  //       'Unexpected liquidator collateral asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
  //       vars.liquidationProtocolFeeAmount,
  //       'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
  //     );
  //   }

  //   /// @dev Test liquidation call with maxLiquidatableDebt <= liquidationRecoveryDebt
  //   function test_liquidationCall_maxLiquidatableDebt_lte_liquidationRecoveryDebt() public {
  //     TestLiquidationCallLocalParams memory vars;

  //     vars.debtToCover = 15_000e18;
  //     vars.daiAssetId = 0;
  //     vars.ethAssetId = 1;
  //     vars.usdcAssetId = 2;
  //     vars.newLpfp = 200;

  //     // total collateral: $30k
  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k

  //     // total borrowed: $15k
  //     uint256 usdcBorrowAmount = vars.debtToCover; // 15k usdc -> $15k
  //     bool usingAsCollateral = true;

  //     // T0
  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);
  //     Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.daiAssetId, vars.newLpfp);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //     vars.hf0 = mockSpoke1.getHealthFactor(USER1);

  //     assertTrue(
  //       vars.hf0 > mockHEALTH_FACTOR_LIQUIDATION_THRESHOLD,
  //       'Unexpected T1 health factor'
  //     );

  //     // eth price drops
  //     MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 0.1e8);

  //     vars.hf1 = mockSpoke1.getHealthFactor(USER1);
  //     assertTrue(vars.hf1 < vars.hf0, 'Unexpected change in user1 hf at T1');

  //     // pre-liquidation
  //     vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.reserveDaiData1 = mockSpoke1.getReserve(vars.daiAssetId);

  //     vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

  //     vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
  //     vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

  //     assertEq(
  //       vars.reserveDaiData1.config.lpfp,
  //       vars.newLpfp,
  //       'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
  //     );

  //     // dai
  //     assertEq(
  //       vars.user1DaiData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 dai usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1DaiData1.supplyShares,
  //       vars.mockSpoke1DaiData1.totalShares,
  //       'Unexpected T1 user1 dai supplyShares'
  //     );
  //     assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
  //     assertEq(
  //       vars.mockSpoke1DaiData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
  //       'Unexpected T1 mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(
  //       vars.user1EthData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 eth usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1EthData1.supplyShares,
  //       vars.mockSpoke1EthData1.totalShares,
  //       'Unexpected T1 user1 eth supplyShares'
  //     );
  //     assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
  //     assertEq(
  //       vars.mockSpoke1EthData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected T1 mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(
  //       vars.user1UsdcData1.usingAsCollateral,
  //       false,
  //       'Unexpected T1 user1 usdc usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user2UsdcData1.supplyShares,
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       'Unexpected T1 user2 usdc supplyShares'
  //     );
  //     assertEq(
  //       vars.user1UsdcData1.debtShares,
  //       vars.user2UsdcData1.supplyShares,
  //       'Unexpected T1 user1 usdc debtShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.drawnShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc drawnShares'
  //     );

  //     // T2 / T_final
  //     // action: liquidation
  //     deal(address(usdc), LIQUIDATOR, vars.debtToCover);
  //     vm.startPrank(LIQUIDATOR);
  //     usdc.approve(address(mockSpoke1), vars.debtToCover);

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

  //     (
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       ,

  //     ) = mockSpoke1.calculateUserAccountData(USER1);

  //     vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtToCover,
  //       USER1,
  //       vars.usdcAssetId,
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       vars.debtAssetPrice
  //     );

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
  //     vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

  //     (
  //       vars.actualCollateralToLiquidate,
  //       vars.actualDebtToLiquidate,
  //       vars.liquidationProtocolFeeAmount
  //     ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtReserve,
  //       vars.actualDebtToLiquidate,
  //       vars.userCollateralBalance,
  //       vars.debtAssetPrice
  //     );

  //     vm.expectEmit(address(mockSpoke1));
  //     emit LiquidationCall({
  //       collateralAssetId: vars.daiAssetId,
  //       debtAssetId: vars.usdcAssetId,
  //       user: USER1,
  //       actualDebtToLiquidate: vars.actualDebtToLiquidate,
  //       actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
  //       liquidator: LIQUIDATOR
  //     });
  //     mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
  //     vm.stopPrank();

  //     // post-liquidation
  //     vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
  //     vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
  //     vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
  //     vars.expectedDaiTotalSharesRemaining =
  //       vars.mockSpoke1DaiData1.totalShares -
  //       hub.convertAssetsToSharesDown(
  //         vars.daiAssetId,
  //         vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
  //       );
  //     vars.expectedUsdcDrawnSharesRemaining =
  //       vars.mockSpoke1UsdcData1.drawnShares -
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
  //     vars.hf2 = mockSpoke1.getHealthFactor(USER1);

  //     // dai
  //     assertEq(vars.user1DaiData2.usingAsCollateral, false, 'Unexpected user1 dai usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1DaiData2.totalShares,
  //       vars.expectedDaiTotalSharesRemaining,
  //       'Unexpected mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1EthData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.drawnShares,
  //       vars.mockSpoke1UsdcData2.totalShares -
  //         hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
  //       'Unexpected mockSpoke1 usdc drawnShares'
  //     );
  //     // health factor
  //     assertTrue(
  //       vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
  //       'Unexpected user1 final health factor'
  //     );
  //     assertTrue(vars.hf2 < vars.hf1, 'Unexpected final change in user1 health factor'); // in this case HF decreases as remaining collateral has dropped in value drastically

  //     // liquidator
  //     assertEq(
  //       usdc.balanceOf(LIQUIDATOR),
  //       vars.debtToCover - vars.actualDebtToLiquidate,
  //       'Unexpected liquidator debt asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(LIQUIDATOR),
  //       vars.actualCollateralToLiquidate,
  //       'Unexpected liquidator collateral asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
  //       vars.liquidationProtocolFeeAmount,
  //       'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
  //     );
  //   }

  //   /// @dev Test liquidation call liquidating the non stablecoin collateral
  //   function test_liquidationCall_gteUserCollateralBalance_liquidateEth() public {
  //     TestLiquidationCallLocalParams memory vars;

  //     vars.debtToCover = 15_000e18;
  //     vars.daiAssetId = 0;
  //     vars.ethAssetId = 1;
  //     vars.usdcAssetId = 2;
  //     vars.newLpfp = 200;

  //     // total collateral: $30k
  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k

  //     // total borrowed: $15k
  //     uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
  //     bool usingAsCollateral = true;

  //     // T0
  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);
  //     Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.ethAssetId, vars.newLpfp);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //     vars.hf0 = mockSpoke1.getHealthFactor(USER1);

  //     assertTrue(
  //       vars.hf0 > mockHEALTH_FACTOR_LIQUIDATION_THRESHOLD,
  //       'Unexpected T1 health factor'
  //     );

  //     // eth price drops from $2000 -> $600/eth
  //     MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 600e8);

  //     vars.hf1 = mockSpoke1.getHealthFactor(USER1);
  //     assertTrue(
  //       vars.hf1 < mockHEALTH_FACTOR_LIQUIDATION_THRESHOLD,
  //       'Unexpected T1 health factor'
  //     );
  //     assertTrue(vars.hf1 < vars.hf0, 'Unexpected T1 increase in health factor');

  //     // pre-liquidation
  //     vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));

  //     vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
  //     vars.reserveEthData1 = mockSpoke1.getReserve(vars.ethAssetId);

  //     vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
  //     vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

  //     assertEq(
  //       vars.reserveEthData1.config.lpfp,
  //       vars.newLpfp,
  //       'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
  //     );

  //     // dai
  //     assertEq(
  //       vars.user1DaiData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 dai usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1DaiData1.supplyShares,
  //       vars.mockSpoke1DaiData1.totalShares,
  //       'Unexpected T1 user1 dai supplyShares'
  //     );
  //     assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
  //     assertEq(
  //       vars.mockSpoke1DaiData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
  //       'Unexpected T1 mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(
  //       vars.user1EthData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 eth usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1EthData1.supplyShares,
  //       vars.mockSpoke1EthData1.totalShares,
  //       'Unexpected T1 user1 eth supplyShares'
  //     );
  //     assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
  //     assertEq(
  //       vars.mockSpoke1EthData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected T1 mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(
  //       vars.user1UsdcData1.usingAsCollateral,
  //       false,
  //       'Unexpected T1 user1 usdc usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user2UsdcData1.supplyShares,
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       'Unexpected T1 user2 usdc supplyShares'
  //     );
  //     assertEq(
  //       vars.user1UsdcData1.debtShares,
  //       vars.user2UsdcData1.supplyShares,
  //       'Unexpected T1 user1 usdc debtShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.drawnShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc drawnShares'
  //     );

  //     // T2 / T_final
  //     // action: liquidation
  //     deal(address(usdc), LIQUIDATOR, vars.debtToCover);
  //     vm.startPrank(LIQUIDATOR);
  //     usdc.approve(address(mockSpoke1), vars.debtToCover);

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.ethAssetId);
  //     vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

  //     (
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       ,

  //     ) = mockSpoke1.calculateUserAccountData(USER1);

  //     vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtToCover,
  //       USER1,
  //       vars.usdcAssetId,
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       vars.debtAssetPrice
  //     );

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.ethAssetId);
  //     vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
  //     vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.ethAssetId, USER1);

  //     (
  //       vars.actualCollateralToLiquidate,
  //       vars.actualDebtToLiquidate,
  //       vars.liquidationProtocolFeeAmount
  //     ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtReserve,
  //       vars.actualDebtToLiquidate,
  //       vars.userCollateralBalance,
  //       vars.debtAssetPrice
  //     );

  //     vm.expectEmit(address(mockSpoke1));
  //     emit LiquidationCall({
  //       collateralAssetId: vars.ethAssetId,
  //       debtAssetId: vars.usdcAssetId,
  //       user: USER1,
  //       actualDebtToLiquidate: vars.actualDebtToLiquidate,
  //       actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
  //       liquidator: LIQUIDATOR
  //     });
  //     mockSpoke1.liquidationCall(vars.ethAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
  //     vm.stopPrank();

  //     // post-liquidation
  //     vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
  //     vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
  //     vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
  //     vars.expectedEthTotalSharesRemaining =
  //       vars.mockSpoke1EthData1.totalShares -
  //       hub.convertAssetsToSharesDown(
  //         vars.ethAssetId,
  //         vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
  //       );
  //     vars.expectedUsdcDrawnSharesRemaining =
  //       vars.mockSpoke1UsdcData1.drawnShares -
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
  //     vars.hf2 = mockSpoke1.getHealthFactor(USER1);

  //     // dai
  //     assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1DaiData2.totalShares,
  //       vars.mockSpoke1DaiData1.totalShares,
  //       'Unexpected mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(vars.user1EthData2.usingAsCollateral, false, 'Unexpected eth usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1EthData2.totalShares,
  //       vars.expectedEthTotalSharesRemaining,
  //       'Unexpected mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.drawnShares,
  //       vars.mockSpoke1UsdcData2.totalShares -
  //         hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
  //       'Unexpected mockSpoke1 usdc drawnShares'
  //     );
  //     // health factor
  //     assertTrue(
  //       vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
  //       'Unexpected user1 final health factor'
  //     );
  //     assertTrue(vars.hf2 > vars.hf1, 'Unexpected decrease in user1 health factor');

  //     // liquidator
  //     assertEq(
  //       usdc.balanceOf(LIQUIDATOR),
  //       vars.debtToCover - vars.actualDebtToLiquidate,
  //       'Unexpected liquidator debt asset balance'
  //     );
  //     assertEq(
  //       eth.balanceOf(LIQUIDATOR),
  //       vars.actualCollateralToLiquidate,
  //       'Unexpected liquidator collateral asset balance'
  //     );
  //     assertEq(
  //       eth.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
  //       vars.liquidationProtocolFeeAmount,
  //       'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
  //     );
  //   }

  //   /// @dev Test liquidation call with liquidated amount < user collateral balance, liquidation protocol fee = 0
  //   function test_liquidationCall_ltCollateralBalance_zeroLiquidationProtocolFee() public {
  //     TestLiquidationCallLocalParams memory vars;

  //     vars.debtToCover = 1000e18;
  //     vars.daiAssetId = 0;
  //     vars.ethAssetId = 1;
  //     vars.usdcAssetId = 2;

  //     // total collateral: $30k
  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k

  //     // total borrowed: $15k
  //     uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
  //     bool usingAsCollateral = true;

  //     // T0
  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);
  //     vars.hf0 = mockSpoke1.getHealthFactor(USER1);
  //     assertTrue(
  //       vars.hf0 > mockHEALTH_FACTOR_LIQUIDATION_THRESHOLD,
  //       'Unexpected T0 health factor'
  //     );

  //     // T1: eth drops fomr $2000 -> $800/eth
  //     MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);

  //     vars.hf1 = mockSpoke1.getHealthFactor(USER1);

  //     // pre-liquidation
  //     vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));

  //     vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

  //     vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
  //     vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

  //     // dai
  //     assertEq(
  //       vars.user1DaiData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 dai usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1DaiData1.supplyShares,
  //       vars.mockSpoke1DaiData1.totalShares,
  //       'Unexpected T1 user1 dai supplyShares'
  //     );
  //     assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
  //     assertEq(
  //       vars.mockSpoke1DaiData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
  //       'Unexpected T1 mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(
  //       vars.user1EthData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 eth usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1EthData1.supplyShares,
  //       vars.mockSpoke1EthData1.totalShares,
  //       'Unexpected T1 user1 eth supplyShares'
  //     );
  //     assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
  //     assertEq(
  //       vars.mockSpoke1EthData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected T1 mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(
  //       vars.user1UsdcData1.usingAsCollateral,
  //       false,
  //       'Unexpected T1 user1 usdc usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user2UsdcData1.supplyShares,
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       'Unexpected T1 user2 usdc supplyShares'
  //     );
  //     assertEq(
  //       vars.user1UsdcData1.debtShares,
  //       vars.user2UsdcData1.supplyShares,
  //       'Unexpected T1 user1 usdc debtShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.drawnShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc drawnShares'
  //     );

  //     // T2 / T_final
  //     // action: liquidation
  //     deal(address(usdc), LIQUIDATOR, vars.debtToCover);
  //     vm.startPrank(LIQUIDATOR);
  //     usdc.approve(address(mockSpoke1), vars.debtToCover);

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

  //     (
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       ,

  //     ) = mockSpoke1.calculateUserAccountData(USER1);

  //     vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtToCover,
  //       USER1,
  //       vars.usdcAssetId,
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       vars.debtAssetPrice
  //     );

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
  //     vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

  //     (
  //       vars.actualCollateralToLiquidate,
  //       vars.actualDebtToLiquidate,
  //       vars.liquidationProtocolFeeAmount
  //     ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtReserve,
  //       vars.actualDebtToLiquidate,
  //       vars.userCollateralBalance,
  //       vars.debtAssetPrice
  //     );

  //     vm.expectEmit(address(mockSpoke1));
  //     emit LiquidationCall({
  //       collateralAssetId: vars.daiAssetId,
  //       debtAssetId: vars.usdcAssetId,
  //       user: USER1,
  //       actualDebtToLiquidate: vars.actualDebtToLiquidate,
  //       actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
  //       liquidator: LIQUIDATOR
  //     });
  //     mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
  //     vm.stopPrank();

  //     // post-liquidation
  //     vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
  //     vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
  //     vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
  //     vars.expectedDaiTotalSharesRemaining =
  //       vars.mockSpoke1DaiData1.totalShares -
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, vars.actualCollateralToLiquidate);
  //     vars.expectedUsdcDrawnSharesRemaining =
  //       vars.mockSpoke1UsdcData1.drawnShares -
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
  //     vars.hf2 = mockSpoke1.getHealthFactor(USER1);

  //     // dai
  //     assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1DaiData2.totalShares,
  //       vars.expectedDaiTotalSharesRemaining,
  //       'Unexpected mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1EthData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.drawnShares,
  //       vars.mockSpoke1UsdcData2.totalShares -
  //         hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
  //       'Unexpected mockSpoke1 usdc drawnShares'
  //     );
  //     // health factor
  //     assertTrue(
  //       vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
  //       'Unexpected user1 final health factor'
  //     );
  //     assertTrue(vars.hf2 > vars.hf1, 'Unexpected decrease in user1 health factor');

  //     // liquidator
  //     assertEq(
  //       usdc.balanceOf(LIQUIDATOR),
  //       vars.debtToCover - vars.actualDebtToLiquidate,
  //       'Unexpected liquidator debt asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(LIQUIDATOR),
  //       vars.actualCollateralToLiquidate,
  //       'Unexpected liquidator collateral asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
  //       vars.liquidationProtocolFeeAmount,
  //       'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
  //     );
  //   }

  //   function test_liquidationCall_ltCollateralBalance() public {
  //     TestLiquidationCallLocalParams memory vars;

  //     vars.debtToCover = 5_000e18;
  //     vars.daiAssetId = 0;
  //     vars.ethAssetId = 1;
  //     vars.usdcAssetId = 2;
  //     vars.newLpfp = 200;

  //     // total collateral: $30k
  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k

  //     // total borrowed: $15k
  //     uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
  //     bool usingAsCollateral = true;

  //     // T0
  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);
  //     Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.daiAssetId, vars.newLpfp);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);
  //     vars.hf0 = mockSpoke1.getHealthFactor(USER1);

  //     assertTrue(
  //       vars.hf0 > mockHEALTH_FACTOR_LIQUIDATION_THRESHOLD,
  //       'Unexpected T1 health factor'
  //     );

  //     // T1: eth price drops from $2000 -> $800/eth
  //     MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);
  //     vars.hf1 = mockSpoke1.getHealthFactor(USER1);

  //     // pre-liquidation
  //     vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.reserveDaiData1 = mockSpoke1.getReserve(vars.daiAssetId);

  //     vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

  //     vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
  //     vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

  //     assertEq(
  //       vars.reserveDaiData1.config.lpfp,
  //       vars.newLpfp,
  //       'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
  //     );

  //     // dai
  //     assertEq(
  //       vars.user1DaiData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 dai usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1DaiData1.supplyShares,
  //       vars.mockSpoke1DaiData1.totalShares,
  //       'Unexpected T1 user1 dai supplyShares'
  //     );
  //     assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
  //     assertEq(
  //       vars.mockSpoke1DaiData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
  //       'Unexpected T1 mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(
  //       vars.user1EthData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 eth usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1EthData1.supplyShares,
  //       vars.mockSpoke1EthData1.totalShares,
  //       'Unexpected T1 user1 eth supplyShares'
  //     );
  //     assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
  //     assertEq(
  //       vars.mockSpoke1EthData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected T1 mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(
  //       vars.user1UsdcData1.usingAsCollateral,
  //       false,
  //       'Unexpected T1 user1 usdc usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user2UsdcData1.supplyShares,
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       'Unexpected T1 user2 usdc supplyShares'
  //     );
  //     assertEq(
  //       vars.user1UsdcData1.debtShares,
  //       vars.user2UsdcData1.supplyShares,
  //       'Unexpected T1 user1 usdc debtShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.drawnShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc drawnShares'
  //     );

  //     // T2 / T_final
  //     // action: liquidation
  //     deal(address(usdc), LIQUIDATOR, vars.debtToCover);
  //     vm.startPrank(LIQUIDATOR);
  //     usdc.approve(address(mockSpoke1), vars.debtToCover);

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

  //     (
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       ,

  //     ) = mockSpoke1.calculateUserAccountData(USER1);

  //     vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtToCover,
  //       USER1,
  //       vars.usdcAssetId,
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       vars.debtAssetPrice
  //     );

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
  //     vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

  //     (
  //       vars.actualCollateralToLiquidate,
  //       vars.actualDebtToLiquidate,
  //       vars.liquidationProtocolFeeAmount
  //     ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtReserve,
  //       vars.actualDebtToLiquidate,
  //       vars.userCollateralBalance,
  //       vars.debtAssetPrice
  //     );

  //     vm.expectEmit(address(mockSpoke1));
  //     emit LiquidationCall({
  //       collateralAssetId: vars.daiAssetId,
  //       debtAssetId: vars.usdcAssetId,
  //       user: USER1,
  //       actualDebtToLiquidate: vars.actualDebtToLiquidate,
  //       actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
  //       liquidator: LIQUIDATOR
  //     });
  //     mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
  //     vm.stopPrank();

  //     // post-liquidation
  //     vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
  //     vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
  //     vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
  //     vars.expectedDaiTotalSharesRemaining =
  //       vars.mockSpoke1DaiData1.totalShares -
  //       hub.convertAssetsToSharesDown(
  //         vars.daiAssetId,
  //         vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
  //       );
  //     vars.expectedUsdcDrawnSharesRemaining =
  //       vars.mockSpoke1UsdcData1.drawnShares -
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
  //     vars.hf2 = mockSpoke1.getHealthFactor(USER1);

  //     // dai
  //     assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1DaiData2.totalShares,
  //       vars.expectedDaiTotalSharesRemaining,
  //       'Unexpected mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1EthData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.drawnShares,
  //       vars.mockSpoke1UsdcData2.totalShares -
  //         hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
  //       'Unexpected mockSpoke1 usdc drawnShares'
  //     );
  //     // health factor
  //     assertTrue(
  //       vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
  //       'Unexpected user1 final health factor'
  //     );
  //     assertTrue(vars.hf2 > vars.hf1, 'Unexpected decrease in user1 health factor');

  //     // liquidator
  //     assertEq(
  //       usdc.balanceOf(LIQUIDATOR),
  //       vars.debtToCover - vars.actualDebtToLiquidate,
  //       'Unexpected liquidator debt asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(LIQUIDATOR),
  //       vars.actualCollateralToLiquidate,
  //       'Unexpected liquidator collateral asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
  //       vars.liquidationProtocolFeeAmount,
  //       'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
  //     );
  //   }

  //   function test_liquidationCall_ltCollateralBalance_multiBorrow() public {
  //     TestLiquidationCallLocalParams memory vars;

  //     vars.debtToCover = 5_000e18;
  //     vars.daiAssetId = 0;
  //     vars.ethAssetId = 1;
  //     vars.usdcAssetId = 2;
  //     vars.wbtcAssetId = 3;
  //     vars.newLpfp = 200;

  //     // total collateral: $30k
  //     uint256 daiAmount = 10_000e18; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k

  //     // total borrowed: $15k
  //     uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
  //     uint256 wbtcBorrowAmount = 0.1e18; // 0.1 wBTC -> $5k
  //     bool usingAsCollateral = true;

  //     // T0
  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);
  //     Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.daiAssetId, vars.newLpfp);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER2 supply wbtc into mockSpoke1
  //     deal(address(wbtc), USER2, wbtcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //     // USER1 borrow wbtc
  //     Utils.borrow(vm, mockSpoke1, vars.wbtcAssetId, USER1, wbtcBorrowAmount, USER1);

  //     vars.hf0 = mockSpoke1.getHealthFactor(USER1);

  //     assertTrue(
  //       vars.hf0 > mockHEALTH_FACTOR_LIQUIDATION_THRESHOLD,
  //       'Unexpected T1 health factor'
  //     );

  //     // T1: eth price drops from $2000 -> $800/eth
  //     MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);
  //     vars.hf1 = mockSpoke1.getHealthFactor(USER1);

  //     // pre-liquidation
  //     vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.reserveDaiData1 = mockSpoke1.getReserve(vars.daiAssetId);

  //     vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

  //     vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
  //     vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

  //     vars.user1WbtcData1 = mockSpoke1.getUser(vars.wbtcAssetId, USER1);
  //     vars.user2WbtcData1 = mockSpoke1.getUser(vars.wbtcAssetId, USER2);
  //     vars.mockSpoke1WbtcData1 = hub.getSpoke(vars.wbtcAssetId, address(mockSpoke1));

  //     assertEq(
  //       vars.reserveDaiData1.config.lpfp,
  //       vars.newLpfp,
  //       'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
  //     );

  //     // dai
  //     assertEq(
  //       vars.user1DaiData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 dai usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1DaiData1.supplyShares,
  //       vars.mockSpoke1DaiData1.totalShares,
  //       'Unexpected T1 user1 dai supplyShares'
  //     );
  //     assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
  //     assertEq(
  //       vars.mockSpoke1DaiData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
  //       'Unexpected T1 mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(
  //       vars.user1EthData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 eth usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1EthData1.supplyShares,
  //       vars.mockSpoke1EthData1.totalShares,
  //       'Unexpected T1 user1 eth supplyShares'
  //     );
  //     assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
  //     assertEq(
  //       vars.mockSpoke1EthData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected T1 mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(
  //       vars.user1UsdcData1.usingAsCollateral,
  //       false,
  //       'Unexpected T1 user1 usdc usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user2UsdcData1.supplyShares,
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       'Unexpected T1 user2 usdc supplyShares'
  //     );
  //     assertEq(
  //       vars.user1UsdcData1.debtShares,
  //       vars.user2UsdcData1.supplyShares,
  //       'Unexpected T1 user1 usdc debtShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.drawnShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc drawnShares'
  //     );
  //     // wbtc
  //     assertEq(
  //       vars.user1WbtcData1.usingAsCollateral,
  //       false,
  //       'Unexpected T1 user1 wbtc usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user2WbtcData1.supplyShares,
  //       vars.mockSpoke1WbtcData1.totalShares,
  //       'Unexpected T1 user2 wbtc supplyShares'
  //     );
  //     assertEq(
  //       vars.user1WbtcData1.debtShares,
  //       vars.user2WbtcData1.supplyShares,
  //       'Unexpected T1 user1 wbtc debtShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1WbtcData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.wbtcAssetId, wbtcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 wbtc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1WbtcData1.drawnShares,
  //       hub.convertAssetsToSharesDown(vars.wbtcAssetId, wbtcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 wbtc drawnShares'
  //     );

  //     // T2 / T_final
  //     // action: liquidation
  //     deal(address(usdc), LIQUIDATOR, vars.debtToCover);
  //     vm.startPrank(LIQUIDATOR);
  //     usdc.approve(address(mockSpoke1), vars.debtToCover);

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

  //     (
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       ,

  //     ) = mockSpoke1.calculateUserAccountData(USER1);

  //     vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtToCover,
  //       USER1,
  //       vars.usdcAssetId,
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       vars.debtAssetPrice
  //     );

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
  //     vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

  //     (
  //       vars.actualCollateralToLiquidate,
  //       vars.actualDebtToLiquidate,
  //       vars.liquidationProtocolFeeAmount
  //     ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtReserve,
  //       vars.actualDebtToLiquidate,
  //       vars.userCollateralBalance,
  //       vars.debtAssetPrice
  //     );

  //     vm.expectEmit(address(mockSpoke1));
  //     emit LiquidationCall({
  //       collateralAssetId: vars.daiAssetId,
  //       debtAssetId: vars.usdcAssetId,
  //       user: USER1,
  //       actualDebtToLiquidate: vars.actualDebtToLiquidate,
  //       actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
  //       liquidator: LIQUIDATOR
  //     });
  //     mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
  //     vm.stopPrank();

  //     // post-liquidation
  //     vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
  //     vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
  //     vars.mockSpoke1WbtcData2 = hub.getSpoke(vars.wbtcAssetId, address(mockSpoke1));
  //     vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
  //     vars.expectedDaiTotalSharesRemaining =
  //       vars.mockSpoke1DaiData1.totalShares -
  //       hub.convertAssetsToSharesDown(
  //         vars.daiAssetId,
  //         vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
  //       );
  //     vars.expectedUsdcDrawnSharesRemaining =
  //       vars.mockSpoke1UsdcData1.drawnShares -
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
  //     vars.hf2 = mockSpoke1.getHealthFactor(USER1);

  //     // dai
  //     assertEq(vars.user1DaiData2.usingAsCollateral, true, 'Unexpected user1 dai usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1DaiData2.totalShares,
  //       vars.expectedDaiTotalSharesRemaining,
  //       'Unexpected mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1EthData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.drawnShares,
  //       vars.mockSpoke1UsdcData2.totalShares -
  //         hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
  //       'Unexpected mockSpoke1 usdc drawnShares'
  //     );
  //     // wbtc
  //     assertEq(vars.user1WbtcData2.usingAsCollateral, false, 'Unexpected wbtc usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1WbtcData2.totalShares,
  //       vars.mockSpoke1WbtcData1.totalShares,
  //       'Unexpected mockSpoke1 wbtc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1WbtcData2.drawnShares,
  //       vars.mockSpoke1WbtcData1.drawnShares,
  //       'Unexpected mockSpoke1 wbtc drawnShares'
  //     );
  //     // health factor
  //     assertTrue(
  //       vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
  //       'Unexpected user1 final health factor'
  //     );
  //     assertTrue(vars.hf2 < vars.hf1, 'Unexpected increase in user1 health factor'); // remaining debt from wbtc, hf decreases

  //     // liquidator
  //     assertEq(
  //       usdc.balanceOf(LIQUIDATOR),
  //       vars.debtToCover - vars.actualDebtToLiquidate,
  //       'Unexpected liquidator debt asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(LIQUIDATOR),
  //       vars.actualCollateralToLiquidate,
  //       'Unexpected liquidator collateral asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
  //       vars.liquidationProtocolFeeAmount,
  //       'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
  //     );
  //   }

  //   function test_liquidationCall_gteCollateralBalance_multiBorrow() public {
  //     TestLiquidationCallLocalParams memory vars;

  //     vars.debtToCover = 10_000e18;
  //     vars.daiAssetId = 0;
  //     vars.ethAssetId = 1;
  //     vars.usdcAssetId = 2;
  //     vars.wbtcAssetId = 3;
  //     vars.newLpfp = 200;

  //     // total collateral: $30k
  //     uint256 daiAmount = vars.debtToCover; // 10k dai -> $10k
  //     uint256 ethAmount = 10e18; // 10 eth -> $20k

  //     // total borrowed: $15k
  //     uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
  //     uint256 wbtcBorrowAmount = 0.1e18; // 0.1 wBTC -> $5k
  //     bool usingAsCollateral = true;

  //     // T0
  //     // USER1 supply dai into mockSpoke1
  //     deal(address(dai), USER1, daiAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.daiAssetId, USER1, daiAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.daiAssetId, usingAsCollateral);
  //     Utils.updateLiquidationProtocolFeePercentage(mockSpoke1, vars.daiAssetId, vars.newLpfp);

  //     // USER1 supply eth into mockSpoke1
  //     deal(address(eth), USER1, ethAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.ethAssetId, USER1, ethAmount, USER1);
  //     Utils.setUsingAsCollateral(vm, mockSpoke1, USER1, vars.ethAssetId, usingAsCollateral);

  //     // USER2 supply usdc into mockSpoke1
  //     deal(address(usdc), USER2, usdcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.usdcAssetId, USER2, usdcBorrowAmount, USER2);

  //     // USER2 supply wbtc into mockSpoke1
  //     deal(address(wbtc), USER2, wbtcBorrowAmount);
  //     Utils.spokeSupply(vm, hub, mockSpoke1, vars.wbtcAssetId, USER2, wbtcBorrowAmount, USER2);

  //     // USER1 borrow usdc
  //     Utils.borrow(vm, mockSpoke1, vars.usdcAssetId, USER1, usdcBorrowAmount, USER1);

  //     // USER1 borrow wbtc
  //     Utils.borrow(vm, mockSpoke1, vars.wbtcAssetId, USER1, wbtcBorrowAmount, USER1);

  //     vars.hf0 = mockSpoke1.getHealthFactor(USER1);

  //     assertTrue(
  //       vars.hf0 > mockHEALTH_FACTOR_LIQUIDATION_THRESHOLD,
  //       'Unexpected T1 health factor'
  //     );

  //     // T1: eth price drops from $2000 -> $800/eth
  //     MockPriceOracle(address(oracle)).setAssetPrice(vars.ethAssetId, 800e8);
  //     vars.hf1 = mockSpoke1.getHealthFactor(USER1);

  //     // pre-liquidation
  //     vars.user1DaiData1 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData1 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.reserveDaiData1 = mockSpoke1.getReserve(vars.daiAssetId);

  //     vars.user1EthData1 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData1 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));

  //     vars.user1UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.user2UsdcData1 = mockSpoke1.getUser(vars.usdcAssetId, USER2);
  //     vars.mockSpoke1UsdcData1 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));

  //     vars.user1WbtcData1 = mockSpoke1.getUser(vars.wbtcAssetId, USER1);
  //     vars.user2WbtcData1 = mockSpoke1.getUser(vars.wbtcAssetId, USER2);
  //     vars.mockSpoke1WbtcData1 = hub.getSpoke(vars.wbtcAssetId, address(mockSpoke1));

  //     assertEq(
  //       vars.reserveDaiData1.config.lpfp,
  //       vars.newLpfp,
  //       'Unexpected mockSpoke1 dai liquidation protocol fee percentage'
  //     );

  //     // dai
  //     assertEq(
  //       vars.user1DaiData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 dai usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1DaiData1.supplyShares,
  //       vars.mockSpoke1DaiData1.totalShares,
  //       'Unexpected T1 user1 dai supplyShares'
  //     );
  //     assertEq(vars.user1DaiData1.debtShares, 0, 'Unexpected T1 user1 dai debtShares');
  //     assertEq(
  //       vars.mockSpoke1DaiData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.daiAssetId, daiAmount),
  //       'Unexpected T1 mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(
  //       vars.user1EthData1.usingAsCollateral,
  //       true,
  //       'Unexpected T1 user1 eth usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user1EthData1.supplyShares,
  //       vars.mockSpoke1EthData1.totalShares,
  //       'Unexpected T1 user1 eth supplyShares'
  //     );
  //     assertEq(vars.user1EthData1.debtShares, 0, 'Unexpected user1 eth debtShares');
  //     assertEq(
  //       vars.mockSpoke1EthData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected T1 mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData1.drawnShares, 0, 'Unexpected T1 mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(
  //       vars.user1UsdcData1.usingAsCollateral,
  //       false,
  //       'Unexpected T1 user1 usdc usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user2UsdcData1.supplyShares,
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       'Unexpected T1 user2 usdc supplyShares'
  //     );
  //     assertEq(
  //       vars.user1UsdcData1.debtShares,
  //       vars.user2UsdcData1.supplyShares,
  //       'Unexpected T1 user1 usdc debtShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData1.drawnShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 usdc drawnShares'
  //     );
  //     // wbtc
  //     assertEq(
  //       vars.user1WbtcData1.usingAsCollateral,
  //       false,
  //       'Unexpected T1 user1 wbtc usingAsCollateral'
  //     );
  //     assertEq(
  //       vars.user2WbtcData1.supplyShares,
  //       vars.mockSpoke1WbtcData1.totalShares,
  //       'Unexpected T1 user2 wbtc supplyShares'
  //     );
  //     assertEq(
  //       vars.user1WbtcData1.debtShares,
  //       vars.user2WbtcData1.supplyShares,
  //       'Unexpected T1 user1 wbtc debtShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1WbtcData1.totalShares,
  //       hub.convertAssetsToSharesDown(vars.wbtcAssetId, wbtcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 wbtc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1WbtcData1.drawnShares,
  //       hub.convertAssetsToSharesDown(vars.wbtcAssetId, wbtcBorrowAmount),
  //       'Unexpected T1 mockSpoke1 wbtc drawnShares'
  //     );

  //     // T2 / T_final
  //     // action: liquidation
  //     deal(address(usdc), LIQUIDATOR, vars.debtToCover);
  //     vm.startPrank(LIQUIDATOR);
  //     usdc.approve(address(mockSpoke1), vars.debtToCover);

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtAssetPrice = oracle.getAssetPrice(vars.usdcAssetId);

  //     (
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       ,

  //     ) = mockSpoke1.calculateUserAccountData(USER1);

  //     vars.actualDebtToLiquidate = mockSpoke1.calculateActualDebtToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtToCover,
  //       USER1,
  //       vars.usdcAssetId,
  //       vars.totalCollateralInBaseCurrency,
  //       vars.totalDebtInBaseCurrency,
  //       vars.avgLiquidationThreshold,
  //       vars.debtAssetPrice
  //     );

  //     vars.collateralReserve = mockSpoke1.getReserve(vars.daiAssetId);
  //     vars.debtReserve = mockSpoke1.getReserve(vars.usdcAssetId);
  //     vars.userCollateralBalance = mockSpoke1.getUserSupplyInAssets(vars.daiAssetId, USER1);

  //     (
  //       vars.actualCollateralToLiquidate,
  //       vars.actualDebtToLiquidate,
  //       vars.liquidationProtocolFeeAmount
  //     ) = mockSpoke1.calculateAvailableCollateralToLiquidate(
  //       vars.collateralReserve,
  //       vars.debtReserve,
  //       vars.actualDebtToLiquidate,
  //       vars.userCollateralBalance,
  //       vars.debtAssetPrice
  //     );

  //     vm.expectEmit(address(mockSpoke1));
  //     emit LiquidationCall({
  //       collateralAssetId: vars.daiAssetId,
  //       debtAssetId: vars.usdcAssetId,
  //       user: USER1,
  //       actualDebtToLiquidate: vars.actualDebtToLiquidate,
  //       actualCollateralToLiquidate: vars.actualCollateralToLiquidate,
  //       liquidator: LIQUIDATOR
  //     });
  //     mockSpoke1.liquidationCall(vars.daiAssetId, vars.usdcAssetId, USER1, vars.debtToCover);
  //     vm.stopPrank();

  //     // post-liquidation
  //     vars.user1DaiData2 = mockSpoke1.getUser(vars.daiAssetId, USER1);
  //     vars.mockSpoke1DaiData2 = hub.getSpoke(vars.daiAssetId, address(mockSpoke1));
  //     vars.user1EthData2 = mockSpoke1.getUser(vars.ethAssetId, USER1);
  //     vars.mockSpoke1EthData2 = hub.getSpoke(vars.ethAssetId, address(mockSpoke1));
  //     vars.user1UsdcData2 = mockSpoke1.getUser(vars.usdcAssetId, USER1);
  //     vars.mockSpoke1UsdcData2 = hub.getSpoke(vars.usdcAssetId, address(mockSpoke1));
  //     vars.mockSpoke1WbtcData2 = hub.getSpoke(vars.wbtcAssetId, address(mockSpoke1));
  //     vars.actualDebtCovered = vars.debtToCover - usdc.balanceOf(LIQUIDATOR);
  //     vars.expectedDaiTotalSharesRemaining =
  //       vars.mockSpoke1DaiData1.totalShares -
  //       hub.convertAssetsToSharesDown(
  //         vars.daiAssetId,
  //         vars.actualCollateralToLiquidate + vars.liquidationProtocolFeeAmount
  //       );
  //     vars.expectedUsdcDrawnSharesRemaining =
  //       vars.mockSpoke1UsdcData1.drawnShares -
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered);
  //     vars.hf2 = mockSpoke1.getHealthFactor(USER1);

  //     // dai
  //     assertEq(vars.user1DaiData2.usingAsCollateral, false, 'Unexpected user1 dai usingAsCollateral'); // all Dai liquidated
  //     assertEq(
  //       vars.mockSpoke1DaiData2.totalShares,
  //       vars.expectedDaiTotalSharesRemaining,
  //       'Unexpected mockSpoke1 dai totalShares'
  //     );
  //     assertEq(vars.mockSpoke1DaiData2.drawnShares, 0, 'Unexpected mockSpoke1 dai drawnShares');
  //     // eth
  //     assertEq(vars.user1EthData2.usingAsCollateral, true, 'Unexpected eth usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1EthData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.ethAssetId, ethAmount),
  //       'Unexpected mockSpoke1 eth totalShares'
  //     );
  //     assertEq(vars.mockSpoke1EthData2.drawnShares, 0, 'Unexpected mockSpoke1 eth drawnShares');
  //     // usdc
  //     assertEq(vars.user1UsdcData2.usingAsCollateral, false, 'Unexpected usdc usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.totalShares,
  //       hub.convertAssetsToSharesDown(vars.usdcAssetId, usdcBorrowAmount),
  //       'Unexpected mockSpoke1 usdc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1UsdcData2.drawnShares,
  //       vars.mockSpoke1UsdcData2.totalShares -
  //         hub.convertAssetsToSharesDown(vars.usdcAssetId, vars.actualDebtCovered),
  //       'Unexpected mockSpoke1 usdc drawnShares'
  //     );
  //     // wbtc
  //     assertEq(vars.user1WbtcData2.usingAsCollateral, false, 'Unexpected wbtc usingAsCollateral');
  //     assertEq(
  //       vars.mockSpoke1WbtcData2.totalShares,
  //       vars.mockSpoke1WbtcData1.totalShares,
  //       'Unexpected mockSpoke1 wbtc totalShares'
  //     );
  //     assertEq(
  //       vars.mockSpoke1WbtcData2.drawnShares,
  //       vars.mockSpoke1WbtcData1.drawnShares,
  //       'Unexpected mockSpoke1 wbtc drawnShares'
  //     );
  //     // health factor
  //     assertTrue(
  //       vars.hf2 <= mockSpoke1.HEALTH_FACTOR_LIQUIDATION_RECOVERY_THRESHOLD(),
  //       'Unexpected user1 final health factor'
  //     );
  //     assertTrue(vars.hf2 < vars.hf1, 'Unexpected increase in user1 health factor'); // remaining debt from wbtc, hf decreases

  //     // liquidator
  //     assertEq(
  //       usdc.balanceOf(LIQUIDATOR),
  //       vars.debtToCover - vars.actualDebtToLiquidate,
  //       'Unexpected liquidator debt asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(LIQUIDATOR),
  //       vars.actualCollateralToLiquidate,
  //       'Unexpected liquidator collateral asset balance'
  //     );
  //     assertEq(
  //       dai.balanceOf(mockSpoke1.RESERVE_TREASURY_ADDRESS()),
  //       vars.liquidationProtocolFeeAmount,
  //       'Unexpected RESERVE_TREASURY_ADDRESS collateral asset balance (protocol fee)'
  //     );
  //   }

  function _createMinCollateralPosition(
    ISpoke spoke,
    address user,
    uint256 collReserveId,
    uint256 debtReserveId,
    uint256 debtAmount
  ) internal returns (uint256 collAmount) {
    _deployLiquidity(spoke, debtReserveId, debtAmount * 10);

    collAmount = _calcMinimumCollAmount(spoke, collReserveId, debtReserveId, debtAmount);
    Utils.supplyCollateral(spoke, collReserveId, user, collAmount, user);
    Utils.borrow(spoke, debtReserveId, user, debtAmount, user);
  }

  // todo: test on if denom is negative, ie HF < LB * CF
  // todo: test w diff combos of decimals
  // test with user's new risk premium post-liquidation
  // test w HF due to debt interest growing
  // test w HF due to debt asset price drop
  // tests with Liq Threshold == close factor
  // tests with Liq Threshold < close factor
  // variable liquidation bonus
}
