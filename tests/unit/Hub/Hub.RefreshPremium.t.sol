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
  /// @dev sharesDelta can't be more than 2 more than offsetDelta
  /// @dev realizedDelta can't be more than 2
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
    } else if (sharesDelta > 2 + offsetDelta || realizedDelta > 2) {
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    }
    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);
  }

  function test_refreshPremium_negativeNumbers(
    uint256 sharesDeltaPos,
    uint256 offsetDeltaPos
  ) public {
    // Bob supplies and borrows dai via spoke 1
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
    // Bob supplies and borrows dai via spoke 1
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
    if (realizedDeltaPos > asset.realizedPremium) {
      vm.expectRevert(stdError.arithmeticError);
    } else if (premiumAssetsPos > offsetDeltaPos) {
      vm.expectRevert(stdError.arithmeticError);
    }

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);
  }
}
