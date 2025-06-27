// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubPayFeeWithExistingLiquidityTest is LiquidityHubBase {
  function test_payFeeWithExistingLiquidity_revertsWith_SuppliedAmountExceeded() public {
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

    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.SuppliedSharesExceeded.selector, feeShares)
    );
    vm.prank(address(spoke1));
    hub.payFeeWithExistingLiquidity(daiAssetId, feeShares + 1);
  }

  function test_payFeeWithExistingLiquidity_revertsWith_SuppliedAmountExceeded_with_interest()
    public
  {
    uint256 addAmount = 100e18;
    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: addAmount,
      user: alice,
      to: address(spoke1)
    });

    _supplyAndDrawLiquidity({
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: addAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: addAmount,
      skipTime: 365 days
    });

    uint256 feeShares = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));

    // supply ex rate increases due to interest
    assertGt(hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1)), feeShares);

    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.SuppliedSharesExceeded.selector, feeShares)
    );
    vm.prank(address(spoke1));
    hub.payFeeWithExistingLiquidity(daiAssetId, feeShares + 1);
  }

  function test_payFeeWithExistingLiquidity_fuzz(uint256 addAmount, uint256 feeShares) public {
    addAmount = bound(addAmount, 1, MAX_SUPPLY_AMOUNT);

    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: addAmount,
      user: alice,
      to: address(spoke1)
    });

    uint256 spokeSharesBefore = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));
    feeShares = bound(feeShares, 1, spokeSharesBefore);

    uint256 feeReceiverSharesBefore = hub.getSpokeSuppliedShares(
      daiAssetId,
      _getFeeReceiver(daiAssetId)
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.PayFeeWithExistingLiquidity(daiAssetId, address(spoke1), feeShares);

    vm.prank(address(spoke1));
    hub.payFeeWithExistingLiquidity(daiAssetId, feeShares);

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

  function test_payFeeWithExistingLiquidity_fuzz_with_interest(
    uint256 addAmount,
    uint256 feeShares,
    uint256 skipTime
  ) public {
    addAmount = bound(addAmount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: addAmount,
      user: alice,
      to: address(spoke1)
    });

    _supplyAndDrawLiquidity({
      assetId: daiAssetId,
      supplyUser: bob,
      supplySpoke: address(spoke2),
      supplyAmount: 100e18,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: 100e18,
      skipTime: skipTime
    });

    uint256 spokeSharesBefore = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));

    // supply ex rate increases due to interest
    assertGt(
      hub.convertToSuppliedAssets(daiAssetId, WadRayMathExtended.RAY),
      WadRayMathExtended.RAY
    );

    feeShares = bound(feeShares, 1, spokeSharesBefore);

    uint256 feeReceiverSharesBefore = hub.getSpokeSuppliedShares(
      daiAssetId,
      _getFeeReceiver(daiAssetId)
    );

    vm.expectEmit(address(hub));
    emit ILiquidityHub.PayFeeWithExistingLiquidity(daiAssetId, address(spoke1), feeShares);

    vm.prank(address(spoke1));
    hub.payFeeWithExistingLiquidity(daiAssetId, feeShares);

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
  function test_payFeeWithExistingLiquidity_revertsWith_InvalidFeeShares() public {
    vm.expectRevert(ILiquidityHub.InvalidFeeShares.selector);
    vm.prank(address(spoke1));
    hub.payFeeWithExistingLiquidity(daiAssetId, 0);
  }
}
