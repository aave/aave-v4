// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract HubBase is Base {
  using SharesMath for uint256;

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

  function _updateAddCap(address asset, address spoke, uint40 newAddCap) internal {
    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(asset, spoke);
    spokeConfig.addCap = newAddCap;
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(asset, spoke, spokeConfig);
  }

  /// @dev mocks rate, addSpoke (addUser) adds asset, drawSpoke (drawUser) draws asset, skips time
  function _addAndDrawLiquidity(
    IHub hub,
    address asset,
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
      asset: asset,
      caller: addSpoke,
      amount: addAmount,
      user: addUser
    });

    drawnShares = Utils.draw({
      hub: hub,
      asset: asset,
      to: drawUser,
      caller: drawSpoke,
      amount: drawAmount
    });

    skip(skipTime);
  }

  /// @dev Draws liquidity from the Hub via a random spoke
  function _drawLiquidity(address asset, uint256 amount, bool withPremium, bool skipTime) internal {
    address tempSpoke = vm.randomAddress();
    address tempUser = vm.randomAddress();

    int256 sharesDelta = int256(amount);
    int256 premiumOffsetDelta = int256(amount);

    vm.prank(HUB_ADMIN);
    hub1.addSpoke(
      asset,
      tempSpoke,
      IHub.SpokeConfig({
        active: true,
        paused: false,
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
      })
    );

    Utils.draw(hub1, asset, tempSpoke, tempUser, amount);

    if (withPremium) {
      // inflate premium data to create premium debt
      vm.prank(tempSpoke);
      hub1.refreshPremium(asset, IHubBase.PremiumDelta(sharesDelta, premiumOffsetDelta, 0));
    }

    if (skipTime) skip(365 days);

    (uint256 drawn, uint256 premium) = hub1.getAssetOwed(asset);
    assertGt(drawn, 0); // non-zero premium debt

    if (withPremium) {
      assertGt(premium, 0); // non-zero premium debt
      // restore premium data
      vm.prank(tempSpoke);
      hub1.refreshPremium(
        asset,
        IHubBase.PremiumDelta(-sharesDelta, -premiumOffsetDelta, int256(premium))
      );
    }
  }

  // @dev Draws liquidity from the Hub via a random spoke and skips time
  function _drawLiquidity(address asset, uint256 amount, bool premium) internal {
    _drawLiquidity(asset, amount, premium, true);
  }

  /// @dev Draws liquidity from the Hub via a specific spoke which is already active
  function _drawLiquidityFromSpoke(
    address spoke,
    address asset,
    uint256 reserveId,
    uint256 amount,
    uint256 skipTime
  ) internal returns (uint256 drawn, uint256 premium) {
    assertTrue(hub1.getSpoke(asset, spoke).active);

    deal(asset, alice, amount * 2);
    Utils.supplyCollateral(ISpoke(spoke), reserveId, alice, amount * 2, alice);
    Utils.borrow(ISpokeBase(spoke), reserveId, alice, amount, alice);

    skip(skipTime);

    (drawn, premium) = hub1.getAssetOwed(asset);
    assertGt(drawn, 0); // non-zero drawn debt
    assertGt(premium, 0); // non-zero premium debt
  }

  /// @dev Adds liquidity to the Hub via a random spoke
  function _addLiquidity(address asset, uint256 amount) public {
    address tempSpoke = vm.randomAddress();
    address tempUser = vm.randomAddress();

    uint256 initialLiq = hub1.getAssetLiquidity(asset);

    deal(asset, tempUser, amount);

    vm.prank(tempUser);
    IERC20(asset).approve(tempSpoke, UINT256_MAX);

    vm.prank(ADMIN);
    hub1.addSpoke(
      asset,
      tempSpoke,
      IHub.SpokeConfig({
        active: true,
        paused: false,
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
      })
    );

    Utils.add({hub: hub1, asset: asset, caller: tempSpoke, amount: amount, user: tempUser});

    assertEq(hub1.getAssetLiquidity(asset), initialLiq + amount);
  }

  function _getExpectedPremiumDelta(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 premiumRestored
  ) internal view override returns (IHubBase.PremiumDelta memory) {
    ISpoke.UserPosition memory userPosition = spoke.getUserPosition(reserveId, user);
    address asset = spoke.getReserve(reserveId).underlying;

    IHubBase.PremiumDelta memory expectedPremiumDelta = IHubBase.PremiumDelta({
      sharesDelta: -int256(uint256(userPosition.premiumShares)),
      offsetDelta: -int256(uint256(userPosition.premiumOffset)),
      realizedDelta: 0
    });

    uint256 accruedPremium = hub1.previewRestoreByShares(asset, userPosition.premiumShares) -
      userPosition.premiumOffset;

    expectedPremiumDelta.realizedDelta = int256(accruedPremium) - int256(premiumRestored);

    return expectedPremiumDelta;
  }

  function _randomAsset(IHub hub) internal returns (address) {
    return hub.getUnderlyingAddress(vm.randomUint(0, hub.getAssetCount() - 1));
  }

  function _randomInvalidAsset(IHub hub) internal returns (address) {
    address asset;
    while (hub.isUnderlyingListed(asset) || asset == address(0)) {
      asset = vm.randomAddress();
    }
    return asset;
  }
}
