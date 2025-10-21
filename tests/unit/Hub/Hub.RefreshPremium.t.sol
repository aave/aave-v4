// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubRefreshPremiumTest is HubBase {
  using SafeCast for *;
  using PercentageMath for *;
  using MathUtils for uint256;
  using WadRayMath for uint256;

  struct PremiumDataLocal {
    uint256 premiumShares;
    uint256 premiumOffset;
    uint256 realizedPremium;
  }

  function test_refreshPremium_revertsWith_SpokeNotActive() public {
    IHubBase.PremiumDelta memory premiumDelta;
    updateSpokeActive(hub1, daiAssetId, address(spoke1), false);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);
  }

  function _createDrawnSharesAndPremiumData() internal {
    Utils.supplyCollateral(spoke1, _wbtcReserveId(spoke1), bob, MAX_SUPPLY_AMOUNT, bob);

    uint256 amount1 = vm.randomUint(1, MAX_SUPPLY_AMOUNT / 2);
    uint256 amount2 = vm.randomUint(1, MAX_SUPPLY_AMOUNT - amount1);

    // create drawn shares and premium data
    _addLiquidity(daiAssetId, MAX_SUPPLY_AMOUNT);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, amount1, bob);
    skip(322 days);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, amount2, bob);
    skip(322 days);
  }

  /// @dev reverts with InvalidPremiumChange with a risk premium cap of 0
  /// @dev allowed if premiumData is within risk premium cap
  function test_refreshPremium_riskPremiumCap() public {
    _createDrawnSharesAndPremiumData();

    uint24 riskPremiumCap = 0.toUint24();
    _updateSpokeRiskPremiumCap(hub1, daiAssetId, address(spoke1), riskPremiumCap);

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: 1, // no shares delta allowed
      offsetDelta: 0,
      realizedDelta: 0
    });

    IHub.Asset memory asset = hub1.getAsset(daiAssetId);
    // expect allowed condition not to be met
    assertFalse(
      asset.premiumShares + premiumDelta.sharesDelta.toUint256() <=
        asset.drawnShares.percentMulUp(riskPremiumCap)
    );

    vm.expectRevert(IHub.InvalidPremiumChange.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);

    riskPremiumCap = (vm.randomUint(0, Constants.MAX_ALLOWED_RISK_PREMIUM_CAP - 1)).toUint24();
    _updateSpokeRiskPremiumCap(hub1, daiAssetId, address(spoke1), riskPremiumCap);

    // expect allowed condition to be met
    assertTrue(
      asset.premiumShares + premiumDelta.sharesDelta.toUint256() <=
        asset.drawnShares.percentMulUp(riskPremiumCap)
    );
    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);
  }

  /// @dev if risk premium cap is max allowed sentinel val, then exceeding max collateral risk is allowed
  function test_refreshPremium_maxRiskPremiumCap() public {
    _createDrawnSharesAndPremiumData();

    _updateSpokeRiskPremiumCap(
      hub1,
      daiAssetId,
      address(spoke1),
      Constants.MAX_ALLOWED_RISK_PREMIUM_CAP
    );

    assertEq(
      hub1.getSpokeConfig(daiAssetId, address(spoke1)).riskPremiumCap,
      Constants.MAX_ALLOWED_RISK_PREMIUM_CAP
    );

    IHub.SpokeData memory spokeData = hub1.getSpoke(daiAssetId, address(spoke1));
    PremiumDataLocal memory premiumData = _loadAssetPremiumData(hub1, daiAssetId);
    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: spokeData
        .drawnShares
        .percentMulUp(Constants.MAX_ALLOWED_COLLATERAL_RISK + 1)
        .toInt256(), // no shares delta allowed
      offsetDelta: 0,
      realizedDelta: 0
    });
    premiumDelta.offsetDelta = hub1
      .previewDrawByShares(daiAssetId, premiumDelta.sharesDelta.toUint256())
      .toInt256();

    // condition not met on max coll risk, but still allowed with MAX_ALLOWED_RISK_PREMIUM_CAP
    assertFalse(
      premiumData.premiumShares + premiumDelta.sharesDelta.toUint256() <=
        spokeData.drawnShares.percentMulUp(Constants.MAX_ALLOWED_COLLATERAL_RISK)
    );

    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);
  }

  /// @dev paused but active spokes are allowed to refresh premium
  function test_refreshPremium_pausedSpokesAllowed() public {
    IHubBase.PremiumDelta memory premiumDelta;
    updateSpokeActive(hub1, daiAssetId, address(spoke1), true);
    _updateSpokePaused(hub1, daiAssetId, address(spoke1), true);

    vm.expectEmit(address(hub1));
    emit IHubBase.RefreshPremium(daiAssetId, address(spoke1), premiumDelta);

    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);
  }

  function test_refreshPremium_emitsEvent() public {
    vm.startPrank(address(spoke1));
    hub1.add(daiAssetId, 10000e18, alice);
    hub1.draw(daiAssetId, 5000e18, alice);

    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, daiAssetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: 1,
      offsetDelta: 1,
      realizedDelta: 1
    });
    vm.expectEmit(address(hub1));
    emit IHubBase.RefreshPremium(daiAssetId, address(spoke1), premiumDelta);

    hub1.refreshPremium(daiAssetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    assertEq(
      _loadAssetPremiumData(hub1, daiAssetId),
      _applyPremiumDelta(premiumDataBefore, premiumDelta)
    );
    assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
    assertBorrowRateSynced(hub1, daiAssetId, 'after refreshPremium');
    vm.stopPrank();
  }

  /// @dev offsetDelta can't be more than sharesDelta or else underflow
  /// @dev sharesDelta + realizedDelta can't be more than 2 more than offsetDelta
  function test_refreshPremium_fuzz_positiveDeltas(
    uint256 borrowAmount,
    int256 sharesDelta,
    int256 offsetDelta,
    int256 realizedDelta,
    bool isRiskPremiumCapMaxAllowed
  ) public {
    sharesDelta = bound(sharesDelta, 0, MAX_SUPPLY_AMOUNT.toInt256());
    offsetDelta = bound(offsetDelta, 0, MAX_SUPPLY_AMOUNT.toInt256());
    realizedDelta = bound(realizedDelta, 0, MAX_SUPPLY_AMOUNT.toInt256());
    borrowAmount = bound(borrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: sharesDelta,
      offsetDelta: offsetDelta,
      realizedDelta: realizedDelta
    });

    uint256 assetId = daiAssetId;

    uint24 riskPremiumCap = vm.randomUint(0, Constants.MAX_ALLOWED_RISK_PREMIUM_CAP - 1).toUint24();
    if (isRiskPremiumCapMaxAllowed) {
      // sentinel value to preclude check
      riskPremiumCap = Constants.MAX_ALLOWED_RISK_PREMIUM_CAP;
    }
    _updateSpokeRiskPremiumCap(hub1, assetId, address(spoke1), riskPremiumCap);

    if (borrowAmount > 0) {
      Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, borrowAmount * 2, bob);
      Utils.borrow(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);
    }

    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, assetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);
    bool reverting;
    IHub.Asset memory asset = hub1.getAsset(assetId);
    uint256 expectedPremiumShares = sharesDelta > 0
      ? asset.premiumShares + sharesDelta.toUint256()
      : asset.premiumShares - (-sharesDelta).toUint256();
    uint256 expectedOffset = offsetDelta > 0
      ? asset.premiumOffset + offsetDelta.toUint256()
      : asset.premiumOffset - (-offsetDelta).toUint256();

    // Only 1 spoke drawing so checks on asset are equivalent to spoke
    if (expectedOffset > expectedPremiumShares.rayMulUp(asset.drawnIndex)) {
      reverting = true;
      vm.expectRevert(stdError.arithmeticError);
    } else if (
      riskPremiumCap != Constants.MAX_ALLOWED_RISK_PREMIUM_CAP &&
      asset.drawnShares.percentMulUp(riskPremiumCap) < asset.premiumShares + sharesDelta.toUint256()
    ) {
      reverting = true;
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    } else if (sharesDelta - offsetDelta + realizedDelta > 2) {
      reverting = true;
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    }
    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    if (!reverting) {
      assertEq(
        _loadAssetPremiumData(hub1, assetId),
        _applyPremiumDelta(premiumDataBefore, premiumDelta)
      );
      assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
      assertBorrowRateSynced(hub1, daiAssetId, 'after refreshPremium');
    }
  }

  function test_refreshPremium_negativeDeltas(int256 sharesDeltaPos, int256 offsetDeltaPos) public {
    uint256 assetId = daiAssetId;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 10000e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);

    IHub.Asset memory asset = hub1.getAsset(assetId);
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, assetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);

    sharesDeltaPos = bound(sharesDeltaPos, 0, asset.premiumShares.toInt256());
    offsetDeltaPos = bound(offsetDeltaPos, sharesDeltaPos, sharesDeltaPos + 2);
    if (offsetDeltaPos > asset.premiumOffset.toInt256()) {
      offsetDeltaPos = asset.premiumOffset.toInt256();
    }

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: -sharesDeltaPos,
      offsetDelta: -offsetDeltaPos,
      realizedDelta: 0
    });

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    assertEq(
      _loadAssetPremiumData(hub1, assetId),
      _applyPremiumDelta(premiumDataBefore, premiumDelta)
    );
    assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
    assertBorrowRateSynced(hub1, daiAssetId, 'after refreshPremium');
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

    IHub.Asset memory asset = hub1.getAsset(assetId);
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, assetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);
    bool reverting;

    sharesDeltaPos = bound(sharesDeltaPos, 0, asset.premiumShares);
    offsetDeltaPos = bound(offsetDeltaPos, 0, asset.premiumOffset);
    uint256 realizedDeltaPos;
    uint256 premiumAssetsPos = hub1.previewRestoreByShares(assetId, sharesDeltaPos);

    // If we introduced debt with shares vs offset, capture with realized delta
    if (offsetDeltaPos > premiumAssetsPos) {
      realizedDeltaPos = offsetDeltaPos - premiumAssetsPos;
    } else {
      realizedDeltaPos = 0;
    }

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
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
          hub1.previewRestoreByAssets(assetId, asset.premiumOffset).toInt256()
        );
        premiumDelta.offsetDelta = -asset.premiumOffset.toInt256();
      }
    }

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    if (!reverting) {
      assertEq(
        _loadAssetPremiumData(hub1, assetId),
        _applyPremiumDelta(premiumDataBefore, premiumDelta)
      );
      assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
      assertBorrowRateSynced(hub1, daiAssetId, 'after refreshPremium');
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

    IHub.Asset memory asset = hub1.getAsset(assetId);
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, assetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);
    bool reverting;

    // Initial user position
    userPremiumShares = bound(userPremiumShares, 0, asset.premiumShares);
    userAccruedPremium = bound(
      userAccruedPremium,
      0,
      hub1.previewRestoreByShares(assetId, asset.premiumShares) - asset.premiumOffset
    );
    vm.assume(hub1.previewRestoreByShares(assetId, userPremiumShares) >= userAccruedPremium);
    uint256 userPremiumOffset = hub1.previewRestoreByShares(assetId, userPremiumShares) -
      userAccruedPremium;

    // New user position
    userPremiumSharesNew = bound(
      userPremiumSharesNew,
      0,
      hub1.previewRestoreByAssets(assetId, MAX_SUPPLY_AMOUNT / 2)
    );
    uint256 userPremiumOffsetNew = hub1.previewDrawByShares(assetId, userPremiumSharesNew);

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: userPremiumSharesNew.toInt256() - userPremiumShares.toInt256(),
      offsetDelta: userPremiumOffsetNew.toInt256() - userPremiumOffset.toInt256(),
      realizedDelta: userAccruedPremium.toInt256()
    });

    uint256 expectedPremiumShares = premiumDelta.sharesDelta >= 0
      ? asset.premiumShares + premiumDelta.sharesDelta.toUint256()
      : asset.premiumShares - (-premiumDelta.sharesDelta).toUint256();

    if (asset.drawnShares.percentMulUp(1000_00) < expectedPremiumShares) {
      reverting = true;
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    } else if (
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
      assertEq(
        _loadAssetPremiumData(hub1, assetId),
        _applyPremiumDelta(premiumDataBefore, premiumDelta)
      );
      assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
      assertBorrowRateSynced(hub1, daiAssetId, 'after refreshPremium');
    }
  }

  function test_refreshPremium_spokePremiumUpdateIsContained() public {
    uint256 assetId = daiAssetId;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);
    Utils.supplyCollateral(spoke2, _daiReserveId(spoke2), alice, 10000e18, alice);
    Utils.borrow(spoke2, _daiReserveId(spoke2), alice, 5000e18, alice);

    skip(322 days);

    uint256 spoke1AccruedPremium = _getSpokeAccruedPremium(hub1, assetId, address(spoke1));
    uint256 spoke2AccruedPremium = _getSpokeAccruedPremium(hub1, assetId, address(spoke2));
    assertGt(spoke1AccruedPremium, 0);
    assertGt(spoke2AccruedPremium, 0);

    vm.expectRevert(stdError.arithmeticError);
    // realize premium by manipulating offset
    vm.prank(address(spoke1));
    hub1.refreshPremium(
      assetId,
      IHubBase.PremiumDelta({
        sharesDelta: 0,
        offsetDelta: (spoke1AccruedPremium + spoke2AccruedPremium).toInt256(),
        realizedDelta: (spoke1AccruedPremium + spoke2AccruedPremium).toInt256()
      })
    );
  }

  function _getSpokeAccruedPremium(
    IHub hub,
    uint256 assetId,
    address spoke
  ) internal view returns (uint256) {
    IHub.SpokeData memory spokeData = hub.getSpoke(assetId, spoke);
    return hub.previewRestoreByShares(assetId, spokeData.premiumShares) - spokeData.premiumOffset;
  }

  function _loadAssetPremiumData(
    IHub hub,
    uint256 assetId
  ) internal view returns (PremiumDataLocal memory) {
    IHub.Asset memory asset = hub.getAsset(assetId);
    return PremiumDataLocal(asset.premiumShares, asset.premiumOffset, asset.realizedPremium);
  }

  function _applyPremiumDelta(
    PremiumDataLocal memory premiumData,
    IHubBase.PremiumDelta memory premiumDelta
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
