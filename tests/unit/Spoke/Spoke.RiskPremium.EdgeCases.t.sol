// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRiskPremiumEdgeCasesTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  /// Bob supplies 2 collateral assets, borrows an amount such that both of them cover it, and then repays any amount of debt
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

    daiSupplyAmount = bound(daiSupplyAmount, 1e18, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1e18, MAX_SUPPLY_AMOUNT / 2);
    // Force least lp asset supply amount to be less than borrow amount, so borrow covered by 2 collaterals at least
    usdxSupplyAmount = bound(
      usdxSupplyAmount,
      1,
      _calcEquivalentAssetAmount(dai2AssetId, borrowAmount, usdxAssetId) - 1
    );
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
      'Risk premium should decrease or remain same after repaying some debt'
    );

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after repay'
    );
  }

  /// Supply two collaterals, borrow, then remove lower LP collateral and risk premium should increase
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

    // Deploy liquidity for usdx borrow
    _deployLiquidity(spoke2, _usdxReserveId(spoke2), borrowAmount);

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

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after disabling collateral'
    );
  }

  /// Supply two collaterals, borrow, then withdraw lower LP collateral and risk premium should increase
  function test_riskPremium_increasesAfterWithdrawal(
    uint256 daiSupplyAmount,
    uint256 borrowAmount
  ) public {
    daiSupplyAmount = bound(daiSupplyAmount, 1, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    uint256 withdrawAmount = daiSupplyAmount;
    test_riskPremium_fuzz_nonDecreasingAfterWithdrawal(
      daiSupplyAmount,
      borrowAmount,
      withdrawAmount
    );
  }

  /// Supply two collaterals, borrow, then fuzz withdraw lower LP collateral and risk premium should increase or remain the same
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

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after withdrawing collateral'
    );
  }

  /// User risk premium changes because of collateral accrual (no debt change)
  /// Debt is initially covered by 2 collaterals, then 1 collateral becomes enough to cover the debt due to interest accrual
  function test_riskPremium_decreasesAfterCollateralAccrual() public {
    uint256 daiSupplyAmount = 1000e18;
    uint40 skipTime = 365 days;
    test_riskPremium_fuzz_nonIncreasesAfterCollateralAccrual(daiSupplyAmount, skipTime);
  }

  /// Debt is initially covered by 2 collaterals, then 1 collateral becomes enough to cover the debt due to interest accrual
  function test_riskPremium_fuzz_nonIncreasesAfterCollateralAccrual(
    uint256 daiSupplyAmount,
    uint40 skipTime
  ) public {
    daiSupplyAmount = bound(daiSupplyAmount, 1e18, MAX_SUPPLY_AMOUNT / 2 - 1); // Leave room for Alice to borrow 1 dai
    // Determine value of daiSupplyAmount in weth terms
    uint256 wethBorrowAmount = _calcEquivalentAssetAmount(
      daiAssetId,
      daiSupplyAmount,
      wethAssetId
    ) + 1; // Borrow more than dai supply value so 2 collaterals cover debt
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

    // Deploy liquidity for weth borrow
    _deployLiquidity(spoke2, _wethReserveId(spoke2), wethBorrowAmount);

    // Bob borrows weth
    Utils.borrow({
      spoke: spoke2,
      reserveId: _wethReserveId(spoke2),
      user: bob,
      amount: wethBorrowAmount,
      onBehalfOf: bob
    });

    // Alice supplies collateral in order to borrow
    uint256 aliceCollateralAmount = _calcMinimumCollAmount(
      spoke2,
      _wbtcReserveId(spoke2),
      _daiReserveId(spoke2),
      daiSupplyAmount
    );
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _wbtcReserveId(spoke2),
      user: alice,
      amount: aliceCollateralAmount,
      onBehalfOf: alice
    });

    // Mock call to raise dai interest rate upon this next borrow call so it outgrows weth debt interest
    DataTypes.Asset memory daiAsset = hub.getAsset(daiAssetId);
    (uint256 baseDebt, ) = hub.getAssetDebt(daiAssetId);
    DataTypes.CalculateInterestRatesParams memory params = DataTypes.CalculateInterestRatesParams({
      liquidityAdded: 0,
      liquidityTaken: daiSupplyAmount,
      totalDebt: baseDebt,
      reserveFactor: 0,
      assetId: daiAssetId,
      virtualUnderlyingBalance: daiAsset.availableLiquidity,
      usingVirtualBalance: true
    });
    vm.mockCall(
      address(irStrategy),
      abi.encodeWithSelector(IReserveInterestRateStrategy.calculateInterestRates.selector, params),
      abi.encode(uint256(10_00).bpsToRay())
    );

    // Alice borrows dai to accrue interest
    Utils.borrow({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      user: alice,
      amount: daiSupplyAmount,
      onBehalfOf: alice
    });

    // Bob's current risk premium should be greater than or equal liquidity premium of dai, since debt is not fully covered by it (and due to rounding)
    assertGt(
      _getValueInBaseCurrency(wethAssetId, wethBorrowAmount),
      _getValueInBaseCurrency(daiAssetId, daiSupplyAmount),
      'Weth borrow amount greater than dai supply amount'
    );
    assertGe(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user rp after borrow'
    );
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after borrow matches expected'
    );

    skip(skipTime);

    // Check Bob's dai collateral amount is now enough to cover his weth debt
    uint256 daiSupplied = spoke2.getUserSuppliedAmount(_daiReserveId(spoke2), bob);
    uint256 bobWethDebt = spoke2.getUserTotalDebt(_wethReserveId(spoke2), bob);
    assertGt(
      _getValueInBaseCurrency(daiAssetId, daiSupplied),
      _getValueInBaseCurrency(wethAssetId, bobWethDebt),
      'Bob dai collateral exceeds weth debt after interest accrual'
    );

    // Now since dai is enough to cover the debt due to interest accrual, Bob's RP should equal LP of dai
    assertEq(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user risk premium after interest accrual'
    );
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after interest accrual matches expected'
    );
  }

  /// Bob's debt initially fully covered by one collateral. Then debt interest accrues, so debt must be covered by 2 collaterals
  function test_riskPremium_increasesAfterDebtAccrual() public {
    uint256 wbtcSupplyAmount = 1e8;
    uint256 daiBorrowAmount = _calcEquivalentAssetAmount(wbtcAssetId, wbtcSupplyAmount, daiAssetId); // Dai debt to equal wbtc supply value
    test_riskPremium_fuzz_increasesAfterDebtAccrual(daiBorrowAmount, 365 days);
  }

  /// Debt initially fully covered by one collateral. Then debt interest accrues, so debt must be covered by 2 collaterals
  function test_riskPremium_fuzz_increasesAfterDebtAccrual(
    uint256 borrowAmount,
    uint40 skipTime
  ) public {
    // Find max supply amount of dai in terms of weth
    uint256 maxWethDebt = _calcEquivalentAssetAmount(daiAssetId, MAX_SUPPLY_AMOUNT, wethAssetId);
    assertLt(
      maxWethDebt,
      MAX_SUPPLY_AMOUNT / 2,
      'Max weth debt should be less than half max supply amount'
    );
    borrowAmount = bound(borrowAmount, 1e18, maxWethDebt); // Allow room for dai supply to cover weth debt
    // Determine value of borrowAmount in dai terms so dai collateral can fully cover weth debt
    uint256 daiSupplyAmount = _calcEquivalentAssetAmount(wethAssetId, borrowAmount, daiAssetId);
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
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after borrow matches expected'
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

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after collateral accrual matches expected'
    );
  }

  /// Initially debt is covered by 1 collateral, both debt and collateral accrue at different rates, such that finally debt is covered by 2 collaterals
  function test_riskPremium_changesAfterAccrual() public {
    uint256 wethBorrowAmount = 100e18;
    uint40 skipTime = 365 days;
    test_riskPremium_fuzz_changesAfterAccrual(wethBorrowAmount, skipTime);
  }

  /// Initially debt is covered by 1 collateral, both debt and collateral accrue at different rates, such that finally debt is covered by 2 collaterals
  function test_riskPremium_fuzz_changesAfterAccrual(
    uint256 wethBorrowAmount,
    uint40 skipTime
  ) public {
    uint256 dai2SupplyAmount = MAX_SUPPLY_AMOUNT;
    // Find max supply amount of dai in terms of weth
    uint256 maxWethDebt = _calcEquivalentAssetAmount(daiAssetId, MAX_SUPPLY_AMOUNT, wethAssetId);
    assertLe(
      maxWethDebt,
      MAX_SUPPLY_AMOUNT / 2,
      'Max weth debt should be less than half max supply amount'
    );
    wethBorrowAmount = bound(wethBorrowAmount, 1e18, maxWethDebt); // Allow room for dai supply to cover weth debt
    uint256 daiSupplyAmount = _calcEquivalentAssetAmount(wethAssetId, wethBorrowAmount, daiAssetId); // Dai collateral will fully cover initial weth borrow
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
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after borrow matches expected'
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

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after collateral accrual matches expected'
    );
  }

  /// Initially debt is covered by 1 collateral, then due to borrowing more, debt is covered by 2 collaterals
  function test_riskPremium_borrowingMoreIncreasesRP() public {
    uint256 wbtcSupplyAmount = 1e8;
    uint256 daiBorrowAmount = _calcEquivalentAssetAmount(wbtcAssetId, wbtcSupplyAmount, daiAssetId); // Dai debt to equal wbtc supply value
    uint256 additionalDaiBorrowAmount = 1000e18;
    test_riskPremium_fuzz_borrowingMoreNonDecreasesRP(daiBorrowAmount, additionalDaiBorrowAmount);
  }

  /// Initially debt is covered by 1 collateral, then due to borrowing more, debt is covered by 2 collaterals
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
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after borrow matches expected'
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

    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after borrowing more matches expected'
    );
  }

  /// Initially 1 higher LP collateral covers debt, then supply lower LP collateral, and RP should decrease
  function test_riskPremium_supplyingLowerLPCollateral_decreasesRP() public {
    uint256 wbtcSupplyAmount = 1e8;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = _calcEquivalentAssetAmount(
      wethAssetId,
      wethSupplyAmount / 2,
      daiAssetId
    ); // Half of the weth collateral value
    test_riskPremium_fuzz_supplyingLowerLPCollateral_nonIncreasesRP(
      wbtcSupplyAmount,
      daiBorrowAmount
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
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'Bob user risk premium after borrow matches expected'
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
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'Bob user risk premium after supplying lower LP collateral matches expected'
    );
  }

  /// Initially debt is covered by 2 collaterals, then due to price change, debt is covered by 1 collateral
  function test_riskPremium_priceChangeReducesRP(uint256 daiSupplyAmount, uint256 newPrice) public {
    daiSupplyAmount = bound(daiSupplyAmount, 1e18, MAX_SUPPLY_AMOUNT);
    uint256 startingPrice = spoke2.getReservePrice(_daiReserveId(spoke2));
    newPrice = bound(newPrice, startingPrice + 1, 1e16);

    // Supply dai and dai2 collaterals to cover weth debt. Dai increases in price to fully cover weth debt
    uint256 dai2SupplyAmount = MAX_SUPPLY_AMOUNT;
    uint256 borrowAmount = _calcEquivalentAssetAmount(daiAssetId, daiSupplyAmount, wethAssetId) + 1; // Borrow more than dai supply value so 2 collaterals cover debt

    // Deploy liquidity for weth borrow
    _deployLiquidity(spoke2, _wethReserveId(spoke2), MAX_SUPPLY_AMOUNT);

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

    // Bob borrows weth
    Utils.borrow({
      spoke: spoke2,
      reserveId: _wethReserveId(spoke2),
      user: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    // Bob's current risk premium should be greater than or equal to liquidity premium of dai, since debt is not fully covered by it (and due to rounding)
    assertLt(
      _getValueInBaseCurrency(daiAssetId, daiSupplyAmount),
      _getValueInBaseCurrency(wethAssetId, borrowAmount),
      'Bob dai collateral less than weth debt'
    );
    assertGe(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user rp greater than or equal dai lp'
    );
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after borrow matches expected'
    );

    // Now change the price of dai
    oracle.setAssetPrice(daiAssetId, newPrice);

    // Now risk premium should equal LP of dai since debt is fully covered by it
    assertGe(
      _getValueInBaseCurrency(daiAssetId, daiSupplyAmount),
      _getValueInBaseCurrency(wethAssetId, borrowAmount),
      'Bob dai collateral greater than weth debt'
    );
    assertEq(
      spoke2.getUserRiskPremium(bob),
      spoke2.getLiquidityPremium(_daiReserveId(spoke2)),
      'Bob user risk premium matches dai lp after price change'
    );
    assertEq(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      'Bob user risk premium after price change matches expected'
    );
  }
}
