// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeUserRiskPremiumTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  struct ReserveInfoLocal {
    uint256 reserveId;
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 price;
    uint256 lp;
    uint256 riskPremium;
  }

  struct UserInfoLocal {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 baseDebt;
    uint256 premiumDebt;
    uint256 totalDebt;
    uint256 riskPremium;
  }

  struct UserAction {
    uint256 borrowAmount;
    uint256 supplyAmount;
  }

  struct DebtChecks {
    uint256 baseDebt;
    uint256 premiumDebt;
    uint256 actualBaseDebt;
    uint256 actualPremium;
    uint256 reserveDebt;
    uint256 reservePremium;
    uint256 spokeDebt;
    uint256 spokePremium;
    uint256 assetDebt;
    uint256 assetPremium;
  }

  /// With no collateral supplied, user risk premium is 0.
  function test_getUserRiskPremium_no_collateral() public {
    // Assert Bob has no collateral
    for (uint256 reserveId = 0; reserveId < spoke1.reserveCount(); reserveId++) {
      DataTypes.UserPosition memory bobInfo = getUserInfo(spoke1, bob, reserveId);
      assertEq(bobInfo.suppliedShares, 0, 'bob supplied collateral');
    }
    assertEq(spoke1.getUserRiskPremium(bob), 0, 'user risk premium');
  }

  /// Without a collateral set, user risk premium is 0.
  function test_getUserRiskPremium_no_collateral_set() public {
    Utils.supply(spoke1, _daiReserveId(spoke1), bob, 100e18, bob);
    // Bob doesn't set dai as collateral, despite supplying, so his user rp is 0
    assertEq(spoke1.getUserRiskPremium(bob), 0, 'user risk premium');
  }

  /// Without a draw, user risk premium is 0.
  function test_getUserRiskPremium_single_reserve_collateral() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 daiAmount = 100e18;

    // Bob supply dai into spoke1
    Utils.supply(spoke1, daiReserveId, bob, daiAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    assertEq(spoke1.getUserRiskPremium(bob), 0, 'user risk premium');
  }

  /// When supplying and borrowing one reserve, user risk premium matches the liquidity premium of that reserve.
  function test_getUserRiskPremium_single_reserve_collateral_borrowed() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 supplyAmount = 100e18;
    uint256 borrowAmount = 50e18;

    // Bob supply dai into spoke1
    Utils.supply(spoke1, daiReserveId, bob, supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);
    Utils.borrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    DataTypes.Reserve memory daiInfo = getReserveInfo(spoke1, daiReserveId);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(userRiskPremium, daiInfo.config.liquidityPremium, 'user risk premium');
  }

  /// When supplying and borrowing one reserve (fuzzed amounts), user risk premium matches the liquidity premium of that reserve.
  function test_getUserRiskPremium_fuzz_single_reserve_collateral_borrowed_amount(
    uint256 borrowAmount
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    ReserveInfoLocal memory daiInfo;
    daiInfo.reserveId = _daiReserveId(spoke1);
    daiInfo.borrowAmount = borrowAmount;
    daiInfo.supplyAmount = borrowAmount * 2;

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supply(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);
    Utils.borrow(spoke1, daiInfo.reserveId, bob, daiInfo.borrowAmount, bob);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(spoke1.getUserRiskPremium(bob), daiInfo.lp, 'user risk premium');
  }

  /// When supplying and borrowing one reserve each, user risk premium matches the liquidity premium of the collateral.
  /// An additional supply of a riskier collateral does not impact the user risk premium.
  function test_getUserRiskPremium_fuzz_supply_does_not_impact(
    uint256 borrowAmount,
    uint256 additionalSupplyAmount
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    additionalSupplyAmount = bound(additionalSupplyAmount, 1, MAX_SUPPLY_AMOUNT);

    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;

    daiInfo.borrowAmount = borrowAmount;
    daiInfo.supplyAmount = borrowAmount * 2;

    daiInfo.reserveId = _daiReserveId(spoke1);
    usdxInfo.reserveId = _usdxReserveId(spoke1);

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supply(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);

    // Bob draw dai
    Utils.borrow(spoke1, daiInfo.reserveId, bob, daiInfo.borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(userRiskPremium, daiInfo.lp, 'user risk premium');

    // Supplying more risky reserve (usdx) should not impact user risk premium
    Utils.supply(spoke1, usdxInfo.reserveId, bob, additionalSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, usdxInfo.reserveId, true);
    assertEq(spoke1.getUserRiskPremium(bob), userRiskPremium, 'user risk premium after supply');
  }

  /// Supply 3 reserves, borrow 2, such that 1 reserve fully covers the debt, then check user risk premium calc.
  function test_getUserRiskPremium_multi_reserve_collateral() public {
    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wethInfo;

    daiInfo.reserveId = _daiReserveId(spoke1);
    usdxInfo.reserveId = _usdxReserveId(spoke1);
    wethInfo.reserveId = _wethReserveId(spoke1);

    daiInfo.supplyAmount = 1000e18;
    usdxInfo.supplyAmount = 1000e6;
    wethInfo.supplyAmount = 1000e18;
    daiInfo.borrowAmount = 1000e18;
    usdxInfo.borrowAmount = 1000e6;

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);
    usdxInfo.lp = spoke1.getLiquidityPremium(usdxInfo.reserveId);
    wethInfo.lp = spoke1.getLiquidityPremium(wethInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supply(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);

    // Bob supply usdx into spoke1
    Utils.supply(spoke1, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, usdxInfo.reserveId, true);

    // Bob supply weth into spoke1
    Utils.supply(spoke1, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethInfo.reserveId, true);

    // Bob draw dai + usdx
    Utils.borrow(spoke1, daiInfo.reserveId, bob, daiInfo.borrowAmount, bob);
    Utils.borrow(spoke1, usdxInfo.reserveId, bob, usdxInfo.borrowAmount, bob);

    // Weth is enough to cover the total debt
    assertGe(
      _getReserveValueInBaseCurrency(wethAssetId, wethInfo.supplyAmount),
      _getReserveValueInBaseCurrency(daiAssetId, daiInfo.borrowAmount) +
        _getReserveValueInBaseCurrency(usdxAssetId, usdxInfo.borrowAmount),
      'weth supply covers debt'
    );
    uint256 expectedUserRiskPremium = wethInfo.lp;
    assertEq(spoke1.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');
  }

  /// Supply 3 reserves, borrow 2, such that 2 reserves fully cover the debt, then check user risk premium calc.
  function test_getUserRiskPremium_multi_reserve_collateral_weth_partial_cover() public {
    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wethInfo;

    daiInfo.reserveId = _daiReserveId(spoke1);
    usdxInfo.reserveId = _usdxReserveId(spoke1);
    wethInfo.reserveId = _wethReserveId(spoke1);

    daiInfo.supplyAmount = 2000e18;
    usdxInfo.supplyAmount = 2000e6;
    wethInfo.supplyAmount = 1e18;

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);
    usdxInfo.lp = spoke1.getLiquidityPremium(usdxInfo.reserveId);
    wethInfo.lp = spoke1.getLiquidityPremium(wethInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supply(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);

    // Bob supply usdx into spoke1
    Utils.supply(spoke1, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, usdxInfo.reserveId, true);

    // Bob supply weth into spoke1
    Utils.supply(spoke1, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethInfo.reserveId, true);

    // Bob draw dai + usdx
    Utils.borrow(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    Utils.borrow(spoke1, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);

    // Weth covers half the debt, dai covers the rest
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'user risk premium'
    );
  }

  /// Supply 2 reserves and borrow one such that the 2 reserves equally cover debt, then check user risk premium calc.
  function test_getUserRiskPremium_two_reserves_equal_parts() public {
    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wethInfo;

    daiInfo.reserveId = _daiReserveId(spoke1);
    usdxInfo.reserveId = _usdxReserveId(spoke1);
    wethInfo.reserveId = _wethReserveId(spoke1);

    daiInfo.supplyAmount = 2000e18;
    usdxInfo.supplyAmount = 6000e6;
    wethInfo.supplyAmount = 10e18;

    wethInfo.borrowAmount = 2e18;

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);
    usdxInfo.lp = spoke1.getLiquidityPremium(usdxInfo.reserveId);
    wethInfo.lp = spoke1.getLiquidityPremium(wethInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supply(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);

    // Bob supply usdx into spoke1
    Utils.supply(spoke1, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, usdxInfo.reserveId, true);

    // Alice supply weth into spoke1
    Utils.supply(spoke1, wethInfo.reserveId, alice, wethInfo.supplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, wethInfo.reserveId, true);

    // Bob draw weth
    Utils.borrow(spoke1, wethInfo.reserveId, bob, wethInfo.borrowAmount, bob);

    // Dai and usdx will each cover half the debt, because dai has lower lp than usdx
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'user risk premium'
    );
  }

  /// Supply 2 reserves and borrow one. Check user risk premium calc.
  function test_getUserRiskPremium_fuzz_two_reserves_supply_and_borrow(
    uint256 daiSupplyAmount,
    uint256 usdxSupplyAmount,
    uint256 wethBorrowAmount
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;
    daiSupplyAmount = bound(daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    usdxSupplyAmount = bound(usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);

    wethBorrowAmount = bound(wethBorrowAmount, 0, totalBorrowAmount);

    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wethInfo;

    daiInfo.reserveId = _daiReserveId(spoke3);
    usdxInfo.reserveId = _usdxReserveId(spoke3);
    wethInfo.reserveId = _wethReserveId(spoke3);

    daiInfo.supplyAmount = daiSupplyAmount;
    usdxInfo.supplyAmount = usdxSupplyAmount;
    wethInfo.supplyAmount = MAX_SUPPLY_AMOUNT;

    // Borrow all value in weth
    wethInfo.borrowAmount = wethBorrowAmount;

    daiInfo.lp = spoke3.getLiquidityPremium(daiInfo.reserveId);
    wethInfo.lp = spoke3.getLiquidityPremium(wethInfo.reserveId);
    usdxInfo.lp = spoke3.getLiquidityPremium(usdxInfo.reserveId);

    // Bob supply dai into spoke3
    if (daiInfo.supplyAmount > 0) {
      Utils.supply(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, daiInfo.reserveId, true);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.supply(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, usdxInfo.reserveId, true);
    }

    // Bob supply weth into spoke3
    Utils.supply(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, wethInfo.reserveId, true);

    // Bob draw weth
    if (wethInfo.borrowAmount > 0) {
      Utils.borrow(spoke3, wethInfo.reserveId, bob, wethInfo.borrowAmount, bob);
    }

    // Dai and usdx will each cover part of the debt
    assertEq(
      spoke3.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke3),
      'user risk premium'
    );
  }

  /// Supply 3 reserves and borrow one. Check user risk premium calc.
  function test_getUserRiskPremium_fuzz_three_reserves_supply_and_borrow(
    uint256 daiSupplyAmount,
    uint256 usdxSupplyAmount,
    uint256 wethSupplyAmount,
    uint256 wbtcBorrowAmount
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;
    daiSupplyAmount = bound(daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wethSupplyAmount = bound(wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    usdxSupplyAmount = bound(usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wbtcBorrowAmount = bound(wbtcBorrowAmount, 0, totalBorrowAmount);

    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory wethInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wbtcInfo;

    daiInfo.reserveId = _daiReserveId(spoke3);
    wethInfo.reserveId = _wethReserveId(spoke3);
    usdxInfo.reserveId = _usdxReserveId(spoke3);
    wbtcInfo.reserveId = _wbtcReserveId(spoke3);

    daiInfo.supplyAmount = daiSupplyAmount;
    wethInfo.supplyAmount = wethSupplyAmount;
    usdxInfo.supplyAmount = usdxSupplyAmount;
    wbtcInfo.supplyAmount = MAX_SUPPLY_AMOUNT;

    wbtcInfo.borrowAmount = wbtcBorrowAmount;

    daiInfo.lp = spoke3.getLiquidityPremium(daiInfo.reserveId);
    wethInfo.lp = spoke3.getLiquidityPremium(wethInfo.reserveId);
    usdxInfo.lp = spoke3.getLiquidityPremium(usdxInfo.reserveId);

    // Bob supply dai into spoke3
    if (daiInfo.supplyAmount > 0) {
      Utils.supply(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, daiInfo.reserveId, true);
    }

    // Bob supply weth into spoke3
    if (wethInfo.supplyAmount > 0) {
      Utils.supply(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, wethInfo.reserveId, true);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.supply(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, usdxInfo.reserveId, true);
    }

    // Bob supply wbtc into spoke3
    Utils.supply(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, wbtcInfo.reserveId, true);

    // Bob draw wbtc
    if (wbtcInfo.borrowAmount > 0) {
      Utils.borrow(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.borrowAmount, bob);
    }

    // Dai, weth, and usdx will each cover part of the debt
    assertEq(
      spoke3.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke3),
      'user risk premium'
    );
  }

  /// Supply 4 reserves and borrow one. Check user risk premium calc.
  function test_getUserRiskPremium_fuzz_four_reserves_supply_and_borrow(
    uint256 daiSupplyAmount,
    uint256 wethSupplyAmount,
    uint256 usdxSupplyAmount,
    uint256 wbtcSupplyAmount,
    uint256 borrowAmount
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;

    daiSupplyAmount = bound(daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wethSupplyAmount = bound(wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    usdxSupplyAmount = bound(usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wbtcSupplyAmount = bound(wbtcSupplyAmount, 0, MAX_SUPPLY_AMOUNT);

    borrowAmount = bound(borrowAmount, 0, totalBorrowAmount);

    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wethInfo;
    ReserveInfoLocal memory wbtcInfo;
    ReserveInfoLocal memory dai2Info;

    daiInfo.reserveId = _daiReserveId(spoke2);
    usdxInfo.reserveId = _usdxReserveId(spoke2);
    wethInfo.reserveId = _wethReserveId(spoke2);
    wbtcInfo.reserveId = _wbtcReserveId(spoke2);
    dai2Info.reserveId = _dai2ReserveId(spoke2);

    daiInfo.supplyAmount = daiSupplyAmount;
    wethInfo.supplyAmount = wethSupplyAmount;
    usdxInfo.supplyAmount = usdxSupplyAmount;
    wbtcInfo.supplyAmount = wbtcSupplyAmount;

    // Borrow all value in dai2
    dai2Info.borrowAmount = borrowAmount;

    daiInfo.lp = spoke2.getLiquidityPremium(daiInfo.reserveId);
    wethInfo.lp = spoke2.getLiquidityPremium(wethInfo.reserveId);
    usdxInfo.lp = spoke2.getLiquidityPremium(usdxInfo.reserveId);
    wbtcInfo.lp = spoke2.getLiquidityPremium(wbtcInfo.reserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (wbtcInfo.supplyAmount > 0) {
      Utils.supply(spoke2, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wbtcInfo.reserveId, true);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.supply(spoke2, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wethInfo.reserveId, true);
    }

    // Bob supply dai into spoke2
    if (daiInfo.supplyAmount > 0) {
      Utils.supply(spoke2, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, daiInfo.reserveId, true);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.supply(spoke2, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, usdxInfo.reserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.supply(spoke2, dai2Info.reserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    setUsingAsCollateral(spoke2, bob, dai2Info.reserveId, true);

    // Bob draw dai2
    if (dai2Info.borrowAmount > 0) {
      Utils.borrow(spoke2, dai2Info.reserveId, bob, dai2Info.borrowAmount, bob);
    }

    // wbtc, weth, dai, and usdx will each cover part of the debt
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );
  }

  /// Supply 4 reserves and borrow one. Change the price of one reserve, and check user risk premium calc.
  function test_getUserRiskPremium_fuzz_four_reserves_change_one_price(
    uint256 daiSupplyAmount,
    uint256 wethSupplyAmount,
    uint256 usdxSupplyAmount,
    uint256 wbtcSupplyAmount,
    uint256 borrowAmount,
    uint256 newUsdxPrice
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;

    newUsdxPrice = bound(newUsdxPrice, 0, 1e16);

    daiSupplyAmount = bound(daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT_DAI);
    wethSupplyAmount = bound(wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT_WETH);
    usdxSupplyAmount = bound(usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT_USDX);
    wbtcSupplyAmount = bound(wbtcSupplyAmount, 0, MAX_SUPPLY_AMOUNT_WBTC);

    borrowAmount = bound(borrowAmount, 0, totalBorrowAmount);

    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wethInfo;
    ReserveInfoLocal memory wbtcInfo;
    ReserveInfoLocal memory dai2Info;

    daiInfo.reserveId = _daiReserveId(spoke2);
    wethInfo.reserveId = _wethReserveId(spoke2);
    usdxInfo.reserveId = _usdxReserveId(spoke2);
    wbtcInfo.reserveId = _wbtcReserveId(spoke2);
    dai2Info.reserveId = _dai2ReserveId(spoke2);

    daiInfo.supplyAmount = daiSupplyAmount;
    wethInfo.supplyAmount = wethSupplyAmount;
    usdxInfo.supplyAmount = usdxSupplyAmount;
    wbtcInfo.supplyAmount = wbtcSupplyAmount;
    dai2Info.supplyAmount = MAX_SUPPLY_AMOUNT;

    // Borrow all value in dai2
    dai2Info.borrowAmount = borrowAmount;

    daiInfo.lp = spoke2.getLiquidityPremium(daiInfo.reserveId);
    wethInfo.lp = spoke2.getLiquidityPremium(wethInfo.reserveId);
    usdxInfo.lp = spoke2.getLiquidityPremium(usdxInfo.reserveId);
    wbtcInfo.lp = spoke2.getLiquidityPremium(wbtcInfo.reserveId);
    dai2Info.lp = spoke2.getLiquidityPremium(dai2Info.reserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (wbtcInfo.supplyAmount > 0) {
      Utils.supply(spoke2, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wbtcInfo.reserveId, true);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.supply(spoke2, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wethInfo.reserveId, true);
    }

    // Bob supply dai into spoke2
    if (daiInfo.supplyAmount > 0) {
      Utils.supply(spoke2, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, daiInfo.reserveId, true);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.supply(spoke2, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, usdxInfo.reserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.supply(spoke2, dai2Info.reserveId, bob, dai2Info.supplyAmount, bob);
    setUsingAsCollateral(spoke2, bob, dai2Info.reserveId, true);

    // Bob draw dai2
    if (dai2Info.borrowAmount > 0) {
      Utils.borrow(spoke2, dai2Info.reserveId, bob, dai2Info.borrowAmount, bob);
    }

    // wbtc, weth, dai, and usdx will each cover part of the debt
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );

    // Now change the price of usdx
    oracle.setAssetPrice(usdxAssetId, newUsdxPrice);

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium after price'
    );
  }

  /// Supply 4 reserves and borrow one. Change liquidity premium of a reserve, and check user risk premium calc.
  function test_getUserRiskPremium_fuzz_four_reserves_change_lp(
    uint256 daiSupplyAmount,
    uint256 wethSupplyAmount,
    uint256 usdxSupplyAmount,
    uint256 wbtcSupplyAmount,
    uint256 borrowAmount,
    uint256 newLpValue
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;

    // Bound LP to below dai2 so reserve is still used in rp calc
    newLpValue = bound(newLpValue, 0, 99_99);

    daiSupplyAmount = bound(daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wethSupplyAmount = bound(wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    usdxSupplyAmount = bound(usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wbtcSupplyAmount = bound(wbtcSupplyAmount, 0, MAX_SUPPLY_AMOUNT);

    borrowAmount = bound(borrowAmount, 0, totalBorrowAmount);

    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wethInfo;
    ReserveInfoLocal memory wbtcInfo;
    ReserveInfoLocal memory dai2Info;

    daiInfo.reserveId = _daiReserveId(spoke2);
    wethInfo.reserveId = _wethReserveId(spoke2);
    usdxInfo.reserveId = _usdxReserveId(spoke2);
    wbtcInfo.reserveId = _wbtcReserveId(spoke2);
    dai2Info.reserveId = _dai2ReserveId(spoke2);

    daiInfo.supplyAmount = daiSupplyAmount;
    wethInfo.supplyAmount = wethSupplyAmount;
    usdxInfo.supplyAmount = usdxSupplyAmount;
    wbtcInfo.supplyAmount = wbtcSupplyAmount;
    dai2Info.supplyAmount = MAX_SUPPLY_AMOUNT;

    // Borrow all value in dai2
    dai2Info.borrowAmount = borrowAmount;

    daiInfo.lp = spoke2.getLiquidityPremium(daiInfo.reserveId);
    wethInfo.lp = spoke2.getLiquidityPremium(wethInfo.reserveId);
    usdxInfo.lp = spoke2.getLiquidityPremium(usdxInfo.reserveId);
    wbtcInfo.lp = spoke2.getLiquidityPremium(wbtcInfo.reserveId);
    dai2Info.lp = spoke2.getLiquidityPremium(dai2Info.reserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (wbtcInfo.supplyAmount > 0) {
      Utils.supply(spoke2, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wbtcInfo.reserveId, true);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.supply(spoke2, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wethInfo.reserveId, true);
    }

    // Bob supply dai into spoke2
    if (daiInfo.supplyAmount > 0) {
      Utils.supply(spoke2, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, daiInfo.reserveId, true);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.supply(spoke2, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, usdxInfo.reserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.supply(spoke2, dai2Info.reserveId, bob, dai2Info.supplyAmount, bob);
    setUsingAsCollateral(spoke2, bob, dai2Info.reserveId, true);

    // Bob draw dai2
    if (dai2Info.borrowAmount > 0) {
      Utils.borrow(spoke2, dai2Info.reserveId, bob, dai2Info.borrowAmount, bob);
    }

    // wbtc, weth, dai, and usdx will each cover part of the debt
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );

    // Change the liquidity premium of wbtc
    spoke2.updateLiquidityPremium(wbtcInfo.reserveId, newLpValue);

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );
  }

  /// Bob supplies and borrows varying amounts of 4 reserves.
  /// We update prices and reserve liquidity premiums, then ensure risk premium is calculated correctly.
  function test_getUserRiskPremium_fuzz_four_reserves_prices_supply_debt(
    ReserveInfoLocal memory daiInfo,
    ReserveInfoLocal memory wethInfo,
    ReserveInfoLocal memory usdxInfo,
    ReserveInfoLocal memory wbtcInfo
  ) public {
    daiInfo.supplyAmount = bound(daiInfo.supplyAmount, 0, MAX_SUPPLY_AMOUNT_DAI);
    wethInfo.supplyAmount = bound(wethInfo.supplyAmount, 0, MAX_SUPPLY_AMOUNT_WETH);
    usdxInfo.supplyAmount = bound(usdxInfo.supplyAmount, 0, MAX_SUPPLY_AMOUNT_USDX);
    wbtcInfo.supplyAmount = bound(wbtcInfo.supplyAmount, 0, MAX_SUPPLY_AMOUNT_WBTC);

    daiInfo.borrowAmount = bound(daiInfo.borrowAmount, 0, daiInfo.supplyAmount / 2);
    wethInfo.borrowAmount = bound(wethInfo.borrowAmount, 0, wethInfo.supplyAmount / 2);
    usdxInfo.borrowAmount = bound(usdxInfo.borrowAmount, 0, usdxInfo.supplyAmount / 2);
    wbtcInfo.borrowAmount = bound(wbtcInfo.borrowAmount, 0, wbtcInfo.supplyAmount / 2);

    vm.assume(
      daiInfo.supplyAmount +
        wethInfo.supplyAmount +
        usdxInfo.supplyAmount +
        wbtcInfo.supplyAmount <=
        MAX_SUPPLY_AMOUNT
    );
    vm.assume(
      daiInfo.borrowAmount +
        wethInfo.borrowAmount +
        usdxInfo.borrowAmount +
        wbtcInfo.borrowAmount <=
        MAX_SUPPLY_AMOUNT / 2
    );

    daiInfo.price = bound(daiInfo.price, 0, 1e16);
    wethInfo.price = bound(wethInfo.price, 0, 1e16);
    usdxInfo.price = bound(usdxInfo.price, 0, 1e16);
    wbtcInfo.price = bound(wbtcInfo.price, 0, 1e16);

    daiInfo.lp = bound(daiInfo.lp, 0, 1000_00);
    wethInfo.lp = bound(wethInfo.lp, 0, 1000_00);
    usdxInfo.lp = bound(usdxInfo.lp, 0, 1000_00);
    wbtcInfo.lp = bound(wbtcInfo.lp, 0, 1000_00);

    // Bob supply dai into spoke2
    if (daiInfo.supplyAmount > 0) {
      Utils.supply(spoke2, _daiReserveId(spoke2), bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, _daiReserveId(spoke2), true);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.supply(spoke2, _wethReserveId(spoke2), bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, _wethReserveId(spoke2), true);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.supply(spoke2, _usdxReserveId(spoke2), bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, _usdxReserveId(spoke2), true);
    }

    // Bob supply wbtc into spoke2
    if (wbtcInfo.supplyAmount > 0) {
      Utils.supply(spoke2, _wbtcReserveId(spoke2), bob, wbtcInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, _wbtcReserveId(spoke2), true);
    }

    // Update prices
    oracle.setAssetPrice(daiAssetId, daiInfo.price);
    oracle.setAssetPrice(wethAssetId, wethInfo.price);
    oracle.setAssetPrice(usdxAssetId, usdxInfo.price);
    oracle.setAssetPrice(wbtcAssetId, wbtcInfo.price);

    // Update LPs
    spoke2.updateLiquidityPremium(_daiReserveId(spoke2), daiInfo.lp);
    spoke2.updateLiquidityPremium(_wethReserveId(spoke2), wethInfo.lp);
    spoke2.updateLiquidityPremium(_usdxReserveId(spoke2), usdxInfo.lp);
    spoke2.updateLiquidityPremium(_wbtcReserveId(spoke2), wbtcInfo.lp);

    // Check user risk premium
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );
  }

  /// Bob supplies varying amounts of dai, weth, and usdx, and max wbtc; borrows wbtc.
  /// We check Bob's risk premium and interest accrual are calculated correctly and accounting percolates through hub.
  function test_getUserRiskPremium_fuzz_applyingInterest(
    uint256 daiSupplyAmount,
    uint256 wethSupplyAmount,
    uint256 usdxSupplyAmount,
    uint256 borrowAmount
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;
    daiSupplyAmount = bound(daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wethSupplyAmount = bound(wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    usdxSupplyAmount = bound(usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);

    borrowAmount = bound(borrowAmount, 0, totalBorrowAmount);

    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory wethInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wbtcInfo;

    daiInfo.reserveId = _daiReserveId(spoke3);
    wethInfo.reserveId = _wethReserveId(spoke3);
    usdxInfo.reserveId = _usdxReserveId(spoke3);
    wbtcInfo.reserveId = _wbtcReserveId(spoke3);

    daiInfo.supplyAmount = daiSupplyAmount;
    wethInfo.supplyAmount = wethSupplyAmount;
    usdxInfo.supplyAmount = usdxSupplyAmount;
    wbtcInfo.supplyAmount = MAX_SUPPLY_AMOUNT;

    wbtcInfo.borrowAmount = borrowAmount;

    daiInfo.lp = spoke3.getLiquidityPremium(daiInfo.reserveId);
    wethInfo.lp = spoke3.getLiquidityPremium(wethInfo.reserveId);
    usdxInfo.lp = spoke3.getLiquidityPremium(usdxInfo.reserveId);

    // Bob supply dai into spoke3
    if (daiInfo.supplyAmount > 0) {
      Utils.supply(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, daiInfo.reserveId, true);
    }

    // Bob supply weth into spoke3
    if (wethInfo.supplyAmount > 0) {
      Utils.supply(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, wethInfo.reserveId, true);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.supply(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, usdxInfo.reserveId, true);
    }

    // Bob supply wbtc into spoke3
    Utils.supply(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, wbtcInfo.reserveId, true);

    // Bob draw wbtc
    if (wbtcInfo.borrowAmount > 0) {
      Utils.borrow(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.borrowAmount, bob);
    }

    // Dai, usdx, and weth will each cover part of the debt
    uint256 expectedUserRiskPremium = _calculateExpectedUserRP(bob, spoke3);

    assertEq(spoke3.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');

    // Get the base rate of wbtc
    uint256 baseRate = hub.getBaseInterestRate(wbtcAssetId);
    uint256 baseDebt = wbtcInfo.borrowAmount;
    (uint256 actualBaseDebt, uint256 actualPremium) = spoke3.getUserDebt(wbtcInfo.reserveId, bob);
    uint40 startTime = uint40(vm.getBlockTimestamp());

    assertEq(baseDebt, actualBaseDebt, 'user base debt');
    assertEq(actualPremium, 0, 'user premium debt');

    // Wait a year
    skip(365 days);

    // Ensure the calculated risk premium would match
    assertEq(
      spoke3.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke3),
      'bob risk premium after time skip'
    );

    // See if base debt of wbtc changes appropriately
    baseDebt = MathUtils.calculateLinearInterest(baseRate, startTime).rayMul(baseDebt);
    (actualBaseDebt, actualPremium) = spoke3.getUserDebt(wbtcInfo.reserveId, bob);
    assertEq(baseDebt, actualBaseDebt, 'user base debt');

    // See if premium debt changes proportionally to user risk premium change
    uint256 premiumDebt = (baseDebt - wbtcInfo.borrowAmount).percentMul(expectedUserRiskPremium);
    assertApproxEqAbs(premiumDebt, actualPremium, 1, 'user premium debt after interest accrual');

    // Since Bob is only user, reserve debt should be equal to user debt
    (uint256 reserveDebt, uint256 reservePremium) = spoke3.getReserveDebt(wbtcInfo.reserveId);
    assertEq(reserveDebt, baseDebt, 'reserve base debt');
    assertApproxEqAbs(reservePremium, premiumDebt, 1, 'reserve premium debt');

    // See if values are reflected on hub side as well
    (uint256 spokeDebt, uint256 spokePremium) = hub.getSpokeDebt(wbtcAssetId, address(spoke3));
    assertEq(spokeDebt, baseDebt, 'hub spoke base debt');
    assertApproxEqAbs(spokePremium, premiumDebt, 1, 'hub spoke premium debt');

    (uint256 assetDebt, uint256 assetPremium) = hub.getAssetDebt(wbtcAssetId);
    assertEq(assetDebt, baseDebt, 'hub asset base debt');
    assertApproxEqAbs(assetPremium, premiumDebt, 1, 'hub asset premium debt');
  }

  /// Bob supplies varying amounts of dai, weth, usdx, and max wbtc, then borrows varying wbtc and weth amounts.
  /// We check interest is updated properly after 1 year, and accounting percolates up through liquidity hub.
  function test_getUserRiskPremium_fuzz_applyInterest_two_reserves_borrowed(
    uint256 daiSupplyAmount,
    uint256 usdxSupplyAmount,
    uint256 wethSupplyAmount,
    uint256 wbtcBorrowamount,
    uint256 wethBorrowAmount
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;
    daiSupplyAmount = bound(daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wethSupplyAmount = bound(wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    usdxSupplyAmount = bound(usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);

    wbtcBorrowamount = bound(wbtcBorrowamount, 0, totalBorrowAmount);
    wethBorrowAmount = bound(wethBorrowAmount, 0, totalBorrowAmount);

    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory wethInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wbtcInfo;

    daiInfo.reserveId = _daiReserveId(spoke3);
    wethInfo.reserveId = _wethReserveId(spoke3);
    usdxInfo.reserveId = _usdxReserveId(spoke3);
    wbtcInfo.reserveId = _wbtcReserveId(spoke3);

    daiInfo.supplyAmount = daiSupplyAmount;
    wethInfo.supplyAmount = wethSupplyAmount;
    usdxInfo.supplyAmount = usdxSupplyAmount;
    wbtcInfo.supplyAmount = MAX_SUPPLY_AMOUNT;

    wbtcInfo.borrowAmount = wbtcBorrowamount;
    wethInfo.borrowAmount = wethBorrowAmount;

    daiInfo.lp = spoke3.getLiquidityPremium(daiInfo.reserveId);
    wethInfo.lp = spoke3.getLiquidityPremium(wethInfo.reserveId);
    usdxInfo.lp = spoke3.getLiquidityPremium(usdxInfo.reserveId);

    // Bob supply dai into spoke3
    if (daiInfo.supplyAmount > 0) {
      Utils.supply(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, daiInfo.reserveId, true);
    }

    // Bob supply weth into spoke3
    if (wethInfo.supplyAmount > 0) {
      Utils.supply(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, wethInfo.reserveId, true);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.supply(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, usdxInfo.reserveId, true);
    }

    // Bob supply wbtc into spoke3
    Utils.supply(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, wbtcInfo.reserveId, true);

    // Alice supply remaining weth into spoke3
    if (MAX_SUPPLY_AMOUNT - wethInfo.supplyAmount > 0) {
      Utils.supply(
        spoke3,
        wethInfo.reserveId,
        alice,
        MAX_SUPPLY_AMOUNT - wethInfo.supplyAmount,
        alice
      );
    }

    // Bob draw wbtc
    if (wbtcInfo.borrowAmount > 0) {
      Utils.borrow(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.borrowAmount, bob);
    }

    // Bob draw weth
    if (wethInfo.borrowAmount > 0) {
      Utils.borrow(spoke3, wethInfo.reserveId, bob, wethInfo.borrowAmount, bob);
    }

    uint256 expectedUserRiskPremium = _calculateExpectedUserRP(bob, spoke3);

    assertEq(spoke3.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');

    DebtChecks memory debtChecks;

    // Get the base rate of wbtc
    uint256 baseRateWbtc = hub.getBaseInterestRate(wbtcAssetId);
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke3.getUserDebt(
      wbtcInfo.reserveId,
      bob
    );
    uint256 startTime = vm.getBlockTimestamp();

    assertEq(wbtcInfo.borrowAmount, debtChecks.actualBaseDebt, 'user base debt');
    assertEq(debtChecks.actualPremium, 0, 'user premium debt');

    // Get the base rate of weth
    uint256 baseRateWeth = hub.getBaseInterestRate(wethAssetId);
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke3.getUserDebt(
      wethInfo.reserveId,
      bob
    );

    assertEq(wethInfo.borrowAmount, debtChecks.actualBaseDebt, 'user base debt');
    assertEq(debtChecks.actualPremium, 0, 'user premium debt');

    // Wait a year
    skip(365 days);

    // Ensure the calculated risk premium would match
    assertEq(
      spoke3.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke3),
      'bob risk premium after time skip'
    );

    // See if base debt of wbtc changes appropriately
    debtChecks.baseDebt = MathUtils.calculateLinearInterest(baseRateWbtc, uint40(startTime)).rayMul(
      wbtcInfo.borrowAmount
    );
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke3.getUserDebt(
      wbtcInfo.reserveId,
      bob
    );
    assertEq(debtChecks.baseDebt, debtChecks.actualBaseDebt, 'user base debt');

    // See if premium debt changes proportionally to user risk premium
    debtChecks.premiumDebt = (debtChecks.baseDebt - wbtcInfo.borrowAmount).percentMul(
      expectedUserRiskPremium
    );
    assertApproxEqAbs(
      debtChecks.premiumDebt,
      debtChecks.actualPremium,
      1,
      'user premium debt after accrual'
    );

    // Since Bob is only user, reserve debt should be equal to user debt
    (debtChecks.reserveDebt, debtChecks.reservePremium) = spoke3.getReserveDebt(wbtcInfo.reserveId);
    assertEq(debtChecks.reserveDebt, debtChecks.baseDebt, 'reserve base debt after accrual');
    assertApproxEqAbs(
      debtChecks.reservePremium,
      debtChecks.premiumDebt,
      1,
      'reserve premium debt after accrual'
    );

    // See if values are reflected on hub side as well
    (debtChecks.spokeDebt, debtChecks.spokePremium) = hub.getSpokeDebt(
      wbtcAssetId,
      address(spoke3)
    );
    assertEq(debtChecks.spokeDebt, debtChecks.baseDebt, 'hub spoke base debt after accrual');
    assertApproxEqAbs(
      debtChecks.spokePremium,
      debtChecks.premiumDebt,
      1,
      'hub spoke premium debt after accrual'
    );

    (debtChecks.assetDebt, debtChecks.assetPremium) = hub.getAssetDebt(wbtcAssetId);
    assertEq(debtChecks.assetDebt, debtChecks.baseDebt, 'hub asset base debt after accrual');
    assertApproxEqAbs(
      debtChecks.assetPremium,
      debtChecks.premiumDebt,
      1,
      'hub asset premium debt after accrual'
    );

    // See if base debt of weth changes appropriately
    debtChecks.baseDebt = MathUtils.calculateLinearInterest(baseRateWeth, uint40(startTime)).rayMul(
      wethInfo.borrowAmount
    );
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke3.getUserDebt(
      wethInfo.reserveId,
      bob
    );
    assertEq(debtChecks.baseDebt, debtChecks.actualBaseDebt, 'user base debt');

    // See if premium debt changes proportionally to user risk premium
    debtChecks.premiumDebt = (debtChecks.baseDebt - wethInfo.borrowAmount).percentMul(
      expectedUserRiskPremium
    );
    assertApproxEqAbs(
      debtChecks.premiumDebt,
      debtChecks.actualPremium,
      1,
      'user premium debt after accrual'
    );

    // Since Bob is only user, reserve debt should be equal to user debt
    (debtChecks.reserveDebt, debtChecks.reservePremium) = spoke3.getReserveDebt(wethInfo.reserveId);
    assertEq(debtChecks.reserveDebt, debtChecks.baseDebt, 'reserve base debt after accrual');
    assertApproxEqAbs(
      debtChecks.reservePremium,
      debtChecks.premiumDebt,
      1,
      'reserve premium debt after accrual'
    );

    // See if values are reflected on hub side as well
    (debtChecks.spokeDebt, debtChecks.spokePremium) = hub.getSpokeDebt(
      wethAssetId,
      address(spoke3)
    );
    assertEq(debtChecks.spokeDebt, debtChecks.baseDebt, 'hub spoke base debt after accrual');
    assertApproxEqAbs(
      debtChecks.spokePremium,
      debtChecks.premiumDebt,
      1,
      'hub spoke premium debt after accrual'
    );

    (debtChecks.assetDebt, debtChecks.assetPremium) = hub.getAssetDebt(wethAssetId);
    assertEq(debtChecks.assetDebt, debtChecks.baseDebt, 'hub asset base debt after accrual');
    assertApproxEqAbs(
      debtChecks.assetPremium,
      debtChecks.premiumDebt,
      1,
      'hub asset premium debt after accrual'
    );
  }

  /// Bob and Alice each supply and borrow varying amounts of usdx and dai, we check interest accrues and values percolate to hub.
  /// After 1 year, Alice does a repay, and we ensure the same values are updated accordingly.
  function test_getUserRiskPremium_applyInterest_two_users_two_reserves_borrowed() public {
    // Set Dai lp to 10% and usdx to 20%
    spoke1.updateLiquidityPremium(_daiReserveId(spoke1), 10_00);
    spoke1.updateLiquidityPremium(_usdxReserveId(spoke1), 20_00);

    UserInfoLocal memory bobDaiInfo;
    UserInfoLocal memory aliceDaiInfo;
    UserInfoLocal memory bobUsdxInfo;
    UserInfoLocal memory aliceUsdxInfo;

    bobDaiInfo.supplyAmount = 1000e18;
    aliceDaiInfo.supplyAmount = 2000e18;
    bobUsdxInfo.supplyAmount = 5000e6;
    aliceUsdxInfo.supplyAmount = 10000e6;

    bobDaiInfo.borrowAmount = bobDaiInfo.supplyAmount / 2;
    aliceDaiInfo.borrowAmount = aliceDaiInfo.supplyAmount / 2;
    bobUsdxInfo.borrowAmount = bobUsdxInfo.supplyAmount / 2;
    aliceUsdxInfo.borrowAmount = aliceUsdxInfo.supplyAmount / 2;

    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;

    daiInfo.reserveId = _daiReserveId(spoke1);
    usdxInfo.reserveId = _usdxReserveId(spoke1);

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);
    usdxInfo.lp = spoke1.getLiquidityPremium(usdxInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supply(spoke1, daiInfo.reserveId, bob, bobDaiInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);

    // Bob supply usdx into spoke1
    Utils.supply(spoke1, usdxInfo.reserveId, bob, bobUsdxInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, usdxInfo.reserveId, true);

    // Alice supply dai into spoke1
    Utils.supply(spoke1, daiInfo.reserveId, alice, aliceDaiInfo.supplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, daiInfo.reserveId, true);

    // Alice supply usdx into spoke1
    Utils.supply(spoke1, usdxInfo.reserveId, alice, aliceUsdxInfo.supplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, usdxInfo.reserveId, true);

    // Bob draw dai
    Utils.borrow(spoke1, daiInfo.reserveId, bob, bobDaiInfo.borrowAmount, bob);

    // Bob draw usdx
    Utils.borrow(spoke1, usdxInfo.reserveId, bob, bobUsdxInfo.borrowAmount, bob);

    // Alice draw dai
    Utils.borrow(spoke1, daiInfo.reserveId, alice, aliceDaiInfo.borrowAmount, alice);

    // Alice draw usdx
    Utils.borrow(spoke1, usdxInfo.reserveId, alice, aliceUsdxInfo.borrowAmount, alice);

    uint256 bobExpectedRiskPremium = _calculateExpectedUserRP(bob, spoke1);
    uint256 aliceExpectedRiskPremium = _calculateExpectedUserRP(alice, spoke1);

    assertEq(spoke1.getUserRiskPremium(bob), bobExpectedRiskPremium, 'bob risk premium');
    assertEq(spoke1.getUserRiskPremium(alice), aliceExpectedRiskPremium, 'alice risk premium');

    DebtChecks memory debtChecks;

    // Get the base rate of dai
    uint256 baseRateDai = hub.getBaseInterestRate(daiAssetId);

    // Check Bob's starting dai debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      bob
    );
    uint256 startTime = vm.getBlockTimestamp();

    assertEq(bobDaiInfo.borrowAmount, debtChecks.actualBaseDebt, 'Bob dai debt before');
    assertEq(debtChecks.actualPremium, 0, 'Bob dai premium before');

    // Get the base rate of usdx
    uint256 baseRateUsdx = hub.getBaseInterestRate(usdxAssetId);

    // Check Bob's starting usdx debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      bob
    );

    assertEq(bobUsdxInfo.borrowAmount, debtChecks.actualBaseDebt, 'Bob usdx debt before');
    assertEq(debtChecks.actualPremium, 0, 'Bob usdx premium before');

    // Check Alice's starting dai debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      alice
    );

    assertEq(aliceDaiInfo.borrowAmount, debtChecks.actualBaseDebt, 'Alice dai debt before');
    assertEq(debtChecks.actualPremium, 0, 'Alice dai premium before');

    // Check Alice's starting usdx debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      alice
    );

    assertEq(aliceUsdxInfo.borrowAmount, debtChecks.actualBaseDebt, 'Alice usdx debt before');
    assertEq(debtChecks.actualPremium, 0, 'Alice usdx premium before');

    // Wait a year
    skip(365 days);

    // User risk premium should remain the same when there is no action
    assertEq(
      spoke1.getUserPreviousRiskPremium(usdxInfo.reserveId, bob),
      bobExpectedRiskPremium,
      'bob risk premium after interest accrual'
    );
    assertEq(
      spoke1.getUserPreviousRiskPremium(usdxInfo.reserveId, alice),
      aliceExpectedRiskPremium,
      'alice risk premium after interest accrual'
    );

    // Ensure the calculated risk premium would match
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'bob risk premium after time skip'
    );
    assertEq(
      spoke1.getUserRiskPremium(alice),
      _calculateExpectedUserRP(alice, spoke1),
      'alice risk premium after time skip'
    );

    // See if Bob's base debt of dai changes appropriately
    bobDaiInfo.baseDebt = MathUtils.calculateLinearInterest(baseRateDai, uint40(startTime)).rayMul(
      bobDaiInfo.borrowAmount
    );
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      bob
    );
    assertApproxEqAbs(bobDaiInfo.baseDebt, debtChecks.actualBaseDebt, 1, 'bob dai base debt after');

    // See if Bob's dai premium debt changes proportionally to bob's risk premium
    bobDaiInfo.premiumDebt = (bobDaiInfo.baseDebt - bobDaiInfo.borrowAmount).percentMul(
      bobExpectedRiskPremium
    );
    assertEq(bobDaiInfo.premiumDebt, debtChecks.actualPremium, 'bob premium debt after accrual');

    // See if Bob's base debt of usdx changes appropriately
    bobUsdxInfo.baseDebt = MathUtils
      .calculateLinearInterest(baseRateUsdx, uint40(startTime))
      .rayMul(bobUsdxInfo.borrowAmount);
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      bob
    );
    assertEq(bobUsdxInfo.baseDebt, debtChecks.actualBaseDebt, 'bob usdx base debt after');

    // See if Bob's usdx premium debt changes proportionally to bob's risk premium
    bobUsdxInfo.premiumDebt = (bobUsdxInfo.baseDebt - bobUsdxInfo.borrowAmount).percentMul(
      bobExpectedRiskPremium
    );
    assertEq(bobUsdxInfo.premiumDebt, debtChecks.actualPremium, 'bob premium debt after accrual');

    // See if Alice's base debt of dai changes appropriately
    aliceDaiInfo.baseDebt = MathUtils
      .calculateLinearInterest(baseRateDai, uint40(startTime))
      .rayMul(aliceDaiInfo.borrowAmount);
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      alice
    );
    assertEq(aliceDaiInfo.baseDebt, debtChecks.actualBaseDebt, 'alice dai base debt after');

    // See if Alice's dai premium debt changes proportionally to alice's risk premium
    aliceDaiInfo.premiumDebt = (aliceDaiInfo.baseDebt - aliceDaiInfo.borrowAmount).percentMul(
      aliceExpectedRiskPremium
    );
    assertEq(
      aliceDaiInfo.premiumDebt,
      debtChecks.actualPremium,
      'alice premium debt after accrual'
    );

    // See if Alice's base debt of usdx changes appropriately
    aliceUsdxInfo.baseDebt = MathUtils
      .calculateLinearInterest(baseRateUsdx, uint40(startTime))
      .rayMul(aliceUsdxInfo.borrowAmount);
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      alice
    );
    assertEq(aliceUsdxInfo.baseDebt, debtChecks.actualBaseDebt, 'alice usdx base debt after');

    // See if Alice's usdx premium debt changes proportionally to alice's risk premium
    aliceUsdxInfo.premiumDebt = (aliceUsdxInfo.baseDebt - aliceUsdxInfo.borrowAmount).percentMul(
      aliceExpectedRiskPremium
    );
    assertEq(
      aliceUsdxInfo.premiumDebt,
      debtChecks.actualPremium,
      'alice premium debt after accrual'
    );

    // Check reserve debt for dai
    (debtChecks.reserveDebt, debtChecks.reservePremium) = spoke1.getReserveDebt(daiInfo.reserveId);

    // Reserve debt should be the sum of both user debts
    assertEq(
      debtChecks.reserveDebt,
      bobDaiInfo.baseDebt + aliceDaiInfo.baseDebt,
      'reserve base debt after accrual'
    );

    // Reserve premium debt should be the sum of both users' premium debt
    assertEq(
      debtChecks.reservePremium,
      bobDaiInfo.premiumDebt + aliceDaiInfo.premiumDebt,
      'reserve premium debt after accrual'
    );

    // Check reserve debt for usdx
    (debtChecks.reserveDebt, debtChecks.reservePremium) = spoke1.getReserveDebt(usdxInfo.reserveId);

    // Reserve debt should be the sum of both user debts
    assertEq(
      debtChecks.reserveDebt,
      bobUsdxInfo.baseDebt + aliceUsdxInfo.baseDebt,
      'reserve base debt after accrual'
    );

    // Reserve premium debt should be the sum of both users' premium debt
    assertEq(
      debtChecks.reservePremium,
      bobUsdxInfo.premiumDebt + aliceUsdxInfo.premiumDebt,
      'reserve premium debt after accrual'
    );

    // Check spoke debt on hub for dai
    (debtChecks.spokeDebt, debtChecks.spokePremium) = hub.getSpokeDebt(daiAssetId, address(spoke1));

    // Spoke debt should be the sum of both user debts
    assertEq(
      debtChecks.spokeDebt,
      bobDaiInfo.baseDebt + aliceDaiInfo.baseDebt,
      'hub spoke base debt after accrual'
    );

    // Spoke premium debt should be the sum of both users' premium debt
    assertEq(
      debtChecks.spokePremium,
      bobDaiInfo.premiumDebt + aliceDaiInfo.premiumDebt,
      'hub spoke premium debt after accrual'
    );

    // Check spoke debt on hub for usdx
    (debtChecks.spokeDebt, debtChecks.spokePremium) = hub.getSpokeDebt(
      usdxAssetId,
      address(spoke1)
    );

    // Spoke debt should be the sum of both user debts
    assertEq(
      debtChecks.spokeDebt,
      bobUsdxInfo.baseDebt + aliceUsdxInfo.baseDebt,
      'hub spoke base debt after accrual'
    );

    // Spoke premium debt should be the sum of both users' premium debt
    assertEq(
      debtChecks.spokePremium,
      bobUsdxInfo.premiumDebt + aliceUsdxInfo.premiumDebt,
      'hub spoke premium debt after accrual'
    );

    // Check asset debt on hub for dai
    (debtChecks.assetDebt, debtChecks.assetPremium) = hub.getAssetDebt(daiAssetId);

    // Asset debt should be the sum of both user debts
    assertEq(
      debtChecks.assetDebt,
      bobDaiInfo.baseDebt + aliceDaiInfo.baseDebt,
      'hub asset base debt after accrual'
    );

    // Asset premium debt should be the sum of both users' premium debt
    assertEq(
      debtChecks.assetPremium,
      bobDaiInfo.premiumDebt + aliceDaiInfo.premiumDebt,
      'hub asset premium debt after accrual'
    );

    // Check asset debt on hub for usdx
    (debtChecks.assetDebt, debtChecks.assetPremium) = hub.getAssetDebt(usdxAssetId);

    // Asset debt should be the sum of both user debts
    assertEq(
      debtChecks.assetDebt,
      bobUsdxInfo.baseDebt + aliceUsdxInfo.baseDebt,
      'hub asset base debt after accrual'
    );

    // Asset premium debt should be the sum of both users' premium debt
    assertEq(
      debtChecks.assetPremium,
      bobUsdxInfo.premiumDebt + aliceUsdxInfo.premiumDebt,
      'hub asset premium debt after accrual'
    );

    // Now, if Alice repays some debt, her user risk premium should change and percolate through protocol
    Utils.repay(spoke1, daiInfo.reserveId, alice, aliceDaiInfo.borrowAmount / 2);

    // Bob's user risk premium remains unchanged
    assertEq(
      spoke1.getUserPreviousRiskPremium(daiInfo.reserveId, bob),
      bobExpectedRiskPremium,
      'bob risk premium after repay'
    );

    // Alice's user risk premium does change
    assertNotEq(
      spoke1.getUserPreviousRiskPremium(daiInfo.reserveId, alice),
      aliceExpectedRiskPremium,
      'alice rp after repay should not match'
    );
    aliceExpectedRiskPremium = _calculateExpectedUserRP(alice, spoke1);
    assertEq(
      spoke1.getUserRiskPremium(alice),
      aliceExpectedRiskPremium,
      'alice risk premium after repay'
    );

    // Gather new totals for base and premium debt on both assets for both users
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      alice
    );

    // Only Alice's premium debt and base debt on dai should change due to repay
    uint256 repayAmount = aliceDaiInfo.borrowAmount / 2;
    // Premium debt repaid first
    repayAmount -= aliceDaiInfo.premiumDebt;
    aliceDaiInfo.baseDebt -= repayAmount;
    aliceDaiInfo.premiumDebt = 0;
    assertApproxEqAbs(
      debtChecks.actualBaseDebt,
      aliceDaiInfo.baseDebt,
      1,
      'alice base debt after repay'
    );
    assertEq(debtChecks.actualPremium, aliceDaiInfo.premiumDebt, 'alice premium debt after repay');
    aliceDaiInfo.totalDebt = aliceDaiInfo.baseDebt + aliceDaiInfo.premiumDebt;

    // Alice's debts on usdx should remain unchanged
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      alice
    );
    assertEq(debtChecks.actualBaseDebt, aliceUsdxInfo.baseDebt, 'alice usdx base debt after');
    assertEq(debtChecks.actualPremium, aliceUsdxInfo.premiumDebt, 'alice usdx premium debt after');
    aliceUsdxInfo.totalDebt = aliceUsdxInfo.baseDebt + aliceUsdxInfo.premiumDebt;

    // Bob's debts on dai should remain unchanged
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      bob
    );
    assertApproxEqAbs(debtChecks.actualBaseDebt, bobDaiInfo.baseDebt, 1, 'bob dai base debt after');
    assertApproxEqAbs(
      debtChecks.actualPremium,
      bobDaiInfo.premiumDebt,
      1,
      'bob dai premium debt after'
    );
    bobDaiInfo.totalDebt = bobDaiInfo.baseDebt + bobDaiInfo.premiumDebt;

    // Bob's debts on usdx should remain unchanged
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      bob
    );
    assertEq(debtChecks.actualBaseDebt, bobUsdxInfo.baseDebt, 'bob usdx base debt after');
    assertEq(debtChecks.actualPremium, bobUsdxInfo.premiumDebt, 'bob usdx premium debt after');
  }

  /// Bob and Alice each supply and borrow varying fuzzed amounts of usdx and dai,
  /// with different risk premiums. We check interest accrues correctly and values percolate to hub.
  function test_getUserRiskPremium_fuzz_two_users_two_reserves_borrowed(
    UserAction memory bobDaiAction,
    UserAction memory bobUsdxAction,
    UserAction memory aliceDaiAction,
    UserAction memory aliceUsdxAction,
    uint256 daiLp,
    uint256 usdxLp,
    uint40 timeSkip,
    uint40 secondTimeSkip,
    uint40 thirdTimeSkip
  ) public {
    vm.skip(true, 'pending migration');
    //   // TODO: Make a dedicated function for bounds
    //   bobDaiAction.supplyAmount = bound(bobDaiAction.supplyAmount, 2, MAX_SUPPLY_AMOUNT / 2);
    //   bobUsdxAction.supplyAmount = bound(bobUsdxAction.supplyAmount, 2, MAX_SUPPLY_AMOUNT / 2);
    //   aliceDaiAction.supplyAmount = bound(aliceDaiAction.supplyAmount, 2, MAX_SUPPLY_AMOUNT / 2);
    //   aliceUsdxAction.supplyAmount = bound(aliceUsdxAction.supplyAmount, 2, MAX_SUPPLY_AMOUNT / 2);

    //   bobDaiAction.borrowAmount = bound(bobDaiAction.borrowAmount, 0, bobDaiAction.supplyAmount / 2);
    //   bobUsdxAction.borrowAmount = bound(
    //     bobUsdxAction.borrowAmount,
    //     0,
    //     bobUsdxAction.supplyAmount / 2
    //   );
    //   aliceDaiAction.borrowAmount = bound(
    //     aliceDaiAction.borrowAmount,
    //     0,
    //     aliceDaiAction.supplyAmount / 2
    //   );
    //   aliceUsdxAction.borrowAmount = bound(
    //     aliceUsdxAction.borrowAmount,
    //     0,
    //     aliceUsdxAction.supplyAmount / 2
    //   );

    //   daiLp = bound(daiLp, 0, MAX_RISK_PREMIUM_BPS);
    //   usdxLp = bound(usdxLp, 0, MAX_RISK_PREMIUM_BPS);

    //   timeSkip = uint40(bound(timeSkip, 0, MAX_SKIP_TIME));
    //   secondTimeSkip = uint40(bound(secondTimeSkip, 0, MAX_SKIP_TIME));
    //   thirdTimeSkip = uint40(bound(thirdTimeSkip, 0, MAX_SKIP_TIME));

    //   // Set liquidity premiums
    //   spoke1.updateLiquidityPremium(_daiReserveId(spoke1), daiLp);
    //   spoke1.updateLiquidityPremium(_usdxReserveId(spoke1), usdxLp);
    //   assertEq(spoke1.getLiquidityPremium(_daiReserveId(spoke1)), daiLp, 'dai lp');
    //   assertEq(spoke1.getLiquidityPremium(_usdxReserveId(spoke1)), usdxLp, 'usdx lp');

    //   UserInfoLocal memory bobDaiInfo;
    //   UserInfoLocal memory aliceDaiInfo;
    //   UserInfoLocal memory bobUsdxInfo;
    //   UserInfoLocal memory aliceUsdxInfo;

    //   // Set up user info structs
    //   bobDaiInfo.supplyAmount = bobDaiAction.supplyAmount;
    //   aliceDaiInfo.supplyAmount = aliceDaiAction.supplyAmount;
    //   bobUsdxInfo.supplyAmount = bobUsdxAction.supplyAmount;
    //   aliceUsdxInfo.supplyAmount = aliceUsdxAction.supplyAmount;

    //   bobDaiInfo.borrowAmount = bobDaiAction.borrowAmount;
    //   aliceDaiInfo.borrowAmount = aliceDaiAction.borrowAmount;
    //   bobUsdxInfo.borrowAmount = bobUsdxAction.borrowAmount;
    //   aliceUsdxInfo.borrowAmount = aliceUsdxAction.borrowAmount;

    //   ReserveInfoLocal memory daiInfo;
    //   ReserveInfoLocal memory usdxInfo;

    //   daiInfo.reserveId = _daiReserveId(spoke1);
    //   usdxInfo.reserveId = _usdxReserveId(spoke1);

    //   daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);
    //   usdxInfo.lp = spoke1.getLiquidityPremium(usdxInfo.reserveId);

    //   // Users supply

    //   // Bob supply dai
    //   Utils.supply(spoke1, daiInfo.reserveId, bob, bobDaiInfo.supplyAmount, bob);
    //   setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);

    //   // Bob supply usdx
    //   Utils.supply(spoke1, usdxInfo.reserveId, bob, bobUsdxInfo.supplyAmount, bob);
    //   setUsingAsCollateral(spoke1, bob, usdxInfo.reserveId, true);

    //   // Alice supply dai
    //   Utils.supply(spoke1, daiInfo.reserveId, alice, aliceDaiInfo.supplyAmount, alice);
    //   setUsingAsCollateral(spoke1, alice, daiInfo.reserveId, true);

    //   // Alice supply usdx
    //   Utils.supply(spoke1, usdxInfo.reserveId, alice, aliceUsdxInfo.supplyAmount, alice);
    //   setUsingAsCollateral(spoke1, alice, usdxInfo.reserveId, true);

    //   // Users borrow

    //   // Bob draw dai (if any)
    //   if (bobDaiInfo.borrowAmount > 0) {
    //     Utils.borrow(spoke1, daiInfo.reserveId, bob, bobDaiInfo.borrowAmount, bob);
    //   }

    //   // Bob draw usdx (if any)
    //   if (bobUsdxInfo.borrowAmount > 0) {
    //     Utils.borrow(spoke1, usdxInfo.reserveId, bob, bobUsdxInfo.borrowAmount, bob);
    //   }

    //   // Alice draw dai (if any)
    //   if (aliceDaiInfo.borrowAmount > 0) {
    //     Utils.borrow(spoke1, daiInfo.reserveId, alice, aliceDaiInfo.borrowAmount, alice);
    //   }

    //   // Alice draw usdx (if any)
    //   if (aliceUsdxInfo.borrowAmount > 0) {
    //     Utils.borrow(spoke1, usdxInfo.reserveId, alice, aliceUsdxInfo.borrowAmount, alice);
    //   }

    //   // Calculate expected risk premiums
    //   uint256 bobExpectedRiskPremium = _calculateExpectedUserRP(bob, spoke1);
    //   uint256 aliceExpectedRiskPremium = _calculateExpectedUserRP(alice, spoke1);

    //   // Verify initial risk premiums
    //   assertEq(spoke1.getUserRiskPremium(bob), bobExpectedRiskPremium, 'bob initial risk premium');
    //   assertEq(
    //     spoke1.getUserRiskPremium(alice),
    //     aliceExpectedRiskPremium,
    //     'alice initial risk premium'
    //   );

    //   DebtChecks memory debtChecks;

    //   // Get the base rates of assets
    //   uint256 baseRateDai = hub.getBaseInterestRate(daiAssetId);
    //   uint256 baseRateUsdx = hub.getBaseInterestRate(usdxAssetId);

    //   // Check initial debts

    //   // Bob's initial dai debt
    //   (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
    //     daiInfo.reserveId,
    //     bob
    //   );
    //   uint256 startTime = vm.getBlockTimestamp();

    //   assertEq(bobDaiInfo.borrowAmount, debtChecks.actualBaseDebt, 'Bob dai debt before');
    //   assertEq(debtChecks.actualPremium, 0, 'Bob dai premium before');

    //   // Bob's initial usdx debt
    //   (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
    //     usdxInfo.reserveId,
    //     bob
    //   );
    //   assertEq(bobUsdxInfo.borrowAmount, debtChecks.actualBaseDebt, 'Bob usdx debt before');
    //   assertEq(debtChecks.actualPremium, 0, 'Bob usdx premium before');

    //   // Alice's initial dai debt
    //   (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
    //     daiInfo.reserveId,
    //     alice
    //   );
    //   assertEq(aliceDaiInfo.borrowAmount, debtChecks.actualBaseDebt, 'Alice dai debt before');
    //   assertEq(debtChecks.actualPremium, 0, 'Alice dai premium before');

    //   // Alice's initial usdx debt
    //   (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
    //     usdxInfo.reserveId,
    //     alice
    //   );
    //   assertEq(aliceUsdxInfo.borrowAmount, debtChecks.actualBaseDebt, 'Alice usdx debt before');
    //   assertEq(debtChecks.actualPremium, 0, 'Alice usdx premium before');

    //   // Skip time
    //   skip(timeSkip);

    //   // Check that risk premiums remain consistent
    //   assertEq(
    //     spoke1.getUserPreviousRiskPremium(daiInfo.reserveId, bob),
    //     bobExpectedRiskPremium,
    //     'bob risk premium after time skip (dai)'
    //   );

    //   assertEq(
    //     spoke1.getUserPreviousRiskPremium(usdxInfo.reserveId, bob),
    //     bobExpectedRiskPremium,
    //     'bob risk premium after time skip (usdx)'
    //   );

    //   assertEq(
    //     spoke1.getUserPreviousRiskPremium(daiInfo.reserveId, alice),
    //     aliceExpectedRiskPremium,
    //     'alice risk premium after time skip (dai)'
    //   );

    //   assertEq(
    //     spoke1.getUserPreviousRiskPremium(usdxInfo.reserveId, alice),
    //     aliceExpectedRiskPremium,
    //     'alice risk premium after time skip (usdx)'
    //   );

    //   // Verify calculated risk premiums match previous values
    //   assertEq(
    //     spoke1.getUserRiskPremium(bob),
    //     _calculateExpectedUserRP(bob, spoke1),
    //     'bob calculated risk premium after time skip'
    //   );
    //   assertEq(
    //     spoke1.getUserRiskPremium(alice),
    //     _calculateExpectedUserRP(alice, spoke1),
    //     'alice calculated risk premium after time skip'
    //   );

    //   // Calculate accumulated debts

    //   // Bob's dai debt after 1 year
    //   if (bobDaiInfo.borrowAmount > 0) {
    //     bobDaiInfo.baseDebt = MathUtils
    //       .calculateLinearInterest(baseRateDai, uint40(startTime))
    //       .rayMul(bobDaiInfo.borrowAmount);

    //     (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
    //       daiInfo.reserveId,
    //       bob
    //     );
    //     assertApproxEqAbs(
    //       bobDaiInfo.baseDebt,
    //       debtChecks.actualBaseDebt,
    //       1,
    //       'bob dai base debt after'
    //     );

    //     bobDaiInfo.premiumDebt = (bobDaiInfo.baseDebt - bobDaiInfo.borrowAmount).percentMul(
    //       bobExpectedRiskPremium
    //     );
    //     assertApproxEqAbs(
    //       bobDaiInfo.premiumDebt,
    //       debtChecks.actualPremium,
    //       1,
    //       'bob dai premium debt after'
    //     );
    //     bobDaiInfo.totalDebt = bobDaiInfo.baseDebt + bobDaiInfo.premiumDebt;
    //   }

    //   // Bob's usdx debt after 1 year
    //   if (bobUsdxInfo.borrowAmount > 0) {
    //     bobUsdxInfo.baseDebt = MathUtils
    //       .calculateLinearInterest(baseRateUsdx, uint40(startTime))
    //       .rayMul(bobUsdxInfo.borrowAmount);

    //     (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
    //       usdxInfo.reserveId,
    //       bob
    //     );
    //     assertApproxEqAbs(
    //       bobUsdxInfo.baseDebt,
    //       debtChecks.actualBaseDebt,
    //       1,
    //       'bob usdx base debt after'
    //     );

    //     bobUsdxInfo.premiumDebt = (bobUsdxInfo.baseDebt - bobUsdxInfo.borrowAmount).percentMul(
    //       bobExpectedRiskPremium
    //     );
    //     assertApproxEqAbs(
    //       bobUsdxInfo.premiumDebt,
    //       debtChecks.actualPremium,
    //       1,
    //       'bob usdx premium debt after'
    //     );
    //     bobUsdxInfo.totalDebt = bobUsdxInfo.baseDebt + bobUsdxInfo.premiumDebt;
    //   }

    //   // Alice's dai debt after 1 year
    //   if (aliceDaiInfo.borrowAmount > 0) {
    //     aliceDaiInfo.baseDebt = MathUtils
    //       .calculateLinearInterest(baseRateDai, uint40(startTime))
    //       .rayMul(aliceDaiInfo.borrowAmount);

    //     (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
    //       daiInfo.reserveId,
    //       alice
    //     );
    //     assertApproxEqAbs(
    //       aliceDaiInfo.baseDebt,
    //       debtChecks.actualBaseDebt,
    //       1,
    //       'alice dai base debt after'
    //     );

    //     aliceDaiInfo.premiumDebt = (aliceDaiInfo.baseDebt - aliceDaiInfo.borrowAmount).percentMul(
    //       aliceExpectedRiskPremium
    //     );
    //     assertApproxEqAbs(
    //       aliceDaiInfo.premiumDebt,
    //       debtChecks.actualPremium,
    //       1,
    //       'alice dai premium debt after'
    //     );
    //     aliceDaiInfo.totalDebt = aliceDaiInfo.baseDebt + aliceDaiInfo.premiumDebt;
    //   }

    //   // Alice's usdx debt after 1 year
    //   if (aliceUsdxInfo.borrowAmount > 0) {
    //     aliceUsdxInfo.baseDebt = MathUtils
    //       .calculateLinearInterest(baseRateUsdx, uint40(startTime))
    //       .rayMul(aliceUsdxInfo.borrowAmount);

    //     (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
    //       usdxInfo.reserveId,
    //       alice
    //     );
    //     assertApproxEqAbs(
    //       aliceUsdxInfo.baseDebt,
    //       debtChecks.actualBaseDebt,
    //       1,
    //       'alice usdx base debt after'
    //     );

    //     aliceUsdxInfo.premiumDebt = (aliceUsdxInfo.baseDebt - aliceUsdxInfo.borrowAmount).percentMul(
    //       aliceExpectedRiskPremium
    //     );
    //     assertApproxEqAbs(
    //       aliceUsdxInfo.premiumDebt,
    //       debtChecks.actualPremium,
    //       1,
    //       'alice usdx premium debt after'
    //     );
    //     aliceUsdxInfo.totalDebt = aliceUsdxInfo.baseDebt + aliceUsdxInfo.premiumDebt;
    //   }

    //   // Check reserve debt for dai
    //   (debtChecks.reserveDebt, debtChecks.reservePremium) = spoke1.getReserveDebt(daiInfo.reserveId);

    //   // Reserve debt should be the sum of both user debts
    //   uint256 expectedDaiTotalDebt = bobDaiInfo.totalDebt + aliceDaiInfo.totalDebt;
    //   uint256 expectedDaiTotalPremium = bobDaiInfo.premiumDebt + aliceDaiInfo.premiumDebt;

    //   assertApproxEqAbs(
    //     debtChecks.reserveDebt,
    //     expectedDaiTotalDebt,
    //     2,
    //     'reserve dai base debt after accrual'
    //   );
    //   assertApproxEqAbs(
    //     debtChecks.reservePremium,
    //     expectedDaiTotalPremium,
    //     2,
    //     'reserve dai premium debt after accrual'
    //   );

    //   // Check reserve debt for usdx
    //   (debtChecks.reserveDebt, debtChecks.reservePremium) = spoke1.getReserveDebt(usdxInfo.reserveId);

    //   // Reserve debt should be the sum of both user debts
    //   uint256 expectedUsdxTotalDebt = bobUsdxInfo.totalDebt + aliceUsdxInfo.totalDebt;
    //   uint256 expectedUsdxTotalPremium = bobUsdxInfo.premiumDebt + aliceUsdxInfo.premiumDebt;

    //   assertApproxEqAbs(
    //     debtChecks.reserveDebt,
    //     expectedUsdxTotalDebt,
    //     2,
    //     'reserve usdx base debt after accrual'
    //   );
    //   assertApproxEqAbs(
    //     debtChecks.reservePremium,
    //     expectedUsdxTotalPremium,
    //     2,
    //     'reserve usdx premium debt after accrual'
    //   );

    //   // Verify spoke debts on hub for dai
    //   (debtChecks.spokeDebt, debtChecks.spokePremium) = hub.getSpokeDebt(daiAssetId, address(spoke1));
    //   assertApproxEqAbs(
    //     debtChecks.spokeDebt,
    //     expectedDaiTotalDebt,
    //     2,
    //     'hub spoke dai base debt after accrual'
    //   );
    //   assertApproxEqAbs(
    //     debtChecks.spokePremium,
    //     expectedDaiTotalPremium,
    //     2,
    //     'hub spoke dai premium debt after accrual'
    //   );

    //   // Verify spoke debts on hub for usdx
    //   (debtChecks.spokeDebt, debtChecks.spokePremium) = hub.getSpokeDebt(
    //     usdxAssetId,
    //     address(spoke1)
    //   );
    //   assertApproxEqAbs(
    //     debtChecks.spokeDebt,
    //     expectedUsdxTotalDebt,
    //     2,
    //     'hub spoke usdx base debt after accrual'
    //   );
    //   assertApproxEqAbs(
    //     debtChecks.spokePremium,
    //     expectedUsdxTotalPremium,
    //     2,
    //     'hub spoke usdx premium debt after accrual'
    //   );

    //   // Verify asset debts on hub
    //   (debtChecks.assetDebt, debtChecks.assetPremium) = hub.getAssetDebt(daiAssetId);
    //   assertApproxEqAbs(
    //     debtChecks.assetDebt,
    //     expectedDaiTotalDebt,
    //     2,
    //     'hub asset dai base debt after accrual'
    //   );
    //   assertApproxEqAbs(
    //     debtChecks.assetPremium,
    //     expectedDaiTotalPremium,
    //     2,
    //     'hub asset dai premium debt after accrual'
    //   );

    //   (debtChecks.assetDebt, debtChecks.assetPremium) = hub.getAssetDebt(usdxAssetId);
    //   assertApproxEqAbs(
    //     debtChecks.assetDebt,
    //     expectedUsdxTotalDebt,
    //     2,
    //     'hub asset usdx base debt after accrual'
    //   );
    //   assertApproxEqAbs(
    //     debtChecks.assetPremium,
    //     expectedUsdxTotalPremium,
    //     2,
    //     'hub asset usdx premium debt after accrual'
    //   );

    //   // Skip time before Bob repay
    //   skip(secondTimeSkip);

    //   // Bob repay half dai debt
    //   if (bobDaiInfo.borrowAmount > 2) {
    //     uint256 repayAmount = (bobDaiInfo.baseDebt + bobDaiInfo.premiumDebt) / 2;
    //     Utils.repay(spoke1, daiInfo.reserveId, bob, repayAmount);

    //     // Bob's risk premium should change
    //     uint256 newBobRiskPremium = _calculateExpectedUserRP(bob, spoke1);

    //     // Verify his new risk premium
    //     assertEq(spoke1.getUserRiskPremium(bob), newBobRiskPremium, 'bob risk premium after repay');

    //     // Alice's risk premium should remain unchanged
    //     assertEq(
    //       spoke1.getUserRiskPremium(alice),
    //       aliceExpectedRiskPremium,
    //       'alice risk premium after bob repay'
    //     );

    //     // Get updated debts since time skip
    //     uint40 secondAccrualTime = uint40(startTime) + timeSkip;
    //     uint256 additionalBaseDebt = MathUtils
    //       .calculateLinearInterest(baseRateDai, secondAccrualTime)
    //       .rayMul(bobDaiInfo.baseDebt) - bobDaiInfo.baseDebt;

    //     uint256 updatedBobBaseDebt = bobDaiInfo.baseDebt + additionalBaseDebt;
    //     uint256 updatedBobPremiumDebt = bobDaiInfo.premiumDebt +
    //       additionalBaseDebt.percentMul(bobExpectedRiskPremium);

    //     // Check Bob's updated dai debt
    //     (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
    //       daiInfo.reserveId,
    //       bob
    //     );

    //     // Premium debt is repaid first
    //     uint256 remainingRepay = repayAmount;
    //     uint256 newBobPremiumDebt = 0;
    //     if (remainingRepay <= updatedBobPremiumDebt) {
    //       newBobPremiumDebt = updatedBobPremiumDebt - remainingRepay;
    //       remainingRepay = 0;
    //     } else {
    //       remainingRepay -= updatedBobPremiumDebt;
    //     }

    //     uint256 newBobBaseDebt = remainingRepay >= updatedBobBaseDebt
    //       ? 0
    //       : updatedBobBaseDebt - remainingRepay;

    //     assertApproxEqAbs(
    //       debtChecks.actualBaseDebt,
    //       newBobBaseDebt,
    //       2,
    //       'bob dai base debt after repay'
    //     );
    //     assertApproxEqAbs(
    //       debtChecks.actualPremium,
    //       newBobPremiumDebt,
    //       2,
    //       'bob dai premium debt after repay'
    //     );
    //   }

    //   // Similar check for Alice but increasing her debt
    //   if (
    //     aliceUsdxInfo.borrowAmount > 0 && aliceUsdxInfo.supplyAmount > aliceUsdxInfo.borrowAmount * 2
    //   ) {
    //     // Alice increases her USDX borrow by 50%
    //     uint256 additionalBorrow = aliceUsdxInfo.borrowAmount / 2;
    //     Utils.borrow(spoke1, usdxInfo.reserveId, alice, additionalBorrow, alice);

    //     // Alice's risk premium should change
    //     uint256 newAliceRiskPremium = _calculateExpectedUserRP(alice, spoke1);

    //     // Verify her new risk premium
    //     assertEq(
    //       spoke1.getUserRiskPremium(alice),
    //       newAliceRiskPremium,
    //       'alice risk premium after borrow'
    //     );

    //     // Verify Bob's risk premium remains the same
    //     assertEq(
    //       spoke1.getUserRiskPremium(bob),
    //       spoke1.getUserRiskPremium(bob),
    //       'bob risk premium after alice borrow'
    //     );

    //     // Check Alice's updated usdx debt
    //     (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
    //       usdxInfo.reserveId,
    //       alice
    //     );

    //     // Account for additional interest during second time skip
    //     uint256 secondAccrualTime = uint40(startTime + timeSkip);
    //     uint256 additionalBaseDebt = MathUtils
    //       .calculateLinearInterest(baseRateUsdx, uint40(secondAccrualTime))
    //       .rayMul(aliceUsdxInfo.baseDebt) - aliceUsdxInfo.baseDebt;

    //     // Base debt increases by the additional borrow plus accrued interest
    //     uint256 newAliceBaseDebt = aliceUsdxInfo.baseDebt + additionalBaseDebt + additionalBorrow;
    //     // Premium debt includes accrued interest from time skip
    //     uint256 newAlicePremiumDebt = aliceUsdxInfo.premiumDebt +
    //       additionalBaseDebt.percentMul(aliceExpectedRiskPremium);

    //     assertApproxEqAbs(
    //       debtChecks.actualBaseDebt,
    //       newAliceBaseDebt,
    //       2,
    //       'alice usdx base debt after additional borrow'
    //     );
    //     assertApproxEqAbs(
    //       debtChecks.actualPremium,
    //       newAlicePremiumDebt,
    //       2,
    //       'alice usdx premium debt after additional borrow'
    //     );
    //   }

    //   // Skip time to accrue interest
    //   skip(thirdTimeSkip);

    //   // Final verification of risk premiums after all changes
    //   uint256 finalBobRiskPremium = _calculateExpectedUserRP(bob, spoke1);
    //   uint256 finalAliceRiskPremium = _calculateExpectedUserRP(alice, spoke1);

    //   assertEq(spoke1.getUserRiskPremium(bob), finalBobRiskPremium, 'bob final risk premium');
    //   assertEq(spoke1.getUserRiskPremium(alice), finalAliceRiskPremium, 'alice final risk premium');

    //   // Verify final reserve states and hub propagation for both assets
    //   (debtChecks.reserveDebt, debtChecks.reservePremium) = spoke1.getReserveDebt(daiInfo.reserveId);
    //   (debtChecks.spokeDebt, debtChecks.spokePremium) = hub.getSpokeDebt(daiAssetId, address(spoke1));
    //   (debtChecks.assetDebt, debtChecks.assetPremium) = hub.getAssetDebt(daiAssetId);

    //   // All three levels should have the same debt values
    //   assertEq(
    //     debtChecks.reserveDebt,
    //     debtChecks.spokeDebt,
    //     'dai base debt consistency reserve-spoke'
    //   );
    //   assertEq(debtChecks.spokeDebt, debtChecks.assetDebt, 'dai base debt consistency spoke-asset');
    //   assertEq(
    //     debtChecks.reservePremium,
    //     debtChecks.spokePremium,
    //     'dai premium debt consistency reserve-spoke'
    //   );
    //   assertEq(
    //     debtChecks.spokePremium,
    //     debtChecks.assetPremium,
    //     'dai premium debt consistency spoke-asset'
    //   );

    //   (debtChecks.reserveDebt, debtChecks.reservePremium) = spoke1.getReserveDebt(usdxInfo.reserveId);
    //   (debtChecks.spokeDebt, debtChecks.spokePremium) = hub.getSpokeDebt(
    //     usdxAssetId,
    //     address(spoke1)
    //   );
    //   (debtChecks.assetDebt, debtChecks.assetPremium) = hub.getAssetDebt(usdxAssetId);

    //   // All three levels should have the same debt values
    //   assertEq(
    //     debtChecks.reserveDebt,
    //     debtChecks.spokeDebt,
    //     'usdx base debt consistency reserve-spoke'
    //   );
    //   assertEq(debtChecks.spokeDebt, debtChecks.assetDebt, 'usdx base debt consistency spoke-asset');
    //   assertEq(
    //     debtChecks.reservePremium,
    //     debtChecks.spokePremium,
    //     'usdx premium debt consistency reserve-spoke'
    //   );
    //   assertEq(
    //     debtChecks.spokePremium,
    //     debtChecks.assetPremium,
    //     'usdx premium debt consistency spoke-asset'
    //   );
  }
}
