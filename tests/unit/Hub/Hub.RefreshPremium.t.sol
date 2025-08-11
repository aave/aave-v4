// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubRefreshPremiumTest is HubBase {
  function test_refreshPremium_revertsWith_SpokeNotActive() public {
    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: 0,
      offsetDelta: 0,
      realizedDelta: 0
    });
    updateSpokeActive(hub1, daiAssetId, address(spoke1), false);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);
  }

  function test_refreshPremium_emitsEvent() public {
    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: 1,
      offsetDelta: 1,
      realizedDelta: 1
    });
    vm.expectEmit(address(hub1));
    emit IHub.RefreshPremium(daiAssetId, address(spoke1), premiumDelta);

    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);
  }

  /// @dev offsetDelta can't be more than sharesDelta or else underflow
  /// @dev sharesDelta + realizedDelta can't be more than 2 more than offsetDelta
  function test_refreshPremium(
    uint256 sharesDelta,
    uint256 offsetDelta,
    uint256 realizedDelta
  ) public {
    sharesDelta = bound(sharesDelta, 0, MAX_SUPPLY_AMOUNT);
    offsetDelta = bound(offsetDelta, 0, MAX_SUPPLY_AMOUNT);
    realizedDelta = bound(realizedDelta, 0, MAX_SUPPLY_AMOUNT);
    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: int256(sharesDelta),
      offsetDelta: int256(offsetDelta),
      realizedDelta: int256(realizedDelta)
    });
    uint256 assetId = daiAssetId;

    if (offsetDelta > sharesDelta) {
      vm.expectRevert(stdError.arithmeticError);
    } else if (sharesDelta - offsetDelta + realizedDelta > 2) {
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    }
    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);
  }

  function test_refreshPremium_negativeNumbers(
    uint256 sharesDeltaPos,
    uint256 offsetDeltaPos
  ) public {
    uint256 assetId = daiAssetId;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 10000e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);

    DataTypes.Asset memory asset = hub1.getAsset(assetId);

    sharesDeltaPos = bound(sharesDeltaPos, 0, asset.premiumShares);
    offsetDeltaPos = bound(offsetDeltaPos, sharesDeltaPos, sharesDeltaPos + 2);
    if (offsetDeltaPos > asset.premiumOffset) {
      offsetDeltaPos = asset.premiumOffset;
    }

    int256 sharesDelta = -int256(sharesDeltaPos);
    int256 offsetDelta = -int256(offsetDeltaPos);
    int256 realizedDelta = 0;
    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: sharesDelta,
      offsetDelta: offsetDelta,
      realizedDelta: realizedDelta
    });

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);
  }

  function test_refreshPremium_negativeNumbers_withAccrual(
    uint256 sharesDeltaPos,
    uint256 offsetDeltaPos
  ) public {
    uint256 assetId = daiAssetId;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 10000e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);

    skip(322 days);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 1e18, bob);

    DataTypes.Asset memory asset = hub1.getAsset(assetId);

    sharesDeltaPos = bound(sharesDeltaPos, 0, asset.premiumShares);
    offsetDeltaPos = bound(offsetDeltaPos, 0, asset.premiumOffset);
    uint256 realizedDeltaPos;
    uint256 premiumAssetsPos = hub1.convertToDrawnAssets(assetId, sharesDeltaPos);

    // If we introduced debt with shares vs offset, capture with realized delta
    if (offsetDeltaPos > premiumAssetsPos) {
      realizedDeltaPos = offsetDeltaPos - premiumAssetsPos;
    } else {
      realizedDeltaPos = 0;
    }

    int256 sharesDelta = -int256(sharesDeltaPos);
    int256 offsetDelta = -int256(offsetDeltaPos);
    int256 realizedDelta = -int256(realizedDeltaPos);
    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: sharesDelta,
      offsetDelta: offsetDelta,
      realizedDelta: realizedDelta
    });

    // Note that we flip these pos numbers to negative
    if (realizedDeltaPos > asset.realizedPremium) {
      vm.expectRevert(stdError.arithmeticError);
    } else if (premiumAssetsPos > offsetDeltaPos) {
      premiumDelta.offsetDelta = -int256(premiumAssetsPos);
      if (premiumAssetsPos > asset.premiumOffset) {
        // set both shares diff and offset diff to match offset
        premiumDelta.sharesDelta = -int256(hub1.convertToDrawnShares(assetId, asset.premiumOffset));
        premiumDelta.offsetDelta = -int256(uint256(asset.premiumOffset));
      }
    }

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);
  }

  function test_refreshPremium_fuzz_withAccrual(
    uint256 borrowAmount,
    uint256 userPremiumShares,
    uint256 userAccruedPremium,
    uint256 userPremiumSharesNew
  ) public {
    uint256 assetId = daiAssetId;
    uint256 skipTime = vm.randomUint(0, MAX_SKIP_TIME);

    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);
    skip(skipTime);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 1e18, bob);

    DataTypes.Asset memory asset = hub1.getAsset(assetId);

    // Initial user position
    userPremiumShares = bound(userPremiumShares, 0, asset.premiumShares);
    userAccruedPremium = bound(
      userAccruedPremium,
      0,
      hub1.convertToDrawnAssets(assetId, asset.premiumShares) - asset.premiumOffset
    );
    vm.assume(hub1.convertToDrawnAssets(assetId, userPremiumShares) >= userAccruedPremium);
    uint256 userPremiumOffset = hub1.convertToDrawnAssets(assetId, userPremiumShares) -
      userAccruedPremium;

    // New user position
    userPremiumSharesNew = bound(userPremiumSharesNew, 0, MAX_SUPPLY_AMOUNT / 2);
    uint256 userPremiumOffsetNew = hub1.previewDrawByShares(assetId, userPremiumSharesNew);

    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: int256(userPremiumSharesNew) - int256(userPremiumShares),
      offsetDelta: int256(userPremiumOffsetNew) - int256(userPremiumOffset),
      realizedDelta: int256(userAccruedPremium)
    });

    if (
      premiumDelta.sharesDelta < 0 &&
      -premiumDelta.sharesDelta > int256(uint256(asset.premiumShares))
    ) {
      vm.expectRevert(stdError.arithmeticError);
    } else if (
      premiumDelta.offsetDelta < 0 &&
      -premiumDelta.offsetDelta > int256(uint256(asset.premiumOffset))
    ) {
      vm.expectRevert(stdError.arithmeticError);
    }

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);
  }
}
