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
    // Make usdx liquidity premium 10 so it's the lower lp asset
    updateLiquidityPremium(spoke2, _usdxReserveId(spoke2), 10_00);

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

    // Now bob removes dai as collateral
    setUsingAsCollateral({
      spoke: spoke2,
      user: bob,
      reserveId: _daiReserveId(spoke2),
      usingAsCollateral: false
    });

    assertGt(
      spoke2.getUserRiskPremium(bob),
      riskPremium,
      'Risk premium should increase after removing collateral'
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
      'Risk premium should increase after withdrawing collateral'
    );
  }

  // TODO: user risk premium changes because of collateral accrual (no debt change)
  // Here I can set up so that one collateral almost covers full debt, but it's actually 2. Then interest is enough to cover the debt

  // TODO: user risk premium changes because of debt accrual (no collateral change)
  // Same as above, but debt covered by 1 collateral, debt outgrows that collateral to be covered by 2

  // TODO: user risk premium changes because of coll and debt accrual
  // ?
}
