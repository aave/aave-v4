// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract HubBase is Base {
  using SharesMath for uint256;
  using MathUtils for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;

  struct TestAddParams {
    uint256 drawnAmount;
    uint256 drawnShares;
    uint256 assetAddedAmount;
    uint256 assetAddedShares;
    uint256 spoke1AddedAmount;
    uint256 spoke1AddedShares;
    uint256 spoke2AddedAmount;
    uint256 spoke2AddedShares;
    uint256 availableLiq;
    uint256 bobBalance;
    uint256 aliceBalance;
  }

  struct HubData {
    IHub.Asset daiData;
    IHub.Asset daiData1;
    IHub.Asset daiData2;
    IHub.Asset daiData3;
    IHub.Asset wethData;
    IHub.SpokeData spoke1WethData;
    IHub.SpokeData spoke1DaiData;
    IHub.SpokeData spoke2WethData;
    IHub.SpokeData spoke2DaiData;
    uint256 timestamp;
    uint256 accruedBase;
    uint256 initialLiquidity;
    uint256 initialAddShares;
    uint256 add2Amount;
    uint256 expectedAdd2Shares;
  }

  struct DrawnData {
    DrawnAccounting asset;
    DrawnAccounting[3] spoke;
  }

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();
  }

  function _updateAddCap(uint256 assetId, address spoke, uint40 newAddCap) internal {
    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetId, spoke);
    spokeConfig.addCap = newAddCap;
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(assetId, spoke, spokeConfig);
  }

  /// @dev mocks rate, addSpoke (addUser) adds asset, drawSpoke (drawUser) draws asset, skips time
  function _addAndDrawLiquidity(
    IHub hub,
    uint256 assetId,
    address addUser,
    address addSpoke,
    uint256 addAmount,
    address drawUser,
    address drawSpoke,
    uint256 drawAmount,
    uint256 skipTime
  ) internal returns (uint256 addedShares, uint256 drawnShares) {
    addedShares = Utils.add({
      hub: hub,
      assetId: assetId,
      caller: addSpoke,
      amount: addAmount,
      user: addUser
    });

    drawnShares = Utils.draw({
      hub: hub,
      assetId: assetId,
      to: drawUser,
      caller: drawSpoke,
      amount: drawAmount
    });

    skip(skipTime);
  }

  /// @dev Draws liquidity from the Hub via a random spoke
  function _drawLiquidity(
    uint256 assetId,
    uint256 amount,
    bool withPremium,
    bool skipTime
  ) internal {
    address tempSpoke = vm.randomAddress();

    vm.prank(HUB_ADMIN);
    hub1.addSpoke(
      assetId,
      tempSpoke,
      IHub.SpokeConfig({
        active: true,
        halted: false,
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
      })
    );

    _drawLiquidity(assetId, amount, withPremium, skipTime, tempSpoke);
  }

  // @dev Draws liquidity from the Hub via a random spoke and skips time
  function _drawLiquidity(uint256 assetId, uint256 amount, bool premium) internal {
    _drawLiquidity(assetId, amount, premium, true);
  }

  function _drawLiquidity(
    uint256 assetId,
    uint256 amount,
    bool withPremium,
    bool skipTime,
    address spoke
  ) internal {
    Utils.draw(hub1, assetId, spoke, vm.randomAddress(), amount);
    int256 oldPremiumOffsetRay = _calculatePremiumAssetsRay(hub1, assetId, amount).toInt256();

    if (withPremium) {
      // inflate premium data to create premium debt
      IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
        hub: hub1,
        assetId: assetId,
        oldPremiumShares: 0,
        oldPremiumOffsetRay: 0,
        drawnShares: amount,
        riskPremium: 100_00,
        restoredPremiumRay: 0
      });
      vm.prank(spoke);
      hub1.refreshPremium(assetId, premiumDelta);
    }

    if (skipTime) skip(365 days);

    (uint256 drawn, uint256 premium) = hub1.getAssetOwed(assetId);
    assertGt(drawn, 0); // non-zero drawn debt

    if (withPremium) {
      assertGt(premium, 0); // non-zero premium debt
      // restore premium data
      IHubBase.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
        hub: hub1,
        assetId: assetId,
        oldPremiumShares: amount,
        oldPremiumOffsetRay: oldPremiumOffsetRay,
        drawnShares: 0, // risk premium is 0
        riskPremium: 0,
        restoredPremiumRay: 0
      });
      vm.prank(spoke);
      hub1.refreshPremium(assetId, premiumDelta);
    }
  }

  /// @dev Draws liquidity from the Hub via a specific spoke which is already active
  function _drawLiquidityFromSpoke(
    address spoke,
    uint256 assetId,
    uint256 reserveId,
    uint256 amount,
    uint256 skipTime
  ) internal returns (uint256 drawn, uint256 premiumRay) {
    assertTrue(hub1.getSpoke(assetId, spoke).active);

    deal(hub1.getAsset(assetId).underlying, alice, amount * 2);
    Utils.supplyCollateral(ISpoke(spoke), reserveId, alice, amount * 2, alice);
    Utils.borrow(ISpokeBase(spoke), reserveId, alice, amount, alice);

    skip(skipTime);

    (drawn, ) = hub1.getAssetOwed(assetId);
    assertGt(drawn, 0); // non-zero drawn debt

    premiumRay = hub1.getAssetPremiumRay(assetId);
    assertGt(premiumRay, 0); // non-zero premium debt
  }

  /// @dev Adds liquidity to the Hub via a random spoke
  function _addLiquidity(uint256 assetId, uint256 amount) public {
    address tempSpoke = vm.randomAddress();
    address tempUser = vm.randomAddress();

    uint256 initialLiq = hub1.getAssetLiquidity(assetId);

    address underlying = hub1.getAsset(assetId).underlying;
    deal(underlying, tempUser, amount);

    vm.prank(tempUser);
    IERC20(underlying).approve(tempSpoke, UINT256_MAX);

    vm.prank(ADMIN);
    hub1.addSpoke(
      assetId,
      tempSpoke,
      IHub.SpokeConfig({
        active: true,
        halted: false,
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
      })
    );

    Utils.add({hub: hub1, assetId: assetId, caller: tempSpoke, amount: amount, user: tempUser});

    assertEq(hub1.getAssetLiquidity(assetId), initialLiq + amount);
  }

  function _randomAssetId(IHub hub) internal returns (uint256) {
    return vm.randomUint(0, hub.getAssetCount() - 1);
  }

  function _randomInvalidAssetId(IHub hub) internal returns (uint256) {
    return vm.randomUint(hub.getAssetCount(), UINT256_MAX);
  }

  /// @dev Calculate the expected dust from fee conversion
  /// @param feeAmount The total fee amount to convert to shares
  /// @param totalAssets Total assets before fee subtraction
  /// @param totalShares Total shares at time of conversion
  /// @return dust The dust amount (feeAmount - feeShares converted back)
  function _calculateDust(
    uint256 feeAmount,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256 dust) {
    if (feeAmount == 0) return 0;
    // totalAssets for share conversion is after fee subtraction
    uint256 assetsForConversion = totalAssets - feeAmount;
    uint256 feeShares = feeAmount.toSharesDown(assetsForConversion, totalShares);
    if (feeShares == 0) {
      return feeAmount; // All goes to dust
    }
    uint256 feesAsAssets = feeShares.toAssetsUp(assetsForConversion, totalShares);
    return feeAmount - feesAsAssets;
  }

  /// @dev Calculate expected dust after accrual given the interest and asset state
  /// @param interest The interest amount accrued in this period
  /// @param addedAssetsBeforeFee Total added assets before fee subtraction (liquidity + aggregatedOwed)
  /// @param addedSharesAtAccrual The addedShares at time of accrual (before fee shares minted)
  /// @return dust The expected dust amount
  function _calculateExpectedDust(
    IHub hub,
    uint256 assetId,
    uint256 interest,
    uint256 addedAssetsBeforeFee,
    uint256 addedSharesAtAccrual
  ) internal view returns (uint256 dust) {
    IHub.Asset memory asset = hub.getAsset(assetId);
    uint256 liquidityFee = asset.liquidityFee;
    if (liquidityFee == 0) return 0;

    // feeAmount = interest * liquidityFee% (for first accrual where realizedFees = 0)
    uint256 feeAmount = interest.percentMulDown(liquidityFee);

    return _calculateDust(feeAmount, addedAssetsBeforeFee, addedSharesAtAccrual);
  }

  /// @dev Calculate expected cumulative dust after multiple accruals
  /// @param interest The new interest amount accrued
  /// @param previousDust The dust from previous accruals
  /// @param addedAssetsBeforeFee Total added assets before fee subtraction
  /// @param addedSharesAtAccrual The addedShares at time of accrual (before fee shares minted)
  /// @return dust The expected cumulative dust amount
  function _calculateCumulativeDust(
    uint256 interest,
    uint256 previousDust,
    uint256 addedAssetsBeforeFee,
    uint256 addedSharesAtAccrual,
    uint256 liquidityFee
  ) internal pure returns (uint256 dust) {
    // When no new interest accrues, drawnIndex == previousIndex, so getFee short-circuits
    // and returns the existing dust unchanged
    if (interest == 0) return previousDust;
    if (liquidityFee == 0) return previousDust;

    // feeAmount includes previous dust + new interest fees
    uint256 feeAmount = previousDust + interest.percentMulDown(liquidityFee);

    return _calculateDust(feeAmount, addedAssetsBeforeFee, addedSharesAtAccrual);
  }
}
