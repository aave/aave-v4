// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubMintFeeSharesTest is HubBase {
  function test_mintFeeShares_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this))
    );
    Utils.mintFeeShares(hub1, daiAssetId, address(this));
  }

  function test_mintFeeShares_revertsWith_SpokeNotActive() public {
    // Create debt to build up fees on the existing treasury spoke
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 100e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 10e18,
      skipTime: 365 days
    });

    updateSpokeActive(hub1, daiAssetId, _getFeeReceiver(hub1, daiAssetId), false);
    vm.expectRevert(IHub.SpokeNotActive.selector, address(hub1));
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);
  }

  function test_mintFeeShares() public {
    // Create debt to build up fees on the existing treasury spoke
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1000e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 100e18,
      skipTime: 365 days
    });

    address feeReceiver = _getFeeReceiver(hub1, daiAssetId);

    // before mintFeeShares, the fee shares should be 0
    uint256 realizedFees = hub1.getAsset(daiAssetId).realizedFees;
    assertEq(realizedFees, 0);
    uint256 feeShares = hub1.getSpokeAddedShares(daiAssetId, feeReceiver);
    assertEq(feeShares, 0);

    uint256 expectedMintedAssets = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    uint256 expectedMintedShares = hub1.previewAddByAssets(daiAssetId, expectedMintedAssets);

    IHub.Asset memory asset = hub1.getAsset(daiAssetId);
    bytes memory irCalldata = abi.encodeCall(
      IBasicInterestRateStrategy.calculateInterestRate,
      (
        daiAssetId,
        asset.liquidity,
        hub1.previewRestoreByShares(daiAssetId, hub1.getAssetDrawnShares(daiAssetId)),
        asset.deficitRay,
        asset.swept
      )
    );
    uint256 mockRate = 0.3e27;
    vm.mockCall(address(irStrategy), irCalldata, abi.encode(mockRate));

    // after mintFeeShares, the fee shares should be the amount of the fees
    vm.expectEmit(address(hub1));
    emit IHub.MintFeeShares(daiAssetId, feeReceiver, expectedMintedShares, expectedMintedAssets);
    vm.expectEmit(address(hub1));
    emit IHub.UpdateAsset(daiAssetId, hub1.getAssetDrawnIndex(daiAssetId), mockRate, 0);

    uint256 addedSharesBefore = hub1.getAddedShares(daiAssetId);
    uint256 sharePriceBefore = hub1.previewAddByShares(daiAssetId, 1e18);

    vm.expectCall(address(irStrategy), irCalldata);
    uint256 mintedShares = Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    assertEq(mintedShares, expectedMintedShares, 'minted shares');
    assertEq(hub1.getAsset(daiAssetId).realizedFees, 0, 'realized fees after');
    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, feeReceiver),
      expectedMintedShares,
      'added shares'
    );
    assertEq(mintedShares, hub1.getAddedShares(daiAssetId) - addedSharesBefore, 'minted shares');
    assertGe(hub1.previewAddByShares(daiAssetId, 1e18), sharePriceBefore, 'share price');
  }

  function test_mintFeeShares_noFees() public {
    test_mintFeeShares();

    IHub.Asset memory asset = hub1.getAsset(daiAssetId);

    // pausing the fee receiver does not revert the action since no shares are minted
    updateSpokeActive(hub1, daiAssetId, _getFeeReceiver(hub1, daiAssetId), false);

    vm.expectEmit(address(hub1));
    emit IHub.UpdateAsset(daiAssetId, asset.drawnIndex, asset.drawnRate, 0);

    vm.recordLogs();
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);
    vm.getRecordedLogs();
    _assertEventNotEmitted(IHub.MintFeeShares.selector);
  }

  function test_mintFeeShares_noShares() public {
    updateLiquidityFee(hub1, daiAssetId, 0);
    _mockInterestRateRay(2);

    // Create debt to build up fees on the existing treasury spoke
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 3,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 1,
      skipTime: 365 days
    });

    // drawn index is 1.0000...002
    assertEq(hub1.getAssetDrawnIndex(daiAssetId), 1e27 + 2);

    _mockInterestRateRay(1e27 - 3);
    updateLiquidityFee(hub1, daiAssetId, PercentageMath.PERCENTAGE_FACTOR);

    // mint fee shares just to accrue (liquidity fee is 0, so no fees are minted)
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);
    skip(365 days);

    // drawn index is 2.000...001
    assertEq(hub1.getAssetDrawnIndex(daiAssetId), 2e27 + 1);

    vm.recordLogs();
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);
    vm.getRecordedLogs();
    _assertEventNotEmitted(IHub.MintFeeShares.selector);

    assertEq(hub1.getAsset(daiAssetId).realizedFees, 1, 'realized fees after');
  }
}
