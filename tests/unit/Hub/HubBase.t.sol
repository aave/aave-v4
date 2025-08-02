// SPDX-License-Identifier: MIT
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
    DataTypes.Asset daiData;
    DataTypes.Asset daiData1;
    DataTypes.Asset daiData2;
    DataTypes.Asset daiData3;
    DataTypes.Asset wethData;
    DataTypes.SpokeData spoke1WethData;
    DataTypes.SpokeData spoke1DaiData;
    DataTypes.SpokeData spoke2WethData;
    DataTypes.SpokeData spoke2DaiData;
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

  function _updateAddCap(uint256 assetId, address spoke, uint256 newAddCap) internal {
    DataTypes.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(assetId, spoke);
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

  function _getDrawn(uint256 assetId) internal view returns (DrawnData memory) {
    revert('implement me');

    // DrawnData memory drawnData;
    // drawnData.asset.cumulativeDebt = hub1.getAssetCumulativeDebt(assetId);
    // (drawnData.asset.drawn, drawnData.asset.outstandingPremium) = hub1.getAssetOwed(assetId);

    // address[3] memory spokes = [address(spoke1), address(spoke2), address(spoke3)];
    // for (uint256 i = 0; i < 3; i++) {
    //   drawnData.spoke[i].cumulativeDebt = hub1.getSpokeCumulativeDebt(assetId, address(spokes[i]));
    //   (drawnData.spoke[i].drawn, drawnData.spoke[i].outstandingPremium) = hub1.getSpokeOwed(
    //     assetId,
    //     spokes[i]
    //   );
    // }
    // return drawnData;
  }

  /// @dev Draws liquidity from the Hub via a random spoke
  function _drawLiquidity(uint256 assetId, uint256 amount, bool withPremium) internal {
    address tempSpoke = vm.randomAddress();
    address tempUser = vm.randomAddress();

    int256 sharesDelta = 1000;
    int256 premiumOffsetDelta = 1000;

    vm.prank(HUB_ADMIN);
    hub1.addSpoke(
      assetId,
      tempSpoke,
      DataTypes.SpokeConfig({active: true, addCap: type(uint256).max, drawCap: type(uint256).max})
    );

    if (withPremium) {
      // inflate premium data to create premium debt
      vm.prank(tempSpoke);
      hub1.refreshPremium(assetId, DataTypes.PremiumDelta(sharesDelta, premiumOffsetDelta, 0));
    }

    Utils.draw(hub1, assetId, tempSpoke, tempUser, amount);

    skip(365 days);

    (uint256 drawn, uint256 premium) = hub1.getAssetOwed(assetId);
    assertGt(drawn, 0); // non-zero premium debt

    if (withPremium) {
      assertGt(premium, 0); // non-zero premium debt
      // restore premium data
      vm.prank(tempSpoke);
      hub1.refreshPremium(
        assetId,
        DataTypes.PremiumDelta(-sharesDelta, -premiumOffsetDelta, int256(premium))
      );
    }
  }

  /// @dev Draws liquidity from the Hub via a specific spoke which is already active
  function _drawLiquidityFromSpoke(
    address spoke,
    uint256 assetId,
    uint256 amount,
    uint256 skipTime,
    bool withPremium
  ) internal returns (uint256 drawn, uint256 premium) {
    address tempUser = vm.randomAddress();

    int256 sharesDelta = 1000;
    int256 premiumOffsetDelta = 1000;

    assertTrue(hub1.getSpoke(assetId, spoke).config.active);

    if (withPremium) {
      // inflate premium data to create premium debt
      vm.prank(spoke);
      hub1.refreshPremium(assetId, DataTypes.PremiumDelta(sharesDelta, premiumOffsetDelta, 0));
    }

    Utils.draw({hub: hub1, assetId: assetId, caller: spoke, amount: amount, to: tempUser});

    skip(skipTime);

    (drawn, premium) = hub1.getAssetOwed(assetId);
    assertGt(drawn, 0); // non-zero premium debt

    if (withPremium) {
      assertGt(premium, 0); // non-zero premium debt
      // restore premium data
      vm.prank(spoke);
      hub1.refreshPremium(
        assetId,
        DataTypes.PremiumDelta(-sharesDelta, -premiumOffsetDelta, int256(premium))
      );
    }
  }

  /// @dev Adds liquidity to the Hub via a random spoke
  function _addLiquidity(uint256 assetId, uint256 amount) public {
    address tempSpoke = vm.randomAddress();
    address tempUser = vm.randomAddress();

    uint256 initialLiq = hub1.getLiquidity(assetId);

    address underlying = hub1.getAsset(assetId).underlying;
    deal(underlying, tempUser, amount);

    vm.prank(tempUser);
    IERC20(underlying).approve(address(hub1), UINT256_MAX);

    vm.prank(ADMIN);
    hub1.addSpoke(
      assetId,
      tempSpoke,
      DataTypes.SpokeConfig({addCap: UINT256_MAX, drawCap: UINT256_MAX, active: true})
    );

    Utils.add({hub: hub1, assetId: assetId, caller: tempSpoke, amount: amount, user: tempUser});

    assertEq(hub1.getLiquidity(assetId), initialLiq + amount);
  }

  function _randomAssetId(IHub hub) internal returns (uint256) {
    return vm.randomUint(0, hub.getAssetCount() - 1);
  }
}
