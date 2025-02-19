// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';

contract SpokeUserRiskPremiumTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_getUserRiskPremium_no_collateral() public view {
    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, 0, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_single_asset_collateral() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 daiAmount = 100e18;
    bool usingAsCollateral = true;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, daiReserveId, usingAsCollateral);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, 0, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_single_asset_collateral_borrowed() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 supplyAmount = 100e18;
    uint256 borrowAmount = 50e18;
    bool usingAsCollateral = true;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, supplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, daiReserveId, usingAsCollateral);
    Utils.spokeBorrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    Spoke.Reserve memory daiInfo = spoke1.getReserve(daiReserveId);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(userRiskPremium, daiInfo.config.liquidityPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_fuzz_single_asset_collateral_borrowed_amount(
    uint256 borrowAmount
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 supplyAmount = borrowAmount * 2;
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    bool usingAsCollateral = true;

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, supplyAmount);
    Utils.spokeSupply(spoke1, daiReserveId, bob, supplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, daiReserveId, usingAsCollateral);
    Utils.spokeBorrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    Spoke.Reserve memory daiInfo = spoke1.getReserve(daiReserveId);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(userRiskPremium, daiInfo.config.liquidityPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_fuzz_supply_does_not_impact(
    uint256 borrowAmount,
    uint256 additionalSupplyAmount
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    additionalSupplyAmount = bound(additionalSupplyAmount, 1, MAX_SUPPLY_AMOUNT);

    uint256 supplyAmount = borrowAmount * 2;
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    bool usingAsCollateral = true;

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, supplyAmount);
    Utils.spokeSupply(spoke1, daiReserveId, bob, supplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, daiReserveId, usingAsCollateral);
    Utils.spokeBorrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    Spoke.Reserve memory daiInfo = spoke1.getReserve(daiReserveId);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(userRiskPremium, daiInfo.config.liquidityPremium, 'wrong user risk premium');

    // Supplying more risky asset (usdx) should not impact user risk premium
    Utils.spokeSupply(spoke1, usdxReserveId, bob, additionalSupplyAmount, bob);
    assertEq(spoke1.getUserRiskPremium(bob), userRiskPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_multi_asset_collateral() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiSupplyAmount = 1000e18;
    uint256 usdxSupplyAmount = 1000e18;
    uint256 wethSupplyAmount = 1000e18;

    bool usingAsCollateral = true;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, daiReserveId, usingAsCollateral);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, usdxReserveId, bob, usdxSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, usdxReserveId, usingAsCollateral);

    // Bob supply weth into spoke1
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, wethReserveId, usingAsCollateral);

    // Bob draw 2000 total dai + usdx
    Utils.spokeBorrow(spoke1, daiReserveId, bob, daiSupplyAmount, bob);
    Utils.spokeBorrow(spoke1, usdxReserveId, bob, usdxSupplyAmount, bob);

    Spoke.Reserve memory daiInfo = spoke1.getReserve(daiReserveId);
    Spoke.Reserve memory usdxInfo = spoke1.getReserve(usdxReserveId);
    Spoke.Reserve memory wethInfo = spoke1.getReserve(wethReserveId);

    // Weth is enough to cover the total debt
    uint256 expectedUserRiskPremium = wethInfo.config.liquidityPremium;

    Spoke.UserConfig memory userConfig = spoke1.getUser(daiReserveId, bob);
    assertEq(userConfig.suppliedShares, hub.convertToSharesDown(daiAssetId, daiSupplyAmount));
    assertEq(userConfig.baseDebt, daiSupplyAmount);

    userConfig = spoke1.getUser(usdxReserveId, bob);
    assertEq(userConfig.suppliedShares, hub.convertToSharesDown(usdxAssetId, usdxSupplyAmount));
    assertEq(userConfig.baseDebt, usdxSupplyAmount);

    userConfig = spoke1.getUser(wethReserveId, bob);
    assertEq(userConfig.suppliedShares, hub.convertToSharesDown(wethAssetId, wethSupplyAmount));
    assertEq(userConfig.baseDebt, 0);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, expectedUserRiskPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_multi_asset_collateral_weth_partial_cover() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiSupplyAmount = 2000e18;
    uint256 usdxSupplyAmount = 2000e18;
    uint256 wethSupplyAmount = 1e18;

    bool usingAsCollateral = true;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, daiReserveId, usingAsCollateral);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, usdxReserveId, bob, usdxSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, usdxReserveId, usingAsCollateral);

    // Bob supply weth into spoke1
    Utils.spokeSupply(spoke1, wethReserveId, bob, wethSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, wethReserveId, usingAsCollateral);

    // Bob draw 2000 total dai + usdx
    Utils.spokeBorrow(spoke1, daiReserveId, bob, daiSupplyAmount, bob);
    Utils.spokeBorrow(spoke1, usdxReserveId, bob, usdxSupplyAmount, bob);

    Spoke.Reserve memory daiInfo = spoke1.getReserve(daiReserveId);
    Spoke.Reserve memory usdxInfo = spoke1.getReserve(usdxReserveId);
    Spoke.Reserve memory wethInfo = spoke1.getReserve(wethReserveId);

    Spoke.UserConfig memory userConfig = spoke1.getUser(daiReserveId, bob);
    assertEq(userConfig.suppliedShares, hub.convertToSharesDown(daiAssetId, daiSupplyAmount));
    assertEq(userConfig.baseDebt, daiSupplyAmount);

    userConfig = spoke1.getUser(usdxReserveId, bob);
    assertEq(userConfig.suppliedShares, hub.convertToSharesDown(usdxAssetId, usdxSupplyAmount));
    assertEq(userConfig.baseDebt, usdxSupplyAmount);

    userConfig = spoke1.getUser(wethReserveId, bob);
    assertEq(userConfig.suppliedShares, hub.convertToSharesDown(wethAssetId, wethSupplyAmount));
    assertEq(userConfig.baseDebt, 0);

    assertEq(wethSupplyAmount * oracle.getAssetPrice(wethAssetId), 2000e26, 'weth supply amount');
    assertEq(daiSupplyAmount * oracle.getAssetPrice(daiAssetId), 2000e26, 'dai supply amount');

    // Weth covers half the debt, dai covers the rest
    uint256 expectedUserRiskPremium = (wethInfo.config.liquidityPremium *
      wethSupplyAmount *
      oracle.getAssetPrice(wethAssetId) +
      daiInfo.config.liquidityPremium *
      daiSupplyAmount *
      oracle.getAssetPrice(daiAssetId)) /
      (wethSupplyAmount *
        oracle.getAssetPrice(wethAssetId) +
        daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId));

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, expectedUserRiskPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_two_assets_equal_parts() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 daiSupplyAmount = 2000e18;
    uint256 usdxSupplyAmount = 6000e18;
    uint256 wethSupplyAmount = 10e18;

    uint256 wethBorrowAmount = 2e18;

    bool usingAsCollateral = true;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, daiReserveId, usingAsCollateral);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, usdxReserveId, bob, usdxSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, usdxReserveId, usingAsCollateral);

    // Alice supply weth into spoke1
    Utils.spokeSupply(spoke1, wethReserveId, alice, wethSupplyAmount, alice);
    Utils.setUsingAsCollateral(spoke1, alice, wethReserveId, usingAsCollateral);

    // Bob draw $4000 total in weth
    Utils.spokeBorrow(spoke1, wethReserveId, bob, wethBorrowAmount, bob);

    Spoke.Reserve memory daiInfo = spoke1.getReserve(daiReserveId);
    Spoke.Reserve memory usdxInfo = spoke1.getReserve(usdxReserveId);
    Spoke.Reserve memory wethInfo = spoke1.getReserve(wethReserveId);

    Spoke.UserConfig memory userConfig = spoke1.getUser(daiReserveId, bob);
    assertEq(userConfig.suppliedShares, hub.convertToSharesDown(daiAssetId, daiSupplyAmount));
    assertEq(userConfig.baseDebt, 0);

    userConfig = spoke1.getUser(usdxReserveId, bob);
    assertEq(userConfig.suppliedShares, hub.convertToSharesDown(usdxAssetId, usdxSupplyAmount));
    assertEq(userConfig.baseDebt, 0);

    userConfig = spoke1.getUser(wethReserveId, bob);
    assertEq(userConfig.baseDebt, wethBorrowAmount);

    userConfig = spoke1.getUser(wethReserveId, alice);
    assertEq(userConfig.suppliedShares, hub.convertToSharesDown(wethAssetId, wethSupplyAmount));

    // Dai and usdx will each cover half the debt
    uint256 expectedUserRiskPremium = (daiInfo.config.liquidityPremium *
      2000e18 *
      oracle.getAssetPrice(daiAssetId) +
      usdxInfo.config.liquidityPremium *
      2000e18 *
      oracle.getAssetPrice(usdxAssetId)) /
      (2000e18 * oracle.getAssetPrice(daiAssetId) + 2000e18 * oracle.getAssetPrice(usdxAssetId));

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, expectedUserRiskPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_fuzz_two_assets_diff_amounts(uint256 daiSupplyAmount) public {
    // Dai lp to account for up to 100% of the debt value
    daiSupplyAmount = bound(daiSupplyAmount, 1, 4000e18);
    uint256 usdxLpContributionAmount = 4000e18 - daiSupplyAmount;

    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 usdxSupplyAmount = 6000e18;
    uint256 wethSupplyAmount = 10e18;

    uint256 wethBorrowAmount = 2e18;

    bool usingAsCollateral = true;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, daiReserveId, usingAsCollateral);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, usdxReserveId, bob, usdxSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, usdxReserveId, usingAsCollateral);

    // Alice supply weth into spoke1
    Utils.spokeSupply(spoke1, wethReserveId, alice, wethSupplyAmount, alice);
    Utils.setUsingAsCollateral(spoke1, alice, wethReserveId, usingAsCollateral);

    // Bob draw $4000 total in weth
    Utils.spokeBorrow(spoke1, wethReserveId, bob, wethBorrowAmount, bob);

    Spoke.Reserve memory daiInfo = spoke1.getReserve(daiReserveId);
    Spoke.Reserve memory usdxInfo = spoke1.getReserve(usdxReserveId);
    Spoke.Reserve memory wethInfo = spoke1.getReserve(wethReserveId);

    // Dai and usdx will each cover half the debt
    uint256 expectedUserRiskPremium = (daiInfo.config.liquidityPremium *
      daiSupplyAmount *
      oracle.getAssetPrice(daiAssetId) +
      usdxInfo.config.liquidityPremium *
      usdxLpContributionAmount *
      oracle.getAssetPrice(usdxAssetId)) /
      (daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        usdxLpContributionAmount *
        oracle.getAssetPrice(usdxAssetId));

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, expectedUserRiskPremium, 'wrong user risk premium');
  }

  // TODO: A mix of 4 of the assets, weighted avg of the four

  /*
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
  */

  // TODO: Test multiple assets with different liquidity premiums
  // TODO: Fuzz multiple asset amounts with diff liquidity premiums

  // TODO: Test where we change one of the liquidity premiums to make our current data structure out of order to ensure ordering works
}
