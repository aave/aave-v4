// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowEdgeCasesTest is SpokeBase {
  using SharesMath for uint256;

  /// inflated exch rate, it's better for user to borrow 1 big amount than 2 small amounts due to rounding up
  function test_borrow_rounding_effect_multiple_actions() public {
    // supply enough weth for high collateral factor
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: carol,
      amount: 100e18,
      onBehalfOf: carol
    });
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob
    });

    TestReserve memory collateral;
    collateral.reserveId = _wethReserveId(spoke1);
    collateral.supplier = alice;
    collateral.supplyAmount = 100e18;

    // execute supply and borrow to inflate the exchange rate
    _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: collateral,
      borrow: TestReserve({
        reserveId: _daiReserveId(spoke1),
        supplier: bob,
        borrower: alice,
        supplyAmount: 1000e18,
        borrowAmount: 100e18
      }),
      rate: 0,
      isMockRate: false,
      skipTime: 365 days * 100
    });

    uint256 amount1 = 8;
    uint256 amount2 = 8;

    uint256 carolDaiBefore = tokenList.dai.balanceOf(carol);
    uint256 bobDaiBefore = tokenList.dai.balanceOf(bob);

    // carol borrows 2 smaller amounts in 2 actions
    vm.startPrank(carol);
    spoke1.borrow(_daiReserveId(spoke1), amount1, carol);
    spoke1.borrow(_daiReserveId(spoke1), amount2, carol);
    vm.stopPrank();

    // bob borrows whole amount at once
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), amount1 + amount2, bob);

    // bob benefits by having less debt shares than carol
    assertLt(
      spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares,
      spoke1.getUserPosition(_daiReserveId(spoke1), carol).drawnShares,
      'bob should have < debt shares than carol'
    );
    // but both users have the same amount of drawn asset
    assertEq(
      tokenList.dai.balanceOf(bob) - bobDaiBefore,
      tokenList.dai.balanceOf(carol) - carolDaiBefore,
      'drawn assets should match'
    );
  }

  /// fuzz - given an inflated ex rate, it's better for the user to borrow 1 big amount than 2 small amounts due to rounding(up)
  function test_borrow_fuzz_rounding_effect_inflated_ex_rate(
    uint256 amount1,
    uint256 amount2,
    uint256 skipTime
  ) public {
    // to account for precision loss from shares conversion in vm.assume calc
    amount1 = bound(amount1, 0, MAX_SUPPLY_AMOUNT_DAI / 1e6);
    amount2 = bound(amount2, 0, MAX_SUPPLY_AMOUNT_DAI / 1e6);
    skipTime = bound(skipTime, 365 days, MAX_SKIP_TIME); // bound with higher elapsed time to inflate exch rate

    // bob supplies max weth for high collateral factor
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: MAX_SUPPLY_AMOUNT_WETH,
      onBehalfOf: bob
    });
    // carol supplies max weth for high collateral factor
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: carol,
      amount: MAX_SUPPLY_AMOUNT_WETH,
      onBehalfOf: carol
    });

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT_DAI);

    TestReserve memory collateral;
    collateral.reserveId = _wethReserveId(spoke1);
    collateral.supplier = alice;
    collateral.supplyAmount = MAX_SUPPLY_AMOUNT_WETH;

    // execute supply and borrow to inflate the exchange rate
    _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: collateral,
      borrow: TestReserve({
        reserveId: _daiReserveId(spoke1),
        supplier: bob,
        borrower: alice,
        supplyAmount: MAX_SUPPLY_AMOUNT_DAI,
        borrowAmount: MAX_SUPPLY_AMOUNT_DAI
      }),
      rate: 0,
      isMockRate: false,
      skipTime: skipTime
    });

    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);

    // ensure inflated exch rate
    vm.assume(hub1.convertToDrawnAssets(daiAssetId, 1e18) > 1e18);
    // ensure that shares conversion of smaller amounts individually are greater than shares of total sum
    vm.assume(
      amount1.toSharesUp(drawnDebt, hub1.getAsset(daiAssetId).drawnShares) +
        amount2.toSharesUp(drawnDebt, hub1.getAsset(daiAssetId).drawnShares) >
        (amount1 + amount2).toSharesUp(drawnDebt, hub1.getAsset(daiAssetId).drawnShares)
    );

    uint256 carolDaiBefore = tokenList.dai.balanceOf(carol);
    uint256 bobDaiBefore = tokenList.dai.balanceOf(bob);

    // bob borrows whole amount at once
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), amount1 + amount2, bob);

    // carol borrows 2 smaller amounts in 2 actions
    vm.startPrank(carol);
    spoke1.borrow(_daiReserveId(spoke1), amount1, carol);
    spoke1.borrow(_daiReserveId(spoke1), amount2, carol);
    vm.stopPrank();

    // bob benefits by having less debt shares than carol
    assertLt(
      spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares,
      spoke1.getUserPosition(_daiReserveId(spoke1), carol).drawnShares,
      'bob should have < debt shares than carol'
    );
    // but both users have the same amount of drawn asset
    assertEq(
      tokenList.dai.balanceOf(bob) - bobDaiBefore,
      tokenList.dai.balanceOf(carol) - carolDaiBefore,
      'drawn assets should match'
    );
  }

  /// base exch rate, it's the same for user to borrow 1 big amount vs 2 small amounts
  function test_borrow_fuzz_rounding_effect(uint256 amount1, uint256 amount2) public {
    amount1 = bound(amount1, 1, MAX_SUPPLY_AMOUNT_DAI / 4);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT_DAI / 4);

    // supply enough weth for high collateral factor
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: carol,
      amount: MAX_SUPPLY_AMOUNT,
      onBehalfOf: carol
    });
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: MAX_SUPPLY_AMOUNT,
      onBehalfOf: bob
    });

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT_DAI);

    uint256 carolDaiBefore = tokenList.dai.balanceOf(carol);
    uint256 bobDaiBefore = tokenList.dai.balanceOf(bob);

    // carol borrows 2 smaller amounts in 2 actions
    vm.startPrank(carol);
    spoke1.borrow(_daiReserveId(spoke1), amount1, carol);
    spoke1.borrow(_daiReserveId(spoke1), amount2, carol);
    vm.stopPrank();

    // bob borrows whole amount at once
    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), amount1 + amount2, bob);

    // both users have the same amount of debt shares
    assertEq(
      spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares,
      spoke1.getUserPosition(_daiReserveId(spoke1), carol).drawnShares,
      'debt shares should match'
    );
    // both users have the same amount of drawn asset
    assertEq(
      tokenList.dai.balanceOf(bob) - bobDaiBefore,
      tokenList.dai.balanceOf(carol) - carolDaiBefore,
      'drawn assets should match'
    );
  }

  /// base exch rate, assert that user receives debt shares with correct rounding
  function test_borrow_rounding_effect_shares() public {
    test_borrow_fuzz_rounding_effect_shares(5e18, 365 days * 3);
  }

  /// fuzz - base exch rate, assert that user receives debt shares with correct rounding
  function test_borrow_fuzz_rounding_effect_shares(uint256 amount1, uint256 skipTime) public {
    amount1 = bound(amount1, 1, MAX_SUPPLY_AMOUNT_DAI / 4);
    skipTime = bound(skipTime, 365 days, MAX_SKIP_TIME);

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: MAX_SUPPLY_AMOUNT,
      onBehalfOf: bob
    });

    TestReserve memory collateral;
    collateral.reserveId = _wethReserveId(spoke1);
    collateral.supplier = alice;
    collateral.supplyAmount = MAX_SUPPLY_AMOUNT;

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT_DAI);

    // execute supply and borrow to inflate the exchange rate
    _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: collateral,
      borrow: TestReserve({
        reserveId: _daiReserveId(spoke1),
        supplier: bob,
        borrower: alice,
        supplyAmount: MAX_SUPPLY_AMOUNT_DAI,
        borrowAmount: MAX_SUPPLY_AMOUNT_DAI
      }),
      rate: 0,
      isMockRate: false,
      skipTime: skipTime
    });

    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);

    // drawn shares are rounded up
    uint256 expectedDebtShares = amount1.toSharesUp(
      drawnDebt,
      hub1.getAsset(daiAssetId).drawnShares
    );

    vm.prank(bob);
    spoke1.borrow(_daiReserveId(spoke1), amount1, bob);

    assertEq(
      expectedDebtShares,
      spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares,
      'base drawn shares'
    );
  }
}
