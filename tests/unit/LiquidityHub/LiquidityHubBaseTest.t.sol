// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {Asset, SpokeData} from 'src/contracts/LiquidityHub.sol';

contract LiquidityHubBaseTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  // TODO: read from baseTest when resolved
  uint256 daiAssetId = 2;
  uint256 wbtcAssetId = 3;
  uint256 maxRiskPremiumRad = PercentageMath.PERCENTAGE_FACTOR.bpsToRad();

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

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_addSpoke() public {
    uint256 assetId = hub.assetCount();

    vm.expectEmit(address(hub));
    emit SpokeAdded(assetId, address(spoke1));
    hub.addSpoke(assetId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(spoke1));

    DataTypes.SpokeConfig memory spokeData = hub.getSpokeConfig(assetId, address(spoke1));
    assertEq(spokeData.supplyCap, 1, 'spoke supply cap');
    assertEq(spokeData.drawCap, 1, 'spoke draw cap');
  }

  function test_addSpoke_revertsWith_invalid_spoke() public {
    uint256 assetId = hub.assetCount();
    vm.expectRevert(TestErrors.INVALID_SPOKE);
    hub.addSpoke(assetId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(0));
  }

  function test_addSpokes() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig memory daiSpokeConfig = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
    DataTypes.SpokeConfig memory ethSpokeConfig = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = daiSpokeConfig;
    spokeConfigs[1] = ethSpokeConfig;

    vm.expectEmit(address(hub));
    emit SpokeAdded(daiAssetId, address(spoke1));
    emit SpokeAdded(wethAssetId, address(spoke1));
    hub.addSpokes(assetIds, spokeConfigs, address(spoke1));

    DataTypes.SpokeConfig memory daiSpokeData = hub.getSpokeConfig(daiAssetId, address(spoke1));
    DataTypes.SpokeConfig memory ethSpokeData = hub.getSpokeConfig(wethAssetId, address(spoke1));

    assertEq(daiSpokeData.supplyCap, daiSpokeConfig.supplyCap, 'dai spoke supply cap');
    assertEq(daiSpokeData.drawCap, daiSpokeConfig.drawCap, 'dai spoke draw cap');

    assertEq(ethSpokeData.supplyCap, ethSpokeConfig.supplyCap, 'eth spoke supply cap');
    assertEq(ethSpokeData.drawCap, ethSpokeConfig.drawCap, 'eth spoke draw cap');
  }

  function test_addSpokes_revertsWith_invalid_spoke() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
    spokeConfigs[1] = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

    vm.expectRevert(TestErrors.INVALID_SPOKE);
    hub.addSpokes(assetIds, spokeConfigs, address(0));
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
    uint256 riskPremiumRad,
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
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity on behalf of user
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: daiDrawAmount,
      riskPremiumRad: riskPremiumRad,
      onBehalfOf: address(spoke1)
    });
  }
}
