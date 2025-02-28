// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract HealthFactorTest is Base {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function setUp() public override {
    super.setUp();
    initEnvironment();

    updateCollateral(spoke1, spokeInfo[spoke1].dai.reserveId, true);
    updateCollateral(spoke1, spokeInfo[spoke1].weth.reserveId, true);
    updateCollateral(spoke1, spokeInfo[spoke1].usdx.reserveId, true);
    updateCollateral(spoke1, spokeInfo[spoke1].wbtc.reserveId, true);
  }

  function test_getHealthFactor_no_supplied() public view {
    // without any supply/borrow, health factor should be max
    uint256 healthFactor = spoke1.getHealthFactor(alice);
    assertEq(healthFactor, type(uint256).max, 'wrong health factor');
  }

  function test_getHealthFactor_no_borrowed() public {
    uint256 daiAmount = 100e18;

    // alice supply dai into spoke1
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(spoke1, _daiReserveId(spoke1), alice, daiAmount, alice);
    setUsingAsCollateral(spoke1, alice, spokeInfo[spoke1].dai.reserveId, true);

    uint256 healthFactor = spoke1.getHealthFactor(alice);
    assertEq(healthFactor, type(uint256).max, 'wrong health factor');
  }

  function test_getHealthFactor_single_borrowed_asset() public {
    uint256 daiAmount = 10_000e18; // 10k dai -> $10k
    uint256 wethAmount = 10e18; // 10 eth -> $20k
    // total collateral -> $30k
    uint256 usdxBorrowAmount = 15_000e6; // 15k usdx -> $15k

    // set Lt to 100% for both assets
    updateLiquidationThreshold(spoke1, spokeInfo[spoke1].dai.reserveId, 1e4);
    updateLiquidationThreshold(spoke1, spokeInfo[spoke1].weth.reserveId, 1e4);

    // alice supply dai into spoke1
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, alice, daiAmount, alice);
    setUsingAsCollateral(spoke1, alice, spokeInfo[spoke1].dai.reserveId, true);

    // alice supply eth into spoke1
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].weth.reserveId, alice, wethAmount, alice);
    setUsingAsCollateral(spoke1, alice, spokeInfo[spoke1].weth.reserveId, true);

    // bob supply usdc into spoke1
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].usdx.reserveId, bob, usdxBorrowAmount, bob);

    // alice borrow usdc
    Utils.spokeBorrow(spoke1, spokeInfo[spoke1].usdx.reserveId, alice, usdxBorrowAmount, alice);

    uint256 healthFactor = ISpoke(spoke1).getHealthFactor(alice);
    // uint256 expectedHF = _calculateHealthFactor([daiAssetId, wethAssetId, usdxAssetId]);
    assertEq(healthFactor, 2 * WadRayMath.WAD, 'wrong health factor');
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
    updateCollateral(spoke1, spokeInfo[spoke1].dai.reserveId, newCollateral);
    updateCollateral(spoke1, spokeInfo[spoke1].weth.reserveId, newCollateral);

    // alice supply dai into spoke1
    deal(address(tokenList.dai), alice, daiAmount);
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].dai.reserveId, alice, daiAmount, alice);
    setUsingAsCollateral(spoke1, alice, spokeInfo[spoke1].dai.reserveId, usingAsCollateral);

    // alice supply eth into spoke1
    deal(address(tokenList.weth), alice, wethAmount);
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].weth.reserveId, alice, wethAmount, alice);
    setUsingAsCollateral(spoke1, alice, spokeInfo[spoke1].weth.reserveId, usingAsCollateral);

    // bob supply usdc into spoke1
    deal(address(tokenList.usdx), bob, usdcBorrowAmount);
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].usdx.reserveId, bob, usdcBorrowAmount, bob);

    // bob supply wbtc into spoke1
    deal(address(tokenList.wbtc), bob, wbtcBorrowAmount);
    Utils.spokeSupply(spoke1, spokeInfo[spoke1].wbtc.reserveId, bob, wbtcBorrowAmount, bob);

    // alice borrow usdc
    Utils.spokeBorrow(spoke1, spokeInfo[spoke1].usdx.reserveId, alice, usdcBorrowAmount, alice);

    // alice borrow wbtc
    Utils.spokeBorrow(spoke1, spokeInfo[spoke1].wbtc.reserveId, alice, wbtcBorrowAmount, alice);

    uint256[] memory assetIds = new uint256[](4);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;
    assetIds[2] = usdxAssetId;
    assetIds[3] = wbtcAssetId;

    // initial health factor
    uint256 healthFactor = ISpoke(spoke1).getHealthFactor(alice);
    uint256 expectedHealthFactor = _calculateHealthFactor(spoke1, alice, assetIds);
    assertEq(healthFactor, expectedHealthFactor, 'wrong initial health factor');

    // prices change for supplied assets
    oracle.setAssetPrice(spokeInfo[spoke1].dai.reserveId, 2e8);
    oracle.setAssetPrice(spokeInfo[spoke1].weth.reserveId, 4000e8);
    // prices change for borrowed assets
    oracle.setAssetPrice(spokeInfo[spoke1].usdx.reserveId, 3e8);
    oracle.setAssetPrice(spokeInfo[spoke1].wbtc.reserveId, 70_000e8);

    // updated health factor
    healthFactor = ISpoke(spoke1).getHealthFactor(alice);
    // expectedHealthFactor = _calculateHealthFactor(assetIds);
    assertEq(healthFactor, 2 * WadRayMath.WAD, 'wrong final health factor');
  }

  function _calculateHealthFactor(
    Spoke spoke,
    address user,
    uint256[] memory reserveIds
  ) internal view returns (uint256) {
    uint256 totalCollateral = 0;
    uint256 totalDebt = 0;
    uint256 avgLiquidationThreshold = 0;
    for (uint256 i = 0; i < reserveIds.length; i++) {
      // uint256 reserveId = reserveIds[i];
      // uint256 assetPrice = oracle.getAssetPrice(assetId);
      // uint256 userCollateral = hub.convertToAssets(
      //   assetId,
      //   spoke1.getUserSupplyAmount(reserveId, alice)
      // ) * assetPrice;
      // totalCollateral += userCollateral;
      // totalDebt += userConfig.debt * assetPrice;
      // avgLiquidationThreshold +=
      //   userCollateral *
      //   spoke1.getLiquidationThreshold(reserveInfo[spoke1][assetId].reserveId);
    }

    avgLiquidationThreshold = totalCollateral != 0 ? avgLiquidationThreshold / totalCollateral : 0;
    return
      totalDebt == 0
        ? type(uint256).max
        : (totalCollateral.percentMul(avgLiquidationThreshold)).wadDiv(totalDebt);
  }

  function _daiReserveId(Spoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].dai.reserveId;
  }
}
