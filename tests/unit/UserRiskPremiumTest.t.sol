// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract UserRiskPremiumTest_ToMigrate is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function setUp() public override {
    vm.skip(true, 'pending spoke migration');

    super.setUp();
  }

  function test_getUserRiskPremium_no_collateral() public view {
    uint256 userRiskPremium = ISpoke(spoke1).getUserRiskPremium(USER1);
    assertEq(userRiskPremium, 0, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_single_asset_collateral() public {
    uint256 daiId = 0;
    uint256 daiAmount = 100e18;
    bool newCollateral = true;
    bool usingAsCollateral = true;

    // ensure DAI allowed as collateral
    Utils.updateCollateral(spoke1, daiId, newCollateral);

    // USER1 supply dai into spoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(spoke1, USER1, daiId, usingAsCollateral);

    uint256 userRiskPremium = ISpoke(spoke1).getUserRiskPremium(USER1);
    assertEq(userRiskPremium, 1e18, 'wrong user risk premium'); // TODO: fix when LP is implemented
  }

  function test_getUserRiskPremium_multi_asset_collateral() public {
    uint256 daiId = 0;
    uint256 ethId = 1;

    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    bool newCollateral = true;
    bool usingAsCollateral = true;

    // ensure DAI allowed as collateral
    Utils.updateCollateral(spoke1, daiId, newCollateral);
    Utils.updateCollateral(spoke1, ethId, newCollateral);

    // USER1 supply dai into spoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(spoke1, USER1, daiId, usingAsCollateral);

    // USER1 supply eth into spoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(hub, spoke1, ethId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(spoke1, USER1, ethId, usingAsCollateral);

    uint256 userRiskPremium = ISpoke(spoke1).getUserRiskPremium(USER1);
    assertEq(userRiskPremium, 1e18, 'wrong user risk premium'); // TODO: fix when LP is implemented
  }

  function test_getUserRiskPremium_asset_price_changes() public {
    uint256 daiId = 0;
    uint256 ethId = 1;

    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 ethAmount = 10e18; // 10 eth -> $20k
    // total collateral -> $30k
    bool newCollateral = true;
    bool usingAsCollateral = true;

    // ensure DAI/ETH allowed as collateral
    Utils.updateCollateral(spoke1, daiId, newCollateral);
    Utils.updateCollateral(spoke1, ethId, newCollateral);

    // USER1 supply dai into spoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(hub, spoke1, daiId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(spoke1, USER1, daiId, usingAsCollateral);

    // USER1 supply eth into spoke1
    deal(address(eth), USER1, ethAmount);
    Utils.spokeSupply(hub, spoke1, ethId, USER1, ethAmount, USER1);
    Utils.setUsingAsCollateral(spoke1, USER1, ethId, usingAsCollateral);

    uint256[] memory assetIds = new uint256[](4);
    assetIds[0] = daiId;
    assetIds[1] = ethId;

    // initial user risk premium
    uint256 userRiskPremium = ISpoke(spoke1).getUserRiskPremium(USER1);
    uint256 expectedUserRiskPremium = _calculateUserRiskPremium(assetIds);
    assertEq(userRiskPremium, expectedUserRiskPremium, 'wrong expected user risk premium');

    // prices change for supplied eth
    oracle.setAssetPrice(daiId, 2e8);
    oracle.setAssetPrice(ethId, 4000e8);

    // initial user risk premium
    userRiskPremium = ISpoke(spoke1).getUserRiskPremium(USER1);
    expectedUserRiskPremium = _calculateUserRiskPremium(assetIds);
    assertEq(userRiskPremium, expectedUserRiskPremium, 'wrong expected user risk premium');
  }

  function _calculateUserRiskPremium(uint256[] memory assetIds) internal view returns (uint256) {
    uint256 totalCollateral = 0;
    uint256 userRiskPremium = 0;
    for (uint256 i = 0; i < assetIds.length; i++) {
      uint256 assetId = assetIds[i];
      Spoke.UserConfig memory userConfig = spoke1.getUser(assetId, USER1);

      // uint256 assetPrice = oracle.getAssetPrice(assetId);
      // uint256 userCollateral = hub.convertToAssetsDown(assetId, userConfig.supplyShares) *
      //   assetPrice;
      // uint256 liquidityPremium = 1; // TODO: get LP from LH
      // userRiskPremium += userCollateral * liquidityPremium;
      // totalCollateral += userCollateral;
    }
    return totalCollateral != 0 ? userRiskPremium.wadDiv(totalCollateral) : 0;
  }
}
