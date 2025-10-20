// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubMintFeeSharesTest is HubBase {
  function test_mintFeeShares() public {
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
    address feeReceiver = _getFeeReceiver(hub1, daiAssetId);

    // before mintFeeShares, the fee shares should be 0
    uint256 feeAmount = hub1.getAsset(daiAssetId).feeAmount;
    assertEq(feeAmount, 0);
    uint256 feeShares = hub1.getSpokeAddedShares(daiAssetId, feeReceiver);
    assertEq(feeShares, 0);

    // trigger accrual of fees
    Utils.addWithoutMintingFeeShares(hub1, daiAssetId, address(spoke1), 1000e18, bob);

    uint256 expectedMintedShares = hub1.previewAddByAssets(
      daiAssetId,
      hub1.getAsset(daiAssetId).feeAmount
    );

    // after mintFeeShares, the fee shares should be the amount of the fees
    vm.expectEmit(address(hub1));
    emit IHub.AccrueFees(daiAssetId, feeReceiver, expectedMintedShares);

    uint256 mintedShares = hub1.mintFeeShares(daiAssetId);

    assertEq(mintedShares, expectedMintedShares, 'minted shares');
    assertEq(hub1.getAsset(daiAssetId).feeAmount, 0, 'fee amount after');
    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, feeReceiver),
      expectedMintedShares,
      'added shares'
    );
  }
}
