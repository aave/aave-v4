// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRiskPremiumTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  struct ReserveInfoLocal {
    uint256 reserveId;
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 price;
    uint256 collateralRisk;
    uint256 riskPremium;
  }

  struct DebtChecks {
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 actualDrawnDebt;
    uint256 actualPremium;
    uint256 reserveDebt;
    uint256 reservePremium;
    uint256 spokeOwed;
    uint256 spokePremium;
    uint256 assetOwed;
    uint256 assetPremium;
  }

  /// With no collateral supplied, user risk premium is 0.
  function test_getUserRiskPremium_no_collateral() public view {
    // Assert Bob has no collateral
    for (uint256 reserveId = 0; reserveId < spoke1.getReserveCount(); reserveId++) {
      DataTypes.UserPosition memory bobInfo = getUserInfo(spoke1, bob, reserveId);
      assertEq(bobInfo.suppliedShares, 0, 'bob supplied collateral');
    }
    assertEq(spoke1.getUserRiskPremium(bob), 0, 'user risk premium');
  }

  /// Without a collateral set, user risk premium is 0.
  function test_getUserRiskPremium_no_collateral_set() public {
    Utils.supply(spoke1, _daiReserveId(spoke1), bob, 100e18, bob);
    // Assert Bob has no collateral set
    for (uint256 reserveId = 0; reserveId < spoke1.getReserveCount(); reserveId++) {
      assertEq(spoke1.isUsingAsCollateral(reserveId, bob), false, 'bob collateral set');
    }
    // Bob doesn't set dai as collateral, despite supplying, so his user rp is 0
    assertEq(spoke1.getUserRiskPremium(bob), 0, 'user risk premium');
  }

  /// Without a draw, user risk premium is 0.
  function test_getUserRiskPremium_single_reserve_collateral() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 daiAmount = 100e18;

    // Bob supply dai into spoke1
    Utils.supplyCollateral(spoke1, daiReserveId, bob, daiAmount, bob);

    assertEq(spoke1.getUserRiskPremium(bob), 0, 'user risk premium');
  }

  /// When supplying and borrowing one reserve, user risk premium matches the collateral risk of that reserve.
  function test_getUserRiskPremium_single_reserve_collateral_borrowed() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 supplyAmount = 100e18;
    uint256 borrowAmount = 50e18;

    // Bob supply dai into spoke1
    Utils.supplyCollateral(spoke1, daiReserveId, bob, supplyAmount, bob);
    Utils.borrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    DataTypes.Reserve memory daiInfo = getReserveInfo(spoke1, daiReserveId);

    // With single collateral, user rp will match collateral risk of collateral
    assertEq(userRiskPremium, daiInfo.config.collateralRisk, 'user risk premium');
  }

  /// When supplying and borrowing one reserve (fuzzed amounts), user risk premium matches the collateral risk of that reserve.
  function test_getUserRiskPremium_fuzz_single_reserve_collateral_borrowed_amount(
    uint256 borrowAmount
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    ReserveInfoLocal memory daiInfo;
    daiInfo.reserveId = _daiReserveId(spoke1);
    daiInfo.borrowAmount = borrowAmount;
    daiInfo.supplyAmount = borrowAmount * 2;

    daiInfo.collateralRisk = _getCollateralRisk(spoke1, daiInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supplyCollateral(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    Utils.borrow(spoke1, daiInfo.reserveId, bob, daiInfo.borrowAmount, bob);

    // With single collateral, user rp will match collateral risk of collateral
    assertEq(spoke1.getUserRiskPremium(bob), daiInfo.collateralRisk, 'user risk premium');
  }

  // TODO: Test the under-collateralized case where borrowed > supplied

  /// When supplying and borrowing one reserve each, user risk premium matches the collateral risk of the collateral.
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

    daiInfo.collateralRisk = _getCollateralRisk(spoke1, daiInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supplyCollateral(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);

    // Bob draw dai
    Utils.borrow(spoke1, daiInfo.reserveId, bob, daiInfo.borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);

    // With single collateral, user rp will match collateral risk of collateral
    assertEq(userRiskPremium, daiInfo.collateralRisk, 'user risk premium');

    // Supplying more risky reserve (usdx) should not impact user risk premium
    Utils.supplyCollateral(spoke1, usdxInfo.reserveId, bob, additionalSupplyAmount, bob);
    assertEq(spoke1.getUserRiskPremium(bob), userRiskPremium, 'user risk premium after supply');
  }

  // Supply multiple collaterals, and borrow one reserve. Then change the price of debt reserve such that collaterals are insufficient to cover the debt
  // User rp should be weighted sum of the collaterals
  function test_riskPremium_collateral_insufficient_to_cover_debt() public {
    uint256 wbtcSupplyAmount = 1e8;
    uint256 daiSupplyAmount = 1000e18;
    uint256 usdxSupplyAmount = 1000e6;
    uint256 wethSupplyAmount = 1e18;
    uint256 borrowAmount = 10000e18;

    // Deploy liquidity to borrow
    _openSupplyPosition(spoke2, _dai2ReserveId(spoke2), borrowAmount);

    // Bob supplies collaterals
    Utils.supplyCollateral(spoke2, _wbtcReserveId(spoke2), bob, wbtcSupplyAmount, bob);
    Utils.supplyCollateral(spoke2, _daiReserveId(spoke2), bob, daiSupplyAmount, bob);
    Utils.supplyCollateral(spoke2, _usdxReserveId(spoke2), bob, usdxSupplyAmount, bob);
    Utils.supplyCollateral(spoke2, _wethReserveId(spoke2), bob, wethSupplyAmount, bob);

    // Bob borrows dai2
    Utils.borrow(spoke2, _dai2ReserveId(spoke2), bob, borrowAmount, bob);

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );

    // Change the price of dai2 via mock call
    _mockReservePrice(spoke2, _dai2ReserveId(spoke2), 100000e8);

    // Check that debt has outgrown collateral
    uint256 collateralValue = _getValueInBaseCurrency(
      spoke2,
      _wbtcReserveId(spoke2),
      wbtcSupplyAmount
    ) +
      _getValueInBaseCurrency(spoke2, _daiReserveId(spoke2), daiSupplyAmount) +
      _getValueInBaseCurrency(spoke2, _usdxReserveId(spoke2), usdxSupplyAmount) +
      _getValueInBaseCurrency(spoke2, _wethReserveId(spoke2), wethSupplyAmount);
    uint256 debtValue = _getValueInBaseCurrency(spoke2, _dai2ReserveId(spoke2), borrowAmount);
    assertGt(debtValue, collateralValue, 'debt outgrows collateral');

    // Now user rp should be weighted sum of the collaterals
    uint256 expectedRiskPremium = (_getValueInBaseCurrency(
      spoke2,
      _daiReserveId(spoke2),
      daiSupplyAmount
    ) *
      _getCollateralRisk(spoke2, _daiReserveId(spoke2)) +
      _getValueInBaseCurrency(spoke2, _usdxReserveId(spoke2), usdxSupplyAmount) *
      _getCollateralRisk(spoke2, _usdxReserveId(spoke2)) +
      _getValueInBaseCurrency(spoke2, _wbtcReserveId(spoke2), wbtcSupplyAmount) *
      _getCollateralRisk(spoke2, _wbtcReserveId(spoke2)) +
      _getValueInBaseCurrency(spoke2, _wethReserveId(spoke2), wethSupplyAmount) *
      _getCollateralRisk(spoke2, _wethReserveId(spoke2))) / collateralValue;
    assertEq(
      spoke2.getUserRiskPremium(bob),
      expectedRiskPremium,
      'user risk premium matches weighted sum of collaterals'
    );
  }

  /// After each spoke action, calculated and stored user RP should remain the same
  function test_riskPremium_postActions() public {
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, 1000e18, alice);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 1000e18, bob);
    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), bob, 1000e6, bob);

    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 500e18, bob);
    _assertUserRpUnchanged(_daiReserveId(spoke1), spoke1, bob);
    Utils.borrow(spoke1, _usdxReserveId(spoke1), bob, 750e6, bob);
    _assertUserRpUnchanged(_usdxReserveId(spoke1), spoke1, bob);

    skip(123 days);

    Utils.withdraw(spoke1, _daiReserveId(spoke1), bob, 0.01e18, bob);
    _assertUserRpUnchanged(_daiReserveId(spoke1), spoke1, bob);
    _assertUserRpUnchanged(_usdxReserveId(spoke1), spoke1, bob);

    Utils.withdraw(spoke1, _usdxReserveId(spoke1), bob, 0.01e6, bob);
    _assertUserRpUnchanged(_daiReserveId(spoke1), spoke1, bob);
    _assertUserRpUnchanged(_usdxReserveId(spoke1), spoke1, bob);

    skip(232 days);

    Utils.repay(spoke1, _daiReserveId(spoke1), bob, 25e18, bob);
    _assertUserRpUnchanged(_daiReserveId(spoke1), spoke1, bob);
    _assertUserRpUnchanged(_usdxReserveId(spoke1), spoke1, bob);
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

    daiInfo.collateralRisk = _getCollateralRisk(spoke1, daiInfo.reserveId);
    usdxInfo.collateralRisk = _getCollateralRisk(spoke1, usdxInfo.reserveId);
    wethInfo.collateralRisk = _getCollateralRisk(spoke1, wethInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supplyCollateral(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);

    // Bob supply usdx into spoke1
    Utils.supplyCollateral(spoke1, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);

    // Bob supply weth into spoke1
    Utils.supplyCollateral(spoke1, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);

    // Bob draw dai + usdx
    Utils.borrow(spoke1, daiInfo.reserveId, bob, daiInfo.borrowAmount, bob);
    Utils.borrow(spoke1, usdxInfo.reserveId, bob, usdxInfo.borrowAmount, bob);

    // Weth is enough to cover the total debt
    assertGe(
      _getValueInBaseCurrency(spoke1, wethInfo.reserveId, wethInfo.supplyAmount),
      _getValueInBaseCurrency(spoke1, daiInfo.reserveId, daiInfo.borrowAmount) +
        _getValueInBaseCurrency(spoke1, usdxInfo.reserveId, usdxInfo.borrowAmount),
      'weth supply covers debt'
    );
    uint256 expectedUserRiskPremium = wethInfo.collateralRisk;
    assertEq(spoke1.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');
  }

  /// Supply a high collateral-risk reserve which fully covers debt, but also supply lower collateral-risk reserves
  /// Assert that user rp should be less than the high collateral-risk reserve
  function test_getUserRiskPremium_multi_reserve_collateral_lower_rp_than_highest_cr() public {
    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory dai2Info;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wethInfo;

    daiInfo.reserveId = _daiReserveId(spoke2);
    dai2Info.reserveId = _dai2ReserveId(spoke2);
    usdxInfo.reserveId = _usdxReserveId(spoke2);
    wethInfo.reserveId = _wethReserveId(spoke2);

    daiInfo.supplyAmount = 1000e18;
    dai2Info.supplyAmount = 10000e18;
    usdxInfo.supplyAmount = 1000e6;
    wethInfo.supplyAmount = 1000e18;
    daiInfo.borrowAmount = 10000e18;

    // Supply the remaining liquidity desired to borrow
    _openSupplyPosition(spoke2, daiInfo.reserveId, daiInfo.borrowAmount - daiInfo.supplyAmount);

    // Bob supply dai into spoke2
    Utils.supplyCollateral(spoke2, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);

    // Bob supply dai2 into spoke2
    Utils.supplyCollateral(spoke2, dai2Info.reserveId, bob, dai2Info.supplyAmount, bob);

    // Bob supply usdx into spoke2
    Utils.supplyCollateral(spoke2, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);

    // Bob supply weth into spoke2
    Utils.supplyCollateral(spoke2, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);

    // Bob draw dai + usdx
    Utils.borrow(spoke2, daiInfo.reserveId, bob, daiInfo.borrowAmount, bob);

    // Dai2 is enough to cover the total debt
    assertGe(
      _getValueInBaseCurrency(spoke2, dai2Info.reserveId, dai2Info.supplyAmount),
      _getValueInBaseCurrency(spoke2, daiInfo.reserveId, daiInfo.borrowAmount),
      'dai2 supply covers debt'
    );

    // User risk premium is less than the collateral risk of the highest collateral-risk reserve
    uint256 expectedUserRiskPremium = _calculateExpectedUserRP(bob, spoke2);
    assertLt(
      expectedUserRiskPremium,
      _getCollateralRisk(spoke2, dai2Info.reserveId),
      'user risk premium is less than highest collateral-risk reserve'
    );
    assertEq(spoke2.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');
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

    daiInfo.collateralRisk = _getCollateralRisk(spoke1, daiInfo.reserveId);
    usdxInfo.collateralRisk = _getCollateralRisk(spoke1, usdxInfo.reserveId);
    wethInfo.collateralRisk = _getCollateralRisk(spoke1, wethInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supplyCollateral(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);

    // Bob supply usdx into spoke1
    Utils.supplyCollateral(spoke1, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);

    // Bob supply weth into spoke1
    Utils.supplyCollateral(spoke1, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);

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

    daiInfo.collateralRisk = _getCollateralRisk(spoke1, daiInfo.reserveId);
    usdxInfo.collateralRisk = _getCollateralRisk(spoke1, usdxInfo.reserveId);
    wethInfo.collateralRisk = _getCollateralRisk(spoke1, wethInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supplyCollateral(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);

    // Bob supply usdx into spoke1
    Utils.supplyCollateral(spoke1, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);

    // Alice supply weth into spoke1
    Utils.supplyCollateral(spoke1, wethInfo.reserveId, alice, wethInfo.supplyAmount, alice);

    // Bob draw weth
    Utils.borrow(spoke1, wethInfo.reserveId, bob, wethInfo.borrowAmount, bob);

    // Dai and usdx will each cover half the debt, because dai has lower collateral risk than usdx
    uint256 expectedRiskPremium = _calculateExpectedUserRP(bob, spoke1);
    assertEq(
      expectedRiskPremium,
      (daiInfo.collateralRisk + usdxInfo.collateralRisk) / 2,
      'user risk premium'
    );
    assertEq(spoke1.getUserRiskPremium(bob), expectedRiskPremium, 'user risk premium');
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

    daiInfo.collateralRisk = _getCollateralRisk(spoke3, daiInfo.reserveId);
    wethInfo.collateralRisk = _getCollateralRisk(spoke3, wethInfo.reserveId);
    usdxInfo.collateralRisk = _getCollateralRisk(spoke3, usdxInfo.reserveId);

    // Bob supply dai into spoke3
    if (daiInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    }

    // Bob supply weth into spoke3
    Utils.supplyCollateral(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);

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

    daiInfo.collateralRisk = _getCollateralRisk(spoke3, daiInfo.reserveId);
    wethInfo.collateralRisk = _getCollateralRisk(spoke3, wethInfo.reserveId);
    usdxInfo.collateralRisk = _getCollateralRisk(spoke3, usdxInfo.reserveId);

    // Bob supply dai into spoke3
    if (daiInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    }

    // Bob supply weth into spoke3
    if (wethInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    }

    // Bob supply wbtc into spoke3
    Utils.supplyCollateral(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);

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

    daiInfo.collateralRisk = _getCollateralRisk(spoke2, daiInfo.reserveId);
    wethInfo.collateralRisk = _getCollateralRisk(spoke2, wethInfo.reserveId);
    usdxInfo.collateralRisk = _getCollateralRisk(spoke2, usdxInfo.reserveId);
    wbtcInfo.collateralRisk = _getCollateralRisk(spoke2, wbtcInfo.reserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (wbtcInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    }

    // Bob supply dai into spoke2
    if (daiInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    }

    // Bob supply dai2 into spoke2
    Utils.supplyCollateral(spoke2, dai2Info.reserveId, bob, MAX_SUPPLY_AMOUNT, bob);

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

    newUsdxPrice = bound(newUsdxPrice, 1, 1e16);

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

    daiInfo.collateralRisk = _getCollateralRisk(spoke2, daiInfo.reserveId);
    wethInfo.collateralRisk = _getCollateralRisk(spoke2, wethInfo.reserveId);
    usdxInfo.collateralRisk = _getCollateralRisk(spoke2, usdxInfo.reserveId);
    wbtcInfo.collateralRisk = _getCollateralRisk(spoke2, wbtcInfo.reserveId);
    dai2Info.collateralRisk = _getCollateralRisk(spoke2, dai2Info.reserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (wbtcInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    }

    // Bob supply dai into spoke2
    if (daiInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    }

    // Bob supply dai2 into spoke2
    Utils.supplyCollateral(spoke2, dai2Info.reserveId, bob, dai2Info.supplyAmount, bob);

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
    _mockReservePrice(spoke2, _usdxReserveId(spoke2), newUsdxPrice);

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium after price change'
    );
  }

  /// Supply 4 reserves and borrow one. Change collateral risk of a reserve, and check user risk premium calc.
  function test_getUserRiskPremium_fuzz_four_reserves_change_cr(
    uint256 daiSupplyAmount,
    uint256 wethSupplyAmount,
    uint256 usdxSupplyAmount,
    uint256 wbtcSupplyAmount,
    uint256 borrowAmount,
    uint256 newCrValue
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;

    // Bound collateral risk to below dai2 so reserve is still used in rp calc
    newCrValue = bound(newCrValue, 0, 99_99);

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

    daiInfo.collateralRisk = _getCollateralRisk(spoke2, daiInfo.reserveId);
    wethInfo.collateralRisk = _getCollateralRisk(spoke2, wethInfo.reserveId);
    usdxInfo.collateralRisk = _getCollateralRisk(spoke2, usdxInfo.reserveId);
    wbtcInfo.collateralRisk = _getCollateralRisk(spoke2, wbtcInfo.reserveId);
    dai2Info.collateralRisk = _getCollateralRisk(spoke2, dai2Info.reserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (wbtcInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    }

    // Bob supply dai into spoke2
    if (daiInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    }

    // Bob supply dai2 into spoke2
    Utils.supplyCollateral(spoke2, dai2Info.reserveId, bob, dai2Info.supplyAmount, bob);

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

    // Change the collateral risk of wbtc
    updateCollateralRisk(spoke2, wbtcInfo.reserveId, newCrValue);

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );
  }

  /// Bob supplies and borrows varying amounts of 4 reserves.
  /// We update prices and reserve collateral risks, then ensure risk premium is calculated correctly.
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

    daiInfo.price = bound(daiInfo.price, 1, 1e16);
    wethInfo.price = bound(wethInfo.price, 1, 1e16);
    usdxInfo.price = bound(usdxInfo.price, 1, 1e16);
    wbtcInfo.price = bound(wbtcInfo.price, 1, 1e16);

    daiInfo.collateralRisk = bound(daiInfo.collateralRisk, 0, 1000_00);
    wethInfo.collateralRisk = bound(wethInfo.collateralRisk, 0, 1000_00);
    usdxInfo.collateralRisk = bound(usdxInfo.collateralRisk, 0, 1000_00);
    wbtcInfo.collateralRisk = bound(wbtcInfo.collateralRisk, 0, 1000_00);

    // Bob supply dai into spoke2
    if (daiInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, _daiReserveId(spoke2), bob, daiInfo.supplyAmount, bob);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, _wethReserveId(spoke2), bob, wethInfo.supplyAmount, bob);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, _usdxReserveId(spoke2), bob, usdxInfo.supplyAmount, bob);
    }

    // Bob supply wbtc into spoke2
    if (wbtcInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke2, _wbtcReserveId(spoke2), bob, wbtcInfo.supplyAmount, bob);
    }

    // Update prices
    _mockReservePrice(spoke2, _daiReserveId(spoke2), daiInfo.price);
    _mockReservePrice(spoke2, _wethReserveId(spoke2), wethInfo.price);
    _mockReservePrice(spoke2, _usdxReserveId(spoke2), usdxInfo.price);
    _mockReservePrice(spoke2, _wbtcReserveId(spoke2), wbtcInfo.price);

    // Update reserves' collateral risk
    updateCollateralRisk(spoke2, _daiReserveId(spoke2), daiInfo.collateralRisk);
    updateCollateralRisk(spoke2, _wethReserveId(spoke2), wethInfo.collateralRisk);
    updateCollateralRisk(spoke2, _usdxReserveId(spoke2), usdxInfo.collateralRisk);
    updateCollateralRisk(spoke2, _wbtcReserveId(spoke2), wbtcInfo.collateralRisk);

    // Check user risk premium
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );
  }

  /// Bob supplies varying amounts of dai, weth, and usdx, and max wbtc; borrows wbtc.
  /// We check Bob's risk premium and interest accrual are calculated correctly and accounting percolates through hub1.
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

    daiInfo.collateralRisk = _getCollateralRisk(spoke3, daiInfo.reserveId);
    wethInfo.collateralRisk = _getCollateralRisk(spoke3, wethInfo.reserveId);
    usdxInfo.collateralRisk = _getCollateralRisk(spoke3, usdxInfo.reserveId);

    // Bob supply dai into spoke3
    if (daiInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    }

    // Bob supply weth into spoke3
    if (wethInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    }

    // Bob supply wbtc into spoke3
    Utils.supplyCollateral(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);

    // Bob draw wbtc
    if (wbtcInfo.borrowAmount > 0) {
      Utils.borrow(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.borrowAmount, bob);
    }

    // Dai, usdx, and weth will each cover part of the debt
    uint256 expectedUserRiskPremium = _calculateExpectedUserRP(bob, spoke3);

    assertEq(spoke3.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');

    // Get the base rate of wbtc
    uint256 baseRate = hub1.getAssetDrawnRate(wbtcAssetId);
    uint256 drawnDebt = wbtcInfo.borrowAmount;
    (uint256 actualDrawnDebt, uint256 actualPremium) = spoke3.getUserDebt(wbtcInfo.reserveId, bob);
    uint40 startTime = uint40(vm.getBlockTimestamp());

    assertEq(drawnDebt, actualDrawnDebt, 'user drawn debt');
    assertEq(actualPremium, 0, 'user premium debt');

    // Wait a year
    skip(365 days);

    // Ensure the calculated risk premium would match
    assertEq(
      spoke3.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke3),
      'bob risk premium after time skip'
    );

    // See if drawn debt of wbtc changes appropriately
    drawnDebt = MathUtils.calculateLinearInterest(baseRate, startTime).rayMulUp(drawnDebt);
    (actualDrawnDebt, actualPremium) = spoke3.getUserDebt(wbtcInfo.reserveId, bob);
    assertEq(drawnDebt, actualDrawnDebt, 'user drawn debt');

    // See if premium debt changes proportionally to user risk premium change
    uint256 premiumDebt = (drawnDebt - wbtcInfo.borrowAmount).percentMulUp(expectedUserRiskPremium);
    assertApproxEqAbs(premiumDebt, actualPremium, 1, 'user premium debt after interest accrual');

    // Since Bob is only user, reserve debt should be equal to user debt
    (uint256 reserveDebt, uint256 reservePremium) = spoke3.getReserveDebt(wbtcInfo.reserveId);
    assertEq(reserveDebt, drawnDebt, 'reserve drawn debt');
    assertApproxEqAbs(reservePremium, premiumDebt, 1, 'reserve premium debt');

    // See if values are reflected on hub side as well
    (uint256 spokeOwed, uint256 spokePremium) = hub1.getSpokeOwed(wbtcAssetId, address(spoke3));
    assertEq(spokeOwed, drawnDebt, 'hub spoke drawn debt');
    assertApproxEqAbs(spokePremium, premiumDebt, 1, 'hub spoke premium debt');

    (uint256 assetOwed, uint256 assetPremium) = hub1.getAssetOwed(wbtcAssetId);
    assertEq(assetOwed, drawnDebt, 'hub asset drawn debt');
    assertApproxEqAbs(assetPremium, premiumDebt, 1, 'hub asset premium debt');
  }

  /// Bob supplies varying amounts of dai, weth, usdx, and max wbtc, then borrows varying wbtc and weth amounts.
  /// We check interest is updated properly after 1 year, and accounting percolates up through hub1.
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

    daiInfo.collateralRisk = _getCollateralRisk(spoke3, daiInfo.reserveId);
    wethInfo.collateralRisk = _getCollateralRisk(spoke3, wethInfo.reserveId);
    usdxInfo.collateralRisk = _getCollateralRisk(spoke3, usdxInfo.reserveId);

    // Bob supply dai into spoke3
    if (daiInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    }

    // Bob supply weth into spoke3
    if (wethInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.supplyCollateral(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    }

    // Bob supply wbtc into spoke3
    Utils.supplyCollateral(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);

    // Alice supply remaining weth into spoke3
    if (MAX_SUPPLY_AMOUNT - wethInfo.supplyAmount > 0) {
      _openSupplyPosition(spoke3, wethInfo.reserveId, MAX_SUPPLY_AMOUNT - wethInfo.supplyAmount);
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
    uint256 baseRateWbtc = hub1.getAssetDrawnRate(wbtcAssetId);
    (debtChecks.actualDrawnDebt, debtChecks.actualPremium) = spoke3.getUserDebt(
      wbtcInfo.reserveId,
      bob
    );
    uint256 startTime = vm.getBlockTimestamp();

    assertEq(wbtcInfo.borrowAmount, debtChecks.actualDrawnDebt, 'user drawn debt');
    assertEq(debtChecks.actualPremium, 0, 'user premium debt');

    // Get the base rate of weth
    uint256 baseRateWeth = hub1.getAssetDrawnRate(wethAssetId);
    (debtChecks.actualDrawnDebt, debtChecks.actualPremium) = spoke3.getUserDebt(
      wethInfo.reserveId,
      bob
    );

    assertEq(wethInfo.borrowAmount, debtChecks.actualDrawnDebt, 'user drawn debt');
    assertEq(debtChecks.actualPremium, 0, 'user premium debt');

    // Wait a year
    skip(365 days);

    // Ensure the calculated risk premium would match
    assertEq(
      spoke3.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke3),
      'bob risk premium after time skip'
    );

    // See if drawn debt of wbtc changes appropriately
    debtChecks.drawnDebt = MathUtils
      .calculateLinearInterest(baseRateWbtc, uint40(startTime))
      .rayMulUp(wbtcInfo.borrowAmount);
    (debtChecks.actualDrawnDebt, debtChecks.actualPremium) = spoke3.getUserDebt(
      wbtcInfo.reserveId,
      bob
    );
    assertEq(debtChecks.drawnDebt, debtChecks.actualDrawnDebt, 'user drawn debt');

    // See if premium debt changes proportionally to user risk premium
    debtChecks.premiumDebt = (debtChecks.drawnDebt - wbtcInfo.borrowAmount).percentMulUp(
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
    assertEq(debtChecks.reserveDebt, debtChecks.drawnDebt, 'reserve drawn debt after accrual');
    assertApproxEqAbs(
      debtChecks.reservePremium,
      debtChecks.premiumDebt,
      1,
      'reserve premium debt after accrual'
    );

    // See if values are reflected on hub side as well
    (debtChecks.spokeOwed, debtChecks.spokePremium) = hub1.getSpokeOwed(
      wbtcAssetId,
      address(spoke3)
    );
    assertEq(debtChecks.spokeOwed, debtChecks.drawnDebt, 'hub spoke drawn debt after accrual');
    assertApproxEqAbs(
      debtChecks.spokePremium,
      debtChecks.premiumDebt,
      1,
      'hub spoke premium debt after accrual'
    );

    (debtChecks.assetOwed, debtChecks.assetPremium) = hub1.getAssetOwed(wbtcAssetId);
    assertEq(debtChecks.assetOwed, debtChecks.drawnDebt, 'hub asset drawn debt after accrual');
    assertApproxEqAbs(
      debtChecks.assetPremium,
      debtChecks.premiumDebt,
      1,
      'hub asset premium debt after accrual'
    );

    // See if drawn debt of weth changes appropriately
    debtChecks.drawnDebt = MathUtils
      .calculateLinearInterest(baseRateWeth, uint40(startTime))
      .rayMulUp(wethInfo.borrowAmount);
    (debtChecks.actualDrawnDebt, debtChecks.actualPremium) = spoke3.getUserDebt(
      wethInfo.reserveId,
      bob
    );
    assertEq(debtChecks.drawnDebt, debtChecks.actualDrawnDebt, 'user drawn debt');

    // See if premium debt changes proportionally to user risk premium
    debtChecks.premiumDebt = (debtChecks.drawnDebt - wethInfo.borrowAmount).percentMulUp(
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
    assertEq(debtChecks.reserveDebt, debtChecks.drawnDebt, 'reserve drawn debt after accrual');
    assertApproxEqAbs(
      debtChecks.reservePremium,
      debtChecks.premiumDebt,
      1,
      'reserve premium debt after accrual'
    );

    // See if values are reflected on hub side as well
    (debtChecks.spokeOwed, debtChecks.spokePremium) = hub1.getSpokeOwed(
      wethAssetId,
      address(spoke3)
    );
    assertEq(debtChecks.spokeOwed, debtChecks.drawnDebt, 'hub spoke drawn debt after accrual');
    assertApproxEqAbs(
      debtChecks.spokePremium,
      debtChecks.premiumDebt,
      1,
      'hub spoke premium debt after accrual'
    );

    (debtChecks.assetOwed, debtChecks.assetPremium) = hub1.getAssetOwed(wethAssetId);
    assertEq(debtChecks.assetOwed, debtChecks.drawnDebt, 'hub asset drawn debt after accrual');
    assertApproxEqAbs(
      debtChecks.assetPremium,
      debtChecks.premiumDebt,
      1,
      'hub asset premium debt after accrual'
    );
  }
}
