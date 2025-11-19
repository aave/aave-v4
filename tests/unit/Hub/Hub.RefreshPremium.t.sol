// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubRefreshPremiumTest is HubBase {
  using SafeCast for *;
  using PercentageMath for *;
  using MathUtils for uint256;
  using WadRayMath for uint256;

  struct PremiumDataLocal {
    uint256 premiumShares;
    uint256 premiumOffsetRay;
    uint256 realizedPremiumRay;
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

  /// @dev reverts with InvalidPremiumChange with a risk premium threshold of 0
  /// @dev allowed if premiumData is within risk premium threshold
  function test_refreshPremium_riskPremiumThreshold() public {
    _createDrawnSharesAndPremiumData();

    uint24 riskPremiumThreshold = 0.toUint24();
    _updateSpokeRiskPremiumThreshold(hub1, daiAssetId, address(spoke1), riskPremiumThreshold);

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: 1,
      offsetDeltaRay: _calculatePremiumAssetsRay(hub1, daiAssetId, 1).toInt256(),
      accruedPremiumRay: 0,
      restoredPremiumRay: 0
    });

    IHub.Asset memory asset = hub1.getAsset(daiAssetId);
    // expect allowed condition not to be met
    assertFalse(
      asset.premiumShares + premiumDelta.sharesDelta.toUint256() <=
        asset.drawnShares.percentMulUp(riskPremiumThreshold)
    );

    vm.expectRevert(IHub.InvalidPremiumChange.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);

    riskPremiumThreshold = (vm.randomUint(0, Constants.MAX_RISK_PREMIUM_THRESHOLD - 1)).toUint24();
    _updateSpokeRiskPremiumThreshold(hub1, daiAssetId, address(spoke1), riskPremiumThreshold);

    // expect allowed condition to be met
    assertTrue(
      asset.premiumShares + premiumDelta.sharesDelta.toUint256() <=
        asset.drawnShares.percentMulUp(riskPremiumThreshold)
    );
    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);
  }

  /// @dev reverts with InvalidPremiumChange as long as threshold is exceeded (even though risk premium is decreasing)
  function test_refreshPremium_revertsWith_InvalidPremiumChange_RiskPremiumThresholdExceeded_DecreasingPremium()
    public
  {
    _createDrawnSharesAndPremiumData();

    uint24 riskPremiumThreshold = 1_00; // 1%
    _updateSpokeRiskPremiumThreshold(hub1, daiAssetId, address(spoke1), riskPremiumThreshold);

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: -1,
      offsetDeltaRay: -_calculatePremiumAssetsRay(hub1, daiAssetId, 1).toInt256(),
      accruedPremiumRay: 0,
      restoredPremiumRay: 0
    });

    vm.expectRevert(IHub.InvalidPremiumChange.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);
  }

  function test_refreshPremium_revertsWith_InvalidPremiumChange_NonZeroRestoredPremiumRay() public {
    _createDrawnSharesAndPremiumData();

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: 1,
      offsetDeltaRay: _calculatePremiumAssetsRay(hub1, daiAssetId, 1).toInt256(),
      accruedPremiumRay: 0,
      restoredPremiumRay: 1
    });

    vm.expectRevert(IHub.InvalidPremiumChange.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);

    // refresh should work if restored premium is 0
    premiumDelta.restoredPremiumRay = 0;
    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);
  }

  /// @dev if risk premium threshold is max allowed sentinel val, then exceeding max collateral risk is allowed
  function test_refreshPremium_maxRiskPremiumThreshold() public {
    _createDrawnSharesAndPremiumData();

    _updateSpokeRiskPremiumThreshold(
      hub1,
      daiAssetId,
      address(spoke1),
      Constants.MAX_RISK_PREMIUM_THRESHOLD
    );

    assertEq(
      hub1.getSpokeConfig(daiAssetId, address(spoke1)).riskPremiumThreshold,
      Constants.MAX_RISK_PREMIUM_THRESHOLD
    );

    IHub.SpokeData memory spokeData = hub1.getSpoke(daiAssetId, address(spoke1));
    PremiumDataLocal memory premiumData = _loadAssetPremiumData(hub1, daiAssetId);
    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: spokeData
        .drawnShares
        .percentMulUp(Constants.MAX_ALLOWED_COLLATERAL_RISK + 1)
        .toInt256(), // no shares delta allowed
      offsetDeltaRay: 0,
      accruedPremiumRay: 0,
      restoredPremiumRay: 0
    });
    premiumDelta.offsetDeltaRay = _calculatePremiumAssetsRay(
      hub1,
      daiAssetId,
      premiumDelta.sharesDelta.toUint256()
    ).toInt256();

    // condition not met on max coll risk, but still allowed with MAX_RISK_PREMIUM_THRESHOLD
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
    tokenList.dai.transferFrom(alice, address(hub1), 10000e18);
    hub1.add(daiAssetId, 10000e18);
    hub1.draw(daiAssetId, 5000e18, alice);

    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, daiAssetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: 1,
      offsetDeltaRay: WadRayMath.RAY.toInt256(),
      accruedPremiumRay: 0,
      restoredPremiumRay: 0
    });
    vm.expectEmit(address(hub1));
    emit IHubBase.RefreshPremium(daiAssetId, address(spoke1), premiumDelta);

    hub1.refreshPremium(daiAssetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    assertEq(
      _loadAssetPremiumData(hub1, daiAssetId),
      _applyPremiumDelta(premiumDataBefore, premiumDelta)
    );
    assertEq(premiumAfter, premiumBefore, 'premium should not change');
    _assertBorrowRateSynced(hub1, daiAssetId, 'after refreshPremium');
    vm.stopPrank();
  }

  /// @dev offsetDeltaRay can't be more than sharesDelta * 1e27 or else underflow
  /// @dev sharesDelta + realizedDelta can't be more than 2 more than offsetDelta
  function test_refreshPremium_fuzz_positiveDeltas(
    uint256 borrowAmount,
    int256 sharesDelta,
    int256 offsetDeltaRay,
    uint256 accruedPremiumRay,
    bool isRiskPremiumThresholdMaxAllowed
  ) public {
    sharesDelta = bound(sharesDelta, 0, MAX_SUPPLY_AMOUNT.toInt256());
    offsetDeltaRay = bound(offsetDeltaRay, 0, MAX_SUPPLY_AMOUNT.toInt256());
    accruedPremiumRay = bound(accruedPremiumRay, 0, MAX_SUPPLY_AMOUNT);
    borrowAmount = bound(borrowAmount, 0, MAX_SUPPLY_AMOUNT / 2);
    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: sharesDelta,
      offsetDeltaRay: offsetDeltaRay,
      accruedPremiumRay: accruedPremiumRay,
      restoredPremiumRay: 0
    });

    uint24 riskPremiumThreshold = vm
      .randomUint(0, Constants.MAX_RISK_PREMIUM_THRESHOLD - 1)
      .toUint24();
    if (isRiskPremiumThresholdMaxAllowed) {
      // sentinel value to preclude check
      riskPremiumThreshold = Constants.MAX_RISK_PREMIUM_THRESHOLD;
    }
    _updateSpokeRiskPremiumThreshold(hub1, daiAssetId, address(spoke1), riskPremiumThreshold);

    if (borrowAmount > 0) {
      Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, borrowAmount * 2, bob);
      Utils.borrow(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);
    }

    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, daiAssetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);
    bool reverting;
    IHub.Asset memory asset = hub1.getAsset(daiAssetId);
    uint256 expectedPremiumShares = sharesDelta > 0
      ? asset.premiumShares + sharesDelta.toUint256()
      : asset.premiumShares - (-sharesDelta).toUint256();
    uint256 expectedOffsetRay = offsetDeltaRay > 0
      ? asset.premiumOffsetRay + offsetDeltaRay.toUint256()
      : asset.premiumOffsetRay - (-offsetDeltaRay).toUint256();

    // Only 1 spoke drawing so checks on asset are equivalent to spoke
    if (expectedOffsetRay > _calculatePremiumAssetsRay(hub1, daiAssetId, expectedPremiumShares)) {
      reverting = true;
      vm.expectRevert(stdError.arithmeticError);
    } else if (
      riskPremiumThreshold != Constants.MAX_RISK_PREMIUM_THRESHOLD &&
      asset.drawnShares.percentMulUp(riskPremiumThreshold) <
      asset.premiumShares + sharesDelta.toUint256()
    ) {
      reverting = true;
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    } else if (
      sharesDelta.toUint256() * WadRayMath.RAY + accruedPremiumRay != offsetDeltaRay.toUint256()
    ) {
      reverting = true;
      vm.expectRevert(IHub.InvalidPremiumChange.selector);
    }
    vm.prank(address(spoke1));
    hub1.refreshPremium(daiAssetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    if (!reverting) {
      assertEq(
        _loadAssetPremiumData(hub1, daiAssetId),
        _applyPremiumDelta(premiumDataBefore, premiumDelta)
      );
      assertEq(premiumAfter, premiumBefore, 'premium should not change');
      _assertBorrowRateSynced(hub1, daiAssetId, 'after refreshPremium');
    }
  }

  function test_refreshPremium_negativeDeltas(int256 sharesDeltaPos) public {
    uint256 assetId = daiAssetId;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 10000e18, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);

    IHub.Asset memory asset = hub1.getAsset(assetId);
    PremiumDataLocal memory premiumDataBefore = _loadAssetPremiumData(hub1, assetId);
    (, uint256 premiumBefore) = hub1.getAssetOwed(daiAssetId);

    sharesDeltaPos = bound(sharesDeltaPos, 0, asset.premiumShares.toInt256());
    int256 offsetDeltaPosRay = _calculatePremiumAssetsRay(hub1, assetId, sharesDeltaPos.toUint256())
      .toInt256();
    if (offsetDeltaPosRay > asset.premiumOffsetRay.toInt256()) {
      offsetDeltaPosRay = asset.premiumOffsetRay.toInt256();
    }

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: -sharesDeltaPos,
      offsetDeltaRay: -offsetDeltaPosRay,
      accruedPremiumRay: 0,
      restoredPremiumRay: 0
    });

    vm.prank(address(spoke1));
    hub1.refreshPremium(assetId, premiumDelta);

    (, uint256 premiumAfter) = hub1.getAssetOwed(daiAssetId);

    assertEq(
      _loadAssetPremiumData(hub1, assetId),
      _applyPremiumDelta(premiumDataBefore, premiumDelta)
    );
    assertEq(premiumAfter, premiumBefore, 'premium should not change');
    _assertBorrowRateSynced(hub1, daiAssetId, 'after refreshPremium');
  }

  function test_refreshPremium_negativeDeltas_withAccrual(
    uint256 sharesDeltaPos,
    uint256 offsetDeltaPosRay
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
    offsetDeltaPosRay = bound(offsetDeltaPosRay, 0, asset.premiumOffsetRay);

    // not allowed to restore debt during refreshPremium
    uint256 premiumAssetsPosRay = _calculatePremiumAssetsRay(hub1, assetId, sharesDeltaPos);
    if (offsetDeltaPosRay > premiumAssetsPosRay) {
      offsetDeltaPosRay = premiumAssetsPosRay;
    }

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: -sharesDeltaPos.toInt256(),
      offsetDeltaRay: -offsetDeltaPosRay.toInt256(),
      accruedPremiumRay: premiumAssetsPosRay - offsetDeltaPosRay,
      restoredPremiumRay: 0
    });

    if (
      _calculatePremiumAssetsRay(hub1, assetId, asset.premiumShares - sharesDeltaPos) <
      asset.premiumOffsetRay - offsetDeltaPosRay
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
      _assertBorrowRateSynced(hub1, daiAssetId, 'after refreshPremium');
    }
  }

  function test_refreshPremium_fuzz_withAccrual(
    uint256 borrowAmount,
    uint256 userPremiumShares,
    uint256 userAccruedPremiumRay,
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
    userAccruedPremiumRay = bound(
      userAccruedPremiumRay,
      0,
      _calculateAccruedPremiumRay(hub1, assetId, asset.premiumShares, asset.premiumOffsetRay)
    );
    vm.assume(
      _calculatePremiumAssetsRay(hub1, assetId, userPremiumShares) >= userAccruedPremiumRay
    );
    uint256 userPremiumOffsetRay = _calculatePremiumAssetsRay(hub1, assetId, userPremiumShares) -
      userAccruedPremiumRay;

    // New user position
    userPremiumSharesNew = bound(
      userPremiumSharesNew,
      0,
      hub1.previewRestoreByAssets(assetId, MAX_SUPPLY_AMOUNT / 2)
    );
    uint256 userPremiumOffsetNewRay = _calculatePremiumAssetsRay(
      hub1,
      assetId,
      userPremiumSharesNew
    );

    IHubBase.PremiumDelta memory premiumDelta = IHubBase.PremiumDelta({
      sharesDelta: userPremiumSharesNew.toInt256() - userPremiumShares.toInt256(),
      offsetDeltaRay: userPremiumOffsetNewRay.toInt256() - userPremiumOffsetRay.toInt256(),
      accruedPremiumRay: userAccruedPremiumRay,
      restoredPremiumRay: 0
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
      premiumDelta.offsetDeltaRay < 0 &&
      -premiumDelta.offsetDeltaRay > asset.premiumOffsetRay.toInt256()
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
      assertEq(premiumAfter, premiumBefore, 'premium should not change');
      _assertBorrowRateSynced(hub1, daiAssetId, 'after refreshPremium');
    }
  }

  function test_refreshPremium_spokePremiumUpdateIsContained() public {
    uint256 assetId = daiAssetId;
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 5000e18, bob);
    Utils.supplyCollateral(spoke2, _daiReserveId(spoke2), alice, 10000e18, alice);
    Utils.borrow(spoke2, _daiReserveId(spoke2), alice, 5000e18, alice);

    skip(322 days);

    uint256 spoke1AccruedPremiumRay = _getSpokeAccruedPremiumRay(hub1, assetId, address(spoke1));
    uint256 spoke2AccruedPremiumRay = _getSpokeAccruedPremiumRay(hub1, assetId, address(spoke2));
    assertGt(spoke1AccruedPremiumRay, 0);
    assertGt(spoke2AccruedPremiumRay, 0);

    vm.expectRevert(stdError.arithmeticError);
    // realize premium by manipulating offset
    vm.prank(address(spoke1));
    hub1.refreshPremium(
      assetId,
      IHubBase.PremiumDelta({
        sharesDelta: 0,
        offsetDeltaRay: (spoke1AccruedPremiumRay + spoke2AccruedPremiumRay).toInt256(),
        accruedPremiumRay: spoke1AccruedPremiumRay + spoke2AccruedPremiumRay,
        restoredPremiumRay: 0
      })
    );
  }

  function _getSpokeAccruedPremiumRay(
    IHub hub,
    uint256 assetId,
    address spoke
  ) internal view returns (uint256) {
    IHub.SpokeData memory spokeData = hub.getSpoke(assetId, spoke);
    return
      _calculateAccruedPremiumRay(
        hub,
        assetId,
        spokeData.premiumShares,
        spokeData.premiumOffsetRay
      );
  }

  function _loadAssetPremiumData(
    IHub hub,
    uint256 assetId
  ) internal view returns (PremiumDataLocal memory) {
    IHub.Asset memory asset = hub.getAsset(assetId);
    return PremiumDataLocal(asset.premiumShares, asset.premiumOffsetRay, asset.realizedPremiumRay);
  }

  function _applyPremiumDelta(
    PremiumDataLocal memory premiumData,
    IHubBase.PremiumDelta memory premiumDelta
  ) internal pure returns (PremiumDataLocal memory) {
    premiumData.premiumShares = premiumData.premiumShares.add(premiumDelta.sharesDelta).toUint120();
    premiumData.premiumOffsetRay = premiumData.premiumOffsetRay.add(premiumDelta.offsetDeltaRay);
    premiumData.realizedPremiumRay =
      premiumData.realizedPremiumRay +
      premiumDelta.accruedPremiumRay -
      premiumDelta.restoredPremiumRay;
    return premiumData;
  }

  function assertEq(PremiumDataLocal memory a, PremiumDataLocal memory b) internal pure {
    assertEq(a.premiumShares, b.premiumShares, 'premium shares');
    assertEq(a.premiumOffsetRay, b.premiumOffsetRay, 'premium offset ray');
    assertEq(a.realizedPremiumRay, b.realizedPremiumRay, 'realized premium ray');
    assertEq(abi.encode(a), abi.encode(b));
  }
}
