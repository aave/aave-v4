// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract HealthFactorTest_ToMigrate is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function setUp() public override {
    vm.skip(true, 'pending spoke migration');
    super.setUp();
  }

  function test_getHealthFactor_no_supplied() public view {
    // without any supply/borrow, health factor should be max
    uint256 healthFactor = spoke1.getHealthFactor(USER1);
    assertEq(healthFactor, type(uint256).max, 'wrong health factor');
  }

  function test_getHealthFactor_no_borrowed() public {
    uint256 daiAmount = 100e18;
    bool newCollateral = true;
    bool usingAsCollateral = true;

    // ensure DAI allowed as collateral
    Utils.updateCollateral(spoke1, spokeInfo[spoke1].dai.reserveId, newCollateral);

    // USER1 supply dai into spoke1
    deal(address(tokenList.dai), USER1, daiAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(spoke1, USER1, spokeInfo[spoke1].dai.reserveId, usingAsCollateral);

    uint256 healthFactor = spoke1.getHealthFactor(USER1);
    assertEq(healthFactor, type(uint256).max, 'wrong health factor');
  }

  function test_getHealthFactor_single_borrowed_asset() public {
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 wethAmount = 10e18; // 10 eth -> $20k
    // total collateral -> $30k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    bool newCollateral = true;
    bool usingAsCollateral = true;

    // ensure DAI/ETH allowed as collateral
    Utils.updateCollateral(spoke1, spokeInfo[spoke1].dai.reserveId, newCollateral);
    Utils.updateCollateral(spoke1, spokeInfo[spoke1].weth.reserveId, newCollateral);

    // set Lt to 100% for both assets
    Utils.updateLiquidationThreshold(spoke1, spokeInfo[spoke1].dai.reserveId, 1e4);
    Utils.updateLiquidationThreshold(spoke1, spokeInfo[spoke1].weth.reserveId, 1e4);

    // USER1 supply dai into spoke1
    deal(address(dai), USER1, daiAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(spoke1, USER1, spokeInfo[spoke1].dai.reserveId, usingAsCollateral);

    // USER1 supply eth into spoke1
    deal(address(eth), USER1, wethAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].weth.reserveId, USER1, wethAmount, USER1);
    Utils.setUsingAsCollateral(spoke1, USER1, spokeInfo[spoke1].weth.reserveId, usingAsCollateral);

    // USER2 supply usdc into spoke1
    deal(address(usdc), USER2, usdcBorrowAmount);
    Utils.spokeSupply(
      hub,
      spoke1,
      spokeInfo[spoke1].usdx.reserveId,
      USER2,
      usdcBorrowAmount,
      USER2
    );

    // USER1 borrow usdc
    Utils.borrow(spoke1, spokeInfo[spoke1].usdx.reserveId, USER1, usdcBorrowAmount, USER1);

    uint256 healthFactor = ISpoke(spoke1).getHealthFactor(USER1);
    assertEq(healthFactor, 2e18, 'wrong health factor');
  }

  function test_getHealthFactor_multi_asset_price_changes() public {
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 wethAmount = 10e18; // 10 eth -> $20k
    // total collateral -> $30k
    uint256 usdcBorrowAmount = 15_000e18; // 15k usdc -> $15k
    uint256 wbtcBorrowAmount = 0.5e18; // 0.5 wbtc -> $25k
    // total borrowed -> $40k
    bool newCollateral = true;
    bool usingAsCollateral = true;

    // ensure DAI/ETH allowed as collateral
    Utils.updateCollateral(spoke1, spokeInfo[spoke1].dai.reserveId, newCollateral);
    Utils.updateCollateral(spoke1, spokeInfo[spoke1].weth.reserveId, newCollateral);

    // USER1 supply dai into spoke1
    deal(address(tokenList.dai), USER1, daiAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, USER1, daiAmount, USER1);
    Utils.setUsingAsCollateral(spoke1, USER1, spokeInfo[spoke1].dai.reserveId, usingAsCollateral);

    // USER1 supply eth into spoke1
    deal(address(tokenList.weth), USER1, wethAmount);
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].weth.reserveId, USER1, wethAmount, USER1);
    Utils.setUsingAsCollateral(spoke1, USER1, spokeInfo[spoke1].weth.reserveId, usingAsCollateral);

    // USER2 supply usdc into spoke1
    deal(address(tokenList.usdx), USER2, usdcBorrowAmount);
    Utils.spokeSupply(
      hub,
      spoke1,
      spokeInfo[spoke1].usdx.reserveId,
      USER2,
      usdcBorrowAmount,
      USER2
    );

    // USER2 supply wbtc into spoke1
    deal(address(tokenList.wbtc), USER2, wbtcBorrowAmount);
    Utils.spokeSupply(
      hub,
      spoke1,
      spokeInfo[spoke1].wbtc.reserveId,
      USER2,
      wbtcBorrowAmount,
      USER2
    );

    // USER1 borrow usdc
    Utils.borrow(spoke1, spokeInfo[spoke1].usdx.reserveId, USER1, usdcBorrowAmount, USER1);

    // USER1 borrow wbtc
    Utils.borrow(spoke1, spokeInfo[spoke1].wbtc.reserveId, USER1, wbtcBorrowAmount, USER1);

    uint256[] memory assetIds = new uint256[](4);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;
    assetIds[2] = usdxAssetId;
    assetIds[3] = wbtcAssetId;

    // initial health factor
    uint256 healthFactor = ISpoke(spoke1).getHealthFactor(USER1);
    uint256 expectedHealthFactor = _calculateHealthFactor(assetIds);
    assertEq(healthFactor, expectedHealthFactor, 'wrong initial health factor');

    // prices change for supplied assets
    oracle.setAssetPrice(spokeInfo[spoke1].dai.reserveId, 2e8);
    oracle.setAssetPrice(spokeInfo[spoke1].weth.reserveId, 4000e8);
    // prices change for borrowed assets
    oracle.setAssetPrice(spokeInfo[spoke1].usdx.reserveId, 3e8);
    oracle.setAssetPrice(spokeInfo[spoke1].wbtc.reserveId, 70_000e8);

    // updated health factor
    healthFactor = ISpoke(spoke1).getHealthFactor(USER1);
    expectedHealthFactor = _calculateHealthFactor(assetIds);
    assertEq(healthFactor, expectedHealthFactor, 'wrong final health factor');
  }

  function _calculateHealthFactor(uint256[] memory assetIds) internal view returns (uint256) {
    uint256 totalCollateral = 0;
    uint256 totalDebt = 0;
    uint256 avgLiquidationThreshold = 0;
    for (uint256 i = 0; i < assetIds.length; i++) {
      uint256 assetId = assetIds[i];
      // Spoke.Reserve memory reserve = spoke1.getReserve(spokeInfo[spoke1][assetId].reserveId);
      // Spoke.UserConfig memory userConfig = spoke1.getUser(
      //   reserveInfo[spoke1][assetId].reserveId,
      //   USER1
      // );

      // uint256 assetPrice = oracle.getAssetPrice(assetId);
      // uint256 userCollateral = hub.convertToAssetsDown(assetId, userConfig.supplyShares) *
      //   assetPrice;
      // totalCollateral += userCollateral;
      // totalDebt += userConfig.debt * assetPrice;

      // avgLiquidationThreshold += userCollateral * reserve.config.lt;
    }
    avgLiquidationThreshold = totalCollateral != 0 ? avgLiquidationThreshold / totalCollateral : 0;
    return
      totalDebt == 0
        ? type(uint256).max
        : (totalCollateral.percentMul(avgLiquidationThreshold)).wadDiv(totalDebt);
  }
}
