// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

contract LiquidityHubBase is Base {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  uint256 internal constant INIT_BASE_BORROW_INDEX = WadRayMath.RAY;

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

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function _updateSupplyCap(uint256 assetId, address spoke, uint256 newSupplyCap) internal {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.supplyCap = newSupplyCap;
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }

  /// @dev spoke1 (alice) supplies dai, spoke1 (alice) draws dai, skip 1 year
  /// increases supply and debt exchange rate
  /// @return daiDrawAmount
  /// @return suppliedShares
  function _increaseExchangeRate(uint256 daiAmount) internal returns (uint256, uint256) {
    uint256 daiDrawAmount = daiAmount;

    // spoke2 supply dai
    uint256 suppliedShares = Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw dai liquidity on behalf of user
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: daiDrawAmount,
      onBehalfOf: address(spoke1)
    });
    skip(365 days);

    // ensure that exchange rate has increased
    assertTrue(hub.convertToSuppliedShares(daiAssetId, daiAmount) < daiAmount);
    assertTrue(hub.convertToDrawnShares(daiAssetId, daiDrawAmount) < daiDrawAmount);

    return (daiDrawAmount, suppliedShares);
  }

  /// @dev spoke2 (bob) supplies dai, spoke1 (alice) draws dai
  function _supplyAndDrawLiquidity(
    uint256 daiAmount,
    uint256 daiDrawAmount,
    uint256 rate,
    uint256 skipTime
  ) internal returns (uint256, uint256) {
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // spoke2 supply dai
    uint256 supplyShares = Utils.add({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw dai liquidity on behalf of user
    uint256 drawnShares = Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: daiDrawAmount,
      onBehalfOf: address(spoke1)
    });

    skip(skipTime);
    return (drawnShares, supplyShares);
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

  // create premium debt on dai asset by supplying and borrowing dai through spoke
  // triggers refresh to cache premium debt
  function _createPremiumDebt(ISpoke spoke, uint256 daiAmount) internal returns (uint256) {
    uint256 daiReserveId = _daiReserveId(spoke);
    Utils.supplyCollateral({
      spoke: spoke,
      reserveId: daiReserveId,
      user: alice,
      amount: daiAmount,
      onBehalfOf: alice
    });
    Utils.borrow({
      spoke: spoke,
      reserveId: daiReserveId,
      user: alice,
      amount: daiAmount / 2, // to ensure HF > 1
      onBehalfOf: alice
    });
    skip(365 days);

    (, uint256 premiumDebt) = hub.getAssetDebt(daiAssetId);
    assertGt(premiumDebt, 0); // non-zero premium debt
  }
}
