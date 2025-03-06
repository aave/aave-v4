// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';

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
  }

  struct RateChecks {
    uint256 baseRateWbtc;
    uint256 baseRateWeth;
    uint256 baseRateDai;
    uint256 baseRateUsdx;
    uint256 baseDebt;
    uint256 premiumDebt;
    uint256 originalBaseDebtWbtc;
    uint256 originalBaseDebtWeth;
    uint256 originalBaseDebtDai;
    uint256 originalBaseDebtUsdx;
    uint256 actualBaseDebt;
    uint256 actualPremium;
    uint256 startTime;
    uint256 reserveDebt;
    uint256 reservePremium;
    uint256 reserveRiskPremium;
    uint256 spokeDebt;
    uint256 spokePremium;
    uint256 spokeRiskPremium;
    uint256 assetDebt;
    uint256 assetPremium;
    uint256 assetRiskPremium;
  }

  struct Debts {
    uint256 bobDaiBaseDebtAfter;
    uint256 bobDaiPremiumDebtAfter;
    uint256 bobUsdxBaseDebtAfter;
    uint256 bobUsdxPremiumDebtAfter;
    uint256 aliceDaiBaseDebtAfter;
    uint256 aliceDaiPremiumDebtAfter;
    uint256 aliceUsdxBaseDebtAfter;
    uint256 aliceUsdxPremiumDebtAfter;
    uint256 bobTotalDaiDebt;
    uint256 bobTotalUsdxDebt;
    uint256 aliceTotalDaiDebt;
    uint256 aliceTotalUsdxDebt;
  }

  function test_getUserRiskPremium_no_collateral() public {
    // Assert Bob has no collateral
    for (uint256 i = 0; i < spoke1.reserveCount(); i++) {
      DataTypes.UserPosition memory bobInfo = getUserInfo(spoke1, bob, i);
      assertEq(bobInfo.suppliedShares, 0, 'bob supplied collateral');
    }
    assertEq(spoke1.getUserRiskPremium(bob), 0, 'user risk premium');
  }

  function test_getUserRiskPremium_no_collateral_set() public {
    Utils.spokeSupply(spoke1, daiReserveId(spoke1), bob, 100e18, bob);
    // Bob doesn't set dai as collateral, despite supplying, so his user rp is 0
    assertEq(spoke1.getUserRiskPremium(bob), 0, 'user risk premium');
  }

  function test_getUserRiskPremium_single_reserve_collateral() public {
    uint256 daiReserveId = daiReserveId(spoke1);
    uint256 daiAmount = 100e18;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    assertEq(spoke1.getUserRiskPremium(bob), 0, 'user risk premium');
  }

  function test_getUserRiskPremium_single_reserve_collateral_borrowed() public {
    uint256 daiReserveId = daiReserveId(spoke1);
    uint256 supplyAmount = 100e18;
    uint256 borrowAmount = 50e18;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);
    Utils.spokeBorrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    DataTypes.Reserve memory daiInfo = getReserveInfo(spoke1, daiReserveId);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(userRiskPremium, daiInfo.config.liquidityPremium, 'user risk premium');
  }

  function test_getUserRiskPremium_fuzz_single_reserve_collateral_borrowed_amount(
    uint256 borrowAmount
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    ReserveInfoLocal memory daiInfo;
    daiInfo.reserveId = daiReserveId(spoke1);
    daiInfo.borrowAmount = borrowAmount;
    daiInfo.supplyAmount = borrowAmount * 2;

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);
    Utils.spokeBorrow(spoke1, daiInfo.reserveId, bob, daiInfo.borrowAmount, bob);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(spoke1.getUserRiskPremium(bob), daiInfo.lp, 'user risk premium');
  }

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

    daiInfo.reserveId = daiReserveId(spoke1);
    usdxInfo.reserveId = usdxReserveId(spoke1);

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);

    // Bob draw dai
    Utils.spokeBorrow(spoke1, daiInfo.reserveId, bob, daiInfo.borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(userRiskPremium, daiInfo.lp, 'user risk premium');

    // Supplying more risky reserve (usdx) should not impact user risk premium
    Utils.spokeSupply(spoke1, usdxInfo.reserveId, bob, additionalSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, usdxInfo.reserveId, true);
    assertEq(spoke1.getUserRiskPremium(bob), userRiskPremium, 'user risk premium after supply');
  }

  function test_getUserRiskPremium_multi_reserve_collateral() public {
    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wethInfo;

    daiInfo.reserveId = daiReserveId(spoke1);
    usdxInfo.reserveId = usdxReserveId(spoke1);
    wethInfo.reserveId = wethReserveId(spoke1);

    daiInfo.supplyAmount = 1000e18;
    usdxInfo.supplyAmount = 1000e6;
    wethInfo.supplyAmount = 1000e18;
    daiInfo.borrowAmount = 1000e18;
    usdxInfo.borrowAmount = 1000e6;

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);
    usdxInfo.lp = spoke1.getLiquidityPremium(usdxInfo.reserveId);
    wethInfo.lp = spoke1.getLiquidityPremium(wethInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, usdxInfo.reserveId, true);

    // Bob supply weth into spoke1
    Utils.spokeSupply(spoke1, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethInfo.reserveId, true);

    // Bob draw dai + usdx
    Utils.spokeBorrow(spoke1, daiInfo.reserveId, bob, daiInfo.borrowAmount, bob);
    Utils.spokeBorrow(spoke1, usdxInfo.reserveId, bob, usdxInfo.borrowAmount, bob);

    // Weth is enough to cover the total debt
    assertGe(
      _getNormalizedReserveValue(wethInfo.supplyAmount, wethAssetId),
      _getNormalizedReserveValue(daiInfo.borrowAmount + usdxInfo.borrowAmount, daiAssetId),
      'weth supply covers debt'
    );
    uint256 expectedUserRiskPremium = wethInfo.lp;
    assertEq(spoke1.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');
  }

  function test_getUserRiskPremium_multi_reserve_collateral_weth_partial_cover() public {
    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wethInfo;

    daiInfo.reserveId = daiReserveId(spoke1);
    usdxInfo.reserveId = usdxReserveId(spoke1);
    wethInfo.reserveId = wethReserveId(spoke1);

    daiInfo.supplyAmount = 2000e18;
    usdxInfo.supplyAmount = 2000e6;
    wethInfo.supplyAmount = 1e18;

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);
    usdxInfo.lp = spoke1.getLiquidityPremium(usdxInfo.reserveId);
    wethInfo.lp = spoke1.getLiquidityPremium(wethInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, usdxInfo.reserveId, true);

    // Bob supply weth into spoke1
    Utils.spokeSupply(spoke1, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, wethInfo.reserveId, true);

    // Bob draw dai + usdx
    Utils.spokeBorrow(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    Utils.spokeBorrow(spoke1, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);

    // Weth covers half the debt, dai covers the rest
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'user risk premium'
    );
  }

  function test_getUserRiskPremium_two_reserves_equal_parts() public {
    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;
    ReserveInfoLocal memory wethInfo;

    daiInfo.reserveId = daiReserveId(spoke1);
    usdxInfo.reserveId = usdxReserveId(spoke1);
    wethInfo.reserveId = wethReserveId(spoke1);

    daiInfo.supplyAmount = 2000e18;
    usdxInfo.supplyAmount = 6000e6;
    wethInfo.supplyAmount = 10e18;

    wethInfo.borrowAmount = 2e18;

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);
    usdxInfo.lp = spoke1.getLiquidityPremium(usdxInfo.reserveId);
    wethInfo.lp = spoke1.getLiquidityPremium(wethInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, usdxInfo.reserveId, true);

    // Alice supply weth into spoke1
    Utils.spokeSupply(spoke1, wethInfo.reserveId, alice, wethInfo.supplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, wethInfo.reserveId, true);

    // Bob draw weth
    Utils.spokeBorrow(spoke1, wethInfo.reserveId, bob, wethInfo.borrowAmount, bob);

    // Dai and usdx will each cover half the debt, because dai has lower lp than usdx
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'user risk premium'
    );
  }

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

    daiInfo.reserveId = daiReserveId(spoke3);
    usdxInfo.reserveId = usdxReserveId(spoke3);
    wethInfo.reserveId = wethReserveId(spoke3);

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
      Utils.spokeSupply(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, daiInfo.reserveId, true);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, usdxInfo.reserveId, true);
    }

    // Bob supply weth into spoke3
    Utils.spokeSupply(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, wethInfo.reserveId, true);

    // Bob draw weth
    if (wethInfo.borrowAmount > 0) {
      Utils.spokeBorrow(spoke3, wethInfo.reserveId, bob, wethInfo.borrowAmount, bob);
    }

    // Dai and usdx will each cover part of the debt
    assertEq(
      spoke3.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke3),
      'user risk premium'
    );
  }

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

    daiInfo.reserveId = daiReserveId(spoke3);
    wethInfo.reserveId = wethReserveId(spoke3);
    usdxInfo.reserveId = usdxReserveId(spoke3);
    wbtcInfo.reserveId = wbtcReserveId(spoke3);

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
      Utils.spokeSupply(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, daiInfo.reserveId, true);
    }

    // Bob supply weth into spoke3
    if (wethInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, wethInfo.reserveId, true);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, usdxInfo.reserveId, true);
    }

    // Bob supply wbtc into spoke3
    Utils.spokeSupply(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, wbtcInfo.reserveId, true);

    // Bob draw wbtc
    if (wbtcInfo.borrowAmount > 0) {
      Utils.spokeBorrow(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.borrowAmount, bob);
    }

    // Dai, weth, and usdx will each cover part of the debt
    assertEq(
      spoke3.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke3),
      'user risk premium'
    );
  }

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

    daiInfo.reserveId = daiReserveId(spoke2);
    usdxInfo.reserveId = usdxReserveId(spoke2);
    wethInfo.reserveId = wethReserveId(spoke2);
    wbtcInfo.reserveId = wbtcReserveId(spoke2);
    dai2Info.reserveId = dai2ReserveId(spoke2);

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
      Utils.spokeSupply(spoke2, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wbtcInfo.reserveId, true);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wethInfo.reserveId, true);
    }

    // Bob supply dai into spoke2
    if (daiInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, daiInfo.reserveId, true);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, usdxInfo.reserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, dai2Info.reserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    setUsingAsCollateral(spoke2, bob, dai2Info.reserveId, true);

    // Bob draw dai2
    if (dai2Info.borrowAmount > 0) {
      Utils.spokeBorrow(spoke2, dai2Info.reserveId, bob, dai2Info.borrowAmount, bob);
    }

    // wbtc, weth, dai, and usdx will each cover part of the debt
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );
  }

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

    daiInfo.reserveId = daiReserveId(spoke2);
    wethInfo.reserveId = wethReserveId(spoke2);
    usdxInfo.reserveId = usdxReserveId(spoke2);
    wbtcInfo.reserveId = wbtcReserveId(spoke2);
    dai2Info.reserveId = dai2ReserveId(spoke2);

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
      Utils.spokeSupply(spoke2, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wbtcInfo.reserveId, true);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wethInfo.reserveId, true);
    }

    // Bob supply dai into spoke2
    if (daiInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, daiInfo.reserveId, true);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, usdxInfo.reserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, dai2Info.reserveId, bob, dai2Info.supplyAmount, bob);
    setUsingAsCollateral(spoke2, bob, dai2Info.reserveId, true);

    // Bob draw dai2
    if (dai2Info.borrowAmount > 0) {
      Utils.spokeBorrow(spoke2, dai2Info.reserveId, bob, dai2Info.borrowAmount, bob);
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

    daiInfo.reserveId = daiReserveId(spoke2);
    wethInfo.reserveId = wethReserveId(spoke2);
    usdxInfo.reserveId = usdxReserveId(spoke2);
    wbtcInfo.reserveId = wbtcReserveId(spoke2);
    dai2Info.reserveId = dai2ReserveId(spoke2);

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
      Utils.spokeSupply(spoke2, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wbtcInfo.reserveId, true);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wethInfo.reserveId, true);
    }

    // Bob supply dai into spoke2
    if (daiInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, daiInfo.reserveId, true);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, usdxInfo.reserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, dai2Info.reserveId, bob, dai2Info.supplyAmount, bob);
    setUsingAsCollateral(spoke2, bob, dai2Info.reserveId, true);

    // Bob draw dai2
    if (dai2Info.borrowAmount > 0) {
      Utils.spokeBorrow(spoke2, dai2Info.reserveId, bob, dai2Info.borrowAmount, bob);
    }

    // wbtc, weth, dai, and usdx will each cover part of the debt
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );

    // Change the liquidity premium of wbtc
    spoke2.updateReserveConfig(
      wbtcInfo.reserveId,
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: newLpValue,
        borrowable: true,
        collateral: true
      })
    );

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );
  }

  function test_getUserRiskPremium_fuzz_four_reserves_prices_supply_debt(
    ReserveInfoLocal memory daiInfo,
    ReserveInfoLocal memory wethInfo,
    ReserveInfoLocal memory usdxInfo,
    ReserveInfoLocal memory wbtcInfo
  ) public {
    daiInfo.supplyAmount = bound(daiInfo.supplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wethInfo.supplyAmount = bound(wethInfo.supplyAmount, 0, MAX_SUPPLY_AMOUNT);
    usdxInfo.supplyAmount = bound(usdxInfo.supplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wbtcInfo.supplyAmount = bound(wbtcInfo.supplyAmount, 0, MAX_SUPPLY_AMOUNT);

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
      Utils.spokeSupply(spoke2, daiReserveId(spoke2), bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, daiReserveId(spoke2), true);
    }

    // Bob supply weth into spoke2
    if (wethInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, wethReserveId(spoke2), bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wethReserveId(spoke2), true);
    }

    // Bob supply usdx into spoke2
    if (usdxInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, usdxReserveId(spoke2), bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, usdxReserveId(spoke2), true);
    }

    // Bob supply wbtc into spoke2
    if (wbtcInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke2, wbtcReserveId(spoke2), bob, wbtcInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, wbtcReserveId(spoke2), true);
    }

    // Update prices
    oracle.setAssetPrice(daiAssetId, daiInfo.price);
    oracle.setAssetPrice(wethAssetId, wethInfo.price);
    oracle.setAssetPrice(usdxAssetId, usdxInfo.price);
    oracle.setAssetPrice(wbtcAssetId, wbtcInfo.price);

    // Update LPs
    spoke2.updateReserveConfig(
      daiReserveId(spoke2),
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: daiInfo.lp,
        borrowable: true,
        collateral: true
      })
    );
    spoke2.updateReserveConfig(
      wethReserveId(spoke2),
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: wethInfo.lp,
        borrowable: true,
        collateral: true
      })
    );
    spoke2.updateReserveConfig(
      usdxReserveId(spoke2),
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: usdxInfo.lp,
        borrowable: true,
        collateral: true
      })
    );
    spoke2.updateReserveConfig(
      wbtcReserveId(spoke2),
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: wbtcInfo.lp,
        borrowable: true,
        collateral: true
      })
    );

    // Check user risk premium
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );
  }

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

    daiInfo.reserveId = daiReserveId(spoke3);
    wethInfo.reserveId = wethReserveId(spoke3);
    usdxInfo.reserveId = usdxReserveId(spoke3);
    wbtcInfo.reserveId = wbtcReserveId(spoke3);

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
      Utils.spokeSupply(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, daiInfo.reserveId, true);
    }

    // Bob supply weth into spoke3
    if (wethInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, wethInfo.reserveId, true);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, usdxInfo.reserveId, true);
    }

    // Bob supply wbtc into spoke3
    Utils.spokeSupply(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, wbtcInfo.reserveId, true);

    // Bob draw wbtc
    if (wbtcInfo.borrowAmount > 0) {
      Utils.spokeBorrow(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.borrowAmount, bob);
    }

    // Dai, usdx, and weth will each cover part of the debt
    uint256 expectedUserRiskPremium = _calculateExpectedUserRP(bob, spoke3);

    assertEq(spoke3.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');

    // Get the base rate of wbtc
    uint256 baseRate = hub.getBaseInterestRate(wbtcAssetId);
    uint256 baseDebt = wbtcInfo.borrowAmount;
    uint256 originalBaseDebt = baseDebt;
    (uint256 actualBaseDebt, uint256 actualPremium) = spoke3.getUserDebt(wbtcInfo.reserveId, bob);
    uint256 startTime = vm.getBlockTimestamp();

    assertEq(baseDebt, actualBaseDebt, 'user base debt');
    assertEq(actualPremium, 0, 'user outstanding premium');

    // Wait a year
    skip(365 days);

    // User risk premium should remain the same when there is no action
    assertEq(
      spoke3.getLastUsedUserRiskPremium(bob),
      expectedUserRiskPremium,
      'user risk premium after interest accrual'
    );

    // See if base debt of wbtc changes appropriately
    baseDebt = MathUtils.calculateLinearInterest(baseRate, uint40(startTime)).rayMul(baseDebt);
    (actualBaseDebt, actualPremium) = spoke3.getUserDebt(wbtcInfo.reserveId, bob);
    assertEq(baseDebt, actualBaseDebt, 'user base debt');

    // See if outstanding premium changes proportionally to user risk premium change
    uint256 premiumDebt = (baseDebt - originalBaseDebt).percentMul(expectedUserRiskPremium);
    assertEq(premiumDebt, actualPremium, 'user outstanding premium after interest accrual');

    // Since Bob is only user, reserve debt should be equal to user debt
    (uint256 reserveDebt, uint256 reservePremium) = spoke3.getReserveDebt(wbtcInfo.reserveId);
    assertEq(reserveDebt, baseDebt, 'reserve base debt');
    assertEq(reservePremium, premiumDebt, 'reserve outstanding premium');

    // See if values are reflected on hub side as well
    (uint256 spokeDebt, uint256 spokePremium) = hub.getSpokeDebt(wbtcAssetId, address(spoke3));
    assertEq(spokeDebt, baseDebt, 'hub spoke base debt');
    assertEq(spokePremium, premiumDebt, 'hub spoke outstanding premium');

    (uint256 assetDebt, uint256 assetPremium) = hub.getAssetDebt(wbtcAssetId);
    assertEq(assetDebt, baseDebt, 'hub asset base debt');
    assertEq(assetPremium, premiumDebt, 'hub asset outstanding premium');
  }

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

    daiInfo.reserveId = daiReserveId(spoke3);
    wethInfo.reserveId = wethReserveId(spoke3);
    usdxInfo.reserveId = usdxReserveId(spoke3);
    wbtcInfo.reserveId = wbtcReserveId(spoke3);

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
      Utils.spokeSupply(spoke3, daiInfo.reserveId, bob, daiInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, daiInfo.reserveId, true);
    }

    // Bob supply weth into spoke3
    if (wethInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke3, wethInfo.reserveId, bob, wethInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, wethInfo.reserveId, true);
    }

    // Bob supply usdx into spoke3
    if (usdxInfo.supplyAmount > 0) {
      Utils.spokeSupply(spoke3, usdxInfo.reserveId, bob, usdxInfo.supplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, usdxInfo.reserveId, true);
    }

    // Bob supply wbtc into spoke3
    Utils.spokeSupply(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.supplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, wbtcInfo.reserveId, true);

    // Alice supply remaining weth into spoke3
    if (MAX_SUPPLY_AMOUNT - wethInfo.supplyAmount > 0) {
      Utils.spokeSupply(
        spoke3,
        wethInfo.reserveId,
        alice,
        MAX_SUPPLY_AMOUNT - wethInfo.supplyAmount,
        alice
      );
    }

    // Bob draw wbtc
    if (wbtcInfo.borrowAmount > 0) {
      Utils.spokeBorrow(spoke3, wbtcInfo.reserveId, bob, wbtcInfo.borrowAmount, bob);
    }

    // Bob draw weth
    if (wethInfo.borrowAmount > 0) {
      Utils.spokeBorrow(spoke3, wethInfo.reserveId, bob, wethInfo.borrowAmount, bob);
    }

    uint256 expectedUserRiskPremium = _calculateExpectedUserRP(bob, spoke3);

    assertEq(spoke3.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');

    RateChecks memory rateChecks;

    // Get the base rate of wbtc
    rateChecks.baseRateWbtc = hub.getBaseInterestRate(wbtcAssetId);
    rateChecks.baseDebt = wbtcInfo.borrowAmount;
    rateChecks.originalBaseDebtWbtc = rateChecks.baseDebt;
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke3.getUserDebt(
      wbtcInfo.reserveId,
      bob
    );
    rateChecks.startTime = vm.getBlockTimestamp();

    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'user base debt');
    assertEq(rateChecks.actualPremium, 0, 'user outstanding premium');

    // Get the base rate of weth
    rateChecks.baseRateWeth = hub.getBaseInterestRate(wethAssetId);
    rateChecks.baseDebt = wethInfo.borrowAmount;
    rateChecks.originalBaseDebtWeth = rateChecks.baseDebt;
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke3.getUserDebt(
      wethInfo.reserveId,
      bob
    );

    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'user base debt');
    assertEq(rateChecks.actualPremium, 0, 'user outstanding premium');

    // Wait a year
    skip(365 days);

    // User risk premium should remain the same when there is no action
    assertEq(
      spoke3.getLastUsedUserRiskPremium(bob),
      expectedUserRiskPremium,
      'user risk premium after interest accrual'
    );

    // See if base debt of wbtc changes appropriately
    rateChecks.baseDebt = MathUtils
      .calculateLinearInterest(rateChecks.baseRateWbtc, uint40(rateChecks.startTime))
      .rayMul(rateChecks.originalBaseDebtWbtc);
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke3.getUserDebt(
      wbtcInfo.reserveId,
      bob
    );
    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'user base debt');

    // See if outstanding premium changes proportionally to user risk premium
    rateChecks.premiumDebt = (rateChecks.baseDebt - rateChecks.originalBaseDebtWbtc).percentMul(
      expectedUserRiskPremium
    );
    assertEq(
      rateChecks.premiumDebt,
      rateChecks.actualPremium,
      'user outstanding premium after accrual'
    );

    // Since Bob is only user, reserve debt should be equal to user debt
    (rateChecks.reserveDebt, rateChecks.reservePremium) = spoke3.getReserveDebt(wbtcInfo.reserveId);
    assertEq(rateChecks.reserveDebt, rateChecks.baseDebt, 'reserve base debt after accrual');
    assertEq(
      rateChecks.reservePremium,
      rateChecks.premiumDebt,
      'reserve outstanding premium after accrual'
    );

    // See if values are reflected on hub side as well
    (rateChecks.spokeDebt, rateChecks.spokePremium) = hub.getSpokeDebt(
      wbtcAssetId,
      address(spoke3)
    );
    assertEq(rateChecks.spokeDebt, rateChecks.baseDebt, 'hub spoke base debt after accrual');
    assertEq(
      rateChecks.spokePremium,
      rateChecks.premiumDebt,
      'hub spoke outstanding premium after accrual'
    );

    (rateChecks.assetDebt, rateChecks.assetPremium) = hub.getAssetDebt(wbtcAssetId);
    assertEq(rateChecks.assetDebt, rateChecks.baseDebt, 'hub asset base debt after accrual');
    assertEq(
      rateChecks.assetPremium,
      rateChecks.premiumDebt,
      'hub asset outstanding premium after accrual'
    );

    // See if base debt of weth changes appropriately
    rateChecks.baseDebt = MathUtils
      .calculateLinearInterest(rateChecks.baseRateWeth, uint40(rateChecks.startTime))
      .rayMul(rateChecks.originalBaseDebtWeth);
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke3.getUserDebt(
      wethInfo.reserveId,
      bob
    );
    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'user base debt');

    // See if outstanding premium changes proportionally to user risk premium
    rateChecks.premiumDebt = (rateChecks.baseDebt - rateChecks.originalBaseDebtWeth).percentMul(
      expectedUserRiskPremium
    );
    assertEq(
      rateChecks.premiumDebt,
      rateChecks.actualPremium,
      'user outstanding premium after accrual'
    );

    // Since Bob is only user, reserve debt should be equal to user debt
    (rateChecks.reserveDebt, rateChecks.reservePremium) = spoke3.getReserveDebt(wethInfo.reserveId);
    assertEq(rateChecks.reserveDebt, rateChecks.baseDebt, 'reserve base debt after accrual');
    assertEq(
      rateChecks.reservePremium,
      rateChecks.premiumDebt,
      'reserve outstanding premium after accrual'
    );

    // See if values are reflected on hub side as well
    (rateChecks.spokeDebt, rateChecks.spokePremium) = hub.getSpokeDebt(
      wethAssetId,
      address(spoke3)
    );
    assertEq(rateChecks.spokeDebt, rateChecks.baseDebt, 'hub spoke base debt after accrual');
    assertEq(
      rateChecks.spokePremium,
      rateChecks.premiumDebt,
      'hub spoke outstanding premium after accrual'
    );

    (rateChecks.assetDebt, rateChecks.assetPremium) = hub.getAssetDebt(wethAssetId);
    assertEq(rateChecks.assetDebt, rateChecks.baseDebt, 'hub asset base debt after accrual');
    assertEq(
      rateChecks.assetPremium,
      rateChecks.premiumDebt,
      'hub asset outstanding premium after accrual'
    );
  }

  function test_getUserRiskPremium_applyInterest_two_users_two_reserves_borrowed() public {
    uint256 bobDaiSupplyAmount = 1000e18;
    uint256 aliceDaiSupplyAmount = 2000e18;
    uint256 bobUsdxSupplyAmount = 5000e6;
    uint256 aliceUsdxSupplyAmount = 10000e6;

    uint256 bobDaiBorrowAmount = bobDaiSupplyAmount / 2;
    uint256 aliceDaiBorrowAmount = aliceDaiSupplyAmount / 2;
    uint256 bobUsdxBorrowAmount = bobUsdxSupplyAmount / 2;
    uint256 aliceUsdxBorrowAmount = aliceUsdxSupplyAmount / 2;

    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;

    daiInfo.reserveId = daiReserveId(spoke1);
    usdxInfo.reserveId = usdxReserveId(spoke1);

    daiInfo.lp = spoke1.getLiquidityPremium(daiInfo.reserveId);
    usdxInfo.lp = spoke1.getLiquidityPremium(usdxInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiInfo.reserveId, bob, bobDaiSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiInfo.reserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, usdxInfo.reserveId, bob, bobUsdxSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, usdxInfo.reserveId, true);

    // Alice supply dai into spoke1
    Utils.spokeSupply(spoke1, daiInfo.reserveId, alice, aliceDaiSupplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, daiInfo.reserveId, true);

    // Alice supply usdx into spoke1
    Utils.spokeSupply(spoke1, usdxInfo.reserveId, alice, aliceUsdxSupplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, usdxInfo.reserveId, true);

    // Bob draw dai
    Utils.spokeBorrow(spoke1, daiInfo.reserveId, bob, bobDaiBorrowAmount, bob);

    // Bob draw usdx
    Utils.spokeBorrow(spoke1, usdxInfo.reserveId, bob, bobUsdxBorrowAmount, bob);

    // Alice draw dai
    Utils.spokeBorrow(spoke1, daiInfo.reserveId, alice, aliceDaiBorrowAmount, alice);

    // Alice draw usdx
    Utils.spokeBorrow(spoke1, usdxInfo.reserveId, alice, aliceUsdxBorrowAmount, alice);

    uint256 bobExpectedRiskPremium = _calculateExpectedUserRP(bob, spoke1);
    uint256 aliceExpectedRiskPremium = _calculateExpectedUserRP(alice, spoke1);

    assertEq(spoke1.getUserRiskPremium(bob), bobExpectedRiskPremium, 'bob risk premium');
    assertEq(spoke1.getUserRiskPremium(alice), aliceExpectedRiskPremium, 'alice risk premium');

    RateChecks memory rateChecks;

    // Get the base rate of dai
    rateChecks.baseRateDai = hub.getBaseInterestRate(daiAssetId);

    // Check Bob's starting dai debt
    rateChecks.baseDebt = bobDaiBorrowAmount;
    rateChecks.originalBaseDebtDai = bobDaiBorrowAmount;
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      bob
    );
    rateChecks.startTime = vm.getBlockTimestamp();

    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'Bob dai debt before');
    assertEq(rateChecks.actualPremium, 0, 'Bob dai premium before');

    // Get the base rate of usdx
    rateChecks.baseRateUsdx = hub.getBaseInterestRate(usdxAssetId);

    // Check Bob's starting usdx debt
    rateChecks.baseDebt = bobUsdxBorrowAmount;
    rateChecks.originalBaseDebtUsdx = bobUsdxBorrowAmount;
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      bob
    );

    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'Bob usdx debt before');
    assertEq(rateChecks.actualPremium, 0, 'Bob usdx premium before');

    // Check Alice's starting dai debt
    rateChecks.baseDebt = aliceDaiBorrowAmount;
    rateChecks.originalBaseDebtDai = aliceDaiBorrowAmount;
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      alice
    );

    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'Alice dai debt before');
    assertEq(rateChecks.actualPremium, 0, 'Alice dai premium before');

    // Check Alice's starting usdx debt
    rateChecks.baseDebt = aliceUsdxBorrowAmount;
    rateChecks.originalBaseDebtWeth = aliceUsdxBorrowAmount;
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      alice
    );

    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'Alice usdx debt before');
    assertEq(rateChecks.actualPremium, 0, 'Alice usdx premium before');

    // Wait a year
    skip(365 days);

    // User risk premium should remain the same when there is no action
    assertEq(
      spoke1.getLastUsedUserRiskPremium(bob),
      bobExpectedRiskPremium,
      'bob risk premium after interest accrual'
    );
    assertEq(
      spoke1.getLastUsedUserRiskPremium(alice),
      aliceExpectedRiskPremium,
      'alice risk premium after interest accrual'
    );

    Debts memory debts;

    // See if Bob's base debt of dai changes appropriately
    debts.bobDaiBaseDebtAfter = MathUtils
      .calculateLinearInterest(rateChecks.baseRateDai, uint40(rateChecks.startTime))
      .rayMul(bobDaiBorrowAmount);
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      bob
    );
    assertEq(debts.bobDaiBaseDebtAfter, rateChecks.actualBaseDebt, 'bob dai base debt after');

    // See if Bob's dai outstanding premium changes proportionally to bob's risk premium
    debts.bobDaiPremiumDebtAfter = (debts.bobDaiBaseDebtAfter - bobDaiBorrowAmount).percentMul(
      bobExpectedRiskPremium
    );
    assertEq(
      debts.bobDaiPremiumDebtAfter,
      rateChecks.actualPremium,
      'bob outstanding premium after accrual'
    );

    // See if Bob's base debt of usdx changes appropriately
    debts.bobUsdxBaseDebtAfter = MathUtils
      .calculateLinearInterest(rateChecks.baseRateUsdx, uint40(rateChecks.startTime))
      .rayMul(bobUsdxBorrowAmount);
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      bob
    );
    assertEq(debts.bobUsdxBaseDebtAfter, rateChecks.actualBaseDebt, 'bob usdx base debt after');

    // See if Bob's usdx outstanding premium changes proportionally to bob's risk premium
    debts.bobUsdxPremiumDebtAfter = (debts.bobUsdxBaseDebtAfter - bobUsdxBorrowAmount).percentMul(
      bobExpectedRiskPremium
    );
    assertEq(
      debts.bobUsdxPremiumDebtAfter,
      rateChecks.actualPremium,
      'bob outstanding premium after accrual'
    );

    // See if Alice's base debt of dai changes appropriately
    debts.aliceDaiBaseDebtAfter = MathUtils
      .calculateLinearInterest(rateChecks.baseRateDai, uint40(rateChecks.startTime))
      .rayMul(aliceDaiBorrowAmount);
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      alice
    );
    assertEq(debts.aliceDaiBaseDebtAfter, rateChecks.actualBaseDebt, 'alice dai base debt after');

    // See if Alice's dai outstanding premium changes proportionally to alice's risk premium
    debts.aliceDaiPremiumDebtAfter = (debts.aliceDaiBaseDebtAfter - aliceDaiBorrowAmount)
      .percentMul(aliceExpectedRiskPremium);
    assertEq(
      debts.aliceDaiPremiumDebtAfter,
      rateChecks.actualPremium,
      'alice outstanding premium after accrual'
    );

    // See if Alice's base debt of usdx changes appropriately
    debts.aliceUsdxBaseDebtAfter = MathUtils
      .calculateLinearInterest(rateChecks.baseRateUsdx, uint40(rateChecks.startTime))
      .rayMul(aliceUsdxBorrowAmount);
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      alice
    );
    assertEq(debts.aliceUsdxBaseDebtAfter, rateChecks.actualBaseDebt, 'alice usdx base debt after');

    // See if Alice's usdx outstanding premium changes proportionally to alice's risk premium
    debts.aliceUsdxPremiumDebtAfter = (debts.aliceUsdxBaseDebtAfter - aliceUsdxBorrowAmount)
      .percentMul(aliceExpectedRiskPremium);
    assertEq(
      debts.aliceUsdxPremiumDebtAfter,
      rateChecks.actualPremium,
      'alice outstanding premium after accrual'
    );

    // Check reserve debt for dai
    (rateChecks.reserveDebt, rateChecks.reservePremium) = spoke1.getReserveDebt(daiInfo.reserveId);

    // Reserve debt should be the sum of both user debts
    assertEq(
      rateChecks.reserveDebt,
      debts.bobDaiBaseDebtAfter + debts.aliceDaiBaseDebtAfter,
      'reserve base debt after accrual'
    );

    // Reserve outstanding premium should be the sum of both users' outstanding premium
    assertEq(
      rateChecks.reservePremium,
      debts.bobDaiPremiumDebtAfter + debts.aliceDaiPremiumDebtAfter,
      'reserve outstanding premium after accrual'
    );

    // Dai reserve risk premium should be wAvg of both users' risk premiums
    uint256 expectedDaiRiskPremium = (bobDaiBorrowAmount *
      bobExpectedRiskPremium +
      aliceDaiBorrowAmount *
      aliceExpectedRiskPremium) / (bobDaiBorrowAmount + aliceDaiBorrowAmount);
    assertEq(
      spoke1.getReserveRiskPremium(daiInfo.reserveId),
      expectedDaiRiskPremium,
      'dai reserve risk premium'
    );

    // Check reserve debt for usdx
    (rateChecks.reserveDebt, rateChecks.reservePremium) = spoke1.getReserveDebt(usdxInfo.reserveId);

    // Reserve debt should be the sum of both user debts
    assertEq(
      rateChecks.reserveDebt,
      debts.bobUsdxBaseDebtAfter + debts.aliceUsdxBaseDebtAfter,
      'reserve base debt after accrual'
    );

    // Reserve outstanding premium should be the sum of both users' outstanding premium
    assertEq(
      rateChecks.reservePremium,
      debts.bobUsdxPremiumDebtAfter + debts.aliceUsdxPremiumDebtAfter,
      'reserve outstanding premium after accrual'
    );

    // Usdx reserve risk premium should be wAvg of both users' risk premiums
    uint256 expectedUsdxRiskPremium = (bobUsdxBorrowAmount *
      bobExpectedRiskPremium +
      aliceUsdxBorrowAmount *
      aliceExpectedRiskPremium) / (bobUsdxBorrowAmount + aliceUsdxBorrowAmount);
    assertEq(
      spoke1.getReserveRiskPremium(usdxInfo.reserveId),
      expectedUsdxRiskPremium,
      'usdx reserve risk premium'
    );

    // Check spoke debt on hub for dai
    (rateChecks.spokeDebt, rateChecks.spokePremium) = hub.getSpokeDebt(daiAssetId, address(spoke1));

    // Spoke debt should be the sum of both user debts
    assertEq(
      rateChecks.spokeDebt,
      debts.bobDaiBaseDebtAfter + debts.aliceDaiBaseDebtAfter,
      'hub spoke base debt after accrual'
    );

    // Spoke outstanding premium should be the sum of both users' outstanding premium
    assertEq(
      rateChecks.spokePremium,
      debts.bobDaiPremiumDebtAfter + debts.aliceDaiPremiumDebtAfter,
      'hub spoke outstanding premium after accrual'
    );

    // Spoke risk premium for dai should match reserve
    assertEq(
      hub.getSpokeRiskPremium(daiAssetId, address(spoke1)),
      expectedDaiRiskPremium,
      'hub spoke dai risk premium'
    );

    // Check spoke debt on hub for usdx
    (rateChecks.spokeDebt, rateChecks.spokePremium) = hub.getSpokeDebt(
      usdxAssetId,
      address(spoke1)
    );

    // Spoke debt should be the sum of both user debts
    assertEq(
      rateChecks.spokeDebt,
      debts.bobUsdxBaseDebtAfter + debts.aliceUsdxBaseDebtAfter,
      'hub spoke base debt after accrual'
    );

    // Spoke outstanding premium should be the sum of both users' outstanding premium
    assertEq(
      rateChecks.spokePremium,
      debts.bobUsdxPremiumDebtAfter + debts.aliceUsdxPremiumDebtAfter,
      'hub spoke outstanding premium after accrual'
    );

    // Spoke risk premium for usdx should match reserve
    assertEq(
      hub.getSpokeRiskPremium(usdxAssetId, address(spoke1)),
      expectedUsdxRiskPremium,
      'hub spoke usdx risk premium'
    );

    // Check asset debt on hub for dai
    (rateChecks.assetDebt, rateChecks.assetPremium) = hub.getAssetDebt(daiAssetId);

    // Asset debt should be the sum of both user debts
    assertEq(
      rateChecks.assetDebt,
      debts.bobDaiBaseDebtAfter + debts.aliceDaiBaseDebtAfter,
      'hub asset base debt after accrual'
    );

    // Asset outstanding premium should be the sum of both users' outstanding premium
    assertEq(
      rateChecks.assetPremium,
      debts.bobDaiPremiumDebtAfter + debts.aliceDaiPremiumDebtAfter,
      'hub asset outstanding premium after accrual'
    );

    // Asset risk premium for dai should match reserve
    assertEq(
      hub.getAssetRiskPremium(daiAssetId),
      expectedDaiRiskPremium,
      'hub asset dai risk premium'
    );

    // Check asset debt on hub for usdx
    (rateChecks.assetDebt, rateChecks.assetPremium) = hub.getAssetDebt(usdxAssetId);

    // Asset debt should be the sum of both user debts
    assertEq(
      rateChecks.assetDebt,
      debts.bobUsdxBaseDebtAfter + debts.aliceUsdxBaseDebtAfter,
      'hub asset base debt after accrual'
    );

    // Asset outstanding premium should be the sum of both users' outstanding premium
    assertEq(
      rateChecks.assetPremium,
      debts.bobUsdxPremiumDebtAfter + debts.aliceUsdxPremiumDebtAfter,
      'hub asset outstanding premium after accrual'
    );

    // Asset risk premium for usdx should match reserve
    assertEq(
      hub.getAssetRiskPremium(usdxAssetId),
      expectedUsdxRiskPremium,
      'hub asset usdx risk premium'
    );

    // Now, if Alice repays some debt, her user risk premium should change and percolate through protocol
    Utils.spokeRepay(spoke1, daiInfo.reserveId, alice, aliceDaiBorrowAmount / 2);

    // Bob's user risk premium remains unchanged
    assertEq(
      spoke1.getLastUsedUserRiskPremium(bob),
      bobExpectedRiskPremium,
      'bob risk premium after repay'
    );

    // Alice's user risk premium does change
    assertNotEq(
      spoke1.getLastUsedUserRiskPremium(alice),
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
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      alice
    );

    // Only Alice's premium debt and base debt on dai should change due to repay
    debts.aliceTotalDaiDebt = debts.aliceDaiBaseDebtAfter + debts.aliceDaiPremiumDebtAfter;
    uint256 repayAmount = aliceDaiBorrowAmount / 2;
    // Premium debt repaid first
    repayAmount -= debts.aliceDaiPremiumDebtAfter;
    debts.aliceDaiBaseDebtAfter -= repayAmount;
    debts.aliceDaiPremiumDebtAfter = 0;
    assertEq(rateChecks.actualBaseDebt, debts.aliceDaiBaseDebtAfter, 'alice base debt after repay');
    assertEq(
      rateChecks.actualPremium,
      debts.aliceDaiPremiumDebtAfter,
      'alice premium debt after repay'
    );
    debts.aliceTotalDaiDebt = debts.aliceDaiBaseDebtAfter + debts.aliceDaiPremiumDebtAfter;

    // Alice's debts on usdx should remain unchanged
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      alice
    );
    assertEq(rateChecks.actualBaseDebt, debts.aliceUsdxBaseDebtAfter, 'alice usdx base debt after');
    assertEq(
      rateChecks.actualPremium,
      debts.aliceUsdxPremiumDebtAfter,
      'alice usdx premium debt after'
    );
    debts.aliceTotalUsdxDebt = debts.aliceUsdxBaseDebtAfter + debts.aliceUsdxPremiumDebtAfter;

    // Bob's debts on dai should remain unchanged
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      bob
    );
    assertEq(rateChecks.actualBaseDebt, debts.bobDaiBaseDebtAfter, 'bob dai base debt after');
    assertEq(rateChecks.actualPremium, debts.bobDaiPremiumDebtAfter, 'bob dai premium debt after');
    debts.bobTotalDaiDebt = debts.bobDaiBaseDebtAfter + debts.bobDaiPremiumDebtAfter;

    // Bob's debts on usdx should remain unchanged
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      bob
    );
    assertEq(rateChecks.actualBaseDebt, debts.bobUsdxBaseDebtAfter, 'bob usdx base debt after');
    assertEq(
      rateChecks.actualPremium,
      debts.bobUsdxPremiumDebtAfter,
      'bob usdx premium debt after'
    );
    debts.bobTotalUsdxDebt = debts.bobUsdxBaseDebtAfter + debts.bobUsdxPremiumDebtAfter;

    // Dai risk premium should be wAvg of user risk premiums
    expectedDaiRiskPremium =
      (debts.bobTotalDaiDebt *
        bobExpectedRiskPremium +
        debts.aliceTotalDaiDebt *
        aliceExpectedRiskPremium) /
      (debts.bobTotalDaiDebt + debts.aliceTotalDaiDebt);
    assertEq(
      spoke1.getReserveRiskPremium(daiInfo.reserveId),
      expectedDaiRiskPremium,
      'dai reserve risk premium after repay'
    );

    // Usdx risk premium should be wAvg of user risk premiums
    expectedUsdxRiskPremium =
      (debts.bobTotalUsdxDebt *
        bobExpectedRiskPremium +
        debts.aliceTotalUsdxDebt *
        aliceExpectedRiskPremium) /
      (debts.bobTotalUsdxDebt + debts.aliceTotalUsdxDebt);

    // Spoke risk premiums should match reserve risk premiums
    assertEq(
      hub.getSpokeRiskPremium(daiAssetId, address(spoke1)),
      expectedDaiRiskPremium,
      'dai spoke risk premium'
    );
    assertEq(
      hub.getSpokeRiskPremium(usdxAssetId, address(spoke1)),
      expectedUsdxRiskPremium,
      'usdx spoke risk premium'
    );

    // Asset risk premiums should match reserve risk premiums
    assertEq(hub.getAssetRiskPremium(daiAssetId), expectedDaiRiskPremium, 'dai asset risk premium');
    assertEq(
      hub.getAssetRiskPremium(usdxAssetId),
      expectedUsdxRiskPremium,
      'usdx asset risk premium'
    );
  }

  // TODO: Fuzz test showing 2 diff users borrowing the same 2 reserves, and show their own risk premiums are calculated and applied correctly
}
