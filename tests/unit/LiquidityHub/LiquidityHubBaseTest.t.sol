// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {Asset, SpokeData} from 'src/contracts/LiquidityHub.sol';

contract LiquidityHubBaseTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  uint256 internal constant INIT_BASE_BORROW_INDEX = WadRayMath.RAY;

  struct TestSupplyUserParams {
    uint256 totalAssets;
    uint256 suppliedShares;
    uint256 userAssets;
    uint256 userShares;
  }

  struct HubData {
    Asset daiData;
    Asset daiData1;
    Asset daiData2;
    Asset daiData3;
    Asset wethData;
    SpokeData spoke1WethData;
    SpokeData spoke1DaiData;
    SpokeData spoke2WethData;
    SpokeData spoke2DaiData;
    uint256 timestamp;
    uint256 accruedBase;
    uint256 initialAvailableLiquidity;
    uint256 initialSupplyShares;
    uint256 supply2Amount;
    uint256 expectedSupply2Shares;
  }

  struct DebtAccounting {
    uint256 cumulativeDebt;
    uint256 baseDebt;
    uint256 outstandingPremium;
  }

  struct DebtData {
    DebtAccounting asset;
    DebtAccounting[3] spoke;
  }

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function _updateActive(uint256 assetId, bool newActive) internal {
    DataTypes.AssetConfig memory reserveConfig = hub.getAsset(assetId).config;
    reserveConfig.active = newActive;
    hub.updateAssetConfig(assetId, reserveConfig);
  }

  function _updateDrawCap(uint256 assetId, address spoke, uint256 newDrawCap) internal {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.drawCap = newDrawCap;
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }

  function _updateSupplyCap(uint256 assetId, address spoke, uint256 newSupplyCap) internal {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.supplyCap = newSupplyCap;
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }

  /// @dev spoke1 (alice) supplies dai, spoke2 (bob) supplies weth, spoke1 (alice) draws dai
  function _supplyAndDrawLiquidity(
    uint256 daiAmount,
    uint256 wethAmount,
    uint256 daiDrawAmount,
    uint32 riskPremium,
    uint256 rate
  ) internal {
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // spoke1 supply weth
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremium: 0,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremium: 0,
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
      riskPremium: riskPremium,
      onBehalfOf: address(spoke1)
    });
  }

  function _getDebt(uint256 assetId) internal view returns (DebtData memory) {
    DebtData memory debtData;
    debtData.asset.cumulativeDebt = hub.getAssetCumulativeDebt(assetId);
    (debtData.asset.baseDebt, debtData.asset.outstandingPremium) = hub.getAssetDebt(assetId);

    address[3] memory spokes = [address(spoke1), address(spoke2), address(spoke3)];
    for (uint256 i = 0; i < 3; i++) {
      debtData.spoke[i].cumulativeDebt = hub.getSpokeCumulativeDebt(assetId, address(spokes[i]));
      (debtData.spoke[i].baseDebt, debtData.spoke[i].outstandingPremium) = hub.getSpokeDebt(
        assetId,
        spokes[i]
      );
    }
    return debtData;
  }
}
