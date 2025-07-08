// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubPayFeeTest is LiquidityHubBase {
  function test_payFee_revertsWith_SuppliedAmountExceeded() public {
    uint256 addAmount = 100e18;
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: addAmount,
      user: alice,
      to: address(spoke1)
    });

    uint256 feeShares = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));
    uint256 feeAmount = hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1));

    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.SuppliedAmountExceeded.selector, feeAmount)
    );
    vm.prank(address(spoke1));
    hub.payFee(daiAssetId, feeShares + 1);
  }

  function test_payFee_revertsWith_SuppliedAmountExceeded_with_interest() public {
    uint256 addAmount = 100e18;
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: addAmount,
      user: alice,
      to: address(spoke1)
    });

    _addLiquidity(daiAssetId, addAmount);
    _drawLiquidity(daiAssetId, addAmount, true);

    uint256 feeShares = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));
    uint256 feeAmount = hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1));

    // supply ex rate increases due to interest
    assertGt(feeAmount, feeShares);

    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.SuppliedAmountExceeded.selector, feeAmount)
    );
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
      spoke: address(spoke1),
      amount: addAmount,
      user: alice,
      to: address(spoke1)
    });

    _addLiquidity(daiAssetId, 100e18);
    _drawLiquidity(daiAssetId, 100e18, true);

    uint256 spokeSharesBefore = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));

    // supply ex rate increases due to interest
    assertGe(
      hub.convertToSuppliedAssets(daiAssetId, WadRayMathExtended.RAY),
      WadRayMathExtended.RAY
    );

    feeShares = bound(feeShares, 1, spokeSharesBefore);
    uint256 feeAmount = hub.convertToSuppliedAssets(daiAssetId, feeShares);

    uint256 feeReceiverSharesBefore = hub.getSpokeSuppliedShares(
      daiAssetId,
      _getFeeReceiver(daiAssetId)
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.Remove(daiAssetId, address(spoke1), feeShares, feeAmount);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Add(daiAssetId, _getFeeReceiver(daiAssetId), feeShares, feeAmount);

    vm.prank(address(spoke1));
    hub.payFee(daiAssetId, feeShares);

    uint256 spokeSharesAfter = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));
    uint256 feeReceiverSharesAfter = hub.getSpokeSuppliedShares(
      daiAssetId,
      _getFeeReceiver(daiAssetId)
    );

    assertEq(spokeSharesAfter, spokeSharesBefore - feeShares, 'spoke supplied shares after');
    assertEq(
      feeReceiverSharesAfter,
      feeReceiverSharesBefore + feeShares,
      'fee receiver supplied shares after'
    );
  }

  function test_payFee_revertsWith_InvalidFeeShares() public {
    vm.expectRevert(ILiquidityHub.InvalidFeeShares.selector);
    vm.prank(address(spoke1));
    hub.payFee(daiAssetId, 0);
  }
}
