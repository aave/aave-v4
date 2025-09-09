// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubRefreshPremiumTest is HubBase {
  using SafeCast for *;
  using MathUtils for uint256;

  struct PremiumDataLocal {
    uint256 premiumShares;
    uint256 premiumOffset;
    uint256 realizedPremium;
  }

  function test_refreshPremium_revertsWith_SpokeNotActive() public {
    DataTypes.PremiumDelta memory premiumDelta;
    updateSpokeActive(hub1, daiAssetId, address(spoke1), false);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);
  }

  function test_refreshPremium_emitsEvent() public {
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(daiAssetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);

    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: 1,
      offsetDelta: 1,
      realizedDelta: 1
    });
    vm.expectEmit(address(hub1));
    emit IHub.RefreshPremium(daiAssetId, address(spoke1), premiumDelta);

    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    assertEq(
      _loadAssetPremiumData(daiAssetId),
      _applyPremiumDelta(premiumDataBefore, premiumDelta)
    );
    assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
  }

  /// @dev offsetDelta can't be more than sharesDelta or else underflow
  /// @dev sharesDelta + realizedDelta can't be more than 2 more than offsetDelta
  function test_refreshPremium_fuzz_positiveDeltas(
    int256 sharesDelta,
    int256 offsetDelta,
    int256 realizedDelta
  ) public {
    sharesDelta = bound(sharesDelta, 0, MAX_SUPPLY_AMOUNT.toInt256());
    offsetDelta = bound(offsetDelta, 0, MAX_SUPPLY_AMOUNT.toInt256());
    realizedDelta = bound(realizedDelta, 0, MAX_SUPPLY_AMOUNT.toInt256());
    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: sharesDelta,
      offsetDelta: offsetDelta,
      realizedDelta: realizedDelta
    });

    uint256 assetId = daiAssetId;
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(assetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);
    bool reverting;

    if (offsetDelta > sharesDelta) {
      reverting = true;
      vm.expectRevert(stdError.arithmeticError);
    } else if (sharesDelta - offsetDelta + realizedDelta > 2) {
      reverting = true;
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    }
    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    if (!reverting) {
      assertEq(_loadAssetPremiumData(assetId), _applyPremiumDelta(premiumDataBefore, premiumDelta));
      assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
    }
  }

  function test_refreshPremium_negativeDeltas(int256 sharesDeltaPos, int256 offsetDeltaPos) public {
    uint256 assetId = daiAssetId;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 10000e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);

    DataTypes.Asset memory asset = hub1.getAsset(assetId);
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(assetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);

    sharesDeltaPos = bound(sharesDeltaPos, 0, asset.premiumShares.toInt256());
    offsetDeltaPos = bound(offsetDeltaPos, sharesDeltaPos, sharesDeltaPos + 2);
    if (offsetDeltaPos > asset.premiumOffset.toInt256()) {
      offsetDeltaPos = asset.premiumOffset.toInt256();
    }

    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: -sharesDeltaPos,
      offsetDelta: -offsetDeltaPos,
      realizedDelta: 0
    });

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    assertEq(_loadAssetPremiumData(assetId), _applyPremiumDelta(premiumDataBefore, premiumDelta));
    assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
  }

  function test_refreshPremium_negativeDeltas_withAccrual(
    uint256 sharesDeltaPos,
    uint256 offsetDeltaPos
  ) public {
    uint256 assetId = daiAssetId;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 10000e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);

    skip(322 days);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 1e18, bob);

    DataTypes.Asset memory asset = hub1.getAsset(assetId);
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(assetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);
    bool reverting;

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

    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: -sharesDeltaPos.toInt256(),
      offsetDelta: -offsetDeltaPos.toInt256(),
      realizedDelta: -realizedDeltaPos.toInt256()
    });

    // Note that we flip these pos numbers to negative
    if (realizedDeltaPos > asset.realizedPremium) {
      reverting = true;
      vm.expectRevert(stdError.arithmeticError);
    } else if (premiumAssetsPos > offsetDeltaPos) {
      premiumDelta.offsetDelta = -premiumAssetsPos.toInt256();
      if (premiumAssetsPos > asset.premiumOffset) {
        // set both shares diff and offset diff to match offset
        premiumDelta.sharesDelta = -(
          hub1.convertToDrawnShares(assetId, asset.premiumOffset).toInt256()
        );
        premiumDelta.offsetDelta = -asset.premiumOffset.toInt256();
      }
    }

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    if (!reverting) {
      assertEq(_loadAssetPremiumData(assetId), _applyPremiumDelta(premiumDataBefore, premiumDelta));
      assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
    }
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
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(assetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);
    bool reverting;

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
    userPremiumSharesNew = bound(
      userPremiumSharesNew,
      0,
      hub1.convertToDrawnShares(assetId, MAX_SUPPLY_AMOUNT / 2)
    );
    uint256 userPremiumOffsetNew = hub1.previewDrawByShares(assetId, userPremiumSharesNew);

    DataTypes.PremiumDelta memory premiumDelta = DataTypes.PremiumDelta({
      sharesDelta: userPremiumSharesNew.toInt256() - userPremiumShares.toInt256(),
      offsetDelta: userPremiumOffsetNew.toInt256() - userPremiumOffset.toInt256(),
      realizedDelta: userAccruedPremium.toInt256()
    });

    if (
      premiumDelta.sharesDelta < 0 && -premiumDelta.sharesDelta > asset.premiumShares.toInt256()
    ) {
      reverting = true;
      vm.expectRevert(stdError.arithmeticError);
    } else if (
      premiumDelta.offsetDelta < 0 && -premiumDelta.offsetDelta > asset.premiumOffset.toInt256()
    ) {
      reverting = true;
      vm.expectRevert(stdError.arithmeticError);
    }

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    if (!reverting) {
      assertEq(_loadAssetPremiumData(assetId), _applyPremiumDelta(premiumDataBefore, premiumDelta));
      assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
    }
  }

  function _loadAssetPremiumData(uint256 assetId) internal view returns (PremiumDataLocal memory) {
    DataTypes.Asset memory asset = hub1.getAsset(assetId);
    return PremiumDataLocal(asset.premiumShares, asset.premiumOffset, asset.realizedPremium);
  }

  function _applyPremiumDelta(
    PremiumDataLocal memory premiumData,
    DataTypes.PremiumDelta memory premiumDelta
  ) internal pure returns (PremiumDataLocal memory) {
    premiumData.premiumShares = premiumData.premiumShares.add(premiumDelta.sharesDelta).toUint128();
    premiumData.premiumOffset = premiumData.premiumOffset.add(premiumDelta.offsetDelta).toUint128();
    premiumData.realizedPremium = premiumData
      .realizedPremium
      .add(premiumDelta.realizedDelta)
      .toUint128();
    return premiumData;
  }

  function assertEq(PremiumDataLocal memory a, PremiumDataLocal memory b) internal pure {
    assertEq(a.premiumShares, b.premiumShares, 'premium shares');
    assertEq(a.premiumOffset, b.premiumOffset, 'premium offset');
    assertEq(a.realizedPremium, b.realizedPremium, 'realized premium');
    assertEq(abi.encode(a), abi.encode(b));
  }
}
