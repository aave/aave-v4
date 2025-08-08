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

  // TODO: A strategy where I just calculate what will happen in advance and proceed accordingly
  // TODO: A strategy where I fix one number and adjust the rest to follow
  function test_refreshPremium_fuzz_withAccrual(
    int256 sharesDelta,
    int256 offsetDelta,
    int256 realizedDelta
  ) public {
    uint256 assetId = daiAssetId;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 10000e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);

    skip(322 days);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 1e18, bob);

    DataTypes.Asset memory asset = hub1.getAsset(assetId);

    sharesDelta = bound(
      sharesDelta,
      -int256(uint256(asset.premiumShares)),
      int256(MAX_SUPPLY_AMOUNT / 2)
    );
    offsetDelta = bound(
      offsetDelta,
      -int256(uint256(asset.premiumOffset)),
      int256(MAX_SUPPLY_AMOUNT / 2)
    );
    realizedDelta = bound(
      realizedDelta,
      -int256(MAX_SUPPLY_AMOUNT / 2),
      int256(MAX_SUPPLY_AMOUNT / 2)
    );

    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: int256(sharesDelta),
      offsetDelta: int256(offsetDelta),
      realizedDelta: int256(realizedDelta)
    });

    int256 premiumAssetsDelta;

    if (
      (sharesDelta < 0 && -sharesDelta > int256(uint256(asset.premiumShares))) ||
      (offsetDelta < 0 && -offsetDelta > int256(uint256(asset.premiumOffset))) ||
      (realizedDelta < 0 && -realizedDelta > int256(uint256(asset.realizedPremium)))
    ) {
      vm.expectRevert(stdError.arithmeticError);
    } else if (sharesDelta >= 0) {
      console.log('positive shares delta case');
      premiumAssetsDelta = int256(hub1.convertToDrawnAssets(assetId, uint256(sharesDelta)));
      // If we introduced debt with shares vs offset, capture with realized delta
      if (premiumAssetsDelta > offsetDelta) {
        premiumDelta.realizedDelta = -int256(premiumAssetsDelta - offsetDelta);
        console.log('case that premium assets delta greater than offset delta');
        if (-premiumDelta.realizedDelta > int256(uint256(asset.realizedPremium))) {
          vm.expectRevert(stdError.arithmeticError);
        }
      } else {
        premiumDelta.realizedDelta = 0;
      }

      if (offsetDelta > premiumAssetsDelta) {
        vm.expectRevert(stdError.arithmeticError);
        console.log('case that offset delta greater than premium assets delta');
      }
    } else {
      premiumAssetsDelta = -int256(hub1.convertToDrawnAssets(assetId, uint256(-sharesDelta)));

      // If we introduced debt with shares vs offset, capture with realized delta
      if (premiumAssetsDelta > offsetDelta) {
        premiumDelta.realizedDelta = -int256(premiumAssetsDelta - offsetDelta);
        if (-premiumDelta.realizedDelta > int256(uint256(asset.realizedPremium))) {
          vm.expectRevert(stdError.arithmeticError);
        }
      } else {
        premiumDelta.realizedDelta = 0;
      }

      // TODO: Make this condition work
      // Note that we flip these pos numbers to negative
      if (offsetDelta > premiumAssetsDelta) {
        premiumDelta.offsetDelta = int256(premiumAssetsDelta);
        if (-premiumDelta.offsetDelta > int256(uint256(asset.premiumOffset))) {
          // set both shares diff and offset diff to match offset
          premiumDelta.sharesDelta = int256(
            hub1.convertToDrawnShares(assetId, asset.premiumOffset)
          );
          premiumDelta.offsetDelta = int256(uint256(asset.premiumOffset));
        }
      }
    }

    /*
    if (offsetDelta > sharesDelta) {
      vm.expectRevert(stdError.arithmeticError);
    } else if (sharesDelta - offsetDelta + realizedDelta > 2) {
      // TODO: Handle realizedDelta better
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    }
    */
    if (premiumAssetsDelta > 0) {
      console.log('premiumAssetsDelta: %s', uint256(premiumAssetsDelta));
    } else {
      console.log('premiumAssetsDelta : %s', uint256(-premiumAssetsDelta));
    }
    console.log(
      'sharesDelta: %s, offsetDelta: %s, realizedDelta: %s',
      premiumDelta.sharesDelta >= 0
        ? uint256(premiumDelta.sharesDelta)
        : uint256(-premiumDelta.sharesDelta),
      premiumDelta.offsetDelta >= 0
        ? uint256(premiumDelta.offsetDelta)
        : uint256(-premiumDelta.offsetDelta),
      premiumDelta.realizedDelta >= 0
        ? uint256(premiumDelta.realizedDelta)
        : uint256(-premiumDelta.realizedDelta)
    );
    if (premiumDelta.sharesDelta < 0) {
      console.log('sharesDelta negative');
    }
    if (premiumDelta.offsetDelta < 0) {
      console.log('offsetDelta negative');
    }
    if (premiumDelta.realizedDelta < 0) {
      console.log('realizedDelta negative');
    }

    console.log('asset.premiumShares: %s', asset.premiumShares);
    console.log('asset.premiumOffset: %s', asset.premiumOffset);
    console.log('asset.realizedPremium: %s', asset.realizedPremium);

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);
  }

  /*
  // TODO: Write a fuzz test with positive or negative numbers, with debt accrual
  // TODO: If I can't generalize, fuzz just 1 number, like sharesDelta, and make the others work around it
  function test_refreshPremium_fuzz_withAccrual(int256 sharesDelta) public {
    // Bob supplies and borrows dai via spoke 1
    uint256 assetId = daiAssetId;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 10000e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);

    skip(322 days);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 1e18, bob);

    DataTypes.Asset memory asset = hub1.getAsset(assetId);

    sharesDelta = bound(sharesDelta, -int256(asset.premiumShares), int256(asset.premiumShares));
    int256 offsetDelta = -int256(asset.premiumOffset); // todo: left off here
    int256 realizedDelta = -int256(asset.realizedPremium);
    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: -int256(sharesDelta),
      offsetDelta: offsetDelta,
      realizedDelta: realizedDelta
    });

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);
  }
  */
}
