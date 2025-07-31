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

  /// @dev mocks rate, supplySpoke (supplyUser) supplies asset, drawSpoke (drawUser) draws asset, skips time
  function _supplyAndDrawLiquidity(
    ILiquidityHub liquidityHub,
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
      hub: liquidityHub,
      assetId: assetId,
      caller: supplySpoke,
      amount: supplyAmount,
      user: supplyUser
    });

    drawnShares = Utils.draw({
      hub: liquidityHub,
      assetId: assetId,
      to: drawUser,
      caller: drawSpoke,
      amount: drawAmount
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
      DataTypes.SpokeConfig({
        active: true,
        supplyCap: type(uint256).max,
        drawCap: type(uint256).max
      })
    );

    if (withPremium) {
      // inflate premium data to create premium debt
      vm.prank(tempSpoke);
      hub.refreshPremiumDebt(
        assetId,
        DataTypes.PremiumDelta(premiumDrawnSharesDelta, premiumOffsetDelta, 0)
      );
    }

    Utils.draw(hub, assetId, tempSpoke, tempUser, amount);

    skip(365 days);

    (uint256 baseDebt, uint256 premiumDebt) = hub.getAssetDebt(assetId);
    assertGt(baseDebt, 0); // non-zero premium debt

    if (withPremium) {
      assertGt(premiumDebt, 0); // non-zero premium debt
      // restore premium data
      vm.prank(tempSpoke);
      hub.refreshPremiumDebt(
        assetId,
        DataTypes.PremiumDelta(-premiumDrawnSharesDelta, -premiumOffsetDelta, int256(premiumDebt))
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
  ) internal returns (uint256 baseDebt, uint256 premiumDebt) {
    address tempUser = vm.randomAddress();

    int256 premiumDrawnSharesDelta = 1000;
    int256 premiumOffsetDelta = 1000;

    assertTrue(hub.getSpoke(assetId, spoke).config.active);

    if (withPremium) {
      // inflate premium data to create premium debt
      vm.prank(spoke);
      hub.refreshPremiumDebt(
        assetId,
        DataTypes.PremiumDelta(premiumDrawnSharesDelta, premiumOffsetDelta, 0)
      );
    }

    Utils.draw({hub: hub, assetId: assetId, caller: spoke, amount: amount, to: tempUser});

    skip(skipTime);

    (baseDebt, premiumDebt) = hub.getAssetDebt(assetId);
    assertGt(baseDebt, 0); // non-zero premium debt

    if (withPremium) {
      assertGt(premiumDebt, 0); // non-zero premium debt
      // restore premium data
      vm.prank(spoke);
      hub.refreshPremiumDebt(
        assetId,
        DataTypes.PremiumDelta(-premiumDrawnSharesDelta, -premiumOffsetDelta, int256(premiumDebt))
      );
    }
  }

  /// @dev Adds liquidity to the Hub via a random spoke
  function _addLiquidity(uint256 assetId, uint256 amount) public {
    address tempSpoke = vm.randomAddress();
    address tempUser = vm.randomAddress();

    uint256 initialLiq = hub.getAvailableLiquidity(assetId);

    address underlying = hub.getAsset(assetId).underlying;
    deal(underlying, tempUser, amount);

    vm.prank(tempUser);
    IERC20(underlying).approve(address(hub), UINT256_MAX);

    vm.prank(ADMIN);
    hub.addSpoke(
      assetId,
      tempSpoke,
      DataTypes.SpokeConfig({supplyCap: UINT256_MAX, drawCap: UINT256_MAX, active: true})
    );

    Utils.add({hub: hub, assetId: assetId, caller: tempSpoke, amount: amount, user: tempUser});

    assertEq(hub.getAvailableLiquidity(assetId), initialLiq + amount);
  }

  function _randomAssetId(ILiquidityHub liqHub) internal returns (uint256) {
    return vm.randomUint(0, liqHub.getAssetCount() - 1);
  }
}
