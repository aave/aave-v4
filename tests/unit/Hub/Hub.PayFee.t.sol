// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubPayFeeTest is HubBase {
  function test_payFee_revertsWith_InvalidFeeShares() public {
    vm.expectRevert(IHub.InvalidFeeShares.selector);
    vm.prank(address(spoke1));
    hub.payFee(daiAssetId, 0);
  }

  function test_payFee_revertsWith_SpokeNotActive() public {
    updateSpokeActive(hub, daiAssetId, address(spoke1), false);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub.payFee(daiAssetId, 1);
  }

  function test_payFee_revertsWith_AddedAmountExceeded() public {
    uint256 addAmount = 100e18;
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: alice
    });

    uint256 feeShares = hub.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 feeAmount = hub.getSpokeAddedAmount(daiAssetId, address(spoke1));

    vm.expectRevert(abi.encodeWithSelector(IHub.AddedAmountExceeded.selector, feeAmount));
    vm.prank(address(spoke1));
    hub.payFee(daiAssetId, feeShares + 1);
  }

  function test_payFee_revertsWith_AddedAmountExceeded_with_interest() public {
    uint256 addAmount = 100e18;
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: alice
    });

    _addLiquidity(daiAssetId, addAmount);
    _drawLiquidity(daiAssetId, addAmount, true);

    uint256 feeShares = hub.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 feeAmount = hub.getSpokeAddedAmount(daiAssetId, address(spoke1));

    // add ex rate increases due to interest
    assertGt(feeAmount, feeShares);

    vm.expectRevert(abi.encodeWithSelector(IHub.AddedAmountExceeded.selector, feeAmount));
    vm.prank(address(spoke1));
    hub.payFee(daiAssetId, feeShares + 1);
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
      hub: hub,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: alice
    });

    _addLiquidity(daiAssetId, 100e18);
    _drawLiquidity(daiAssetId, 100e18, true);

    uint256 spokeSharesBefore = hub.getSpokeAddedShares(daiAssetId, address(spoke1));

    // add ex rate increases due to interest
    assertGe(hub.convertToAddedAssets(daiAssetId, WadRayMathExtended.RAY), WadRayMathExtended.RAY);

    feeShares = bound(feeShares, 1, spokeSharesBefore);
    uint256 feeAmount = hub.convertToAddedAssets(daiAssetId, feeShares);

    uint256 feeReceiverSharesBefore = hub.getSpokeAddedShares(
      daiAssetId,
      _getFeeReceiver(daiAssetId)
    );

    vm.expectEmit(address(hub));
    emit IHub.Remove(daiAssetId, address(spoke1), feeShares, feeAmount);
    vm.expectEmit(address(hub));
    emit IHub.Add(daiAssetId, _getFeeReceiver(daiAssetId), feeShares, feeAmount);

    vm.prank(address(spoke1));
    hub.payFee(daiAssetId, feeShares);

    uint256 spokeSharesAfter = hub.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 feeReceiverSharesAfter = hub.getSpokeAddedShares(
      daiAssetId,
      _getFeeReceiver(daiAssetId)
    );

    assertEq(spokeSharesAfter, spokeSharesBefore - feeShares, 'spoke added shares after');
    assertEq(
      feeReceiverSharesAfter,
      feeReceiverSharesBefore + feeShares,
      'fee receiver added shares after'
    );
  }
}
