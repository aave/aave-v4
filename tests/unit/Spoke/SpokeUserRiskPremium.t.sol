// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {KeyValueListInMemory} from 'src/contracts/KeyValueListInMemory.sol';
import {Spoke} from 'src/contracts/Spoke.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';

contract SpokeUserRiskPremiumTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using KeyValueListInMemory for KeyValueListInMemory.List;

  struct TestInfo {
    uint256 daiReserveId;
    uint256 wethReserveId;
    uint256 usdxReserveId;
    uint256 wbtcReserveId;
    uint256 dai2ReserveId;
    uint256 borrowAmount;
    uint256 supplyAmount;
    uint256 daiSupplyAmount;
    uint256 usdxSupplyAmount;
    uint256 wethSupplyAmount;
    uint256 wbtcSupplyAmount;
    uint256 dai2SupplyAmount;
    uint256 daiBorrowAmount;
    uint256 usdxBorrowAmount;
    uint256 wethBorrowAmount;
    uint256 wbtcBorrowAmount;
    uint256 dai2BorrowAmount;
    uint256 daiPrice;
    uint256 wethPrice;
    uint256 usdxPrice;
    uint256 wbtcPrice;
    uint256 daiLP;
    uint256 wethLP;
    uint256 usdxLP;
    uint256 wbtcLP;
    uint256 dai2LP;
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
    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, 0, 'user risk premium');
  }

  function test_getUserRiskPremium_no_collateral_set() public {
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, bob, 100e18, bob);
    // Bob doesn't set dai as collateral, despite supplying, so his user rp is 0
    assertEq(spoke1.getUserRiskPremium(bob), 0, 'user risk premium');
  }

  function test_getUserRiskPremium_single_reserve_collateral() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 daiAmount = 100e18;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, 0, 'user risk premium');
  }

  function test_getUserRiskPremium_single_reserve_collateral_borrowed() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
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

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.borrowAmount = borrowAmount;
    params.supplyAmount = borrowAmount * 2;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.borrowAmount, bob);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(spoke1.getUserRiskPremium(bob), params.daiLP, 'user risk premium');
  }

  function test_getUserRiskPremium_fuzz_supply_does_not_impact(
    uint256 borrowAmount,
    uint256 additionalSupplyAmount
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    additionalSupplyAmount = bound(additionalSupplyAmount, 1, MAX_SUPPLY_AMOUNT);

    TestInfo memory params;
    params.borrowAmount = borrowAmount;
    params.supplyAmount = borrowAmount * 2;

    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob draw dai
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(userRiskPremium, params.daiLP, 'user risk premium');

    // Supplying more risky reserve (usdx) should not impact user risk premium
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, additionalSupplyAmount, bob);
    assertEq(spoke1.getUserRiskPremium(bob), userRiskPremium, 'user risk premium after supply');
  }

  function test_getUserRiskPremium_multi_reserve_collateral() public {
    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke1].weth.reserveId;

    params.daiSupplyAmount = 1000e18;
    params.usdxSupplyAmount = 1000e6;
    params.wethSupplyAmount = 1000e18;
    params.daiBorrowAmount = 1000e18;
    params.usdxBorrowAmount = 1000e6;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke1.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke1.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Bob supply weth into spoke1
    Utils.spokeSupply(spoke1, params.wethReserveId, bob, params.wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.wethReserveId, true);

    // Bob draw 2000 total dai + usdx
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.daiBorrowAmount, bob);
    Utils.spokeBorrow(spoke1, params.usdxReserveId, bob, params.usdxBorrowAmount, bob);

    // Weth is enough to cover the total debt
    uint256 expectedUserRiskPremium = params.wethLP;
    assertEq(spoke1.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');
  }

  function test_getUserRiskPremium_multi_reserve_collateral_weth_partial_cover() public {
    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke1].weth.reserveId;

    params.daiSupplyAmount = 2000e18;
    params.usdxSupplyAmount = 2000e6;
    params.wethSupplyAmount = 1e18;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke1.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke1.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Bob supply weth into spoke1
    Utils.spokeSupply(spoke1, params.wethReserveId, bob, params.wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.wethReserveId, true);

    // Bob draw dai + usdx
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    Utils.spokeBorrow(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);

    // Weth covers half the debt, dai covers the rest
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'user risk premium'
    );
  }

  function test_getUserRiskPremium_two_reserves_equal_parts() public {
    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke1].weth.reserveId;

    params.daiSupplyAmount = 2000e18;
    params.usdxSupplyAmount = 6000e6;
    params.wethSupplyAmount = 10e18;

    params.wethBorrowAmount = 2e18;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke1.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke1.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Alice supply weth into spoke1
    Utils.spokeSupply(spoke1, params.wethReserveId, alice, params.wethSupplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, params.wethReserveId, true);

    // Bob draw weth
    Utils.spokeBorrow(spoke1, params.wethReserveId, bob, params.wethBorrowAmount, bob);

    // Dai and usdx will each cover half the debt, because dai has lower lp than usdx
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'user risk premium'
    );
  }

  function test_getUserRiskPremium_fuzz_two_reserves_diff_amounts(uint256 daiSupplyAmount) public {
    // Dai lp to account for up to 100% of the debt value
    daiSupplyAmount = bound(daiSupplyAmount, 1, 4000e18);

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke1].weth.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.usdxSupplyAmount = 6000e6;
    params.wethSupplyAmount = 10e18;

    params.wethBorrowAmount = 2e18;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke1.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke1.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Alice supply weth into spoke1
    Utils.spokeSupply(spoke1, params.wethReserveId, alice, params.wethSupplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, params.wethReserveId, true);

    // Bob draw weth
    Utils.spokeBorrow(spoke1, params.wethReserveId, bob, params.wethBorrowAmount, bob);

    // Dai and usdx will each cover part of the debt
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

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke3].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke3].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke3].weth.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.usdxSupplyAmount = usdxSupplyAmount;
    params.wethSupplyAmount = MAX_SUPPLY_AMOUNT;

    // Borrow all value in weth
    params.wethBorrowAmount = wethBorrowAmount;

    params.daiLP = spoke3.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke3.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke3.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke3
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.daiReserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.daiReserveId, true);
    }

    // Bob supply usdx into spoke3
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.usdxReserveId, true);
    }

    // Bob supply weth into spoke3
    Utils.spokeSupply(spoke3, params.wethReserveId, bob, params.wethSupplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, params.wethReserveId, true);

    // Bob draw weth
    if (params.wethBorrowAmount > 0) {
      Utils.spokeBorrow(spoke3, params.wethReserveId, bob, params.wethBorrowAmount, bob);
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
    usdxSupplyAmount = bound(usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wethSupplyAmount = bound(wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wbtcBorrowAmount = bound(wbtcBorrowAmount, 0, totalBorrowAmount);

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke3].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke3].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke3].weth.reserveId;
    params.wbtcReserveId = spokeInfo[spoke3].wbtc.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.usdxSupplyAmount = usdxSupplyAmount;
    params.wethSupplyAmount = wethSupplyAmount;
    params.wbtcSupplyAmount = MAX_SUPPLY_AMOUNT;

    params.wbtcBorrowAmount = wbtcBorrowAmount;

    params.daiLP = spoke3.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke3.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke3.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke3
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.daiReserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.daiReserveId, true);
    }

    // Bob supply usdx into spoke3
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.usdxReserveId, true);
    }

    // Bob supply weth into spoke3
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.wethReserveId, bob, params.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.wethReserveId, true);
    }

    // Bob supply wbtc into spoke3
    Utils.spokeSupply(spoke3, params.wbtcReserveId, bob, params.wbtcSupplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, params.wbtcReserveId, true);

    // Bob draw wbtc
    if (params.wbtcBorrowAmount > 0) {
      Utils.spokeBorrow(spoke3, params.wbtcReserveId, bob, params.wbtcBorrowAmount, bob);
    }

    // Dai, usdx, and weth will each cover part of the debt
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

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke2].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke2].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke2].weth.reserveId;
    params.wbtcReserveId = spokeInfo[spoke2].wbtc.reserveId;
    params.dai2ReserveId = spokeInfo[spoke2].dai2.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.wethSupplyAmount = wethSupplyAmount;
    params.usdxSupplyAmount = usdxSupplyAmount;
    params.wbtcSupplyAmount = wbtcSupplyAmount;

    // Borrow all value in dai2
    params.dai2BorrowAmount = borrowAmount;

    params.daiLP = spoke2.getLiquidityPremium(params.daiReserveId);
    params.wethLP = spoke2.getLiquidityPremium(params.wethReserveId);
    params.usdxLP = spoke2.getLiquidityPremium(params.usdxReserveId);
    params.wbtcLP = spoke2.getLiquidityPremium(params.wbtcReserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (params.wbtcSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wbtcReserveId, bob, params.wbtcSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wbtcReserveId, true);
    }

    // Bob supply weth into spoke2
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wethReserveId, bob, params.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wethReserveId, true);
    }

    // Bob supply dai into spoke2
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.daiReserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.daiReserveId, true);
    }

    // Bob supply usdx into spoke2
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.usdxReserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, params.dai2ReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    setUsingAsCollateral(spoke2, bob, params.dai2ReserveId, true);

    // Bob draw dai2
    if (params.dai2BorrowAmount > 0) {
      Utils.spokeBorrow(spoke2, params.dai2ReserveId, bob, params.dai2BorrowAmount, bob);
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

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke2].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke2].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke2].weth.reserveId;
    params.wbtcReserveId = spokeInfo[spoke2].wbtc.reserveId;
    params.dai2ReserveId = spokeInfo[spoke2].dai2.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.wethSupplyAmount = wethSupplyAmount;
    params.usdxSupplyAmount = usdxSupplyAmount;
    params.wbtcSupplyAmount = wbtcSupplyAmount;

    // Borrow all value in dai2
    params.dai2BorrowAmount = borrowAmount;

    params.daiLP = spoke2.getLiquidityPremium(params.daiReserveId);
    params.wethLP = spoke2.getLiquidityPremium(params.wethReserveId);
    params.usdxLP = spoke2.getLiquidityPremium(params.usdxReserveId);
    params.wbtcLP = spoke2.getLiquidityPremium(params.wbtcReserveId);
    params.dai2LP = spoke2.getLiquidityPremium(params.dai2ReserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (params.wbtcSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wbtcReserveId, bob, params.wbtcSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wbtcReserveId, true);
    }

    // Bob supply weth into spoke2
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wethReserveId, bob, params.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wethReserveId, true);
    }

    // Bob supply dai into spoke2
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.daiReserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.daiReserveId, true);
    }

    // Bob supply usdx into spoke2
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.usdxReserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, params.dai2ReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    setUsingAsCollateral(spoke2, bob, params.dai2ReserveId, true);

    // Bob draw dai2
    if (params.dai2BorrowAmount > 0) {
      Utils.spokeBorrow(spoke2, params.dai2ReserveId, bob, params.dai2BorrowAmount, bob);
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

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke2].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke2].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke2].weth.reserveId;
    params.wbtcReserveId = spokeInfo[spoke2].wbtc.reserveId;
    params.dai2ReserveId = spokeInfo[spoke2].dai2.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.wethSupplyAmount = wethSupplyAmount;
    params.usdxSupplyAmount = usdxSupplyAmount;
    params.wbtcSupplyAmount = wbtcSupplyAmount;

    // Borrow all value in dai2
    params.dai2BorrowAmount = borrowAmount;

    params.daiLP = spoke2.getLiquidityPremium(params.daiReserveId);
    params.wethLP = spoke2.getLiquidityPremium(params.wethReserveId);
    params.usdxLP = spoke2.getLiquidityPremium(params.usdxReserveId);
    params.wbtcLP = spoke2.getLiquidityPremium(params.wbtcReserveId);
    params.dai2LP = spoke2.getLiquidityPremium(params.dai2ReserveId);

    params.daiLP = spoke2.getLiquidityPremium(params.daiReserveId);
    params.wethLP = spoke2.getLiquidityPremium(params.wethReserveId);
    params.usdxLP = spoke2.getLiquidityPremium(params.usdxReserveId);
    params.wbtcLP = spoke2.getLiquidityPremium(params.wbtcReserveId);
    params.dai2LP = spoke2.getLiquidityPremium(params.dai2ReserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (params.wbtcSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wbtcReserveId, bob, params.wbtcSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wbtcReserveId, true);
    }

    // Bob supply weth into spoke2
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wethReserveId, bob, params.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wethReserveId, true);
    }

    // Bob supply dai into spoke2
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.daiReserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.daiReserveId, true);
    }

    // Bob supply usdx into spoke2
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.usdxReserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, params.dai2ReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    setUsingAsCollateral(spoke2, bob, params.dai2ReserveId, true);

    // Bob draw dai2
    if (params.dai2BorrowAmount > 0) {
      Utils.spokeBorrow(spoke2, params.dai2ReserveId, bob, params.dai2BorrowAmount, bob);
    }

    // wbtc, weth, dai, and usdx will each cover part of the debt
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'user risk premium'
    );

    // Change the liquidity premium of wbtc
    spoke2.updateReserveConfig(
      params.wbtcReserveId,
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
    TestInfo memory params
  ) public {
    params.daiSupplyAmount = bound(params.daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    params.wethSupplyAmount = bound(params.wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    params.usdxSupplyAmount = bound(params.usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    params.wbtcSupplyAmount = bound(params.wbtcSupplyAmount, 0, MAX_SUPPLY_AMOUNT);

    params.daiBorrowAmount = bound(params.daiBorrowAmount, 0, params.daiSupplyAmount / 2);
    params.wethBorrowAmount = bound(params.wethBorrowAmount, 0, params.wethSupplyAmount / 2);
    params.usdxBorrowAmount = bound(params.usdxBorrowAmount, 0, params.usdxSupplyAmount / 2);
    params.wbtcBorrowAmount = bound(params.wbtcBorrowAmount, 0, params.wbtcSupplyAmount / 2);

    vm.assume(
      params.daiSupplyAmount +
        params.wethSupplyAmount +
        params.usdxSupplyAmount +
        params.wbtcSupplyAmount <=
        MAX_SUPPLY_AMOUNT
    );
    vm.assume(
      params.daiBorrowAmount +
        params.wethBorrowAmount +
        params.usdxBorrowAmount +
        params.wbtcBorrowAmount <=
        MAX_SUPPLY_AMOUNT / 2
    );

    params.daiPrice = bound(params.daiPrice, 0, 1e16);
    params.wethPrice = bound(params.wethPrice, 0, 1e16);
    params.usdxPrice = bound(params.usdxPrice, 0, 1e16);
    params.wbtcPrice = bound(params.wbtcPrice, 0, 1e16);

    params.daiLP = bound(params.daiLP, 0, 1000_00);
    params.wethLP = bound(params.wethLP, 0, 1000_00);
    params.usdxLP = bound(params.usdxLP, 0, 1000_00);
    params.wbtcLP = bound(params.wbtcLP, 0, 1000_00);

    // Bob supply dai into spoke2
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].dai.reserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].dai.reserveId, true);
    }

    // Bob supply weth into spoke2
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(
        spoke2,
        spokeInfo[spoke2].weth.reserveId,
        bob,
        params.wethSupplyAmount,
        bob
      );
      setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].weth.reserveId, true);
    }

    // Bob supply usdx into spoke2
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(
        spoke2,
        spokeInfo[spoke2].usdx.reserveId,
        bob,
        params.usdxSupplyAmount,
        bob
      );
      setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].usdx.reserveId, true);
    }

    // Bob supply wbtc into spoke2
    if (params.wbtcSupplyAmount > 0) {
      Utils.spokeSupply(
        spoke2,
        spokeInfo[spoke2].wbtc.reserveId,
        bob,
        params.wbtcSupplyAmount,
        bob
      );
      setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].wbtc.reserveId, true);
    }

    // Update prices
    oracle.setAssetPrice(daiAssetId, params.daiPrice);
    oracle.setAssetPrice(wethAssetId, params.wethPrice);
    oracle.setAssetPrice(usdxAssetId, params.usdxPrice);
    oracle.setAssetPrice(wbtcAssetId, params.wbtcPrice);

    // Update LPs
    spoke2.updateReserveConfig(
      spokeInfo[spoke2].dai.reserveId,
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: params.daiLP,
        borrowable: true,
        collateral: true
      })
    );
    spoke2.updateReserveConfig(
      spokeInfo[spoke2].weth.reserveId,
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: params.wethLP,
        borrowable: true,
        collateral: true
      })
    );
    spoke2.updateReserveConfig(
      spokeInfo[spoke2].usdx.reserveId,
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: params.usdxLP,
        borrowable: true,
        collateral: true
      })
    );
    spoke2.updateReserveConfig(
      spokeInfo[spoke2].wbtc.reserveId,
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: params.wbtcLP,
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

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke3].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke3].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke3].weth.reserveId;
    params.wbtcReserveId = spokeInfo[spoke3].wbtc.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.usdxSupplyAmount = usdxSupplyAmount;
    params.wethSupplyAmount = wethSupplyAmount;
    params.wbtcSupplyAmount = MAX_SUPPLY_AMOUNT;

    params.wbtcBorrowAmount = borrowAmount;

    params.daiLP = spoke3.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke3.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke3.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke3
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.daiReserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.daiReserveId, true);
    }

    // Bob supply usdx into spoke3
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.usdxReserveId, true);
    }

    // Bob supply weth into spoke3
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.wethReserveId, bob, params.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.wethReserveId, true);
    }

    // Bob supply wbtc into spoke3
    Utils.spokeSupply(spoke3, params.wbtcReserveId, bob, params.wbtcSupplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, params.wbtcReserveId, true);

    // Bob draw wbtc
    if (params.wbtcBorrowAmount > 0) {
      Utils.spokeBorrow(spoke3, params.wbtcReserveId, bob, params.wbtcBorrowAmount, bob);
    }

    // Dai, usdx, and weth will each cover part of the debt
    uint256 expectedUserRiskPremium = _calculateExpectedUserRP(bob, spoke3);

    assertEq(spoke3.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');

    // Get the base rate of wbtc
    uint256 baseRate = hub.getBaseInterestRate(wbtcAssetId);
    uint256 baseDebt = params.wbtcBorrowAmount;
    uint256 originalBaseDebt = params.wbtcBorrowAmount;
    (uint256 actualBaseDebt, uint256 actualPremium) = spoke3.getUserDebt(params.wbtcReserveId, bob);
    uint256 startTime = vm.getBlockTimestamp();

    assertEq(baseDebt, actualBaseDebt, 'user base debt');
    assertEq(actualPremium, 0, 'user outstanding premium');

    // Wait a year
    skip(365 days);

    // See if base debt of wbtc changes appropriately
    baseDebt = MathUtils.calculateLinearInterest(baseRate, uint40(startTime)).rayMul(baseDebt);
    (actualBaseDebt, actualPremium) = spoke3.getUserDebt(params.wbtcReserveId, bob);
    assertEq(baseDebt, actualBaseDebt, 'user base debt');

    // See if outstanding premium changes proportionally to user risk premium change
    uint256 premiumDebt = (baseDebt - originalBaseDebt).percentMul(expectedUserRiskPremium);
    assertEq(premiumDebt, actualPremium, 'user outstanding premium after interest accrual');

    // Since Bob is only user, reserve debt should be equal to user debt
    (uint256 reserveDebt, uint256 reservePremium) = spoke3.getReserveDebt(params.wbtcReserveId);
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
    usdxSupplyAmount = bound(usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wethSupplyAmount = bound(wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT);

    wbtcBorrowamount = bound(wbtcBorrowamount, 0, totalBorrowAmount);
    wethBorrowAmount = bound(wethBorrowAmount, 0, totalBorrowAmount);

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke3].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke3].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke3].weth.reserveId;
    params.wbtcReserveId = spokeInfo[spoke3].wbtc.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.usdxSupplyAmount = usdxSupplyAmount;
    params.wethSupplyAmount = wethSupplyAmount;
    params.wbtcSupplyAmount = MAX_SUPPLY_AMOUNT;

    params.wbtcBorrowAmount = wbtcBorrowamount;
    params.wethBorrowAmount = wethBorrowAmount;

    params.daiLP = spoke3.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke3.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke3.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke3
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.daiReserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.daiReserveId, true);
    }

    // Bob supply usdx into spoke3
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.usdxReserveId, true);
    }

    // Bob supply weth into spoke3
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.wethReserveId, bob, params.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.wethReserveId, true);
    }

    // Bob supply wbtc into spoke3
    Utils.spokeSupply(spoke3, params.wbtcReserveId, bob, params.wbtcSupplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, params.wbtcReserveId, true);

    // Alice supply remaining weth into spoke3
    if (MAX_SUPPLY_AMOUNT - params.wethSupplyAmount > 0) {
      Utils.spokeSupply(
        spoke3,
        params.wethReserveId,
        alice,
        MAX_SUPPLY_AMOUNT - params.wethSupplyAmount,
        alice
      );
    }

    // Bob draw wbtc
    if (params.wbtcBorrowAmount > 0) {
      Utils.spokeBorrow(spoke3, params.wbtcReserveId, bob, params.wbtcBorrowAmount, bob);
    }

    // Bob draw weth
    if (params.wethBorrowAmount > 0) {
      Utils.spokeBorrow(spoke3, params.wethReserveId, bob, params.wethBorrowAmount, bob);
    }

    uint256 expectedUserRiskPremium = _calculateExpectedUserRP(bob, spoke3);

    assertEq(spoke3.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');

    RateChecks memory rateChecks;

    // Get the base rate of wbtc
    rateChecks.baseRateWbtc = hub.getBaseInterestRate(wbtcAssetId);
    rateChecks.baseDebt = params.wbtcBorrowAmount;
    rateChecks.originalBaseDebtWbtc = params.wbtcBorrowAmount;
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke3.getUserDebt(
      params.wbtcReserveId,
      bob
    );
    rateChecks.startTime = vm.getBlockTimestamp();

    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'user base debt');
    assertEq(rateChecks.actualPremium, 0, 'user outstanding premium');

    // Get the base rate of weth
    rateChecks.baseRateWeth = hub.getBaseInterestRate(wethAssetId);
    rateChecks.baseDebt = params.wethBorrowAmount;
    rateChecks.originalBaseDebtWeth = params.wethBorrowAmount;
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke3.getUserDebt(
      params.wethReserveId,
      bob
    );

    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'user base debt');
    assertEq(rateChecks.actualPremium, 0, 'user outstanding premium');

    // Wait a year
    skip(365 days);

    // See if base debt of wbtc changes appropriately
    rateChecks.baseDebt = MathUtils
      .calculateLinearInterest(rateChecks.baseRateWbtc, uint40(rateChecks.startTime))
      .rayMul(rateChecks.originalBaseDebtWbtc);
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke3.getUserDebt(
      params.wbtcReserveId,
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
    (rateChecks.reserveDebt, rateChecks.reservePremium) = spoke3.getReserveDebt(
      params.wbtcReserveId
    );
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
      params.wethReserveId,
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
    (rateChecks.reserveDebt, rateChecks.reservePremium) = spoke3.getReserveDebt(
      params.wethReserveId
    );
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

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke1.getLiquidityPremium(params.usdxReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, bobDaiSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, bobUsdxSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Alice supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, alice, aliceDaiSupplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, params.daiReserveId, true);

    // Alice supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, alice, aliceUsdxSupplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, params.usdxReserveId, true);

    // Bob draw dai
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, bobDaiBorrowAmount, bob);

    // Bob draw usdx
    Utils.spokeBorrow(spoke1, params.usdxReserveId, bob, bobUsdxBorrowAmount, bob);

    // Alice draw dai
    Utils.spokeBorrow(spoke1, params.daiReserveId, alice, aliceDaiBorrowAmount, alice);

    // Alice draw usdx
    Utils.spokeBorrow(spoke1, params.usdxReserveId, alice, aliceUsdxBorrowAmount, alice);

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
      params.daiReserveId,
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
      params.usdxReserveId,
      bob
    );

    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'Bob usdx debt before');
    assertEq(rateChecks.actualPremium, 0, 'Bob usdx premium before');

    // Check Alice's starting dai debt
    rateChecks.baseDebt = aliceDaiBorrowAmount;
    rateChecks.originalBaseDebtDai = aliceDaiBorrowAmount;
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      params.daiReserveId,
      alice
    );

    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'Alice dai debt before');
    assertEq(rateChecks.actualPremium, 0, 'Alice dai premium before');

    // Check Alice's starting usdx debt
    rateChecks.baseDebt = aliceUsdxBorrowAmount;
    rateChecks.originalBaseDebtWeth = aliceUsdxBorrowAmount;
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      params.usdxReserveId,
      alice
    );

    assertEq(rateChecks.baseDebt, rateChecks.actualBaseDebt, 'Alice usdx debt before');
    assertEq(rateChecks.actualPremium, 0, 'Alice usdx premium before');

    // Wait a year
    skip(365 days);

    Debts memory debts;

    // See if Bob's base debt of dai changes appropriately
    debts.bobDaiBaseDebtAfter = MathUtils
      .calculateLinearInterest(rateChecks.baseRateDai, uint40(rateChecks.startTime))
      .rayMul(bobDaiBorrowAmount);
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      params.daiReserveId,
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
      params.usdxReserveId,
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
      params.daiReserveId,
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
      params.usdxReserveId,
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
    (rateChecks.reserveDebt, rateChecks.reservePremium) = spoke1.getReserveDebt(
      params.daiReserveId
    );

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
      spoke1.getReserveRiskPremium(params.daiReserveId),
      expectedDaiRiskPremium,
      'dai reserve risk premium'
    );

    // Check reserve debt for usdx
    (rateChecks.reserveDebt, rateChecks.reservePremium) = spoke1.getReserveDebt(
      params.usdxReserveId
    );

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
      spoke1.getReserveRiskPremium(params.usdxReserveId),
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
    Utils.spokeRepay(spoke1, params.daiReserveId, alice, aliceDaiBorrowAmount / 2);

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
      params.daiReserveId,
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
      params.usdxReserveId,
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
      params.daiReserveId,
      bob
    );
    assertEq(rateChecks.actualBaseDebt, debts.bobDaiBaseDebtAfter, 'bob dai base debt after');
    assertEq(rateChecks.actualPremium, debts.bobDaiPremiumDebtAfter, 'bob dai premium debt after');
    debts.bobTotalDaiDebt = debts.bobDaiBaseDebtAfter + debts.bobDaiPremiumDebtAfter;

    // Bob's debts on usdx should remain unchanged
    (rateChecks.actualBaseDebt, rateChecks.actualPremium) = spoke1.getUserDebt(
      params.usdxReserveId,
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
      spoke1.getReserveRiskPremium(params.daiReserveId),
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

  function _normalizedValue(uint256 amount, uint256 assetId) internal view returns (uint256) {
    return
      (amount * oracle.getAssetPrice(assetId) * WadRayMath.WAD) /
      (10 ** hub.getAssetConfig(assetId).decimals);
  }

  function _calculateExpectedUserRP(address user, ISpoke spoke) internal view returns (uint256) {
    uint256 assetId;
    uint256 totalDebt;
    uint256 suppliedReservesCount;
    uint256 userRP;
    DataTypes.UserPosition memory userPosition;

    // Find all reserves user has supplied, adding up total debt
    for (uint256 reserveId; reserveId < spoke.reserveCount(); ++reserveId) {
      if (spoke.getUsingAsCollateral(reserveId, user)) {
        ++suppliedReservesCount;
      }
      (assetId, ) = getAssetByReserveId(spoke, reserveId);
      totalDebt += _normalizedValue(spoke.getUserCumulativeDebt(reserveId, user), assetId);
    }

    if (totalDebt == 0) {
      return 0;
    }

    // Gather up list of reserves as collateral to sort by LP
    KeyValueListInMemory.List memory reserveLP = KeyValueListInMemory.init(suppliedReservesCount);
    uint256 idx = 0;
    for (uint256 reserveId; reserveId < spoke.reserveCount(); ++reserveId) {
      if (spoke.getUsingAsCollateral(reserveId, user)) {
        reserveLP.add(idx, spoke.getLiquidityPremium(reserveId), reserveId);
        ++idx;
      }
    }

    // Sort supplied reserves by LP
    reserveLP.sortByKey();

    // While user's normalized debt amount is non-zero, iterate through supplied reserves, and add up LP
    idx = 0;
    uint256 originalTotalDebt = totalDebt;
    while (totalDebt > 0) {
      (uint256 lp, uint256 reserveId) = reserveLP.get(idx);
      userPosition = getUserInfo(spoke, user, reserveId);
      (assetId, ) = getAssetByReserveId(spoke, reserveId);
      uint256 supplyAmount = _normalizedValue(
        hub.convertToAssets(assetId, userPosition.suppliedShares),
        assetId
      );

      if (supplyAmount >= totalDebt) {
        userRP += totalDebt * lp;
        break;
      } else {
        userRP += supplyAmount * lp;
        totalDebt -= supplyAmount;
      }

      ++idx;
    }

    return userRP / originalTotalDebt;
  }
}
