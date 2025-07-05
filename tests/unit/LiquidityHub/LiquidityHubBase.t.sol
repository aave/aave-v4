// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract LiquidityHubBase is Base {
  using SharesMath for uint256;

  struct TestSupplyParams {
    uint256 drawnAmount;
    uint256 drawnShares;
    uint256 assetSuppliedAmount;
    uint256 assetSuppliedShares;
    uint256 spoke1SuppliedAmount;
    uint256 spoke1SuppliedShares;
    uint256 spoke2SuppliedAmount;
    uint256 spoke2SuppliedShares;
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
    uint256 initialSupplyShares;
    uint256 supply2Amount;
    uint256 expectedSupply2Shares;
  }

  struct DebtData {
    DebtAccounting asset;
    DebtAccounting[3] spoke;
  }

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();
  }

  function _updateSupplyCap(uint256 assetId, address spoke, uint256 newSupplyCap) internal {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.supplyCap = newSupplyCap;
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }

  /// @dev tempSpoke1 (tempUser1) supplies asset, tempSpoke2 (tempUser2) draws asset, skip 1 year
  /// increases supply and debt exchange rate
  function _increaseExchangeRate(uint256 assetId, uint256 amount) internal {
    address tempUser1 = makeAddr('TEMP_USER_1');
    deal(hub.getAsset(assetId).underlying, tempUser1, amount);

    address tempSpoke1 = makeAddr('TEMP_SPOKE_1');
    vm.startPrank(ADMIN);
    hub.addSpoke(
      assetId,
      tempSpoke1,
      DataTypes.SpokeConfig({
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        active: true
      })
    );

    address tempUser2 = makeAddr('TEMP_USER_2');
    deal(hub.getAsset(assetId).underlying, tempUser2, amount);

    address tempSpoke2 = makeAddr('TEMP_SPOKE_2');
    hub.addSpoke(
      assetId,
      tempSpoke2,
      DataTypes.SpokeConfig({
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        active: true
      })
    );
    vm.stopPrank();

    _supplyAndDrawLiquidity({
      assetId: assetId,
      supplyUser: tempUser1,
      supplySpoke: tempSpoke1,
      supplyAmount: amount,
      drawUser: tempUser2,
      drawSpoke: tempSpoke2,
      drawAmount: amount,
      skipTime: 365 days
    });

    // ensure that exchange rate has increased
    assertTrue(hub.convertToSuppliedShares(assetId, amount) < amount);
    assertTrue(hub.convertToDrawnShares(assetId, amount) < amount);
  }

  /// @dev mocks rate, supplySpoke (supplyUser) supplies asset, drawSpoke (drawUser) draws asset, skips time
  function _supplyAndDrawLiquidity(
    uint256 assetId,
    address supplyUser,
    address supplySpoke,
    uint256 supplyAmount,
    address drawUser,
    address drawSpoke,
    uint256 drawAmount,
    uint256 skipTime
  ) internal returns (uint256 supplyShares, uint256 drawnShares) {
    supplyShares = Utils.add({
      hub: hub,
      assetId: assetId,
      spoke: supplySpoke,
      amount: supplyAmount,
      user: supplyUser,
      to: supplySpoke
    });

    drawnShares = Utils.draw({
      hub: hub,
      assetId: assetId,
      to: drawUser,
      spoke: drawSpoke,
      amount: drawAmount,
      onBehalfOf: drawSpoke
    });

    skip(skipTime);
  }

  function _getDebt(uint256 assetId) internal view returns (DebtData memory) {
    revert('implement me');

    // DebtData memory debtData;
    // debtData.asset.cumulativeDebt = hub.getAssetCumulativeDebt(assetId);
    // (debtData.asset.baseDebt, debtData.asset.outstandingPremium) = hub.getAssetDebt(assetId);

    // address[3] memory spokes = [address(spoke1), address(spoke2), address(spoke3)];
    // for (uint256 i = 0; i < 3; i++) {
    //   debtData.spoke[i].cumulativeDebt = hub.getSpokeCumulativeDebt(assetId, address(spokes[i]));
    //   (debtData.spoke[i].baseDebt, debtData.spoke[i].outstandingPremium) = hub.getSpokeDebt(
    //     assetId,
    //     spokes[i]
    //   );
    // }
    // return debtData;
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
      DataTypes.SpokeConfig({
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        active: true
      })
    );

    Utils.add({
      hub: hub,
      assetId: assetId,
      spoke: tempSpoke,
      amount: amount,
      user: tempUser,
      to: tempSpoke
    });

    assertEq(hub.getAvailableLiquidity(assetId), initialLiq + amount);
  }

  /// @dev Draws liquidity from the Hub via a random spoke
  function _drawLiquidity(
    uint256 assetId,
    uint256 amount,
    bool withPremium
  ) internal returns (uint256) {
    address tempSpoke = vm.randomAddress();
    address tempUser = vm.randomAddress();

    int256 premiumDrawnSharesDelta = 1000;
    int256 premiumOffsetDelta = 1000;

    vm.prank(HUB_ADMIN);
    hub.addSpoke(
      assetId,
      tempSpoke,
      DataTypes.SpokeConfig({
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max,
        active: true
      })
    );

    if (withPremium) {
      // inflate premium data to create premium debt
      vm.prank(tempSpoke);
      hub.refreshPremiumDebt(assetId, premiumDrawnSharesDelta, premiumOffsetDelta, 0, 0);
    }

    Utils.draw(hub, assetId, tempSpoke, tempUser, amount, tempUser);

    skip(365 days);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getAssetDebt(assetId);
    assertGt(baseDebt, 0); // non-zero premium debt

    if (withPremium) {
      assertGt(premiumDebt, 0); // non-zero premium debt
      // restore premium data
      vm.prank(tempSpoke);
      hub.refreshPremiumDebt(
        assetId,
        -premiumDrawnSharesDelta,
        -premiumOffsetDelta,
        premiumDebt,
        0
      );
    }
  }
}
