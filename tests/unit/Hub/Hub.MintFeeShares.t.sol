// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubMintFeeSharesTest is HubBase {
  function setUp() public override {
    super.setUp();
    // Create debt to build up fees on the existing treasury spoke
    _addAndDrawLiquidity(
      hub1,
      daiAssetId,
      bob,
      address(spoke1),
      1000e18,
      bob,
      address(spoke1),
      100e18,
      365 days
    );
  }

  function test_mintFeeShares() public {
    address feeReceiver = _getFeeReceiver(hub1, daiAssetId);

    // before mintFeeShares, the fee shares should be 0
    uint256 feeAmount = hub1.getAsset(daiAssetId).feeAmount;
    assertEq(feeAmount, 0);
    uint256 feeShares = hub1.getSpokeAddedShares(daiAssetId, feeReceiver);
    assertEq(feeShares, 0);

    uint256 expectedMintedShares = hub1.previewAddByAssets(
      daiAssetId,
      _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId)
    );

    IHub.Asset memory asset = hub1.getAsset(daiAssetId);
    bytes memory irCalldata = abi.encodeCall(
      IBasicInterestRateStrategy.calculateInterestRate,
      (
        daiAssetId,
        asset.liquidity,
        hub1.previewRestoreByShares(daiAssetId, hub1.getAssetDrawnShares(daiAssetId)),
        asset.deficit,
        asset.swept
      )
    );
    uint256 mockRate = 0.3e27;
    vm.mockCall(address(irStrategy), irCalldata, abi.encode(mockRate));

    // after mintFeeShares, the fee shares should be the amount of the fees
    vm.expectEmit(address(hub1));
    emit IHub.UpdateAsset(daiAssetId, hub1.getAssetDrawnIndex(daiAssetId), mockRate);
    vm.expectEmit(address(hub1));
    emit IHub.AccrueFees(daiAssetId, feeReceiver, expectedMintedShares);

    uint256 addedSharesBefore = hub1.getAddedShares(daiAssetId);
    uint256 sharePriceBefore = hub1.previewAddByShares(daiAssetId, 1e18);

    vm.expectCall(address(irStrategy), irCalldata);
    uint256 mintedShares = hub1.mintFeeShares(daiAssetId);

    assertEq(mintedShares, expectedMintedShares, 'minted shares');
    assertEq(hub1.getAsset(daiAssetId).feeAmount, 0, 'fee amount after');
    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, feeReceiver),
      expectedMintedShares,
      'added shares'
    );
    assertEq(mintedShares, hub1.getAddedShares(daiAssetId) - addedSharesBefore, 'minted shares');
    assertGe(hub1.previewAddByShares(daiAssetId, 1e18), sharePriceBefore, 'share price');
  }
}
