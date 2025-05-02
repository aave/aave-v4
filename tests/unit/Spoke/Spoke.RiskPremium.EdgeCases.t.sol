// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRiskPremiumEdgeCasesTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  /// Bob supplies 2 collateral assets, borrows an amount such that both of them cover it, and then repays any nonzero amount of the higher lp one
  /// Bob's user risk premium should decrease or remain same after repay
  /// @dev due to rounding within risk premium calc, repaying doesn't guarantee user rp decrease
  function test_riskPremium_nonIncreasingAfterRepay(
    uint256 usdxSupplyAmount,
    uint256 daiSupplyAmount,
    uint256 borrowAmount,
    uint256 repayAmount
  ) public {
    // Make usdx liquidity premium 10% so it's the lower lp reserve compared to dai
    updateLiquidityPremium(spoke2, _usdxReserveId(spoke2), 10_00);
    assertLt(
      spoke2.getLiquidityPremium(_usdxReserveId(spoke2)),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Usdx lower lp than dai'
    );

    daiSupplyAmount = bound(daiSupplyAmount, 4, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 3, MAX_SUPPLY_AMOUNT / 2);
    // Force least lp asset supply amount to be less than borrow amount, so borrow covered by 2 collaterals at least
    // Here it will be due to decimals of usdx vs dai
    usdxSupplyAmount = bound(usdxSupplyAmount, 1, borrowAmount);
    repayAmount = bound(repayAmount, 2, borrowAmount);

    // Deal bob dai to cover dai and dai2 supply
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Supply max dai2, the highest lp asset, to allow borrowing without affecting RP
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: MAX_SUPPLY_AMOUNT,
      onBehalfOf: bob
    });

    // Bob supplies usdx and dai collaterals
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _usdxReserveId(spoke2),
      user: bob,
      amount: usdxSupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: daiSupplyAmount,
      onBehalfOf: bob
    });

    // Bob borrows dai2
    Utils.borrow({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // Get Bob's risk premium
    uint256 riskPremium = spoke2.getUserRiskPremium(bob);

    // Now bob repays dai2
    deal(address(tokenList.dai), bob, repayAmount);
    Utils.repay({spoke: spoke2, reserveId: _dai2ReserveId(spoke2), user: bob, amount: repayAmount});

    assertLe(
      spoke2.getUserRiskPremium(bob),
      riskPremium,
      'Risk premium should decrease or remain same after repaying higher lp asset'
    );
  }

  /// Supply dai2 and dai as collateral, borrow dai2, then remove dai as collateral and risk premium should increase
  function test_riskPremium_increasesAfterCollateralRemoval(
    uint256 daiSupplyAmount,
    uint256 borrowAmount
  ) public {
    uint256 dai2SupplyAmount = MAX_SUPPLY_AMOUNT;
    daiSupplyAmount = bound(daiSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // Deal bob dai to cover dai and dai2 supply
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supplies dai and dai2 collaterals
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: dai2SupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: daiSupplyAmount,
      onBehalfOf: bob
    });

    // Bob borrows dai2
    Utils.borrow({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // Get Bob's risk premium
    uint256 riskPremium = spoke2.getUserRiskPremium(bob);

    // Now bob disables dai as collateral
    setUsingAsCollateral({
      spoke: spoke2,
      user: bob,
      reserveId: _daiReserveId(spoke2),
      usingAsCollateral: false
    });

    assertGt(
      spoke2.getUserRiskPremium(bob),
      riskPremium,
      'Risk premium should increase after disabling lower LP reserve as collateral'
    );
  }

  /// Supply dai2 and dai as collateral, borrow dai2, then withdraw dai as collateral and risk premium should increase
  function test_riskPremium_increasesAfterWithdrawal(
    uint256 daiSupplyAmount,
    uint256 borrowAmount
  ) public {
    uint256 dai2SupplyAmount = MAX_SUPPLY_AMOUNT;
    daiSupplyAmount = bound(daiSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // Deal bob dai to cover dai and dai2 supply
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supplies dai and dai2 collaterals
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: dai2SupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: daiSupplyAmount,
      onBehalfOf: bob
    });

    // Bob borrows dai2
    Utils.borrow({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // Get Bob's risk premium
    uint256 riskPremium = spoke2.getUserRiskPremium(bob);

    // Now bob withdraws dai
    Utils.withdraw({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: daiSupplyAmount,
      onBehalfOf: bob
    });

    assertGt(
      spoke2.getUserRiskPremium(bob),
      riskPremium,
      'Risk premium should increase after withdrawing lower LP collateral'
    );
  }

  /// Supply dai2 and dai as collateral, borrow dai2, then fuzz withdraw dai as collateral and risk premium should increase or remain the same
  function test_riskPremium_fuzz_nonDecreasingAfterWithdrawal(
    uint256 daiSupplyAmount,
    uint256 borrowAmount,
    uint256 withdrawAmount
  ) public {
    uint256 dai2SupplyAmount = MAX_SUPPLY_AMOUNT;
    daiSupplyAmount = bound(daiSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    withdrawAmount = bound(withdrawAmount, 1, daiSupplyAmount);

    // Deal bob dai to cover dai and dai2 supply
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supplies dai and dai2 collaterals
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: dai2SupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: daiSupplyAmount,
      onBehalfOf: bob
    });

    // Bob borrows dai2
    Utils.borrow({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // Get Bob's risk premium
    uint256 riskPremium = spoke2.getUserRiskPremium(bob);

    // Now bob withdraws dai
    Utils.withdraw({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: withdrawAmount,
      onBehalfOf: bob
    });

    assertGe(
      spoke2.getUserRiskPremium(bob),
      riskPremium,
      'Risk premium should increase or remain same after withdrawing fuzzed amount of lower LP collateral'
    );
  }

  /// User risk premium changes because of collateral accrual (no debt change)
  /// Debt is initially covered by 2 collaterals, then 1 collateral becomes enough to cover the debt due to interest accrual
  function test_riskPremium_decreasesAfterCollateralAccrual() public {
    uint256 wbtcSupplyAmount = 1e8;
    uint256 wethSupplyAmount = 100e18;
    uint256 daiBorrowAmount = 50500e18; // More than price of 1 wbtc

    // Deploy liquidity for dai borrow
    _deployLiquidity(spoke1, _daiReserveId(spoke1), daiBorrowAmount);

    // Bob supplies wbtc and weth collaterals
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      user: bob,
      amount: wbtcSupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      user: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Bob borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

    // Alice borrows wbtc to accrue interest
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      user: alice,
      amount: wethSupplyAmount,
      onBehalfOf: alice
    });
    Utils.borrow({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      user: alice,
      amount: wbtcSupplyAmount,
      onBehalfOf: alice
    });

    // Bob's current risk premium should be greater than liquidity premium of wbtc, since debt is not fully covered by it
    assertGt(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wbtcReserveId(spoke1)),
      'Bob user rp after borrow'
    );

    // Mock calls to ensure dai debt does not does not grow due to interest
    DataTypes.UserPosition memory bobPosition = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    vm.mockCall(
      address(hub),
      abi.encodeWithSelector(
        LiquidityHub.convertToDrawnAssets.selector,
        daiAssetId,
        bobPosition.baseDrawnShares
      ),
      abi.encode(daiBorrowAmount)
    );
    vm.mockCall(
      address(hub),
      abi.encodeWithSelector(
        LiquidityHub.convertToDrawnAssets.selector,
        daiAssetId,
        bobPosition.premiumDrawnShares
      ),
      abi.encode(bobPosition.premiumOffset)
    );

    skip(365 days);

    // Ensure Bob's debt amount does not change (we mocked calls to ensure it doesn't)
    (uint256 bobBaseDebt, uint256 bobPremiumDebt) = spoke1.getUserDebt(_daiReserveId(spoke1), bob);
    assertEq(bobBaseDebt, daiBorrowAmount, 'Bob base debt after 1 year');
    assertEq(bobPremiumDebt, 0, 'Bob premium debt after 1 year');
    uint256 bobDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    assertEq(bobDaiDebt, daiBorrowAmount, 'Bob dai total debt after 1 year');

    // Check Bob's wbtc collateral amount is now enough to cover his debt
    uint256 wbtcSupplied = spoke1.getUserSuppliedAmount(_wbtcReserveId(spoke1), bob);
    assertGt(
      _getValueInBaseCurrency(wbtcAssetId, wbtcSupplied),
      _getValueInBaseCurrency(daiAssetId, bobDaiDebt),
      'Bob wbtc collateral exceeds dai debt after 1 year'
    );

    // Now since wbtc is enough to cover the debt due to interest accrual, Bob's RP should equal LP of wbtc
    assertEq(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wbtcReserveId(spoke1)),
      'Bob user risk premium after collateral accrual'
    );
  }

  /// Debt is initially covered by 2 collaterals (dai + dai2), then 1 collateral becomes enough to cover the debt due to interest accrual
  function test_riskPremium_fuzz_nonIncreasesAfterCollateralAccrual(
    uint256 daiSupplyAmount,
    uint40 skipTime
  ) public {
    daiSupplyAmount = bound(daiSupplyAmount, 1e18, MAX_SUPPLY_AMOUNT / 2 - 2); // Leave some room to allow borrowing more than this supply, and for Alice borrow
    uint256 daiBorrowAmount = daiSupplyAmount + 1; // Borrow more than dai supply amount so 2 collaterals cover debt
    uint256 dai2SupplyAmount = MAX_SUPPLY_AMOUNT;
    skipTime = uint40(bound(skipTime, 365 days, MAX_SKIP_TIME)); // At least skip one year to ensure sufficient accrual

    // Deal bob dai to cover dai and dai2 supply
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supplies dai and dai2 collaterals
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: daiSupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: dai2SupplyAmount,
      onBehalfOf: bob
    });

    // Deploy liquidity for dai borrows
    _deployLiquidity(spoke2, _daiReserveId(spoke2), MAX_SUPPLY_AMOUNT - daiBorrowAmount - 1);

    // Bob borrows dai
    Utils.borrow({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

    // Alice borrows dai to accrue interest
    uint256 aliceCollateralAmount = _calcMinimumCollAmount(
      spoke2,
      _wethReserveId(spoke2),
      _daiReserveId(spoke2),
      daiBorrowAmount
    );
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _wethReserveId(spoke2),
      user: alice,
      amount: aliceCollateralAmount,
      onBehalfOf: alice
    });
    Utils.borrow({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: alice,
      amount: 1,
      onBehalfOf: alice
    });

    // Bob's current risk premium should be greater than or equal liquidity premium of dai, since debt is not fully covered by it (and due to rounding)
    assertGe(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user rp after borrow'
    );

    // Mock calls to ensure dai debt does not does not grow due to interest
    DataTypes.UserPosition memory bobPosition = spoke2.getUserPosition(_daiReserveId(spoke2), bob);
    vm.mockCall(
      address(hub),
      abi.encodeWithSelector(
        LiquidityHub.convertToDrawnAssets.selector,
        daiAssetId,
        bobPosition.baseDrawnShares
      ),
      abi.encode(daiBorrowAmount)
    );
    vm.mockCall(
      address(hub),
      abi.encodeWithSelector(
        LiquidityHub.convertToDrawnAssets.selector,
        daiAssetId,
        bobPosition.premiumDrawnShares
      ),
      abi.encode(bobPosition.premiumOffset)
    );

    skip(skipTime);

    // Ensure Bob's debt amount does not change (we mocked calls to ensure it doesn't)
    (uint256 bobBaseDebt, uint256 bobPremiumDebt) = spoke2.getUserDebt(_daiReserveId(spoke2), bob);
    assertEq(bobBaseDebt, daiBorrowAmount, 'Bob base debt after 1 year');
    assertEq(bobPremiumDebt, 0, 'Bob premium debt after 1 year');
    uint256 bobDaiDebt = spoke2.getUserTotalDebt(_daiReserveId(spoke2), bob);
    assertEq(bobDaiDebt, daiBorrowAmount, 'Bob dai total debt after 1 year');

    // Check Bob's dai collateral amount is now enough to cover his debt
    uint256 daiSupplied = spoke2.getUserSuppliedAmount(_daiReserveId(spoke2), bob);
    assertGt(
      _getValueInBaseCurrency(daiAssetId, daiSupplied),
      _getValueInBaseCurrency(daiAssetId, bobDaiDebt),
      'Bob dai collateral exceeds dai debt after 1 year'
    );

    // Now since dai is enough to cover the debt due to interest accrual, Bob's RP should equal LP of dai
    assertEq(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user risk premium after collateral accrual'
    );
  }

  /// Bob's debt initially fully covered by wbtc collateral. Then interest accrues, so debt must be covered by 2 collaterals
  function test_riskPremium_increasesAfterDebtAccrual() public {
    uint256 wbtcSupplyAmount = 1e8;
    uint256 wethSupplyAmount = 100e18;
    uint256 daiBorrowAmount = 50000e18; // The price of 1 wbtc

    // Deploy liquidity for dai borrow
    _deployLiquidity(spoke1, _daiReserveId(spoke1), daiBorrowAmount);

    // Bob supplies wbtc and weth collaterals
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      user: bob,
      amount: wbtcSupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      user: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Bob borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

    // Bob's current risk premium should be equal to liquidity premium of wbtc, since debt is fully covered by it
    assertEq(
      _getValueInBaseCurrency(wbtcAssetId, wbtcSupplyAmount),
      _getValueInBaseCurrency(daiAssetId, daiBorrowAmount),
      'Bob wbtc collateral equals dai debt'
    );
    assertEq(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wbtcReserveId(spoke1)),
      'Bob user rp after borrow'
    );

    skip(365 days);

    // Ensure that Bob's collateral amount is unchanged
    uint256 bobWbtcCollateral = spoke1.getUserSuppliedAmount(_wbtcReserveId(spoke1), bob);
    assertEq(bobWbtcCollateral, wbtcSupplyAmount, 'Bob wbtc collateral after 1 year');

    // Ensure debt has grown beyond wbtc collateral
    uint256 bobDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    assertGt(
      _getValueInBaseCurrency(daiAssetId, bobDebt),
      _getValueInBaseCurrency(wbtcAssetId, bobWbtcCollateral),
      'Bob dai debt exceeds wbtc collateral after 1 year'
    );

    // Now since Bob's wbtc collateral is less than debt due to interest accrual, Bob's RP is greater than LP of wbtc
    assertGt(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wbtcReserveId(spoke1)),
      'Bob user risk premium after collateral accrual'
    );
  }

  /// Bob's weth debt initially fully covered by dai collateral. Then interest accrues, so debt must be covered by 2 collaterals (dai + dai2)
  function test_riskPremium_fuzz_increasesAfterDebtAccrual(
    uint256 borrowAmount,
    uint40 skipTime
  ) public {
    borrowAmount = bound(borrowAmount, 1e18, MAX_SUPPLY_AMOUNT / 4000); // Allow room for dai supply to cover weth debt (2000x)
    uint256 daiSupplyAmount = borrowAmount * 2000; // Dai collateral will fully cover initial borrow (weth = 2000 dai)
    uint256 dai2SupplyAmount = MAX_SUPPLY_AMOUNT;
    skipTime = uint40(bound(skipTime, 365 days, MAX_SKIP_TIME)); // At least skip one year to ensure sufficient accrual

    // Deal bob dai to cover dai and dai2 supply
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supplies dai and dai2 collaterals
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: daiSupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: dai2SupplyAmount,
      onBehalfOf: bob
    });

    // Deploy weth liquidity for borrow
    _deployLiquidity(spoke2, _wethReserveId(spoke2), borrowAmount);

    // Bob borrows weth
    Utils.borrow({
      spoke: spoke2,
      reserveId: _wethReserveId(spoke2),
      user: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // Bob's current risk premium should be equal to liquidity premium of dai, since debt is fully covered by it
    assertEq(
      _getValueInBaseCurrency(daiAssetId, daiSupplyAmount),
      _getValueInBaseCurrency(wethAssetId, borrowAmount),
      'Bob dai collateral equals weth debt'
    );
    assertEq(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user rp after borrow'
    );

    skip(skipTime);

    // Ensure debt has grown beyond dai collateral
    uint256 bobDebt = spoke2.getUserTotalDebt(_wethReserveId(spoke2), bob);
    assertGt(
      _getValueInBaseCurrency(wethAssetId, bobDebt),
      _getValueInBaseCurrency(daiAssetId, spoke2.getUserSuppliedAmount(_daiReserveId(spoke2), bob)),
      'Bob weth debt exceeds dai collateral after time skip'
    );

    // Now since Bob's dai collateral is less than debt due to interest accrual, Bob's RP is greater than LP of dai
    assertGt(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user risk premium after collateral accrual'
    );
  }

  /// Initially debt is covered by 1 collateral, both debt and collateral accrue at different rates, such that finally debt is covered by 2 collaterals
  function test_riskPremium_changesAfterAccrual() public {
    uint256 wethSupplyAmount = 2e18;
    uint256 daiSupplyAmount = 10000e18;
    uint256 daiBorrowAmount = 4000e18; // The price of 2 eth

    // Bob supplies weth and dai collaterals
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      user: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: daiSupplyAmount,
      onBehalfOf: bob
    });

    // Bob borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

    // Bob's current risk premium should be equal to liquidity premium of weth, since debt is fully covered by it
    assertEq(
      _getValueInBaseCurrency(wethAssetId, wethSupplyAmount),
      _getValueInBaseCurrency(daiAssetId, daiBorrowAmount),
      'Bob weth collateral equals dai debt'
    );
    assertEq(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wethReserveId(spoke1)),
      'Bob user rp after borrow'
    );

    // Alice borrows weth to accrue interest over the next year
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: alice,
      amount: daiSupplyAmount,
      onBehalfOf: alice
    });
    Utils.borrow({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      user: alice,
      amount: wethSupplyAmount,
      onBehalfOf: alice
    });

    skip(365 days);

    // Ensure that Bob's collateral amount is changed
    uint256 bobWethCollateral = spoke1.getUserSuppliedAmount(_wethReserveId(spoke1), bob);
    assertGt(bobWethCollateral, wethSupplyAmount, 'Bob weth collateral after 1 year');

    // Ensure debt has grown beyond weth collateral
    uint256 bobDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    assertGt(
      _getValueInBaseCurrency(daiAssetId, bobDebt),
      _getValueInBaseCurrency(wethAssetId, bobWethCollateral),
      'Bob dai debt exceeds weth collateral after 1 year'
    );

    // Now Bob's RP should be greater than LP of weth, since debt is not fully covered by it
    assertGt(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wethReserveId(spoke1)),
      'Bob user risk premium after collateral accrual'
    );
  }

  /// Initially debt (weth) is covered by 1 collateral (dai), both debt and collateral accrue at different rates, such that finally debt is covered by 2 collaterals
  function test_riskPremium_fuzz_changesAfterAccrual(
    uint256 wethBorrowAmount,
    uint40 skipTime
  ) public {
    uint256 dai2SupplyAmount = MAX_SUPPLY_AMOUNT;
    wethBorrowAmount = bound(wethBorrowAmount, 1e18, MAX_SUPPLY_AMOUNT / 4000); // Allow room for dai supply to cover weth debt (2000x)
    uint256 daiSupplyAmount = wethBorrowAmount * 2000; // Dai collateral will fully cover initial borrow (weth = 2000 dai)
    skipTime = uint40(bound(skipTime, 365 days, MAX_SKIP_TIME)); // At least skip one year to ensure sufficient accrual

    // Deal bob dai to cover dai and dai2 supply
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supplies dai and dai2 collaterals
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: daiSupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: dai2SupplyAmount,
      onBehalfOf: bob
    });

    // Deploy weth liquidity for borrow
    _deployLiquidity(spoke2, _wethReserveId(spoke2), wethBorrowAmount);

    // Bob borrows weth
    Utils.borrow({
      spoke: spoke2,
      reserveId: _wethReserveId(spoke2),
      user: bob,
      amount: wethBorrowAmount,
      onBehalfOf: bob
    });

    // Bob's current risk premium should be equal to liquidity premium of dai, since debt is fully covered by it
    assertEq(
      _getValueInBaseCurrency(daiAssetId, daiSupplyAmount),
      _getValueInBaseCurrency(wethAssetId, wethBorrowAmount),
      'Bob weth collateral equals dai debt'
    );
    assertEq(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user rp after borrow'
    );

    // Alice borrows dai to accrue interest over the next year
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _wbtcReserveId(spoke2),
      user: alice,
      amount: 1e8,
      onBehalfOf: alice
    });
    Utils.borrow({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: alice,
      amount: 1,
      onBehalfOf: alice
    });

    skip(skipTime);

    // Ensure that Bob's collateral amount has changed
    uint256 bobDaiCollateral = spoke2.getUserSuppliedAmount(_daiReserveId(spoke2), bob);
    assertGt(bobDaiCollateral, daiSupplyAmount, 'Bob dai collateral after 1 year');

    // Ensure Bob's weth debt has grown beyond dai collateral
    uint256 bobDebt = spoke2.getUserTotalDebt(_wethReserveId(spoke2), bob);
    assertGt(
      _getValueInBaseCurrency(wethAssetId, bobDebt),
      _getValueInBaseCurrency(daiAssetId, bobDaiCollateral),
      'Bob weth debt exceeds dai collateral after 1 year'
    );

    // Now Bob's RP should be greater than LP of dai, since debt is not fully covered by it
    assertGt(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user risk premium after collateral accrual'
    );
  }

  /// Initially debt is covered by 1 collateral, then due to borrowing more, debt is covered by 2 collaterals
  function test_riskPremium_borrowingMoreIncreasesRP() public {
    uint256 wbtcSupplyAmount = 1e8;
    uint256 wethSupplyAmount = 100e18;
    uint256 daiBorrowAmount = 50000e18; // The price of 1 wbtc
    uint256 additionalDaiBorrowAmount = 1000e18;

    // Deploy liquidity for dai borrow
    _deployLiquidity(spoke1, _daiReserveId(spoke1), daiBorrowAmount + additionalDaiBorrowAmount);

    // Bob supplies wbtc and weth collaterals
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      user: bob,
      amount: wbtcSupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      user: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Bob borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

    // Bob's current risk premium should be equal to liquidity premium of wbtc, since debt is fully covered by it
    assertEq(
      _getValueInBaseCurrency(wbtcAssetId, wbtcSupplyAmount),
      _getValueInBaseCurrency(daiAssetId, daiBorrowAmount),
      'Bob wbtc collateral equals dai debt'
    );
    assertEq(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wbtcReserveId(spoke1)),
      'Bob user rp after borrow'
    );

    // Bob borrows more dai to increase debt position
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: additionalDaiBorrowAmount,
      onBehalfOf: bob
    });

    // Now wbtc collateral is insufficient to cover the debt
    assertLt(
      _getValueInBaseCurrency(wbtcAssetId, wbtcSupplyAmount),
      _getValueInBaseCurrency(daiAssetId, spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob)),
      'Bob wbtc collateral less than dai debt'
    );

    // So now risk premium has increased
    assertGt(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wbtcReserveId(spoke1)),
      'Bob user risk premium after borrowing more'
    );
  }

  /// Initially debt is covered by 1 collateral (dai), then due to borrowing more, debt is covered by 2 collaterals (dai + dai2)
  function test_riskPremium_fuzz_borrowingMoreNonDecreasesRP(
    uint256 initialBorrowAmount,
    uint256 additionalBorrowAmount
  ) public {
    initialBorrowAmount = bound(initialBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2 - 1); // leave some space for additional borrow
    uint256 daiSupplyAmount = initialBorrowAmount; // Dai collateral will fully cover initial borrow
    uint256 dai2SupplyAmount = MAX_SUPPLY_AMOUNT;
    additionalBorrowAmount = bound(additionalBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // Deal bob dai to cover dai and dai2 supply
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supplies dai and dai2 collaterals
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: daiSupplyAmount,
      onBehalfOf: bob
    });
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _dai2ReserveId(spoke2),
      user: bob,
      amount: dai2SupplyAmount,
      onBehalfOf: bob
    });

    // Bob borrows dai
    Utils.borrow({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: initialBorrowAmount,
      onBehalfOf: bob
    });

    // Bob's current risk premium should be equal to liquidity premium of dai, since debt is fully covered by it
    assertEq(
      _getValueInBaseCurrency(daiAssetId, daiSupplyAmount),
      _getValueInBaseCurrency(daiAssetId, initialBorrowAmount),
      'Bob dai collateral equals dai debt'
    );
    assertEq(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user rp after borrow'
    );

    // Deploy enough liquidity for additional borrow
    _deployLiquidity(spoke2, _daiReserveId(spoke2), additionalBorrowAmount);

    // Bob borrows more dai to increase debt position
    Utils.borrow({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: bob,
      amount: additionalBorrowAmount,
      onBehalfOf: bob
    });

    // Now dai collateral is insufficient to cover the debt
    assertLt(
      _getValueInBaseCurrency(daiAssetId, daiSupplyAmount),
      _getValueInBaseCurrency(daiAssetId, spoke2.getUserTotalDebt(_daiReserveId(spoke2), bob)),
      'Bob wbtc collateral less than dai debt'
    );

    // So now risk premium has increased or remained same
    assertGe(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user risk premium after borrowing more'
    );
  }

  /// Initially 1 higher LP collateral covers debt, then supply lower LP collateral, and RP should decrease
  function test_riskPremium_supplyingLowerLPCollateral_decreasesRP() public {
    uint256 wbtcSupplyAmount = 1e8;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = 10000e18; // The price of 5 weth

    // Deploy liquidity for dai borrow
    _deployLiquidity(spoke1, _daiReserveId(spoke1), daiBorrowAmount);

    // Bob supplies weth collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      user: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Bob borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

    // Bob's current risk premium should be equal to liquidity premium of weth, since debt is fully covered by it
    assertGt(
      _getValueInBaseCurrency(wethAssetId, wethSupplyAmount),
      _getValueInBaseCurrency(daiAssetId, daiBorrowAmount),
      'Bob weth collateral enough to cover dai debt'
    );
    assertEq(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wethReserveId(spoke1)),
      'Bob user rp after borrow matches weth lp'
    );

    // Bob supplies lower LP collateral (wbtc)
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      user: bob,
      amount: wbtcSupplyAmount,
      onBehalfOf: bob
    });

    // Now risk premium should be less than LP of weth
    assertLt(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wethReserveId(spoke1)),
      'Bob user risk premium after supplying lower LP collateral'
    );
  }

  /// Supply max of higher LP collateral, borrow any amount, then supply any amount of lower LP collateral and RP should not increase
  function test_riskPremium_fuzz_supplyingLowerLPCollateral_nonIncreasesRP(
    uint256 wbtcSupplyAmount,
    uint256 borrowAmount
  ) public {
    uint256 wethSupplyAmount = MAX_SUPPLY_AMOUNT;
    wbtcSupplyAmount = bound(wbtcSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    // Deploy liquidity for dai borrow
    _deployLiquidity(spoke1, _daiReserveId(spoke1), borrowAmount);

    // Bob supplies max weth collateral
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      user: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Bob borrows dai
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      user: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // Bob's current risk premium should be equal to liquidity premium of weth, since debt is fully covered by it
    assertGt(
      _getValueInBaseCurrency(wethAssetId, wethSupplyAmount),
      _getValueInBaseCurrency(daiAssetId, borrowAmount),
      'Bob weth collateral enough to cover dai debt'
    );
    assertEq(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wethReserveId(spoke1)),
      'Bob user rp after borrow matches weth lp'
    );

    // Bob supplies lower LP collateral (wbtc)
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      user: bob,
      amount: wbtcSupplyAmount,
      onBehalfOf: bob
    });

    // Now risk premium should be less than or equal to LP of weth
    assertLe(
      spoke1.getUserRiskPremium(bob),
      spoke1.getLiquidityPremium(_wethReserveId(spoke1)),
      'Bob user risk premium after supplying lower LP collateral'
    );
  }
}
