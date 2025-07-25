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
    uint256 initialAvailableLiquidity;
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
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.addCap = newAddCap;
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }

  /// @dev mocks rate, addSpoke (addUser) adds asset, drawSpoke (drawUser) draws asset, skips time
  function _addAndDrawLiquidity(
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
    // drawnData.asset.cumulativeDebt = hub.getAssetCumulativeDebt(assetId);
    // (drawnData.asset.drawn, drawnData.asset.outstandingPremium) = hub.getAssetOwed(assetId);

    // address[3] memory spokes = [address(spoke1), address(spoke2), address(spoke3)];
    // for (uint256 i = 0; i < 3; i++) {
    //   drawnData.spoke[i].cumulativeDebt = hub.getSpokeCumulativeDebt(assetId, address(spokes[i]));
    //   (drawnData.spoke[i].drawn, drawnData.spoke[i].outstandingPremium) = hub.getSpokeOwed(
    //     assetId,
    //     spokes[i]
    //   );
    // }
    // return drawnData;
  }

  /// @dev Adds liquidity to the Hub via a random spoke
  function _addLiquidity(uint256 assetId, uint256 amount) public {
    address tempSpoke = vm.randomAddress();
    address tempUser = vm.randomAddress();

    uint256 initialLiq = hub.getAvailableLiquidity(assetId);

    address underlying = hub.getAsset(assetId).underlying;
    deal(underlying, tempUser, amount);

    vm.prank(tempUser);
    IERC20(underlying).approve(address(hub), type(uint256).max);

    vm.prank(ADMIN);
    hub.addSpoke(
      assetId,
      tempSpoke,
      DataTypes.SpokeConfig({active: true, addCap: type(uint256).max, drawCap: type(uint256).max})
    );

    Utils.add({hub: hub, assetId: assetId, caller: tempSpoke, amount: amount, user: tempUser});

    assertEq(hub.getAvailableLiquidity(assetId), initialLiq + amount);
  }

  /// @dev Draws liquidity from the Hub via a random spoke
  function _drawLiquidity(uint256 assetId, uint256 amount, bool withPremium) internal {
    address tempSpoke = vm.randomAddress();
    address tempUser = vm.randomAddress();

    int256 premiumDrawnSharesDelta = 1000;
    int256 premiumOffsetDelta = 1000;

    vm.prank(HUB_ADMIN);
    hub.addSpoke(
      assetId,
      tempSpoke,
      DataTypes.SpokeConfig({active: true, addCap: type(uint256).max, drawCap: type(uint256).max})
    );

    if (withPremium) {
      // inflate premium data to create premium debt
      vm.prank(tempSpoke);
      hub.refreshPremium(assetId, premiumDrawnSharesDelta, premiumOffsetDelta, 0, 0);
    }

    Utils.draw(hub, assetId, tempSpoke, tempUser, amount);

    skip(365 days);

    (uint256 drawn, uint256 premium) = hub.getAssetOwed(assetId);
    assertGt(drawn, 0); // non-zero premium debt

    if (withPremium) {
      assertGt(premium, 0); // non-zero premium debt
      // restore premium data
      vm.prank(tempSpoke);
      hub.refreshPremium(assetId, -premiumDrawnSharesDelta, -premiumOffsetDelta, premium, 0);
    }
  }
}
