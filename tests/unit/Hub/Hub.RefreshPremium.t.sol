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
    updateSpokeActive(hub1, address(tokenList.dai), address(spoke1), false);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(address(tokenList.dai), premiumDelta);
  }

  function _createDrawnSharesAndPremiumData() internal {
    Utils.supplyCollateral(spoke1, _wbtcReserveId(spoke1), bob, MAX_SUPPLY_AMOUNT, bob);

    uint256 amount1 = vm.randomUint(1, MAX_SUPPLY_AMOUNT / 2);
    uint256 amount2 = vm.randomUint(1, MAX_SUPPLY_AMOUNT - amount1);

    // create drawn shares and premium data
    _addLiquidity(address(tokenList.dai), MAX_SUPPLY_AMOUNT);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, amount1, bob);
    skip(322 days);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, amount2, bob);
    skip(322 days);
  }

  /// @dev reverts with InvalidPremiumChange with a risk premium threshold of 0
  /// @dev allowed if premiumData is within risk premium threshold
  function test_refreshPremium_riskPremiumThreshold() public {
    _createDrawnSharesAndPremiumData();

    uint24 riskPremiumThreshold = 0.toUint24();
    _updateSpokeRiskPremiumThreshold(
      hub1,
      address(tokenList.dai),
      address(spoke1),
      riskPremiumThreshold
    );

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: 1,
      offsetDelta: 0,
      realizedDelta: 0
    });

    IHub.Asset memory asset = hub1.getAsset(address(tokenList.dai));
    // expect allowed condition not to be met
    assertFalse(
      asset.premiumShares + premiumDelta.sharesDelta.toUint256() <=
        asset.drawnShares.percentMulUp(riskPremiumThreshold)
    );

    vm.expectRevert(IHub.InvalidPremiumChange.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(address(tokenList.dai), premiumDelta);

    riskPremiumThreshold = (vm.randomUint(0, Constants.MAX_RISK_PREMIUM_THRESHOLD - 1)).toUint24();
    _updateSpokeRiskPremiumThreshold(
      hub1,
      address(tokenList.dai),
      address(spoke1),
      riskPremiumThreshold
    );

    // expect allowed condition to be met
    assertTrue(
      asset.premiumShares + premiumDelta.sharesDelta.toUint256() <=
        asset.drawnShares.percentMulUp(riskPremiumThreshold)
    );
    vm.prank(address(spoke1));
    hub1.refreshPremium(address(tokenList.dai), premiumDelta);
  }

  /// @dev reverts with InvalidPremiumChange as long as threshold is exceeded (even though risk premium is decreasing)
  function test_refreshPremium_revertsWith_InvalidPremiumChange_RiskPremiumThresholdExceeded_DecreasingPremium()
    public
  {
    _createDrawnSharesAndPremiumData();

    uint24 riskPremiumThreshold = 1_00; // 1%
    _updateSpokeRiskPremiumThreshold(
      hub1,
      address(tokenList.dai),
      address(spoke1),
      riskPremiumThreshold
    );

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: -1,
      offsetDelta: -1,
      realizedDelta: 0
    });

    vm.expectRevert(IHub.InvalidPremiumChange.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(address(tokenList.dai), premiumDelta);
  }

  /// @dev if risk premium threshold is max allowed sentinel val, then exceeding max collateral risk is allowed
  function test_refreshPremium_maxRiskPremiumThreshold() public {
    _createDrawnSharesAndPremiumData();

    _updateSpokeRiskPremiumThreshold(
      hub1,
      address(tokenList.dai),
      address(spoke1),
      Constants.MAX_RISK_PREMIUM_THRESHOLD
    );

    assertEq(
      hub1.getSpokeConfig(address(tokenList.dai), address(spoke1)).riskPremiumThreshold,
      Constants.MAX_RISK_PREMIUM_THRESHOLD
    );

    IHub.SpokeData memory spokeData = hub1.getSpoke(address(tokenList.dai), address(spoke1));
    PremiumDataLocal memory premiumData = _loadAssetPremiumData(hub1, address(tokenList.dai));
    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: spokeData
        .drawnShares
        .percentMulUp(Constants.MAX_ALLOWED_COLLATERAL_RISK + 1)
        .toInt256(), // no shares delta allowed
      offsetDelta: 0,
      realizedDelta: 0
    });
    premiumDelta.offsetDelta = hub1
      .previewDrawByShares(address(tokenList.dai), premiumDelta.sharesDelta.toUint256())
      .toInt256();

    // condition not met on max coll risk, but still allowed with MAX_RISK_PREMIUM_THRESHOLD
    assertFalse(
      premiumData.premiumShares + premiumDelta.sharesDelta.toUint256() <=
        spokeData.drawnShares.percentMulUp(Constants.MAX_ALLOWED_COLLATERAL_RISK)
    );

    vm.prank(address(spoke1));
    hub1.refreshPremium(address(tokenList.dai), premiumDelta);
  }

  /// @dev paused but active spokes are allowed to refresh premium
  function test_refreshPremium_pausedSpokesAllowed() public {
    IHubBase.PremiumDelta memory premiumDelta;
    updateSpokeActive(hub1, address(tokenList.dai), address(spoke1), true);
    _updateSpokePaused(hub1, address(tokenList.dai), address(spoke1), true);

    vm.expectEmit(address(hub1));
    emit IHubBase.RefreshPremium(address(tokenList.dai), address(spoke1), premiumDelta);

    vm.prank(address(spoke1));
    hub1.refreshPremium(address(tokenList.dai), premiumDelta);
  }

  function test_refreshPremium_emitsEvent() public {
    vm.startPrank(address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), 10000e18);
    hub1.add(address(tokenList.dai), 10000e18);
    hub1.draw(address(tokenList.dai), 5000e18, alice);

    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, address(tokenList.dai));
    (, uint256 premiumBefore) = hub1.getAssetOwed(address(tokenList.dai));

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: 1,
      offsetDelta: 1,
      realizedDelta: 1
    });
    vm.expectEmit(address(hub1));
    emit IHubBase.RefreshPremium(address(tokenList.dai), address(spoke1), premiumDelta);

    hub1.refreshPremium(address(tokenList.dai), premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(address(tokenList.dai));

    assertEq(
      _loadAssetPremiumData(hub1, address(tokenList.dai)),
      _applyPremiumDelta(premiumDataBefore, premiumDelta)
    );
    assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
    assertBorrowRateSynced(hub1, address(tokenList.dai), 'after refreshPremium');
    vm.stopPrank();
  }

  /// @dev offsetDelta can't be more than sharesDelta or else underflow
  /// @dev sharesDelta + realizedDelta can't be more than 2 more than offsetDelta
  function test_refreshPremium_fuzz_positiveDeltas(
    uint256 borrowAmount,
    int256 sharesDelta,
    int256 offsetDelta,
    int256 realizedDelta,
    bool isRiskPremiumThresholdMaxAllowed
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

    address asset = address(tokenList.dai);

    uint24 riskPremiumThreshold = vm
      .randomUint(0, Constants.MAX_RISK_PREMIUM_THRESHOLD - 1)
      .toUint24();
    if (isRiskPremiumThresholdMaxAllowed) {
      // sentinel value to preclude check
      riskPremiumThreshold = Constants.MAX_RISK_PREMIUM_THRESHOLD;
    }
    _updateSpokeRiskPremiumThreshold(hub1, asset, address(spoke1), riskPremiumThreshold);

    if (borrowAmount > 0) {
      Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, borrowAmount * 2, bob);
      Utils.borrow(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);
    }

    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, asset);
    (, uint256 premiumBefore) = hub1.getAssetOwed(address(tokenList.dai));
    bool reverting;
    IHub.Asset memory assetData = hub1.getAsset(asset);
    uint256 expectedPremiumShares = sharesDelta > 0
      ? assetData.premiumShares + sharesDelta.toUint256()
      : assetData.premiumShares - (-sharesDelta).toUint256();
    uint256 expectedOffset = offsetDelta > 0
      ? assetData.premiumOffset + offsetDelta.toUint256()
      : assetData.premiumOffset - (-offsetDelta).toUint256();

    // Only 1 spoke drawing so checks on asset are equivalent to spoke
    if (expectedOffset > expectedPremiumShares.rayMulUp(assetData.drawnIndex)) {
      reverting = true;
      vm.expectRevert(stdError.arithmeticError);
    } else if (
      riskPremiumThreshold != Constants.MAX_RISK_PREMIUM_THRESHOLD &&
      assetData.drawnShares.percentMulUp(riskPremiumThreshold) <
      assetData.premiumShares + sharesDelta.toUint256()
    ) {
      reverting = true;
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    } else if (sharesDelta - offsetDelta + realizedDelta > 2) {
      reverting = true;
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    }
    vm.prank(address(spoke1));
    hub1.refreshPremium(asset, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(address(tokenList.dai));

    if (!reverting) {
      assertEq(
        _loadAssetPremiumData(hub1, asset),
        _applyPremiumDelta(premiumDataBefore, premiumDelta)
      );
      assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
      assertBorrowRateSynced(hub1, address(tokenList.dai), 'after refreshPremium');
    }
  }

  function test_refreshPremium_negativeDeltas(int256 sharesDeltaPos, int256 offsetDeltaPos) public {
    address asset = address(tokenList.dai);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 10000e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);

    IHub.Asset memory assetData = hub1.getAsset(asset);
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, asset);
    (, uint256 premiumBefore) = hub1.getAssetOwed(address(tokenList.dai));

    sharesDeltaPos = bound(sharesDeltaPos, 0, assetData.premiumShares.toInt256());
    offsetDeltaPos = bound(offsetDeltaPos, sharesDeltaPos, sharesDeltaPos + 2);
    if (offsetDeltaPos > assetData.premiumOffset.toInt256()) {
      offsetDeltaPos = assetData.premiumOffset.toInt256();
    }

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: -sharesDeltaPos,
      offsetDelta: -offsetDeltaPos,
      realizedDelta: 0
    });

    vm.prank(address(spoke1));
    hub1.refreshPremium(asset, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(address(tokenList.dai));

    assertEq(
      _loadAssetPremiumData(hub1, asset),
      _applyPremiumDelta(premiumDataBefore, premiumDelta)
    );
    assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
    assertBorrowRateSynced(hub1, address(tokenList.dai), 'after refreshPremium');
  }

  function test_refreshPremium_negativeDeltas_withAccrual(
    uint256 sharesDeltaPos,
    uint256 offsetDeltaPos
  ) public {
    address asset = address(tokenList.dai);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 10000e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);

    skip(322 days);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 1e18, bob);

    IHub.Asset memory assetData = hub1.getAsset(asset);
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, asset);
    (, uint256 premiumBefore) = hub1.getAssetOwed(address(tokenList.dai));
    bool reverting;

    sharesDeltaPos = bound(sharesDeltaPos, 0, assetData.premiumShares);
    offsetDeltaPos = bound(offsetDeltaPos, 0, assetData.premiumOffset);
    uint256 realizedDeltaPos;
    uint256 premiumAssetsPos = hub1.previewRestoreByShares(asset, sharesDeltaPos);

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
    if (realizedDeltaPos > assetData.realizedPremium) {
      reverting = true;
      vm.expectRevert(stdError.arithmeticError);
    } else if (premiumAssetsPos > offsetDeltaPos) {
      premiumDelta.offsetDelta = -premiumAssetsPos.toInt256();
      if (premiumAssetsPos > assetData.premiumOffset) {
        // set both shares diff and offset diff to match offset
        premiumDelta.sharesDelta = -(
          hub1.previewRestoreByAssets(asset, assetData.premiumOffset).toInt256()
        );
        premiumDelta.offsetDelta = -assetData.premiumOffset.toInt256();
      }
    }

    vm.prank(address(spoke1));
    hub1.refreshPremium(asset, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(address(tokenList.dai));

    if (!reverting) {
      assertEq(
        _loadAssetPremiumData(hub1, asset),
        _applyPremiumDelta(premiumDataBefore, premiumDelta)
      );
      assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
      assertBorrowRateSynced(hub1, address(tokenList.dai), 'after refreshPremium');
    }
  }

  function test_refreshPremium_fuzz_withAccrual(
    uint256 borrowAmount,
    uint256 userPremiumShares,
    uint256 userAccruedPremium,
    uint256 userPremiumSharesNew
  ) public {
    address asset = address(tokenList.dai);
    uint256 skipTime = vm.randomUint(0, MAX_SKIP_TIME);

    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);
    skip(skipTime);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 1e18, bob);

    IHub.Asset memory assetData = hub1.getAsset(asset);
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, asset);
    (, uint256 premiumBefore) = hub1.getAssetOwed(address(tokenList.dai));
    bool reverting;

    // Initial user position
    userPremiumShares = bound(userPremiumShares, 0, assetData.premiumShares);
    userAccruedPremium = bound(
      userAccruedPremium,
      0,
      hub1.previewRestoreByShares(asset, assetData.premiumShares) - assetData.premiumOffset
    );
    vm.assume(hub1.previewRestoreByShares(asset, userPremiumShares) >= userAccruedPremium);
    uint256 userPremiumOffset = hub1.previewRestoreByShares(asset, userPremiumShares) -
      userAccruedPremium;

    // New user position
    userPremiumSharesNew = bound(
      userPremiumSharesNew,
      0,
      hub1.previewRestoreByAssets(asset, MAX_SUPPLY_AMOUNT / 2)
    );
    uint256 userPremiumOffsetNew = hub1.previewDrawByShares(asset, userPremiumSharesNew);

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: userPremiumSharesNew.toInt256() - userPremiumShares.toInt256(),
      offsetDelta: userPremiumOffsetNew.toInt256() - userPremiumOffset.toInt256(),
      realizedDelta: userAccruedPremium.toInt256()
    });

    uint256 expectedPremiumShares = premiumDelta.sharesDelta >= 0
      ? assetData.premiumShares + premiumDelta.sharesDelta.toUint256()
      : assetData.premiumShares - (-premiumDelta.sharesDelta).toUint256();

    if (assetData.drawnShares.percentMulUp(1000_00) < expectedPremiumShares) {
      reverting = true;
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    } else if (
      premiumDelta.sharesDelta < 0 && -premiumDelta.sharesDelta > assetData.premiumShares.toInt256()
    ) {
      reverting = true;
      vm.expectRevert(stdError.arithmeticError);
    } else if (
      premiumDelta.offsetDelta < 0 && -premiumDelta.offsetDelta > assetData.premiumOffset.toInt256()
    ) {
      reverting = true;
      vm.expectRevert(stdError.arithmeticError);
    }

    vm.prank(address(spoke1));
    hub1.refreshPremium(asset, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(address(tokenList.dai));

    if (!reverting) {
      assertEq(
        _loadAssetPremiumData(hub1, asset),
        _applyPremiumDelta(premiumDataBefore, premiumDelta)
      );
      assertLe(premiumAfter - premiumBefore, 2, 'premium should not increase by more than 2');
      assertBorrowRateSynced(hub1, address(tokenList.dai), 'after refreshPremium');
    }
  }

  function test_refreshPremium_spokePremiumUpdateIsContained() public {
    address asset = address(tokenList.dai);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);
    Utils.supplyCollateral(spoke2, _daiReserveId(spoke2), alice, 10000e18, alice);
    Utils.borrow(spoke2, _daiReserveId(spoke2), alice, 5000e18, alice);

    skip(322 days);

    uint256 spoke1AccruedPremium = _getSpokeAccruedPremium(hub1, asset, address(spoke1));
    uint256 spoke2AccruedPremium = _getSpokeAccruedPremium(hub1, asset, address(spoke2));
    assertGt(spoke1AccruedPremium, 0);
    assertGt(spoke2AccruedPremium, 0);

    vm.expectRevert(stdError.arithmeticError);
    // realize premium by manipulating offset
    vm.prank(address(spoke1));
    hub1.refreshPremium(
      asset,
      IHubBase.PremiumDelta({
        sharesDelta: 0,
        offsetDelta: (spoke1AccruedPremium + spoke2AccruedPremium).toInt256(),
        realizedDelta: (spoke1AccruedPremium + spoke2AccruedPremium).toInt256()
      })
    );
  }

  function _getSpokeAccruedPremium(
    IHub hub,
    address asset,
    address spoke
  ) internal view returns (uint256) {
    IHub.SpokeData memory spokeData = hub.getSpoke(asset, spoke);
    return hub.previewRestoreByShares(asset, spokeData.premiumShares) - spokeData.premiumOffset;
  }

  function _loadAssetPremiumData(
    IHub hub,
    address asset
  ) internal view returns (PremiumDataLocal memory) {
    IHub.Asset memory assetData = hub.getAsset(asset);
    return
      PremiumDataLocal(assetData.premiumShares, assetData.premiumOffset, assetData.realizedPremium);
  }

  function _applyPremiumDelta(
    PremiumDataLocal memory premiumData,
    IHubBase.PremiumDelta memory premiumDelta
  ) internal pure returns (PremiumDataLocal memory) {
    premiumData.premiumShares = premiumData.premiumShares.add(premiumDelta.sharesDelta).toUint120();
    premiumData.premiumOffset = premiumData.premiumOffset.add(premiumDelta.offsetDelta).toUint120();
    premiumData.realizedPremium = premiumData
      .realizedPremium
      .add(premiumDelta.realizedDelta)
      .toUint120();
    return premiumData;
  }

  function assertEq(PremiumDataLocal memory a, PremiumDataLocal memory b) internal pure {
    assertEq(a.premiumShares, b.premiumShares, 'premium shares');
    assertEq(a.premiumOffset, b.premiumOffset, 'premium offset');
    assertEq(a.realizedPremium, b.realizedPremium, 'realized premium');
    assertEq(abi.encode(a), abi.encode(b));
  }
}
