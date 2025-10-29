// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubPayFeeTest is HubBase {
  function test_payFee_revertsWith_InvalidShares() public {
    vm.expectRevert(IHub.InvalidShares.selector, address(hub1));
    vm.prank(address(spoke1));
    hub1.payFeeShares(address(tokenList.dai), 0);
  }

  function test_payFee_revertsWith_SpokeNotActive() public {
    updateSpokeActive(hub1, address(tokenList.dai), address(spoke1), false);
    vm.expectRevert(IHub.SpokeNotActive.selector, address(hub1));
    vm.prank(address(spoke1));
    hub1.payFeeShares(address(tokenList.dai), 1);
  }

  function test_payFee_revertsWith_underflow_added_shares_exceeded() public {
    uint256 addAmount = 100e18;
    Utils.add({
      hub: hub1,
      asset: address(tokenList.dai),
      caller: address(spoke1),
      amount: addAmount,
      user: alice
    });

    uint256 feeShares = hub1.getSpokeAddedShares(address(tokenList.dai), address(spoke1));
    uint256 feeAmount = hub1.getSpokeAddedAssets(address(tokenList.dai), address(spoke1));

    vm.expectRevert(stdError.arithmeticError);
    vm.prank(address(spoke1));
    hub1.payFeeShares(address(tokenList.dai), feeShares + 1);
  }

  function test_payFee_revertsWith_underflow_added_shares_exceeded_with_interest() public {
    uint256 addAmount = 100e18;
    Utils.add({
      hub: hub1,
      asset: address(tokenList.dai),
      caller: address(spoke1),
      amount: addAmount,
      user: alice
    });

    _addLiquidity(address(tokenList.dai), addAmount);
    _drawLiquidity(address(tokenList.dai), addAmount, true);

    uint256 feeShares = hub1.getSpokeAddedShares(address(tokenList.dai), address(spoke1));
    uint256 feeAmount = hub1.getSpokeAddedAssets(address(tokenList.dai), address(spoke1));

    // supply ex rate increases due to interest
    assertGt(feeAmount, feeShares);

    vm.expectRevert(stdError.arithmeticError);
    vm.prank(address(spoke1));
    hub1.payFeeShares(address(tokenList.dai), feeShares + 1);
  }

  function test_payFee_fuzz(uint256 addAmount, uint256 feeShares) public {
    test_payFee_fuzz_with_interest(addAmount, feeShares, 0);
  }

  function test_payFee_fuzz_with_interest(
    uint256 addAmount,
    uint256 feeShares,
    uint256 skipTime
  ) public {
    addAmount = bound(addAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME);

    Utils.add({
      hub: hub1,
      asset: address(tokenList.dai),
      caller: address(spoke1),
      amount: addAmount,
      user: alice
    });

    _addLiquidity(address(tokenList.dai), 100e18);
    _drawLiquidity(address(tokenList.dai), 100e18, true);

    uint256 spokeSharesBefore = hub1.getSpokeAddedShares(address(tokenList.dai), address(spoke1));

    // supply ex rate increases due to interest
    assertGe(hub1.previewRemoveByShares(address(tokenList.dai), WadRayMath.RAY), WadRayMath.RAY);

    feeShares = bound(feeShares, 1, spokeSharesBefore);

    uint256 feeReceiverSharesBefore = hub1.getSpokeAddedShares(
      address(tokenList.dai),
      _getFeeReceiver(hub1, address(tokenList.dai))
    );

    vm.expectEmit(address(hub1));
    emit IHubBase.TransferShares(
      address(tokenList.dai),
      address(spoke1),
      _getFeeReceiver(hub1, address(tokenList.dai)),
      feeShares
    );

    vm.prank(address(spoke1));
    hub1.payFeeShares(address(tokenList.dai), feeShares);

    assertBorrowRateSynced(hub1, address(tokenList.dai), 'payFee');
    assertHubLiquidity(hub1, address(tokenList.dai), 'payFee');
    uint256 spokeSharesAfter = hub1.getSpokeAddedShares(address(tokenList.dai), address(spoke1));
    uint256 feeReceiverSharesAfter = hub1.getSpokeAddedShares(
      address(tokenList.dai),
      _getFeeReceiver(hub1, address(tokenList.dai))
    );

    assertEq(spokeSharesAfter, spokeSharesBefore - feeShares, 'spoke supplied shares after');
    assertEq(
      feeReceiverSharesAfter,
      feeReceiverSharesBefore + feeShares,
      'fee receiver supplied shares after'
    );
  }
}
