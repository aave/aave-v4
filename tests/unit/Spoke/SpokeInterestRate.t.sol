// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeInterestRateTest is SpokeBase {
  function test_donation(uint256 donationAmount, uint256 daiBorrowAmount) public {
    daiBorrowAmount = bound(daiBorrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      daiBorrowAmount
    );

    // Bob supply weth
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiBorrowAmount, alice);

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    // Check debt exchange ratio before donation
    uint256 debtExRatioBefore = hub.convertToDrawnAssets(daiAssetId, 1e30);

    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub));

    // Bob donates to hub
    deal(address(tokenList.dai), bob, donationAmount);
    vm.prank(bob);
    tokenList.dai.transfer(address(hub), donationAmount);

    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      hubBalanceBefore + donationAmount,
      'hub balance after donation'
    );

    uint256 debtExRatioAfter = hub.convertToDrawnAssets(daiAssetId, 1e30);
    assertEq(debtExRatioAfter, debtExRatioBefore, 'debt exchange ratio after donation');
  }

  // TODO: Complete this test suite
}
